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
            let caleDescarcata = support.appendingPathComponent("CGConvertor/bin/ffmpeg").path
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

    /// Construieste argumentele FFmpeg in functie de modul de conversie ales
    static func construiesteArgumente(job: VideoJob, mod: ModConversie, codec: CodecOutput, destinatie: URL) -> [String] {
        var args: [String] = ["-y", "-i", job.urlSursa.path]

        switch mod {
        case .rewrap:
            // Doar schimbare container, fara re-encode — foarte rapid
            // -c copy pastreaza automat audio in bit depth-ul original (16/24/32 bit, PCM sau orice)
            args += ["-c", "copy"]
        case .transcode:
            // Re-encode complet folosind codecul ales pentru video
            args += codec.ffmpegArgs
            // Audio: copiat 1:1, fara re-encode — pastreaza exact bit depth-ul sursei (16/24/32-bit float etc.)
            args += ["-c:a", "copy"]
            // Track-ul de Timecode QuickTime e un "data stream" — trebuie copiat explicit, altfel se pierde la transcode
            args += ["-c:d", "copy"]
        }

        // Pastreaza timecode-ul original (track-ul QuickTime TC din container)
        // -map_metadata 0 copiaza toate metadatele globale
        // -map 0 include toate track-urile sursei: video, audio, timecode
        // -ignore_unknown evita oprirea daca sursa are un track pe care encoder-ul nu-l recunoaste
        // Nota: -timecode NU e pus aici — prores_videotoolbox il ignora la encode.
        //       Timecode-ul e injectat corect intr-un pas 2 separat cu -c copy, dupa transcode.
        args += ["-map_metadata", "0"]
        args += ["-map", "0", "-ignore_unknown"]
        args.append(destinatie.path)
        return args
    }

    /// Ruleaza conversia unui singur job, raportand progresul prin callback (0.0 - 1.0).
    /// Intoarce un `ConversieHandle` — apelantul il poate folosi ca sa
    /// anuleze conversia in curs (`.anuleaza()`).
    @discardableResult
    static func ruleazaConversie(
        job: VideoJob,
        mod: ModConversie,
        codec: CodecOutput,
        destinatie: URL,
        progresCallback: @escaping (Double) -> Void,
        finalizareCallback: @escaping (Result<Void, Error>) -> Void
    ) -> ConversieHandle {
        let handle = ConversieHandle()

        guard let ffmpegPath = gasesteBinar() else {
            finalizareCallback(.failure(EroareFFmpeg.binarNegasit))
            return handle
        }

        // Extrage timecode-ul sursei INAINTE de conversie
        let tcSursa = timecodeSursa(url: job.urlSursa)

        let durataTotala = durataClip(url: job.urlSursa) ?? 0

        // Pasul 1: transcode / rewrap principal
        let proces = Process()
        proces.executableURL = URL(fileURLWithPath: ffmpegPath)
        proces.arguments = construiesteArgumente(job: job, mod: mod, codec: codec, destinatie: destinatie)

        let pipeEroare = Pipe()
        proces.standardError = pipeEroare
        proces.standardOutput = Pipe()
        handle.procesActiv = proces

        var mesajEroareAcumulat = ""

        pipeEroare.fileHandleForReading.readabilityHandler = { fh in
            let data = fh.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            mesajEroareAcumulat += text

            if durataTotala > 0, let interval = Self.extrageTimp(din: text) {
                let progres = min(interval / durataTotala, 1.0) * (tcSursa != nil ? 0.95 : 1.0)
                DispatchQueue.main.async {
                    progresCallback(progres)
                }
            }
        }

        proces.terminationHandler = { proc in
            pipeEroare.fileHandleForReading.readabilityHandler = nil

            guard proc.terminationStatus == 0 else {
                if handle.aFostAnulat {
                    DispatchQueue.main.async {
                        finalizareCallback(.failure(EroareFFmpeg.anulat))
                    }
                    return
                }
                let ultimeleLinii = mesajEroareAcumulat
                    .split(separator: "\n").suffix(5).joined(separator: " ")
                DispatchQueue.main.async {
                    finalizareCallback(.failure(EroareFFmpeg.esecProces(cod: proc.terminationStatus, mesaj: ultimeleLinii)))
                }
                return
            }

            // Pasul 2: injecteaza timecode-ul original printr-un re-wrap rapid (fara re-encode)
            // prores_videotoolbox ignora -timecode la encode, deci il injectam dupa, cu -c copy
            guard let tc = tcSursa else {
                DispatchQueue.main.async {
                    progresCallback(1.0)
                    finalizareCallback(.success(()))
                }
                return
            }

            // Fisier temporar langa destinatie
            let tmpURL = destinatie.deletingPathExtension()
                .appendingPathExtension("_tc_tmp")
                .appendingPathExtension(destinatie.pathExtension)

            let proc2 = Process()
            proc2.executableURL = URL(fileURLWithPath: ffmpegPath)
            proc2.arguments = [
                "-y",
                "-i", destinatie.path,
                "-c", "copy",
                "-map", "0:v",          // doar video
                "-map", "0:a?",         // audio daca exista (? = optional, ghilimelele il protejeaza in Swift)
                "-map_metadata", "0",
                "-timecode", tc,        // acum e respectat — nu mai e track tmcd care sa-l ignore
                tmpURL.path
            ]
            proc2.standardOutput = Pipe()
            proc2.standardError = Pipe()
            handle.procesActiv = proc2

            proc2.terminationHandler = { proc2result in
                DispatchQueue.main.async {
                    if proc2result.terminationStatus == 0 {
                        // Inlocuieste fisierul final cu cel cu timecode corectat
                        do {
                            try FileManager.default.removeItem(at: destinatie)
                            try FileManager.default.moveItem(at: tmpURL, to: destinatie)
                            progresCallback(1.0)
                            finalizareCallback(.success(()))
                        } catch {
                            // Daca move esueaza, pastreaza fisierul fara timecode corectat
                            try? FileManager.default.removeItem(at: tmpURL)
                            progresCallback(1.0)
                            finalizareCallback(.success(()))
                        }
                    } else {
                        // Timecode inject a esuat dar fisierul principal e ok — nu blocam
                        try? FileManager.default.removeItem(at: tmpURL)
                        progresCallback(1.0)
                        finalizareCallback(.success(()))
                    }
                }
            }

            do {
                try proc2.run()
            } catch {
                // Daca pasul 2 nu porneste, fisierul principal e totusi valid
                DispatchQueue.main.async {
                    progresCallback(1.0)
                    finalizareCallback(.success(()))
                }
            }
        }

        do {
            try proces.run()
        } catch {
            finalizareCallback(.failure(error))
        }
        return handle
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
