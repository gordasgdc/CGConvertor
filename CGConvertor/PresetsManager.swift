import Foundation

/// Presets Manager (Faza 1 v3.0.0, secțiunea D) — înlocuiește picker-ul
/// fix Mod(Rewrap/Transcode)+Codec cu o listă de presetări denumite,
/// editabile, importabile/exportabile. Persistat în `~/Library/
/// Application Support/CGConvertor/presets.json` — ACELAȘI nume de
/// fișier și STRUCTURĂ de câmpuri (`CodingKeys` mapate explicit la
/// snake_case) ca varianta Windows (`presets_manager.py`), ca un preset
/// exportat pe o platformă să se importe corect pe cealaltă.

enum AudioMode: String, CaseIterable, Identifiable, Codable {
    case passthrough, pcm16, pcm24, aac
    var id: String { rawValue }
    var labelKey: String {
        switch self {
        case .passthrough: return "audio.passthrough"
        case .pcm16: return "audio.pcm16"
        case .pcm24: return "audio.pcm24"
        case .aac: return "audio.aac"
        }
    }
    var ffmpegArgs: [String] {
        switch self {
        case .passthrough: return ["-c:a", "copy"]
        case .pcm16: return ["-c:a", "pcm_s16le"]
        case .pcm24: return ["-c:a", "pcm_s24le"]
        case .aac: return ["-c:a", "aac", "-b:a", "320k"]
        }
    }
}

enum ChannelLayout: String, CaseIterable, Identifiable, Codable {
    case original, stereo
    case surround51 = "5.1"
    var id: String { rawValue }
    var labelKey: String {
        switch self {
        case .original: return "channel.original"
        case .stereo: return "channel.stereo"
        case .surround51: return "channel.51"
        }
    }
    var ffmpegArgs: [String] {
        switch self {
        case .original: return []
        case .stereo: return ["-ac", "2"]
        case .surround51: return ["-ac", "6"]
        }
    }
}

enum TargetApp: String, CaseIterable, Identifiable, Codable {
    case davinci, premiere, fcp, avid, web, custom
    var id: String { rawValue }
    var labelKey: String { "targetApp.\(rawValue)" }
}

struct OutputPreset: Identifiable, Codable, Equatable {
    var id: String
    var label: String
    var targetApp: TargetApp
    var profileID: String  // id din FormatRegistry, sau FormatRegistry.rewrapProfileID
    var audioMode: AudioMode = .passthrough
    var channelLayout: ChannelLayout = .original
    var fileSuffix: String = "_convertit"
    var isBuiltin: Bool = false

    // Mapare explicită la snake_case — ACEEAȘI cheie JSON ca
    // `presets_manager.py` (Windows), pentru portabilitate reală
    // Import/Export între platforme, nu doar coincidență de nume.
    enum CodingKeys: String, CodingKey {
        case id, label
        case targetApp = "target_app"
        case profileID = "profile_id"
        case audioMode = "audio_mode"
        case channelLayout = "channel_layout"
        case fileSuffix = "file_suffix"
        case isBuiltin = "is_builtin"
    }
}

enum PresetsManager {
    private static var fileURL: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("CGConvertor", isDirectory: true)
            .appendingPathComponent("presets.json")
    }

    static func defaultPresets() -> [OutputPreset] {
        [
            OutputPreset(id: "builtin_rewrap", label: "Rewrap Rapid", targetApp: .custom,
                         profileID: FormatRegistry.rewrapProfileID, fileSuffix: "_rewrap", isBuiltin: true),
            OutputPreset(id: "builtin_prores422hq", label: "ProRes 422 HQ (Mezzanine DaVinci/FCP)",
                         targetApp: .davinci, profileID: "prores422hq", fileSuffix: "_proresHQ", isBuiltin: true),
            OutputPreset(id: "builtin_dnxhrhq", label: "DNxHR HQ (Mezzanine Avid/Premiere)",
                         targetApp: .avid, profileID: "dnxhrhq", fileSuffix: "_dnxhr", isBuiltin: true),
            OutputPreset(id: "builtin_h264_web", label: "H.264 1080p (YouTube/Web)",
                         targetApp: .web, profileID: "h264", audioMode: .aac, channelLayout: .stereo,
                         fileSuffix: "_web", isBuiltin: true),
            OutputPreset(id: "builtin_hevc_master", label: "HEVC 10-bit (Master Delivery)",
                         targetApp: .custom, profileID: "hevc10", audioMode: .aac, fileSuffix: "_master", isBuiltin: true),
            OutputPreset(id: "builtin_av1_web", label: "AV1 (Web modern)",
                         targetApp: .web, profileID: "av1", audioMode: .aac, channelLayout: .stereo,
                         fileSuffix: "_av1", isBuiltin: true),
            OutputPreset(id: "builtin_uncompressed", label: "Uncompressed 10-bit (Arhivare)",
                         targetApp: .custom, profileID: "uncompressed", audioMode: .pcm24,
                         fileSuffix: "_uncompressed", isBuiltin: true),
        ]
    }

    /// La prima lansare, seed cu presetările implicite (scrise pe disc,
    /// ca userul să le poată duplica/edita ca punct de plecare).
    static func load() -> [OutputPreset] {
        guard let url = fileURL,
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([OutputPreset].self, from: data),
              !decoded.isEmpty else {
            let defaults = defaultPresets()
            save(defaults)
            return defaults
        }
        return decoded
    }

    static func save(_ presets: [OutputPreset]) {
        guard let url = fileURL else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(presets) else { return }
        try? data.write(to: url, options: .atomic)
    }

    static func duplicate(_ preset: OutputPreset, newID: String, newLabel: String) -> OutputPreset {
        var clone = preset
        clone.id = newID
        clone.label = newLabel
        clone.isBuiltin = false
        return clone
    }

    static func exportToFile(_ presets: [OutputPreset], url: URL) throws {
        let data = try JSONEncoder().encode(presets)
        try data.write(to: url, options: .atomic)
    }

    static func importFromFile(url: URL) throws -> [OutputPreset] {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([OutputPreset].self, from: data)
    }
}
