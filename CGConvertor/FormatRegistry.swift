import Foundation

/// Sursă unică de adevăr pentru profilurile de encodare video (Faza 1
/// v3.0.0, secțiunea A "Format Registry unificat") — structură cu
/// ACELEAȘI id-uri ca `format_registry.py` (Windows), verificat manual
/// la fiecare adăugare (Regula 30). Argumentele ProRes/DNxHD/DNxHR sunt
/// PĂSTRATE byte-identice cu `CodecOutput.ffmpegArgs` dinaintea acestei
/// refactorizări (regresie interzisă) — doar mutate aici.
///
/// Pe Mac, spre deosebire de Windows (unde există NVENC/AMF/QSV de ales),
/// accelerarea hardware pentru H.264/HEVC e MEREU VideoToolbox — nu
/// există alt vânzător posibil pe niciun Mac. AV1 nu are encoder hardware
/// pe niciun Mac existent — cade întotdeauna pe `libsvtav1` (software),
/// verificat direct cu binarul static din acest repo.
struct EncoderProfile {
    let id: String
    let label: String
    let container: String  // extensie fără punct: "mov", "mxf", "mp4"
    let hintKey: String     // cheie L.t() pentru textul de sub picker
    let ffmpegArgs: [String]
    var extraMuxArgs: [String] = []

    var fullFFmpegArgs: [String] { ffmpegArgs + extraMuxArgs }
}

enum FormatRegistry {
    /// Sentinelă pentru modul "Rewrap" (nu e un profil real din listă —
    /// tratat separat în MotorFFmpeg.swift ca `-c copy` total).
    static let rewrapProfileID = "rewrap"

    static let proRes422 = EncoderProfile(
        id: "prores422", label: "ProRes 422", container: "mov", hintKey: "codec.hint.proRes422",
        ffmpegArgs: ["-c:v", "prores_videotoolbox", "-profile:v", "2", "-pix_fmt", "yuv422p10le"])
    static let proRes422HQ = EncoderProfile(
        id: "prores422hq", label: "ProRes 422 HQ", container: "mov", hintKey: "codec.hint.proRes422HQ",
        ffmpegArgs: ["-c:v", "prores_videotoolbox", "-profile:v", "3", "-pix_fmt", "yuv422p10le"])
    static let proRes422LT = EncoderProfile(
        id: "prores422lt", label: "ProRes 422 LT", container: "mov", hintKey: "codec.hint.proRes422LT",
        ffmpegArgs: ["-c:v", "prores_videotoolbox", "-profile:v", "1", "-pix_fmt", "yuv422p10le"])
    static let proRes4444 = EncoderProfile(
        id: "prores4444", label: "ProRes 4444", container: "mov", hintKey: "codec.hint.proRes4444",
        ffmpegArgs: ["-c:v", "prores_videotoolbox", "-profile:v", "4", "-pix_fmt", "yuva444p10le"])
    static let dnxhd = EncoderProfile(
        id: "dnxhd", label: "DNxHD", container: "mxf", hintKey: "codec.hint.dnx",
        ffmpegArgs: ["-c:v", "dnxhd", "-profile:v", "dnxhd", "-b:v", "36M", "-pix_fmt", "yuv422p"])
    static let dnxhrHQ = EncoderProfile(
        id: "dnxhrhq", label: "DNxHR HQ", container: "mxf", hintKey: "codec.hint.dnx",
        ffmpegArgs: ["-c:v", "dnxhd", "-profile:v", "dnxhr_hq", "-qscale:v", "1", "-pix_fmt", "yuv422p"])

    // ── Codecuri de livrare noi (Faza 1) — argumente verificate REAL cu
    // binarul ffmpeg static din acest repo (VideoToolbox + libsvtav1). ──
    static let h264 = EncoderProfile(
        id: "h264", label: "H.264", container: "mp4", hintKey: "codec.hint.h264",
        ffmpegArgs: ["-c:v", "h264_videotoolbox", "-profile:v", "high", "-b:v", "12M"])
    static let hevc10 = EncoderProfile(
        id: "hevc10", label: "HEVC 10-bit", container: "mp4", hintKey: "codec.hint.hevc10",
        ffmpegArgs: ["-c:v", "hevc_videotoolbox", "-profile:v", "main10", "-pix_fmt", "p010le", "-b:v", "20M"],
        extraMuxArgs: ["-tag:v", "hvc1"])  // fara asta, QuickTime/Final Cut nu recunosc HEVC in .mp4
    static let av1 = EncoderProfile(
        id: "av1", label: "AV1", container: "mp4", hintKey: "codec.hint.av1",
        ffmpegArgs: ["-c:v", "libsvtav1", "-preset", "6", "-crf", "30"])
    static let uncompressed = EncoderProfile(
        id: "uncompressed", label: "Uncompressed 10-bit", container: "mov", hintKey: "codec.hint.uncompressed",
        ffmpegArgs: ["-c:v", "v210"])

    static let allProfiles: [EncoderProfile] = [
        proRes422, proRes422HQ, proRes422LT, proRes4444, dnxhd, dnxhrHQ, h264, hevc10, av1, uncompressed,
    ]

    static func profile(id: String) -> EncoderProfile? {
        allProfiles.first { $0.id == id }
    }
}
