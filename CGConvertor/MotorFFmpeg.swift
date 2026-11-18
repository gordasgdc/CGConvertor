import Foundation

/// Erori posibile la rularea FFmpeg
enum EroareFFmpeg: LocalizedError {
    case binarNegasit
    case esecProces(cod: Int32, mesaj: String)
    case anulat

    var errorDescription: String? {
        switch self {
        case .binarNegasit:
            return "FFmpeg nu a fost gasit. Instaleaza-l cu Homebrew: brew install ffmpeg"
        case .esecProces(let cod, let mesaj):
            return "FFmpeg a esuat (cod \(cod)): \(mesaj)"
        case .anulat:
            return "Anulat de utilizator."
        }
    }
}

/// Handle intors de `ruleazaConversie`, ca apelantul sa poata opri
/// conversia in curs (buton "Opreste" din UI) — tine o referinta slaba la
/// procesul FFmpeg activ in acel moment (primul sau al doilea pas, cel de
/// injectare timecode), ca `anuleaza()` sa il termine pe oricare ruleaza.
final class ConversieHandle {
    fileprivate weak var procesActiv: Process?
    private var esteAnulat = false

    func anuleaza() {
        esteAnulat = true
        procesActiv?.terminate()
    }

    fileprivate var aFostAnulat: Bool { esteAnulat }
}

/// Gaseste si ruleaza binarul FFmpeg instalat prin Homebrew
final class MotorFFmpeg {

    /// Cauta ffmpeg, in ordine: (1) copie descarcata manual prin Managerul
    /// de Dependinte (DependencyManager) — verificata INTAI, ca un download
    /// nou sa aiba mereu prioritate fata de un bundle posibil stricat;
    /// (2) binarul bundle-uit in aplicatie (self-contained, build static);
    /// (3) Homebrew, ca fallback pentru un mediu de dezvoltare.
    static func gasesteBinar() -> String? {
        // 1. Descarcat prin Managerul de Dependinte (~/Library/Application Support/CGConvertor/bin/)
        if let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let caleDescarcata = support.appendingPathComponent("\(AppIsolation.folderName)/bin/ffmpeg").path
            if FileManager.default.isExecutableFile(atPath: caleDescarcata) {
                return caleDescarcata
            }
        }

        // 2. In bundle-ul aplicatiei (Resources/ffmpeg) — build static, self-contained
        if let caleBundle = Bundle.main.path(forResource: "ffmpeg", ofType: nil) {
            if FileManager.default.fileExists(atPath: caleBundle) {
                return caleBundle
            }
        }

