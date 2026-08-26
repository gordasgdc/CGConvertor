import Foundation

enum StareJob: Equatable {
    case astept
    case inLucru(progres: Double)
    case finalizat
    case anulat
    case eroare(mesaj: String)
}

enum ModConversie: String, CaseIterable, Identifiable {
    case rewrap = "Rewrap (rapid, fara re-encode)"
    case transcode = "Transcode (re-encode complet)"
    var id: String { rawValue }
}

enum CodecOutput: String, CaseIterable, Identifiable {
    case proRes422 = "ProRes 422"
    case proRes422HQ = "ProRes 422 HQ"
    case proRes422LT = "ProRes 422 LT"
    case proRes4444 = "ProRes 4444"
    case dnxhd = "DNxHD"
    case dnxhr = "DNxHR HQ"
    var id: String { rawValue }

    /// Argumentele FFmpeg pentru codecul ales
    /// ProRes foloseste prores_videotoolbox — encoder-ul hardware nativ Apple,
    /// care respecta automat bitrate-urile oficiale Apple (la fel ca EditReady/Compressor).
    /// prores_ks (software) NU atinge niciodata bitrate-ul oficial, indiferent de qscale.
    var ffmpegArgs: [String] {
        switch self {
        case .proRes422:
            return ["-c:v", "prores_videotoolbox", "-profile:v", "2", "-pix_fmt", "yuv422p10le"]
        case .proRes422HQ:
            return ["-c:v", "prores_videotoolbox", "-profile:v", "3", "-pix_fmt", "yuv422p10le"]
        case .proRes422LT:
            return ["-c:v", "prores_videotoolbox", "-profile:v", "1", "-pix_fmt", "yuv422p10le"]
        case .proRes4444:
            return ["-c:v", "prores_videotoolbox", "-profile:v", "4", "-pix_fmt", "yuva444p10le"]
        case .dnxhd:
            // 36 Mbps e standardul DNxHD 1080p23.976 (linie color, nu HQX)
            return ["-c:v", "dnxhd", "-profile:v", "dnxhd", "-b:v", "36M", "-pix_fmt", "yuv422p"]
        case .dnxhr:
            // DNxHR HQ: qscale 1 = calitate maxima fara pierdere vizibila
            return ["-c:v", "dnxhd", "-profile:v", "dnxhr_hq", "-qscale:v", "1", "-pix_fmt", "yuv422p"]
        }
    }

    var extensieContainer: String {
        switch self {
        case .dnxhd, .dnxhr:
            return "mxf"
        default:
            return "mov"
        }
    }
}

struct VideoJob: Identifiable, Equatable {
    let id = UUID()
    let urlSursa: URL
    var urlDestinatie: URL?
    var stare: StareJob = .astept

    var numeFisier: String {
        urlSursa.lastPathComponent
    }

    static func == (lhs: VideoJob, rhs: VideoJob) -> Bool {
        lhs.id == rhs.id
    }
}
