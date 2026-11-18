import Foundation

// MARK: - Extragerea metadatelor în offload — separată de verdictul copiei
//
// Contract (același cu DataMover):
//  • rulează DOAR după copiere și doar pentru clipuri cu cel puțin o copie confirmată prin sumă de control;
//  • sursa se citește fără a fi modificată (nucleul GDC Metadata o deschide doar pentru citire);
//  • fișa `<clip>.gdc-metadata.json` se scrie lângă FIECARE copie confirmată, după MHL:
//    nu intră în MHL și nu e numărată ca fișier copiat;
//  • un fișier existent cu același nume care nu e al GDC Metadata nu se suprascrie niciodată;
//  • verdictul extracției nu influențează niciodată `DestinationOutcome`/`TransferOutcome`.

enum MetadataVerdict: String, Equatable {
    case found, failed, notVerified, unavailable
}

struct MetadataClipResult: Equatable {
    var relPath: String
    var verdict: MetadataVerdict
    var error: String?
    /// destRoot → written · refused_foreign · error
    var sidecars: [String: String] = [:]
}

struct MetadataSummary: Equatable {
    var results: [MetadataClipResult] = []
    var cancelled = false
    var found: Int { results.filter { $0.verdict == .found }.count }
    var failed: Int { results.filter { $0.verdict == .failed }.count }
    var notVerified: Int { results.filter { $0.verdict == .notVerified }.count }
    var written: Int { results.reduce(0) { $0 + $1.sidecars.values.filter { $0 == "written" }.count } }
    var refusedForeign: Int { results.reduce(0) { $0 + $1.sidecars.values.filter { $0 == "refused_foreign" }.count } }
    var sidecarErrors: Int { results.reduce(0) { $0 + $1.sidecars.values.filter { $0 == "error" }.count } }
    var coreUnavailable: Bool { !results.isEmpty && results.allSatisfy { $0.verdict == .unavailable } }
    var needsAttention: Bool { failed + notVerified + refusedForeign + sidecarErrors > 0 || coreUnavailable }
}

enum OffloadMetadataExtraction {
    static let clipExtensions: Set<String> = ["mp4", "mov", "mxf", "mts", "m2ts", "avi", "mkv", "braw", "r3d", "crm", "arx", "ari"]

    static func isClip(_ relPath: String) -> Bool {
        clipExtensions.contains(((relPath as NSString).pathExtension).lowercased())
    }

    /// Un fișier de metadate al GDC? (`schema` începe cu „gdc-metadata”.)
    static func isOurSidecar(_ path: String) -> Bool {
        guard let d = FileManager.default.contents(atPath: path),
              let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
              let s = j["schema"] as? String else { return false }
        return s.hasPrefix("gdc-metadata")
    }

    /// `verified[relPath]` = rădăcinile de destinație (targetRoot) în care fișierul e confirmat.
    /// `sourcePath[relPath]` = calea originalului (citit doar).
    static func run(files: [(rel: String, source: String)],
                    verifiedOn: [String: [String]],
                    isCancelled: @escaping () -> Bool,
                    onProgress: @escaping (Int, Int) -> Void = { _, _ in }) -> MetadataSummary {
        var summary = MetadataSummary()
        let clips = files.filter { isClip($0.rel) }
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("cgc-offload-meta-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        for (i, clip) in clips.enumerated() {
            if isCancelled() { summary.cancelled = true; break }
            onProgress(i, clips.count)
            let targets = verifiedOn[clip.rel] ?? []
            var r = MetadataClipResult(relPath: clip.rel, verdict: .notVerified)
            guard !targets.isEmpty else { summary.results.append(r); continue }
            guard let bin = MetadataCore.binaryURL() else {
                r.verdict = .unavailable; r.error = "nucleul de metadate lipsește"
                summary.results.append(r); continue
            }
            let out = tmp.appendingPathComponent("\(i)", isDirectory: true)
            try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
            let p = Process()
            p.executableURL = bin
            p.arguments = ["export", clip.source, "--out-dir", out.path]
            p.standardOutput = Pipe(); p.standardError = Pipe()
            do { try p.run() } catch { r.verdict = .failed; r.error = "\(error)"; summary.results.append(r); continue }
            let watchdog = DispatchWorkItem { if p.isRunning { p.terminate() } }
            DispatchQueue.global().asyncAfter(deadline: .now() + 120, execute: watchdog)
            p.waitUntilExit(); watchdog.cancel()
            let produced = (try? FileManager.default.contentsOfDirectory(at: out, includingPropertiesForKeys: nil))?
                .first { $0.lastPathComponent.hasSuffix(".gdc-metadata.json") }
            guard p.terminationStatus == 0, let file = produced else {
                r.verdict = .failed; r.error = "nucleul a ieșit cu \(p.terminationStatus)"
                summary.results.append(r); continue
            }
            r.verdict = .found
            for root in targets {
                let dest = (root as NSString).appendingPathComponent(clip.rel)
                let name = ((clip.rel as NSString).lastPathComponent) + ".gdc-metadata.json"
                let target = ((dest as NSString).deletingLastPathComponent as NSString).appendingPathComponent(name)
                if FileManager.default.fileExists(atPath: target), !isOurSidecar(target) {
                    r.sidecars[root] = "refused_foreign"; continue
                }
                do {
                    let data = try Data(contentsOf: file)
                    try data.write(to: URL(fileURLWithPath: target), options: .atomic)
                    r.sidecars[root] = "written"
                } catch { r.sidecars[root] = "error" }
            }
            summary.results.append(r)
        }
        onProgress(clips.count, clips.count)
        return summary
    }
}
