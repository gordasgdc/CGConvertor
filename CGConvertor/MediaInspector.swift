import Foundation

/// Inspecție/Metadata profundă + thumbnail cu LUT static (Faza 2). Rulează
/// `ffprobe`/`ffmpeg` — ACELAȘI binar deja folosit de `MotorFFmpeg` pentru
/// conversie, fără nicio dependință nouă. Analiza rulează asincron, în
/// fundal, imediat după ce un fișier intră în coadă (vezi
/// `ConvertorViewModel.adaugaFisiere`) — nu blochează UI-ul niciodată.
struct MediaMetadata: Equatable {
    var durataSecunde: Double?
    var codecVideo: String?
    var latime: Int?
    var inaltime: Int?
    var frameRate: String?      // ex. "23.976", derivat din r_frame_rate (fracție)
    var bitrateVideo: Int?      // bps
    var pixFmt: String?
    var colorSpace: String?
    var colorTransfer: String?
    var colorPrimaries: String?
    var codecAudio: String?
    var sampleRateAudio: Int?
    var canaleAudio: Int?
    var bitrateAudio: Int?

    var rezolutieText: String? {
        guard let l = latime, let h = inaltime else { return nil }
        return "\(l)×\(h)"
    }
}

enum MediaInspector {
    /// Rulează `ffprobe -show_format -show_streams` și parsează JSON-ul
    /// brut manual (nu Codable pe structura ffprobe direct — câmpurile ei
    /// variază mult între containere/codecuri, un parsing tolerant e mai
    /// robust decât un model rigid care ar eșua la primul câmp lipsă).
    static func probe(url: URL) -> MediaMetadata? {
        guard let ffmpegPath = MotorFFmpeg.gasesteBinar() else { return nil }
        let ffprobePath = ffmpegPath.replacingOccurrences(of: "ffmpeg", with: "ffprobe")
        guard FileManager.default.fileExists(atPath: ffprobePath) else { return nil }

        let proces = Process()
        proces.executableURL = URL(fileURLWithPath: ffprobePath)
        proces.arguments = [
            "-v", "error", "-print_format", "json",
            "-show_format", "-show_streams",
            url.path
        ]
        let pipe = Pipe()
        proces.standardOutput = pipe
        proces.standardError = Pipe()

        do {
            try proces.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            proces.waitUntilExit()
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
            return parse(json)
        } catch {
            return nil
        }
    }

    private static func parse(_ json: [String: Any]) -> MediaMetadata {
        var meta = MediaMetadata()
        if let format = json["format"] as? [String: Any] {
            meta.durataSecunde = (format["duration"] as? String).flatMap(Double.init)
        }
        guard let streams = json["streams"] as? [[String: Any]] else { return meta }

        if let v = streams.first(where: { ($0["codec_type"] as? String) == "video" }) {
            meta.codecVideo = v["codec_name"] as? String
            meta.latime = v["width"] as? Int
            meta.inaltime = v["height"] as? Int
            meta.pixFmt = v["pix_fmt"] as? String
            meta.colorSpace = v["color_space"] as? String
            meta.colorTransfer = v["color_transfer"] as? String
            meta.colorPrimaries = v["color_primaries"] as? String
            if let br = v["bit_rate"] as? String { meta.bitrateVideo = Int(br) }
            if let rate = v["r_frame_rate"] as? String {
                let parts = rate.split(separator: "/")
                if parts.count == 2, let num = Double(parts[0]), let den = Double(parts[1]), den != 0 {
                    meta.frameRate = String(format: "%.3f", num / den)
                }
            }
        }
        if let a = streams.first(where: { ($0["codec_type"] as? String) == "audio" }) {
            meta.codecAudio = a["codec_name"] as? String
            meta.canaleAudio = a["channels"] as? Int
            if let sr = a["sample_rate"] as? String { meta.sampleRateAudio = Int(sr) }
            if let br = a["bit_rate"] as? String { meta.bitrateAudio = Int(br) }
        }
        return meta
    }

    /// Extrage un cadru static (~1s în clip, sau primul cadru dacă mai
    /// scurt) ca thumbnail JPEG, opțional cu un LUT `.cube` aplicat prin
    /// filtrul nativ `lut3d` al FFmpeg — NU un player real-time (acela
    /// rămâne un TODO separat, mult mai mare, vezi CLAUDE.md).
    static func genereazaThumbnail(url: URL, lutPath: String?, iesire: URL) -> Bool {
        guard let ffmpegPath = MotorFFmpeg.gasesteBinar() else { return false }
        var filtru = "scale=320:-2"
        if let lutPath, !lutPath.isEmpty {
            let caleEscapata = lutPath.replacingOccurrences(of: "'", with: "\\'")
            filtru += ",lut3d=file='\(caleEscapata)'"
        }
        let proces = Process()
        proces.executableURL = URL(fileURLWithPath: ffmpegPath)
        proces.arguments = [
            "-y", "-ss", "1", "-i", url.path,
            "-frames:v", "1", "-vf", filtru,
            iesire.path
        ]
        proces.standardOutput = Pipe()
        proces.standardError = Pipe()
        do {
            try proces.run()
            proces.waitUntilExit()
            return proces.terminationStatus == 0 && FileManager.default.fileExists(atPath: iesire.path)
        } catch {
            return false
        }
    }

    /// Folder de lucru pentru thumbnail-uri, curățat la fiecare lansare
    /// (nu sunt persistente — regenerate din surse la nevoie).
    static func folderThumbnailuri() -> URL {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent("CGConvertorThumbs", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }
}