        // 3. Locatii standard Homebrew (Apple Silicon si Intel) — fallback
        let caiPosibile = [
            "/opt/homebrew/bin/ffmpeg",   // Apple Silicon
            "/usr/local/bin/ffmpeg",      // Intel Mac
            "/usr/bin/ffmpeg"
        ]
        for cale in caiPosibile {
            if FileManager.default.fileExists(atPath: cale) {
                return cale
            }
        }
        return nil
    }

    /// Returneaza durata clipului in secunde, folosind ffprobe (vine cu ffmpeg)
    static func durataClip(url: URL) -> Double? {
        guard let ffmpegPath = gasesteBinar() else { return nil }
        let ffprobePath = ffmpegPath.replacingOccurrences(of: "ffmpeg", with: "ffprobe")
        guard FileManager.default.fileExists(atPath: ffprobePath) else { return nil }

        let proces = Process()
        proces.executableURL = URL(fileURLWithPath: ffprobePath)
        proces.arguments = [
            "-v", "error",
            "-show_entries", "format=duration",
            "-of", "default=noprint_wrappers=1:nokey=1",
            url.path
        ]
        let pipe = Pipe()
        proces.standardOutput = pipe
        proces.standardError = Pipe()

        do {
            try proces.run()
            proces.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               let durata = Double(text) {
                return durata
            }
        } catch {
            return nil
        }
        return nil
    }

    /// Extrage timecode-ul de start al clipului sursa (din track-ul QuickTime TC sau tag-ul global)
    /// Format intors: "HH:MM:SS:FF" sau "HH:MM:SS;FF" (drop-frame), exact cum il citeste FFmpeg cu -timecode
    static func timecodeSursa(url: URL) -> String? {
        guard let ffmpegPath = gasesteBinar() else { return nil }
        let ffprobePath = ffmpegPath.replacingOccurrences(of: "ffmpeg", with: "ffprobe")
        guard FileManager.default.fileExists(atPath: ffprobePath) else { return nil }

        let proces = Process()
        proces.executableURL = URL(fileURLWithPath: ffprobePath)
        // Cauta tag-ul "timecode": intai pe stream-ul dedicat de tip 'data' (track QuickTime TC),
        // apoi ca fallback pe format_tags (metadata globala a containerului)
        proces.arguments = [
            "-v", "error",
            "-select_streams", "d",
            "-show_entries", "stream_tags=timecode:format_tags=timecode",
            "-of", "default=noprint_wrappers=1:nokey=1",
            url.path
        ]
        let pipe = Pipe()
        proces.standardOutput = pipe
        proces.standardError = Pipe()

        do {
            try proces.run()
            proces.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let text = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               !text.isEmpty {
                // Daca apar mai multe linii (format + stream), ia prima valoare ne-goala
                let primaLinie = text.split(separator: "\n").first(where: { !$0.isEmpty })
                return primaLinie.map(String.init)
            }
        } catch {
            return nil
        }
        return nil
    }

    /// Extensia de container pentru un preset (Faza 1 v3.0.0) — "mov"
    /// pentru Rewrap, altfel containerul definit in FormatRegistry.
    static func extensieContainer(pentru preset: OutputPreset) -> String {
        if preset.profileID == FormatRegistry.rewrapProfileID { return "mov" }
        return FormatRegistry.profile(id: preset.profileID)?.container ?? "mov"
    }

    /// Construieste argumentele FFmpeg pentru un preset (Presets Manager,
    /// Faza 1 v3.0.0) — inlocuieste vechiul cuplu `mod`/`codec`.
    static func construiesteArgumente(job: VideoJob, preset: OutputPreset, destinatie: URL,
                                      pastreazaLog: Bool = false, interval: (start: Double, durata: Double)? = nil) -> [String] {
        var args: [String] = ["-y"]
        // Interval: -ss ca optiune de intrare (decodare + re-encode = exact pe cadru), -t limiteaza
        // IMAGINEA SI SUNETUL impreuna, ca raman sincronizate.
        if let iv = interval { args += ["-ss", String(format: "%.6f", iv.start)] }
        args += ["-i", job.urlSursa.path]
        if let iv = interval { args += ["-t", String(format: "%.6f", iv.durata)] }

        if preset.profileID == FormatRegistry.rewrapProfileID {
            // Rewrap: doar schimbare container, fara re-encode — foarte rapid
            // -c copy pastreaza automat audio in bit depth-ul original (16/24/32 bit, PCM sau orice)
            args += ["-c", "copy"]
        } else if let profil = FormatRegistry.profile(id: preset.profileID) {
            // Re-encode complet folosind profilul ales pentru video
            args += profil.ffmpegArgs
            // Cadre/s la iesire (2026-09-05) — nil pastreaza fps-ul sursei,
            // comportamentul de dinainte. Doar la transcodare (Rewrap
            // foloseste -c copy mai sus, fara re-encode posibil).
            if let fps = preset.frameRate, !fps.isEmpty {
                args += ["-r", fps]
            }
            // Etichetare spatiu de culoare (2026-09-05) — doar tag-uri
            // container/VUI, nu transformare reala a pixelilor (scop
            // confirmat explicit inainte de implementare).
            if let colorSpace = preset.colorSpace {
                args += colorSpace.ffmpegArgs
            } else if pastreazaLog {
                // Imaginea ramane Log (nicio transformare): containerul nu trebuie sa
                // afirme primarii/transfer Rec.709 pe care camera le-a pus din
                // obisnuinta. Matricea YCbCr ramane cea reala; profilul adevarat al
                // capturii e in pistele native si in raport (nu are cod in `colr`).
                args += ["-vf", "setparams=color_primaries=unknown:color_trc=unknown"]
            }
            // Audio: dupa AudioMode-ul presetului (Passthrough implicit —
            // pastreaza exact bit depth-ul sursei; presetele de livrare
            // web re-codeaza explicit in AAC, cu layout de canale ales).
            args += preset.audioMode.ffmpegArgs
            if preset.audioMode != .passthrough {
                args += preset.channelLayout.ffmpegArgs
            }
            // Track-ul de Timecode QuickTime e un "data stream" — trebuie copiat explicit, altfel se pierde la transcode
            args += ["-c:d", "copy"]
            args += profil.extraMuxArgs
        }

        // Pastreaza timecode-ul original (track-ul QuickTime TC din container)
        // -map_metadata 0 copiaza toate metadatele globale
        // -map 0 include toate track-urile sursei: video, audio, timecode
        // -ignore_unknown evita oprirea daca sursa are un track pe care encoder-ul nu-l recunoaste
        // Nota: -timecode NU e pus aici — prores_videotoolbox il ignora la encode.
        //       Timecode-ul e injectat corect intr-un pas 2 separat cu -c copy, dupa transcode.
        args += ["-map_metadata", "0"]
        // Doar video + audio: pistele de date (tmcd/cndm/rtmd) nu se copiaza
        // prin FFmpeg (le pierde sau le strica); timecode-ul se scrie in pasul 2,
        // pistele native se grefeaza in pasul 3 (TrackGrafter).
        args += ["-map", "0:v", "-map", "0:a?"]
        args.append(destinatie.path)
        return args
    }

    /// Ruleaza conversia unui singur job, raportand progresul prin callback (0.0 - 1.0).
    /// Intoarce un `ConversieHandle` — apelantul il poate folosi ca sa
    /// anuleze conversia in curs (`.anuleaza()`).
    ///
    /// Etape (toate pe fisiere temporare langa destinatie; destinatia
    /// apare DOAR dupa verificare, deci un fisier partial nu e niciodata
    /// prezentat ca rezultat final):
    ///   1. transcodare/rewrap (video + audio),
    ///   2. injectare timecode (re-wrap fara re-encode),
    ///   3. grefare piste native (cndm/rtmd) — dupa ULTIMA reimpachetare,
    ///   4. verificare (cadre, audio, durata, timecode, piste) si mutare.
    @discardableResult
    static func ruleazaConversie(
        job: VideoJob,
        preset: OutputPreset,
        destinatie: URL,
        pastreazaMetadate: Bool = true,
        scrieSidecar: Bool = true,
        progresCallback: @escaping (Double) -> Void,
        finalizareCallback: @escaping (Result<ConversionReport, Error>) -> Void
    ) -> ConversieHandle {
        let handle = ConversieHandle()
        guard let ffmpegPath = gasesteBinar() else {
            StructuredLog.shared.log(.error, "convert", "job.fail", "FFmpeg lipseste", job: StructuredLog.newID(), error: EroareFFmpeg.binarNegasit)
            finalizareCallback(.failure(EroareFFmpeg.binarNegasit))
            return handle
        }
        DispatchQueue.global(qos: .userInitiated).async {
            let rezultat: Result<ConversionReport, Error>
            let jobID = StructuredLog.newID()
            let t0 = Date()
            let log = StructuredLog.shared
            log.log(.info, "convert", "job.start", "Conversie pornita",
                    job: jobID, fields: ["preset": preset.id, "metadata": pastreazaMetadate ? "on" : "off",
                                         "sidecar": scrieSidecar ? "on" : "off", "src": Redactor.pathToken(job.urlSursa.path)])
            do {
                rezultat = .success(try executaPipeline(
                    job: job, preset: preset, destinatie: destinatie, ffmpegPath: ffmpegPath,
                    pastreazaMetadate: pastreazaMetadate, scrieSidecar: scrieSidecar, handle: handle,
                    progres: { p in DispatchQueue.main.async { progresCallback(p) } }))
            } catch {
                rezultat = .failure(error)
            }
            let ms = String(Int(Date().timeIntervalSince(t0) * 1000))
            switch rezultat {
            case .success(let r):
                log.log(r.metadata == .incomplete ? .warning : .info, "convert", "job.finish", "Conversie terminata",
                        job: jobID, fields: ["ms": ms, "metadata": "\(r.metadata)", "grafted": "\(r.grafted.count)",
                                             "frames": "\(r.framesOutput ?? -1)",
                                             "problems": r.metadataProblems.map { $0.key }.joined(separator: ",")])
            case .failure(let e):
                if case EroareFFmpeg.anulat = e {
                    log.log(.info, "convert", "job.cancel", "Conversie anulata de utilizator", job: jobID, fields: ["ms": ms])
                } else {
                    log.log(.error, "convert", "job.fail", "Conversie esuata", job: jobID, fields: ["ms": ms], error: e)
                }
            }
            DispatchQueue.main.async { finalizareCallback(rezultat) }
        }
        return handle
    }

    private static func executaPipeline(
        job: VideoJob, preset: OutputPreset, destinatie: URL, ffmpegPath: String,
        pastreazaMetadate: Bool, scrieSidecar: Bool, handle: ConversieHandle, progres: @escaping (Double) -> Void
    ) throws -> ConversionReport {
        let fm = FileManager.default
        let dir = destinatie.deletingLastPathComponent()
        let baza = destinatie.deletingPathExtension().lastPathComponent
        let ext = destinatie.pathExtension
        let tmp1 = dir.appendingPathComponent(".\(baza).cgc-1.\(ext)")
        let tmp2 = dir.appendingPathComponent(".\(baza).cgc-2.\(ext)")
        var raport = ConversionReport()
        defer { try? fm.removeItem(at: tmp1); try? fm.removeItem(at: tmp2) }
        try? fm.removeItem(at: tmp1); try? fm.removeItem(at: tmp2)

        // Originalul nu se modifica: retinem marimea/data ca sa o putem dovedi.
        let atrSursa = try? fm.attributesOfItem(atPath: job.urlSursa.path)

        // Timecode: nucleul GDC Metadata (stie drop-frame la Sony, unde ffprobe raporteaza non-drop);
        // rezerva = ffprobe.
        let profilSursa = MetadataCore.scan(job.urlSursa)
        var tcSursa = profilSursa?.timecode ?? timecodeSursa(url: job.urlSursa)
        raport.timecodeSource = tcSursa
        raport.sourceProfile = profilSursa
        var durataTotala = durataClip(url: job.urlSursa) ?? 0
        let sursa = rezumatFluxuri(url: job.urlSursa)

        // Interval ales: limite aliniate la cadre, doar la transcodare (rewrap = -c copy nu taie exact pe cadru).
        var interval: (start: Double, durata: Double)?
        var cadreAsteptate: Int?
        if job.areInterval {
            guard preset.profileID != FormatRegistry.rewrapProfileID else {
                throw EroareConversie.verificareEsuata(L.t("interval.needsTranscode"))
            }
            guard let fps = sursa?.fps, let dur = sursa?.durata, fps > 0 else {
                throw EroareConversie.verificareEsuata(L.t("interval.unreadable"))
            }
            let f0 = Int(((job.intervalStart ?? 0) * fps).rounded())
            let f1 = Int(((min(job.intervalEnd ?? dur, dur)) * fps).rounded())
            guard f0 >= 0, f1 > f0 else { throw EroareConversie.verificareEsuata(L.t("interval.invalid")) }
            interval = (Double(f0) / fps, Double(f1 - f0) / fps)
            cadreAsteptate = f1 - f0
            durataTotala = Double(f1 - f0) / fps
            if let tc = tcSursa {
                let nou = TimecodeMath.offset(tc, frames: f0, fps: fps)
                tcSursa = nou
                raport.timecodeSource = nou
                if nou == nil { raport.metadataProblems.append(.init(key: "report.tcFailed", arg: tc)) }
            }
            raport.interval = .init(startFrame: f0, frames: f1 - f0, fps: fps)
        }
        raport.framesSource = sursa?.cadre
        raport.audioStreamsSource = sursa?.audio ?? 0
        raport.durationSource = sursa?.durata

        // Pasul 1: transcodare / rewrap principal
        var ultimeleLinii = ""
        let cod1 = try ruleazaProces(ffmpegPath, construiesteArgumente(job: job, preset: preset, destinatie: tmp1,
                                                                  pastreazaLog: profilSursa?.curve.map { Self.esteLog($0.value) } ?? false,
                                                                  interval: interval),
                                     handle: handle) { text in
            ultimeleLinii = String((ultimeleLinii + text).suffix(2000))
            if durataTotala > 0, let t = extrageTimp(din: text) {
                progres(min(t / durataTotala, 1.0) * 0.9)
            }
        }
        if handle.aFostAnulat { throw EroareFFmpeg.anulat }
        guard cod1 == 0 else {
            let linii = ultimeleLinii.split(separator: "\n").suffix(5).joined(separator: " ")
            throw EroareFFmpeg.esecProces(cod: cod1, mesaj: linii)
        }
        var curent = tmp1

        // Pasul 2: timecode prin re-wrap rapid (prores_videotoolbox ignora -timecode la encode)
        if let tc = tcSursa {
            let cod2 = try ruleazaProces(ffmpegPath, [
                "-y", "-i", tmp1.path, "-c", "copy", "-map", "0:v", "-map", "0:a?",
                "-map_metadata", "0", "-timecode", tc, tmp2.path], handle: handle, onStderr: nil)
            if handle.aFostAnulat { throw EroareFFmpeg.anulat }
            if cod2 == 0 { curent = tmp2 }
            else { raport.metadataProblems.append(.init(key: "report.tcFailed", arg: tc)) }
        }
        progres(0.93)

        // Pasul 3: piste native, DUPA ultima reimpachetare
        let conversieNeschimbata = preset.frameRate == nil && preset.colorSpace == nil
        if !pastreazaMetadate {
            raport.metadata = .off
        } else if ext.lowercased() != "mov" {
            raport.metadata = .nothingToCarry
            raport.notKept.append(.init(key: "report.nativeNeedsMov", arg: ext))
        } else if !conversieNeschimbata {
            raport.metadata = .nothingToCarry
            let motiv = preset.colorSpace != nil ? "report.reasonColorRelabel" : "report.reasonFrameRate"
            raport.notKept.append(.init(key: "report.nativeSkipped", arg: motiv))
        } else {
            do {
                let g = try TrackGrafter.graft(source: job.urlSursa, into: curent, start: interval?.start ?? 0, duration: interval?.durata)
                raport.grafted = g.tracks
                let probleme = try TrackGrafter.verify(report: g, source: job.urlSursa, output: curent, start: interval?.start ?? 0, duration: interval?.durata)
                if !probleme.isEmpty {
                    raport.metadata = .incomplete
                    for p in probleme { raport.metadataProblems.append(.init(key: "report.graftVerify", arg: p)) }
                } else {
                    raport.metadata = g.tracks.isEmpty ? .nothingToCarry : .complete
                    for t in g.tracks { raport.kept.append(.init(key: "report.keptTrack", arg: "\(t.fourcc) · \(t.sampleCount)")) }
                }
            } catch {
                raport.metadata = .incomplete
                raport.metadataProblems.append(.init(key: "report.graftFailed", arg: error.localizedDescription))
            }
        }
        if preset.profileID != FormatRegistry.rewrapProfileID, preset.colorSpace == nil,
           let c = profilSursa?.curve, esteLog(c.value) {
            raport.kept.append(.init(key: "report.colorTagsNeutral", arg: c.value))
        }
        if !raport.metadataProblems.isEmpty && raport.metadata != .off { raport.metadata = .incomplete }
        progres(0.97)

        // Pasul 4: verificare independenta a rezultatului
        let iesire = rezumatFluxuri(url: curent)
        raport.framesOutput = iesire?.cadre
        raport.audioStreamsOutput = iesire?.audio ?? 0
        raport.durationOutput = iesire?.durata
        raport.timecodeOutput = tcSursa == nil ? nil : timecodeSursa(url: curent)
        if preset.frameRate == nil, let a = cadreAsteptate ?? raport.framesSource, let b = raport.framesOutput, a != b {
            throw EroareConversie.verificareEsuata("Numar de cadre diferit: asteptat \(a), rezultat \(b).")
        }
        if raport.audioStreamsOutput < raport.audioStreamsSource, preset.audioMode == .passthrough {
            throw EroareConversie.verificareEsuata("Piste audio lipsa: sursa \(raport.audioStreamsSource), rezultat \(raport.audioStreamsOutput).")
        }
        if let a = tcSursa, raport.timecodeOutput != a {
            raport.metadataProblems.append(.init(key: "report.tcMismatch", arg: "\(a) → \(raport.timecodeOutput ?? "—")"))
            raport.metadata = .incomplete
        } else if let a = tcSursa {
            raport.kept.insert(.init(key: "report.keptTimecode", arg: a), at: 0)
        }

        // Originalul trebuie sa fie neatins.
        if let a = atrSursa, let b = try? fm.attributesOfItem(atPath: job.urlSursa.path),
           (a[.size] as? NSNumber) != (b[.size] as? NSNumber) || (a[.modificationDate] as? Date) != (b[.modificationDate] as? Date) {
            throw EroareConversie.verificareEsuata("Originalul pare modificat in timpul conversiei.")
        }

        // Finalizare: destinatia apare doar acum.
        try? fm.removeItem(at: destinatie)
        try fm.moveItem(at: curent, to: destinatie)

        // Sidecar (alternativa pentru ce Resolve nu citeste din fisier)
        if pastreazaMetadate && scrieSidecar && profilSursa != nil {
            do {
                _ = try MetadataCore.writeSidecar(source: job.urlSursa, output: destinatie,
                                                   kept: raport.kept.map { $0.text }, notKept: raport.notKept.map { $0.text })
                raport.kept.append(.init(key: "report.keptSidecar", arg: ""))
            } catch {
                raport.metadata = .incomplete
                raport.metadataProblems.append(.init(key: "report.sidecarFailed", arg: error.localizedDescription))
            }
        }
        progres(1.0)
        return raport
    }

    /// Curba detectata e de tip Log/Film (nu Rec.709/sRGB/gamma simpla).
    static func esteLog(_ curve: String) -> Bool {
        let c = curve.lowercased()
        return c.contains("log") || c.contains("film")
    }

    /// Ruleaza un proces si asteapta; stderr se transmite pe masura ce vine.
    private static func ruleazaProces(_ exe: String, _ args: [String], handle: ConversieHandle,
                                      onStderr: ((String) -> Void)?) throws -> Int32 {
        let proces = Process()
        proces.executableURL = URL(fileURLWithPath: exe)
        proces.arguments = args
        let pipe = Pipe()
        proces.standardError = pipe
        proces.standardOutput = Pipe()
        pipe.fileHandleForReading.readabilityHandler = { fh in
            let d = fh.availableData
            guard !d.isEmpty, let t = String(data: d, encoding: .utf8) else { return }
            onStderr?(t)
        }
        handle.procesActiv = proces
        if handle.aFostAnulat { throw EroareFFmpeg.anulat }
        try proces.run()
        proces.waitUntilExit()
        pipe.fileHandleForReading.readabilityHandler = nil
        return proces.terminationStatus
    }

    struct RezumatFluxuri { let cadre: Int?; let audio: Int; let durata: Double?; var fps: Double? = nil }

    /// Numar de cadre video (din container), piste audio si durata, prin ffprobe.
    static func rezumatFluxuri(url: URL) -> RezumatFluxuri? {
        guard let ffmpegPath = gasesteBinar() else { return nil }
        let ffprobePath = ffmpegPath.replacingOccurrences(of: "ffmpeg", with: "ffprobe")
        let p = Process()
        p.executableURL = URL(fileURLWithPath: ffprobePath)
        p.arguments = ["-v", "error", "-show_entries", "stream=codec_type,nb_frames,r_frame_rate:format=duration",
                       "-of", "json", url.path]
        let pipe = Pipe(); p.standardOutput = pipe; p.standardError = Pipe()
        guard (try? p.run()) != nil else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        guard let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        let streams = (j["streams"] as? [[String: Any]]) ?? []
        let video = streams.first { ($0["codec_type"] as? String) == "video" }
        let cadre = (video?["nb_frames"] as? String).flatMap(Int.init)
        let audio = streams.filter { ($0["codec_type"] as? String) == "audio" }.count
        let durata = ((j["format"] as? [String: Any])?["duration"] as? String).flatMap(Double.init)
        var fps: Double?
        if let r = video?["r_frame_rate"] as? String {
            let q = r.split(separator: "/").compactMap { Double($0) }
            if q.count == 2, q[1] > 0 { fps = q[0] / q[1] }
        }
        return RezumatFluxuri(cadre: cadre, audio: audio, durata: durata, fps: fps)
    }

    /// Extrage timpul curent (in secunde) dintr-o linie de output FFmpeg de forma "time=00:01:23.45"
    private static func extrageTimp(din text: String) -> Double? {
        guard let rangeTime = text.range(of: "time=") else { return nil }
        let dupaTime = text[rangeTime.upperBound...]
        guard let rangeSpatiu = dupaTime.firstIndex(of: " ") else { return nil }
        let valoareTimp = String(dupaTime[..<rangeSpatiu])

        let componente = valoareTimp.split(separator: ":")
        guard componente.count == 3,
              let ore = Double(componente[0]),
              let minute = Double(componente[1]),
              let secunde = Double(componente[2]) else { return nil }

        return ore * 3600 + minute * 60 + secunde
    }
}
