import Foundation

/// Profilul unui clip sursă, citit prin nucleul GDC Metadata (subproces,
/// contract JSON: linii NDJSON `{"clip": {...}}`). Nu are decodoare proprii:
/// valorile și proveniența vin din nucleu și se păstrează ca atare.
struct SourceProfile: Equatable {
    struct Detected: Equatable {
        let value: String
        /// decoded = citit din date native; declared = etichetă a producătorului;
        /// computed = dedus dintr-o regulă; user = confirmat manual.
        let kind: String
        let source: String
    }
    var cameraModel: String?
    var lens: String?
    var focalLength: String?
    var aperture: String?
    var iso: String?
    var shutter: String?
    var whiteBalance: String?
    var curve: Detected?
    var gamut: Detected?
    var timecode: String?       // cu ';' pentru drop-frame
    var frameRate: String?
    /// Nucleul a raportat eroare (ex. ExifTool absent): profilul poate fi parțial.
    var partialReason: String?

    var hasAnything: Bool {
        cameraModel != nil || curve != nil || gamut != nil || timecode != nil
    }
}

enum MetadataCore {
    /// Commit fixat al nucleului inclus în aplicație (tag v0.3.0 al gdc-metadata).
    static let pinnedCommit = "65e07a8b1d5268732d4180d6fe45e4311731540a"

    static func binaryURL() -> URL? {
        if let p = Bundle.main.path(forResource: "gdc-metadata-core", ofType: nil) {
            return URL(fileURLWithPath: p)
        }
        return nil
    }

    /// Citește profilul unui singur clip (blocant; apelat din fundal).
    static func scan(_ url: URL, timeout: TimeInterval = 60) -> SourceProfile? {
        guard let bin = binaryURL() else { return nil }
        let p = Process()
        p.executableURL = bin
        p.arguments = ["scan", url.path]
        let out = Pipe()
        p.standardOutput = out
        p.standardError = Pipe()
        guard (try? p.run()) != nil else { return nil }
        let watchdog = DispatchWorkItem { if p.isRunning { p.terminate() } }
        DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: watchdog)
        let data = out.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        watchdog.cancel()
        return parse(data)
    }

    /// Parsare defensivă: forma necunoscută => nil, niciodată crash.
    static func parse(_ data: Data) -> SourceProfile? {
        for line in data.split(separator: UInt8(ascii: "\n")) {
            guard let j = try? JSONSerialization.jsonObject(with: Data(line)) as? [String: Any],
                  let clip = j["clip"] as? [String: Any],
                  let fields = clip["fields"] as? [[String: Any]] else { continue }
            var prof = SourceProfile()
            func value(_ id: String) -> String? {
                guard let f = fields.first(where: { ($0["id"] as? String) == id }),
                      let st = f["status"] as? String, st != "unavailable",
                      let v = f["value"] as? String, !v.isEmpty else { return nil }
                return v
            }
            func detected(_ id: String) -> SourceProfile.Detected? {
                guard let v = value(id),
                      let f = fields.first(where: { ($0["id"] as? String) == id }) else { return nil }
                let prim = f["primary"] as? [String: Any]
                return .init(value: v, kind: (prim?["kind"] as? String) ?? "declared",
                             source: (prim?["source"] as? String) ?? "")
            }
            prof.cameraModel = value("camera_model")
            prof.lens = value("lens")
            prof.focalLength = value("focal_length")
            prof.aperture = value("aperture")
            prof.iso = value("iso")
            prof.shutter = value("shutter")
            prof.whiteBalance = value("wb_temp") ?? value("wb_mode")
            prof.curve = detected("curve")
            prof.gamut = detected("gamut")
            prof.timecode = value("timecode")
            prof.frameRate = value("frame_rate")
            if (clip["ok"] as? Bool) == false { prof.partialReason = clip["error"] as? String }
            return prof
        }
        return nil
    }
}

extension MetadataCore {
    /// Scrie `<rezultat>.gdc-metadata.json` (schema gdc-metadata/1): fisa clipului
    /// SURSA, exportata de nucleu, atribuita fisierului rezultat (dir/name/size/mtime),
    /// cu originea si raportul conversiei in `converted`. Completeaza ce Resolve nu
    /// citeste singur din fisier; nu inlocuieste incorporarea.
    static func writeSidecar(source: URL, output: URL, kept: [String], notKept: [String]) throws -> URL {
        guard let bin = binaryURL() else { throw TrackGrafterError.unsupported("nucleul de metadate lipseste") }
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("cgc-sidecar-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        let p = Process()
        p.executableURL = bin
        p.arguments = ["export", source.path, "--out-dir", tmp.path]
        p.standardOutput = Pipe(); p.standardError = Pipe()
        try p.run(); p.waitUntilExit()
        let produced = try FileManager.default.contentsOfDirectory(at: tmp, includingPropertiesForKeys: nil)
            .first { $0.lastPathComponent.hasSuffix(".gdc-metadata.json") }
        guard let file = produced,
              var json = try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any],
              let oldSource = json["source"] as? [String: Any] else {
            throw TrackGrafterError.io("sidecar-ul nucleului nu a putut fi citit")
        }
        let attrs = try FileManager.default.attributesOfItem(atPath: output.path)
        let mtime = ((attrs[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0) * 1e9
        json["source"] = [
            "dir": output.deletingLastPathComponent().path,
            "name": output.lastPathComponent,
            "size": (attrs[.size] as? NSNumber)?.int64Value ?? 0,
            "mtime_ns": String(UInt64(mtime)),
        ] as [String: Any]
        json["converted"] = [
            "by": "CG Convertor",
            "origin": oldSource,
            "origin_path": source.path,
            "kept": kept, "not_kept": notKept,
            "note": "Valorile descriu captura originala; nu sunt re-masurate pe imaginea rezultata.",
        ] as [String: Any]
        let dest = output.appendingPathExtension("gdc-metadata.json")
        let data = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: dest, options: .atomic)
        return dest
    }
}
