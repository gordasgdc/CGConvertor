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
    /// Clipurile incluse în rularea curentă și momentul pornirii (pentru progres total, viteză, timp estimat).
    @Published private(set) var multimeRulare: Set<UUID> = []
    private(set) var startRulare: Date?
    private var destinatiiRezervate: Set<String> = []

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
            let job = VideoJob(urlSursa: url)
            joburi.append(job)
            analizeazaFisier(job.id, url: url)
        }
    }

    /// Inspecție/Metadata profundă + thumbnail (Faza 2) — pornită automat
    /// la adăugare, rulează pe fundal (`Task.detached`), NU pe MainActor
    /// (ffprobe/ffmpeg pot dura câteva sute de ms pe fișiere mari) — starea
    /// jobului se actualizează abia la final, pe MainActor.
    private func analizeazaFisier(_ jobID: UUID, url: URL) {
        BackgroundWork.run {
            let meta = MediaInspector.probe(url: url)
            let thumbURL = MediaInspector.folderThumbnailuri().appendingPathComponent(jobID.uuidString + ".jpg")
            let thumbOK = MediaInspector.genereazaThumbnail(url: url, lutPath: nil, iesire: thumbURL)
            Task { @MainActor [weak self] in
                guard let self, let idx = self.joburi.firstIndex(where: { $0.id == jobID }) else { return }
                self.joburi[idx].metadataMedia = meta
                if thumbOK { self.joburi[idx].caleThumbnail = thumbURL.path }
            }
        }
    }

    /// Raport HTML per lot (Faza 2) — un singur fișier auto-conținut
    /// (thumbnail-uri ca data URI base64, ca la precedentul din `DataMover`)
    /// cu toate joburile din coada curentă: thumbnail, metadata, status.
    /// NEIMPLEMENTAT deliberat: varianta PDF — vezi CLAUDE.md pentru motiv
    /// (ar necesita o dependință nouă de layout PDF, neverificată încă).
    func genereazaRaportHTML() -> URL? {
        var randuri = ""
        for job in joburi {
            let thumbTag: String
            if let cale = job.caleThumbnail, let data = FileManager.default.contents(atPath: cale) {
                let base64 = data.base64EncodedString()
                thumbTag = "<img src=\"data:image/jpeg;base64,\(base64)\" width=\"160\">"
            } else {
                thumbTag = "<span class=\"muted\">—</span>"
            }
            let m = job.metadataMedia
            let metaText = [
                m?.rezolutieText,
                m?.codecVideo?.uppercased(),
                m?.frameRate.map { "\($0) fps" },
                m?.durataSecunde.map { String(format: "%.1fs", $0) },
                m?.codecAudio?.uppercased()
            ].compactMap { $0 }.joined(separator: " · ")
            let statusText: String
            switch job.stare {
            case .astept: statusText = "Așteaptă"
            case .inLucru(let p): statusText = String(format: "În lucru (%.0f%%)", p * 100)
            case .finalizat: statusText = "Finalizat"
            case .finalizatCuAvertisment(let mesaj): statusText = "Finalizat — ⚠ \(mesaj)"
            case .anulat: statusText = "Anulat"
            case .eroare(let mesaj): statusText = "Eroare: \(mesaj)"
            }
            randuri += """
            <tr>
              <td>\(thumbTag)</td>
              <td>\(job.numeFisier)</td>
              <td>\(metaText.isEmpty ? "—" : metaText)</td>
              <td>\(statusText)</td>
            </tr>
            """
        }

        let html = """
        <!DOCTYPE html><html><head><meta charset="utf-8">
        <title>Raport CG Convertor</title>
        <style>
        body{font-family:-apple-system,Helvetica,Arial,sans-serif;background:#14161A;color:#EDEFF2;padding:24px}
        h1{color:#E8963C}
        table{border-collapse:collapse;width:100%}
        td,th{border-bottom:1px solid #2B2F36;padding:10px;text-align:left;vertical-align:middle}
        .muted{color:#5C6169}
        .pdf-btn{position:fixed;top:16px;right:16px;background:#E8963C;color:#14161A;border:none;border-radius:6px;padding:8px 16px;font-size:13px;font-weight:600;cursor:pointer;z-index:100}
        .pdf-btn:hover{opacity:.85}
        @media print{
          .pdf-btn{display:none}
          body{background:#fff!important;color:#111!important}
          h1{color:#000!important}
          td,th{border-bottom:1px solid #ccc!important}
          .muted{color:#666!important}
        }
        </style></head><body>
        <button class="pdf-btn" onclick="window.print()">Descarcă PDF</button>
        <h1>Raport conversie — CG Convertor</h1>
        <p>\(joburi.count) fișiere · generat \(DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short))</p>
        <table><tr><th>Thumbnail</th><th>Fișier</th><th>Metadata</th><th>Status</th></tr>
        \(randuri)
        </table></body></html>
        """

        let iesire = FileManager.default.temporaryDirectory.appendingPathComponent("CGConvertor_Raport_\(Int(Date().timeIntervalSince1970)).html")
        do {
            try html.write(to: iesire, atomically: true, encoding: .utf8)
            return iesire
        } catch {
            return nil
        }
    }

    func seteazaInterval(_ job: VideoJob, start: Double?, end: Double?) {
        guard let i = joburi.firstIndex(where: { $0.id == job.id }) else { return }
        joburi[i].intervalStart = start
        joburi[i].intervalEnd = end
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

    // ── Configurare efectivă per clip (override explicit, altfel valoarea implicită din inspector) ──
    func presetEfectiv(_ job: VideoJob) -> OutputPreset? {
        if let id = job.presetOverrideID, let p = presets.first(where: { $0.id == id }) { return p }
        return presetSelectat
    }
    func sufixEfectiv(_ job: VideoJob) -> String {
        job.sufixOverride ?? presetEfectiv(job)?.fileSuffix ?? ""
    }
    func folderEfectiv(_ job: VideoJob) -> URL {
        job.destinatieOverride ?? folderDestinatie ?? job.urlSursa.deletingLastPathComponent()
    }
    /// Numele pe care îl va avea rezultatul, fără a ține cont de coliziuni (afișat ca exemplu în inspector).
    func numeRezultat(_ job: VideoJob) -> String {
        guard let preset = presetEfectiv(job) else { return job.numeFisier }
        let baza = job.urlSursa.deletingPathExtension().lastPathComponent
        return "\(baza)\(sufixEfectiv(job)).\(MotorFFmpeg.extensieContainer(pentru: preset))"
    }

    /// Ce se va produce pentru un set de clipuri: avertismente afișate înainte de pornire.
    struct Previzualizare {
        var clipuri = 0
        var existente = 0          // rezultate care ar exista deja și vor primi un nume nou (nu se suprascrie nimic)
        var peSursa = 0            // rezultate care ar coincide cu sursa
        var faraSpatiu: [String] = []
        var avertismente: [String] = []
    }
    func previzualizeaza(_ ids: Set<UUID>) -> Previzualizare {
        var r = Previzualizare()
        let fm = FileManager.default
        var folosite = Set<String>()
        var necesarPerVolum: [String: Int64] = [:]
        for job in joburi where ids.contains(job.id) {
            r.clipuri += 1
            guard let preset = presetEfectiv(job) else { continue }
            var p = preset; p.fileSuffix = sufixEfectiv(job)
            let d = urlDestinatieBrut(pentru: job, preset: p)
            if d == job.urlSursa { r.peSursa += 1 }
            if fm.fileExists(atPath: d.path) || folosite.contains(d.path) { r.existente += 1 }
            folosite.insert(d.path)
            if preset.profileID == FormatRegistry.rewrapProfileID, job.areInterval {
                r.avertismente.append(String(format: L.t("tw.warn.rewrapInterval"), job.numeFisier))
            }
            let dim = (try? job.urlSursa.resourceValues(forKeys: [.fileSizeKey]).fileSize).flatMap { $0 } ?? 0
            let vol = folderEfectiv(job).path
            necesarPerVolum[vol, default: 0] += Int64(dim) * (preset.profileID.hasPrefix("prores") ? 3 : 1)
        }
        for (vol, nec) in necesarPerVolum {
            if let lib = freeSpaceBytes(at: URL(fileURLWithPath: vol)), lib < nec {
                r.faraSpatiu.append((vol as NSString).lastPathComponent)
            }
        }
        if r.existente > 0 { r.avertismente.append(String(format: L.t("tw.warn.exists"), r.existente)) }
        if !r.faraSpatiu.isEmpty { r.avertismente.append(String(format: L.t("tw.warn.space"), r.faraSpatiu.joined(separator: ", "))) }
        return r
    }

    /// Aplică un preset / sufix / destinație pe clipurile indicate (None = revine la valoarea implicită).
    func aplicaPreset(_ id: String?, pe ids: Set<UUID>) {
        for i in joburi.indices where ids.contains(joburi[i].id) { joburi[i].presetOverrideID = id }
    }
    func aplicaSufix(_ sufix: String?, pe ids: Set<UUID>) {
        for i in joburi.indices where ids.contains(joburi[i].id) { joburi[i].sufixOverride = sufix }
    }
    func aplicaDestinatie(_ url: URL?, pe ids: Set<UUID>) {
        for i in joburi.indices where ids.contains(joburi[i].id) { joburi[i].destinatieOverride = url }
    }
    func marcheaza(_ ids: Set<UUID>, _ valoare: Bool) {
        for i in joburi.indices where ids.contains(joburi[i].id) { joburi[i].marcat = valoare }
    }

    /// Profilul de sursă (nucleul GDC Metadata), citit pe cerere pentru spațiul Metadate.
    func scaneazaProfil(_ job: VideoJob) {
        guard !job.scanTerminat else { return }
        let id = job.id, url = job.urlSursa
        BackgroundWork.run {
            let prof = MetadataCore.scan(url)
            Task { @MainActor [weak self] in
                guard let self, let i = self.joburi.firstIndex(where: { $0.id == id }) else { return }
                self.joburi[i].profilSursa = prof
                self.joburi[i].scanTerminat = true
            }
        }
    }

    // ── Progres total, viteză și timp estimat (doar când pot fi calculate credibil) ──
    var progresTotal: Double? {
        let j = joburi.filter { multimeRulare.contains($0.id) }
        guard !j.isEmpty else { return nil }
        let sum = j.reduce(0.0) { acc, x in
            switch x.stare {
            case .inLucru(let p): return acc + p
            case .finalizat, .finalizatCuAvertisment, .anulat, .eroare: return acc + 1
            case .astept: return acc
            }
        }
        return sum / Double(j.count)
    }
    /// Viteza ca multiplu al timpului real (secunde de material / secunde scurse); nil dacă durata nu e cunoscută.
    var vitezaRulare: Double? {
        guard let start = startRulare else { return nil }
        let scurs = Date().timeIntervalSince(start)
        guard scurs > 4 else { return nil }
        var material = 0.0
        for j in joburi where multimeRulare.contains(j.id) {
            guard let d = j.metadataMedia?.durataSecunde else { return nil }
            let dur = (j.intervalEnd ?? d) - (j.intervalStart ?? 0)
            switch j.stare {
            case .inLucru(let p): material += dur * p
            case .finalizat, .finalizatCuAvertisment: material += dur
            default: break
            }
        }
        return material > 0 ? material / scurs : nil
    }
    var timpRamas: TimeInterval? {
        guard let start = startRulare, let p = progresTotal, p > 0.05, p < 1 else { return nil }
        let scurs = Date().timeIntervalSince(start)
        guard scurs > 6 else { return nil }
        return scurs / p * (1 - p)
    }

    private func urlDestinatieBrut(pentru job: VideoJob, preset: OutputPreset) -> URL {
        let numeBaza = job.urlSursa.deletingPathExtension().lastPathComponent
        let extensie = MotorFFmpeg.extensieContainer(pentru: preset)
        return folderEfectiv(job).appendingPathComponent("\(numeBaza)\(preset.fileSuffix).\(extensie)")
    }

    /// Nu suprascrie niciodată o sursă sau un rezultat existent: dacă numele e ocupat, adaugă _2, _3…
    private func urlDestinatie(pentru job: VideoJob, preset: OutputPreset) -> URL {
        let brut = urlDestinatieBrut(pentru: job, preset: preset)
        let fm = FileManager.default
        var candidat = brut
        var n = 2
        while fm.fileExists(atPath: candidat.path) || destinatiiRezervate.contains(candidat.path) {
            let baza = brut.deletingPathExtension().lastPathComponent
            candidat = brut.deletingLastPathComponent()
                .appendingPathComponent("\(baza)_\(n)").appendingPathExtension(brut.pathExtension)
            n += 1
        }
        destinatiiRezervate.insert(candidat.path)
        return candidat
    }

    /// `doarSelectate` (2026-09-05, fix bug real raportat de Cristi: "dacă
    /// selectez doar una el transcodeaza tot, nu doar selecția") —
    /// reutilizează checkmark-urile deja existente pe fiecare rând
    /// (`selectedJobIDs` din `ContentView`, introduse pentru comparația de
    /// metadate) ca scop dublu: dacă userul a bifat 1+ fișiere, Start
    /// procesează DOAR pe acelea; dacă nu e bifat nimic, comportamentul
    /// rămâne neschimbat — toată coada, exact ca înainte.
    func pornesteCoada(doarSelectate: Set<UUID>? = nil) {
        guard !seRuleazaCoada, !joburi.isEmpty, let preset = presetSelectat else { return }
        guard ffmpegInstalat else { return }
        seRuleazaCoada = true
        estePauza = false
        stopTotal = false
        destinatiiRezervate.removeAll()

        // Procesare paralelă (Faza 1, secțiunea F): joburile deja
        // "in asteptare" sunt împărțite pe un număr limitat de sloturi
        // concurente — fiecare slot preia jobul următor disponibil de
        // îndată ce termină pe al lui, respectând pauza înainte de a
        // porni un job NOU (un job deja început termină natural).
        var indexUrmator = 0
        let coadaIndexuri: [Int]
        if let doarSelectate, !doarSelectate.isEmpty {
            coadaIndexuri = joburi.indices.filter { doarSelectate.contains(joburi[$0].id) }
        } else {
            coadaIndexuri = Array(joburi.indices)
        }
        let numarSloturi = min(joburiSimultane, max(1, coadaIndexuri.count))
        multimeRulare = Set(coadaIndexuri.map { joburi[$0].id })
        startRulare = Date()
        // Fiecare clip din rulare pornește curat (progresul total se calculează doar pe ele).
        for i in coadaIndexuri { joburi[i].stare = .astept; joburi[i].raport = nil }

        func porneseUrmatorul() {
            Task { @MainActor in
                await self.asteaptaDacaPauza()
                guard !self.stopTotal else { return }
                guard indexUrmator < coadaIndexuri.count else { return }
                let idx = coadaIndexuri[indexUrmator]
                indexUrmator += 1
                let jobCurent = self.joburi[idx]
                var presetJob = self.presetEfectiv(jobCurent) ?? preset
                presetJob.fileSuffix = self.sufixEfectiv(jobCurent)
                self.proceseaza(job: jobCurent, preset: presetJob) {
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
        for idx in joburi.indices where joburi[idx].stare == .astept && multimeRulare.contains(joburi[idx].id) {
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
            pastreazaMetadate: AppSettings.shared.preserveNativeMetadata,
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
                case .success(let raport):
                    self.joburi[idx].raport = raport
                    // Interval: conducta a verificat deja numarul exact de cadre asteptate; durata sursei nu mai e termenul de comparatie.
                    var stare = raport.interval != nil ? StareJob.finalizat : self.verificaIntegritate(sursa: job.urlSursa, destinatie: destinatie)
                    // Esec de pastrare a metadatelor != succes complet.
                    if stare == .finalizat, raport.metadata == .incomplete {
                        let motiv = raport.metadataProblems.map { "\($0.key) \($0.arg)" }.joined(separator: "; ")
                        stare = .finalizatCuAvertisment(mesaj: L.t("report.metadataIncomplete") + " " + motiv)
                    }
                    self.joburi[idx].stare = stare
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

    /// Verificare de siguranță post-conversie (2026-09-05, cerută explicit
    /// de Cristi — cod ieșire 0 la ffmpeg NU garantează un fișier complet;
    /// o trunchiere/corupere silențioasă tot ar apărea ca "succes" fără
    /// asta). Compară durata sursă vs. destinație via ffprobe (`durataClip`,
    /// deja folosit pentru bara de progres) — o toleranță de 1s absoarbe
    /// rotunjirile normale de containere/framerate, nu maschează o
    /// trunchiere reală (de obicei diferențe de zeci de secunde sau mai
    /// mult). Dacă ffprobe nu poate citi durata (fișier neobișnuit/fără
    /// track video clar), NU raportăm eroare — am verifica ceva ce nu
    /// putem măsura, deci rămâne "finalizat" simplu (fail-open, ca restul
    /// verificărilor opționale din aplicație).
    private func verificaIntegritate(sursa: URL, destinatie: URL) -> StareJob {
        guard let durataSursa = MotorFFmpeg.durataClip(url: sursa),
              let durataDestinatie = MotorFFmpeg.durataClip(url: destinatie) else {
            return .finalizat
        }
        let diferenta = abs(durataSursa - durataDestinatie)
        guard diferenta > 1.0 else { return .finalizat }
        let mesaj = String(format: L.t("queue.integrityMismatch"), durataSursa, durataDestinatie)
        return .finalizatCuAvertisment(mesaj: mesaj)
    }

    private func verificaFinalizareaCozii() {
        // Coada s-a terminat cand TOATE joburile au o stare finala
        // (finalizat/anulat/eroare) — NICIODATA cand sunt inca "in
        // asteptare" (.astept), care nu inseamna "gata", doar "neinceput
        // inca". Apelat dupa fiecare job finalizat (nu o singura data la
        // capatul unei bucle secventiale, ca la varianta anterioara).
        guard seRuleazaCoada, handleuriActive.isEmpty else { return }
        let toateAuStareFinala = joburi.filter { multimeRulare.contains($0.id) }.allSatisfy { job in
            switch job.stare {
            case .finalizat, .finalizatCuAvertisment, .anulat, .eroare: return true
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
