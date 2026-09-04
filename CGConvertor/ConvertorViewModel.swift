import Foundation
import SwiftUI
import Combine

@MainActor
final class ConvertorViewModel: ObservableObject {
    @Published var joburi: [VideoJob] = []
    @Published var presets: [OutputPreset]
    @Published var presetSelectatID: String {
        didSet { UserDefaults.standard.set(presetSelectatID, forKey: Self.cheiePreset) }
    }
    @Published var folderDestinatie: URL? {
        didSet { UserDefaults.standard.set(folderDestinatie?.path, forKey: Self.cheieDestinatie) }
    }
    @Published var seRuleazaCoada: Bool = false
    @Published var estePauza: Bool = false
    @Published var ffmpegInstalat: Bool = MotorFFmpeg.gasesteBinar() != nil

    /// Joburi simultane (Faza 1, secțiunea F) — configurabil din Setări,
    /// implicit 1 (un singur VideoToolbox session e adesea limitarea
    /// reală a plăcii pe encodere hardware; CPU/software beneficiază de
    /// mai multe simultan).
    var joburiSimultane: Int {
        max(1, min(4, AppSettings.shared.maxParallelJobs))
    }

    private static let cheiePreset = "cgconvertor_last_preset_id"
    private static let cheieDestinatie = "cgconvertor_last_destination"

    var presetSelectat: OutputPreset? {
        presets.first(where: { $0.id == presetSelectatID }) ?? presets.first
    }

    /// Handle-urile active — un job per handle, ca "Oprește" să poată
    /// termina TOATE joburile în curs, nu doar unul (procesare paralelă).
    private var handleuriActive: [UUID: ConversieHandle] = [:]
    private var stopTotal = false

    init() {
        let defaults = UserDefaults.standard
        // Fix compilator: citirea altei proprietati @Published (`presets`)
        // in aceeasi initializare, chiar dupa ce a fost asignata, declanseaza
        // "used before being initialized" (analiza definite-initialization
        // e conservatoare cu accesori de property wrapper inainte ca TOATE
        // proprietatile clasei sa fie setate) - se ocoleste citind dintr-o
        // variabila locala, nu din `self.presets` propriu-zis.
        let presetariIncarcate = PresetsManager.load()
        presets = presetariIncarcate
        presetSelectatID = defaults.string(forKey: Self.cheiePreset) ?? presetariIncarcate.first?.id ?? ""
        folderDestinatie = defaults.string(forKey: Self.cheieDestinatie).map(URL.init(fileURLWithPath:))
    }

    func verificaFFmpeg() {
        ffmpegInstalat = MotorFFmpeg.gasesteBinar() != nil
    }

    func reincarcaPresets() {
        presets = PresetsManager.load()
        if presetSelectat == nil { presetSelectatID = presets.first?.id ?? "" }
    }

    func adaugaFisiere(_ urlURIs: [URL]) {
        for url in urlURIs {
            guard !joburi.contains(where: { $0.urlSursa == url }) else { continue }
            joburi.append(VideoJob(urlSursa: url))
        }
    }

    func stergeJob(_ job: VideoJob) {
        // Nu sterge jobul aflat efectiv in lucru — ar lasa procesul FFmpeg
        // sa scrie orfan, fara nimic in UI care sa-l reflecte. Foloseste
        // "Opreste" pentru asta.
        if case .inLucru = job.stare { return }
        joburi.removeAll { $0.id == job.id }
    }

    func golesteLista() {
        guard !seRuleazaCoada else { return }
        joburi.removeAll()
    }

    /// Reordonare (Faza 1, secțiunea F) — mută un job cu `delta` poziții
    /// (`-1` sus, `+1` jos); dezactivat cât timp coada rulează.
    func mutaJob(_ job: VideoJob, delta: Int) {
        guard !seRuleazaCoada, let idx = joburi.firstIndex(where: { $0.id == job.id }) else { return }
        let newIdx = idx + delta
        guard newIdx >= 0, newIdx < joburi.count else { return }
        joburi.swapAt(idx, newIdx)
    }

