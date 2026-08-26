import Foundation
import SwiftUI
import Combine

@MainActor
final class ConvertorViewModel: ObservableObject {
    @Published var joburi: [VideoJob] = []
    @Published var modConversie: ModConversie {
        didSet { UserDefaults.standard.set(modConversie.rawValue, forKey: Self.cheieMod) }
    }
    @Published var codecAles: CodecOutput {
        didSet { UserDefaults.standard.set(codecAles.rawValue, forKey: Self.cheieCodec) }
    }
    @Published var folderDestinatie: URL? {
        didSet { UserDefaults.standard.set(folderDestinatie?.path, forKey: Self.cheieDestinatie) }
    }
    @Published var seRuleazaCoada: Bool = false
    @Published var ffmpegInstalat: Bool = MotorFFmpeg.gasesteBinar() != nil

    // Portat din varianta Python (config.py, settings persistate) — Swift-ul
    // native reseta mereu ultimele alegeri la fiecare lansare, spre
    // deosebire de Python care le ținea minte (mod/codec/folder). Acum
    // ambele variante se comportă identic.
    private static let cheieMod = "cgconvertor_last_mode"
    private static let cheieCodec = "cgconvertor_last_codec"
    private static let cheieDestinatie = "cgconvertor_last_destination"

    private var indexCurent: Int = 0
    private var handleCurent: ConversieHandle?

    init() {
        let defaults = UserDefaults.standard
        modConversie = defaults.string(forKey: Self.cheieMod).flatMap(ModConversie.init(rawValue:)) ?? .rewrap
        codecAles = defaults.string(forKey: Self.cheieCodec).flatMap(CodecOutput.init(rawValue:)) ?? .proRes422HQ
        folderDestinatie = defaults.string(forKey: Self.cheieDestinatie).map(URL.init(fileURLWithPath:))
    }

    func verificaFFmpeg() {
        ffmpegInstalat = MotorFFmpeg.gasesteBinar() != nil
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

    /// Portat din Python (`main.py._clear_list`, care ignora apelul cat
    /// timp `self.is_running`) — varianta Swift originala nu avea aceasta
    /// garda, deci "Goleste lista" apasat in timpul unei conversii active
    /// ar fi lasat procesul FFmpeg sa scrie intr-un fisier disparut din UI.
    func golesteLista() {
        guard !seRuleazaCoada else { return }
        joburi.removeAll()
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

    private func urlDestinatie(pentru job: VideoJob) -> URL {
        let numeBaza = job.urlSursa.deletingPathExtension().lastPathComponent
        let extensie = modConversie == .rewrap ? "mov" : codecAles.extensieContainer
        let folder = folderDestinatie ?? job.urlSursa.deletingLastPathComponent()
        return folder.appendingPathComponent("\(numeBaza)_convertit.\(extensie)")
    }

    func pornesteCoada() {
        guard !seRuleazaCoada, !joburi.isEmpty else { return }
        guard ffmpegInstalat else { return }
        seRuleazaCoada = true
        indexCurent = 0
        proceseazaUrmatorul()
    }

    /// Portat din Python (`Converter.stop()`/`_stop_requested`) — varianta
    /// Swift originala nu putea opri o coada in curs de procesare deloc.
    /// Oprește doar jobul curent; restul cozii rămâne "În așteptare" (nu
    /// se șterge), utilizatorul poate reporni ulterior.
    func opresteCoada() {
        handleCurent?.anuleaza()
        seRuleazaCoada = false
    }

    private func proceseazaUrmatorul() {
        guard indexCurent < joburi.count else {
            seRuleazaCoada = false
            handleCurent = nil
            return
        }

        let job = joburi[indexCurent]
        let destinatie = urlDestinatie(pentru: job)
        joburi[indexCurent].urlDestinatie = destinatie
        joburi[indexCurent].stare = .inLucru(progres: 0)

        handleCurent = MotorFFmpeg.ruleazaConversie(
            job: job,
            mod: modConversie,
            codec: codecAles,
            destinatie: destinatie,
            progresCallback: { [weak self] progres in
                guard let self else { return }
                guard let idx = self.joburi.firstIndex(where: { $0.id == job.id }) else { return }
                self.joburi[idx].stare = .inLucru(progres: progres)
            },
            finalizareCallback: { [weak self] rezultat in
                guard let self else { return }
                guard let idx = self.joburi.firstIndex(where: { $0.id == job.id }) else { return }
                switch rezultat {
                case .success:
                    self.joburi[idx].stare = .finalizat
                case .failure(let eroare):
                    if case EroareFFmpeg.anulat = eroare {
                        self.joburi[idx].stare = .anulat
                        self.handleCurent = nil
                        return // nu continua coada — utilizatorul a apasat Opreste
                    }
                    self.joburi[idx].stare = .eroare(mesaj: eroare.localizedDescription)
                }
                self.indexCurent += 1
                self.proceseazaUrmatorul()
            }
        )
    }
}

#if canImport(AppKit)
import AppKit
#endif
