import Foundation
import CryptoKit

/// Pachetul de diagnostic local („Exportă diagnosticul”). Nu se încarcă
/// nicăieri: se creează un ZIP într-un folder vizibil, utilizatorul îl poate
/// deschide și inspecta înainte să decidă dacă îl trimite.
///
/// Conține NUMAI: jurnalele structurate (re-redactate; căile anonimizate
/// implicit), `manifest.json`, `system.json`, `settings.json` (listă albă de
/// setări tehnice), `last-job.json` (ultimul job din istoric, fără căi).
/// Nu citește și nu copiază niciun alt fișier — deci niciun material media,
/// cod de licență sau credențial.
struct DiagnosticExporter {
    struct Options {
        /// Opțiune explicită: include căile și numele fișierelor în clar.
        var includePaths = false
    }

    /// Setări tehnice nesensibile, exportate prin listă albă.
    static let settingsWhitelist = [
        "CGConvertor.appTheme", "cgconvertor_preserve_native_metadata",
    ]

    let log: StructuredLog
    var defaults: UserDefaults = .standard
    /// Ultimul job, deja redus la câmpuri nesensibile (fără căi).
    var lastJob: [String: String]? = nil
    /// Starea accesului (Demo/Full), fără identificatori, chei sau textul licenței (vezi `LicenseManager.diagnosticSummary`).
    var accessSummary: [String: String] = [:]
    var now: () -> Date = Date.init

    struct Manifest: Codable {
        struct File: Codable { let name: String; let bytes: Int; let sha256: String }
        let format = "cgconvertor-diagnostic/1"
        let created: String
        let app: String
        let build: String
        let session: String
        let pathsIncluded: Bool
        let redaction: String
        var files: [File]
    }

    /// Creează ZIP-ul în `folder` și întoarce calea lui.
    func export(to folder: URL, options: Options = Options()) throws -> URL {
        log.flush()
        let fm = FileManager.default
        let stamp = Self.stamp(now())
        let stage = fm.temporaryDirectory.appendingPathComponent("CGConvertor-diagnostic-\(stamp)-\(UUID().uuidString.prefix(6))")
        let root = stage.appendingPathComponent("CGConvertor-diagnostic-\(stamp)")
        try fm.createDirectory(at: root.appendingPathComponent("logs"), withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: stage) }

        var written: [URL] = []
        func write(_ data: Data, _ rel: String) throws {
            let u = root.appendingPathComponent(rel)
            try data.write(to: u)
            written.append(u)
        }
        func clean(_ s: String) -> String {
            let r = Redactor.redactSecrets(s)
            return options.includePaths ? r : Redactor.anonymizePaths(r)
        }

        for file in log.logFiles() {
            guard let text = try? String(contentsOf: file, encoding: .utf8) else { continue }
            try write(Data(clean(text).utf8), "logs/\(file.lastPathComponent)")
        }

        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let v = ProcessInfo.processInfo.operatingSystemVersion
        let system: [String: String] = [
            "os": "macOS \(v.majorVersion).\(v.minorVersion).\(v.patchVersion)",
            "arch": Self.arch, "locale": Locale.current.identifier,
            "memoryGB": String(format: "%.0f", Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824),
            "cpuCount": "\(ProcessInfo.processInfo.processorCount)",
            "logWriteError": log.lastWriteError ?? "",
        ]
        try write(try enc.encode(system), "system.json")

        var settings: [String: String] = [:]
        for key in Self.settingsWhitelist { if let v = defaults.object(forKey: key) { settings[key] = "\(v)" } }
        try write(try enc.encode(settings), "settings.json")

        if !accessSummary.isEmpty { try write(try enc.encode(Redactor.redactFields(accessSummary)), "access-state.json") }

        if let j = lastJob { try write(try enc.encode(Redactor.redactFields(j)), "last-job.json") }

        let info = Bundle.main.infoDictionary
        let manifest = Manifest(created: Self.stamp(now()), app: info?["CFBundleShortVersionString"] as? String ?? "dev",
                                build: info?["CFBundleVersion"] as? String ?? "dev", session: log.sessionID,
                                pathsIncluded: options.includePaths,
                                redaction: options.includePaths ? "secrets" : "secrets+paths",
                                files: try written.map { u in
                                    let d = try Data(contentsOf: u)
                                    let h = SHA256.hash(data: d).map { String(format: "%02x", $0) }.joined()
                                    return .init(name: String(u.path.dropFirst(root.path.count + 1)), bytes: d.count, sha256: h)
                                })
        try enc.encode(manifest).write(to: root.appendingPathComponent("manifest.json"))

        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        let zip = folder.appendingPathComponent("\(root.lastPathComponent).zip")
        try? fm.removeItem(at: zip)
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        p.arguments = ["-c", "-k", "--keepParent", root.path, zip.path]
        try p.run(); p.waitUntilExit()
        guard p.terminationStatus == 0 else { throw CocoaError(.fileWriteUnknown) }
        log.log(.info, "diagnostics", "diagnostics.exported", "Pachet de diagnostic creat",
                fields: ["files": "\(written.count + 1)", "paths": options.includePaths ? "included" : "anonymized"])
        return zip
    }

    static var defaultFolder: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/CGConvertor/Exports", isDirectory: true)
    }

    private static func stamp(_ d: Date) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyyMMdd-HHmmss'Z'"
        return f.string(from: d)
    }

    private static var arch: String {
        #if arch(arm64)
        return "arm64"
        #else
        return "x86_64"
        #endif
    }
}