    func alegeFolderDestinatie() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Alege folder"
        if panel.runModal() == .OK {
            folderDestinatie = panel.url
        }
    }

    private func urlDestinatie(pentru job: VideoJob, preset: OutputPreset) -> URL {
        let numeBaza = job.urlSursa.deletingPathExtension().lastPathComponent
        let extensie = MotorFFmpeg.extensieContainer(pentru: preset)
        let folder = folderDestinatie ?? job.urlSursa.deletingLastPathComponent()
        return folder.appendingPathComponent("\(numeBaza)\(preset.fileSuffix).\(extensie)")
    }

    func pornesteCoada() {
        guard !seRuleazaCoada, !joburi.isEmpty, let preset = presetSelectat else { return }
        guard ffmpegInstalat else { return }
        seRuleazaCoada = true
        estePauza = false
        stopTotal = false

        // Procesare paralelă (Faza 1, secțiunea F): joburile deja
        // "in asteptare" sunt împărțite pe un număr limitat de sloturi
        // concurente — fiecare slot preia jobul următor disponibil de
        // îndată ce termină pe al lui, respectând pauza înainte de a
        // porni un job NOU (un job deja început termină natural).
        var indexUrmator = 0
        let coadaIndexuri = Array(joburi.indices)
        let numarSloturi = min(joburiSimultane, max(1, coadaIndexuri.count))

        func porneseUrmatorul() {
            Task { @MainActor in
                await self.asteaptaDacaPauza()
                guard !self.stopTotal else { return }
                guard indexUrmator < coadaIndexuri.count else { return }
                let idx = coadaIndexuri[indexUrmator]
                indexUrmator += 1
                self.proceseaza(job: self.joburi[idx], preset: preset) {
                    porneseUrmatorul()
                }
            }
        }

        for _ in 0..<numarSloturi {
            porneseUrmatorul()
        }
    }

    private func asteaptaDacaPauza() async {
        while estePauza && !stopTotal {
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
    }

    func comutaPauza() {
        estePauza.toggle()
    }

    /// Oprește TOTAL — termină toate joburile active (spre deosebire de
    /// pauză, care doar oprește pornirea jobului următor).
    func opresteCoada() {
        stopTotal = true
        estePauza = false
        for handle in handleuriActive.values {
            handle.anuleaza()
        }
        // Joburile inca ne-pornite (in "asteptare", niciun slot liber nu
        // a ajuns inca la ele) nu vor mai fi preluate niciodata de
        // `porneseUrmatorul()` odata ce `stopTotal` e true — marcate
        // direct "Anulat", altfel ar ramane vesnic "In asteptare" si
        // `verificaFinalizareaCozii()` n-ar inchide niciodata coada.
        for idx in joburi.indices where joburi[idx].stare == .astept {
            joburi[idx].stare = .anulat
        }
        verificaFinalizareaCozii()
    }

    private func proceseaza(job: VideoJob, preset: OutputPreset, laFinalizare: @escaping () -> Void) {
        guard let idx = joburi.firstIndex(where: { $0.id == job.id }) else {
            laFinalizare()
            return
        }
        if stopTotal {
            laFinalizare()
            return
        }

        let destinatie = urlDestinatie(pentru: job, preset: preset)
        joburi[idx].urlDestinatie = destinatie
        joburi[idx].stare = .inLucru(progres: 0)

        let handle = MotorFFmpeg.ruleazaConversie(
            job: job,
            preset: preset,
            destinatie: destinatie,
            progresCallback: { [weak self] progres in
                guard let self else { return }
                guard let idx = self.joburi.firstIndex(where: { $0.id == job.id }) else { return }
                self.joburi[idx].stare = .inLucru(progres: progres)
            },
            finalizareCallback: { [weak self] rezultat in
                guard let self else { return }
                self.handleuriActive.removeValue(forKey: job.id)
                guard let idx = self.joburi.firstIndex(where: { $0.id == job.id }) else {
                    laFinalizare()
                    return
                }
                switch rezultat {
                case .success:
                    self.joburi[idx].stare = .finalizat
                case .failure(let eroare):
                    if case EroareFFmpeg.anulat = eroare {
                        self.joburi[idx].stare = .anulat
                    } else {
                        self.joburi[idx].stare = .eroare(mesaj: eroare.localizedDescription)
                    }
                }
                self.verificaFinalizareaCozii()
                laFinalizare()
            }
        )
        handleuriActive[job.id] = handle
    }

    private func verificaFinalizareaCozii() {
        // Coada s-a terminat cand TOATE joburile au o stare finala
        // (finalizat/anulat/eroare) — NICIODATA cand sunt inca "in
        // asteptare" (.astept), care nu inseamna "gata", doar "neinceput
        // inca". Apelat dupa fiecare job finalizat (nu o singura data la
        // capatul unei bucle secventiale, ca la varianta anterioara).
        guard seRuleazaCoada, handleuriActive.isEmpty else { return }
        let toateAuStareFinala = joburi.allSatisfy { job in
            switch job.stare {
            case .finalizat, .anulat, .eroare: return true
            case .astept, .inLucru: return false
            }
        }
        if toateAuStareFinala {
            seRuleazaCoada = false
            estePauza = false
        }
    }
}

#if canImport(AppKit)
import AppKit
#endif
