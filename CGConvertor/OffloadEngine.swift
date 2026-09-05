import Foundation
import CryptoKit
import Combine

// ─────────────────────────────────────────────────────────────────────────
// Offload/Checksum — copiere sursă→destinație(i) cu verificare integrală
// (MD5/SHA-1/SHA-256/xxHash64/doar-mărime), gândită pentru offload de card
// media (Faza 2 din planul CGConvertor v3.0.0).
//
// SCOP DELIBERAT REDUS față de `DataMover` (aplicația soră din ecosistemul
// GDC, unde acest tipar a fost dezvoltat inițial și rafinat de-a lungul a
// multe etape): NU se portează aici MHL, sincronizare Cloud (rclone),
// detecție structură de card de cameră, șabloane de denumire a folderelor,
// coadă automată de carduri, ejectare automată, sau rapoarte PDF/HTML
// brandate. Acelea sunt un flux profesional de post-producție complet,
// dincolo de ce cere planul acestui repo ("Offload/Checksum: card→
// destinație, MD5/SHA-1/xxHash"). Ce urmează e nucleul: copiere fiabilă,
// verificată, cu buffer/backpressure conform Regulii 21, plus un raport
// CSV incremental — dacă se cere vreodată mai mult, restul tiparului
// există deja, testat, în `DataMover/mac-native/Sources/DataMoverMac/
// OffloadEngine.swift`.
// ─────────────────────────────────────────────────────────────────────────

struct OffloadFileEntry {
    let fullPath: String
    let relPath: String
    let size: UInt64
}

/// Ireversibil odată apăsat — la fel ca la coada de conversie existentă.
final class CancelToken: @unchecked Sendable {
    private let lock = NSLock()
    private var _cancelled = false
    var isCancelled: Bool { lock.lock(); defer { lock.unlock() }; return _cancelled }
    func cancel() { lock.lock(); _cancelled = true; lock.unlock() }
}

/// Reversibil — spre deosebire de `CancelToken`. Verificat între FIȘIERE
/// (nu la mijlocul unuia), ca fișierul curent să-și termine copierea.
final class PauseToken: @unchecked Sendable {
    private let lock = NSLock()
    private var _paused = false
    var isPaused: Bool { lock.lock(); defer { lock.unlock() }; return _paused }
    func pause() { lock.lock(); _paused = true; lock.unlock() }
    func resume() { lock.lock(); _paused = false; lock.unlock() }
    func waitWhilePaused(cancel: CancelToken) {
        while isPaused && !cancel.isCancelled {
            Thread.sleep(forTimeInterval: 0.2)
        }
    }
}

enum VerificationModel: String, CaseIterable, Identifiable {
    case xxhash64, md5, sha1, sha256, sizeOnly
    var id: String { rawValue }
    var label: String {
        switch self {
        case .xxhash64: return "xxHash64 (\(L.t("offload.verify.recommended")))"
        case .md5: return "MD5"
        case .sha1: return "SHA-1"
        case .sha256: return "SHA-256"
        case .sizeOnly: return L.t("offload.verify.sizeOnly")
        }
    }
}

func offloadIsExcluded(filename: String) -> Bool {
    filename.hasPrefix(".") // fișiere ascunse — .DS_Store, .Trashes etc.
}

/// Scanare recursivă simplă — NU streaming (Regula 21 documentează varianta
/// lazy/manifest pentru surse foarte mari; un card media tipic (sute-mii
/// de fișiere) rămâne confortabil sub pragul unde asta ar conta). Dacă se
/// dovedește insuficient pe surse uriașe reale, poate fi înlocuit ulterior
/// cu tiparul `scan_files_streaming` din `DataMover`.
func offloadListAllFiles(root: String) -> [OffloadFileEntry] {
    var out: [OffloadFileEntry] = []
    let fm = FileManager.default
    let rootURL = URL(fileURLWithPath: root)
    guard let enumerator = fm.enumerator(at: rootURL, includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey]) else {
        return out
    }
    for case let fileURL as URL in enumerator {
        if offloadIsExcluded(filename: fileURL.lastPathComponent) { continue }
        guard let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
              values.isRegularFile == true else { continue }
        let rel = fileURL.path.hasPrefix(rootURL.path) ? String(fileURL.path.dropFirst(rootURL.path.count + 1)) : fileURL.lastPathComponent
        out.append(OffloadFileEntry(fullPath: fileURL.path, relPath: rel, size: UInt64(values.fileSize ?? 0)))
    }
    return out
}

func offloadIsPermissionError(_ error: Error) -> Bool {
    let nsError = error as NSError
    return nsError.domain == NSCocoaErrorDomain && (nsError.code == 257 || nsError.code == 513)
}

/// Copiere în bucăți, cancelabilă — citire/scriere prin `FileHandle`
/// (varianta `throwing`, nu `readData(ofLength:)`, ca o eroare reală de I/O
/// — card scos brusc — să nu arunce o excepție Objective-C necapturabilă).
/// `autoreleasepool` per iterație e obligatoriu (Regula 21) — altfel
/// obiectele `NSData` din spatele fiecărui `Data` bridge-uit se acumulează
/// pe tot parcursul copierii unui fișier mare.
func offloadCopyFile(src: String, dst: String, cancel: CancelToken, chunkSize: Int) throws {
    let fm = FileManager.default
    if fm.fileExists(atPath: dst) { try? fm.removeItem(atPath: dst) }
    fm.createFile(atPath: dst, contents: nil)
    guard let input = FileHandle(forReadingAtPath: src), let output = FileHandle(forWritingAtPath: dst) else {
        throw NSError(domain: "Offload", code: 1, userInfo: [NSLocalizedDescriptionKey: "Nu pot deschide \(src) sau \(dst)"])
    }
    defer { try? input.close(); try? output.close() }

    while true {
        if cancel.isCancelled {
            try? fm.removeItem(atPath: dst)
            throw NSError(domain: "Offload", code: 2, userInfo: [NSLocalizedDescriptionKey: "Anulat"])
        }
        var chunk: Data?
        try autoreleasepool {
            chunk = try input.read(upToCount: chunkSize)
        }
        guard let data = chunk, !data.isEmpty else { break }
        try autoreleasepool {
            try output.write(contentsOf: data)
        }
    }
    try? fm.setAttributes(try fm.attributesOfItem(atPath: src), ofItemAtPath: dst)
}

private func offloadGenericHash<H: HashFunction>(_ type: H.Type, path: String, cancel: CancelToken, chunkSize: Int) throws -> String {
    guard let input = FileHandle(forReadingAtPath: path) else {
        throw NSError(domain: "Offload", code: 3, userInfo: [NSLocalizedDescriptionKey: "Nu pot citi \(path)"])
    }
    defer { try? input.close() }
    var hasher = H()
    while true {
        if cancel.isCancelled { throw NSError(domain: "Offload", code: 2, userInfo: [NSLocalizedDescriptionKey: "Anulat"]) }
        var chunk: Data?
        try autoreleasepool { chunk = try input.read(upToCount: chunkSize) }
        guard let data = chunk, !data.isEmpty else { break }
        autoreleasepool { hasher.update(data: data) }
    }
    return hasher.finalize().map { String(format: "%02x", $0) }.joined()
}

func offloadXXHash64(path: String, cancel: CancelToken, chunkSize: Int) throws -> String {
    guard let input = FileHandle(forReadingAtPath: path) else {
        throw NSError(domain: "Offload", code: 3, userInfo: [NSLocalizedDescriptionKey: "Nu pot citi \(path)"])
    }
    defer { try? input.close() }
    var hasher = XXHash64()
    while true {
        if cancel.isCancelled { throw NSError(domain: "Offload", code: 2, userInfo: [NSLocalizedDescriptionKey: "Anulat"]) }
        var chunk: Data?
        try autoreleasepool { chunk = try input.read(upToCount: chunkSize) }
        guard let data = chunk, !data.isEmpty else { break }
        autoreleasepool { hasher.update(data) }
    }
    return hasher.hexDigest
}

func offloadHashOfFile(path: String, model: VerificationModel, cancel: CancelToken, chunkSize: Int) throws -> String {
    switch model {
    case .xxhash64: return try offloadXXHash64(path: path, cancel: cancel, chunkSize: chunkSize)
    case .md5: return try offloadGenericHash(Insecure.MD5.self, path: path, cancel: cancel, chunkSize: chunkSize)
    case .sha1: return try offloadGenericHash(Insecure.SHA1.self, path: path, cancel: cancel, chunkSize: chunkSize)
    case .sha256: return try offloadGenericHash(SHA256.self, path: path, cancel: cancel, chunkSize: chunkSize)
    case .sizeOnly: return ""
    }
}

struct OffloadReportRow {
    let relPath: String
    let sizeBytes: UInt64
    let srcHash: String
    let dstHash: String
    let status: String
    let error: String
}

struct OffloadDestinationResult {
    let destination: String
    let okCount: Int
    let mismatchCount: Int
    let errorCount: Int
    let csvPath: String?
}

/// Copiază + verifică toate fișierele sursă către O destinație. Rulează pe
/// un `DispatchQueue` de fundal, niciodată pe thread-ul principal.
final class OffloadDestinationJob {
    let destination: String
    let files: [OffloadFileEntry]
    let sourceRoot: String
    let model: VerificationModel
    let cancel: CancelToken
    let pause: PauseToken
    let onFileDone: (UInt64) -> Void
    let onActivity: (String) -> Void

    init(destination: String, files: [OffloadFileEntry], sourceRoot: String, model: VerificationModel,
         cancel: CancelToken, pause: PauseToken, onFileDone: @escaping (UInt64) -> Void, onActivity: @escaping (String) -> Void) {
        self.destination = destination
        self.files = files
        self.sourceRoot = sourceRoot
        self.model = model
        self.cancel = cancel
        self.pause = pause
        self.onFileDone = onFileDone
        self.onActivity = onActivity
    }

    func run() -> OffloadDestinationResult {
        let fm = FileManager.default
        try? fm.createDirectory(atPath: destination, withIntermediateDirectories: true)

        let csvPath = (destination as NSString).appendingPathComponent("offload_report_\(Self.timestamp()).csv")
        let csvHandle: FileHandle? = {
            fm.createFile(atPath: csvPath, contents: "fisier,marime_bytes,verificare_sursa,verificare_destinatie,status,eroare\n".data(using: .utf8))
            return FileHandle(forWritingAtPath: csvPath)
        }()
        defer { try? csvHandle?.close() }

        func logRow(_ row: OffloadReportRow) {
            let line = "\"\(row.relPath)\",\(row.sizeBytes),\(row.srcHash),\(row.dstHash),\(row.status),\"\(row.error)\"\n"
            csvHandle?.seekToEndOfFile()
            csvHandle?.write(line.data(using: .utf8) ?? Data())
        }

        var ok = 0, mismatch = 0, errors = 0
        let chunkSize = IOSettings.chunkSizeBytes

        for entry in files {
            if cancel.isCancelled { break }
            pause.waitWhilePaused(cancel: cancel)
            if cancel.isCancelled { break }
            IOSettings.waitIfOverRAMLimit(cancel: cancel) { [weak self] in
                self?.onActivity(L.t("offload.log.ramWait"))
            }

            let dstPath = (destination as NSString).appendingPathComponent(entry.relPath)
            let dstDir = (dstPath as NSString).deletingLastPathComponent
            try? fm.createDirectory(atPath: dstDir, withIntermediateDirectories: true)

            do {
                try offloadCopyFile(src: entry.fullPath, dst: dstPath, cancel: cancel, chunkSize: chunkSize)
                if model == .sizeOnly {
                    let dstSize = (try? fm.attributesOfItem(atPath: dstPath)[.size] as? UInt64) ?? 0
                    if dstSize == entry.size {
                        ok += 1
                        logRow(OffloadReportRow(relPath: entry.relPath, sizeBytes: entry.size, srcHash: "", dstHash: "", status: "OK", error: ""))
                    } else {
                        mismatch += 1
                        logRow(OffloadReportRow(relPath: entry.relPath, sizeBytes: entry.size, srcHash: "", dstHash: "", status: "NEPOTRIVIRE", error: "marime diferita"))
                    }
                } else {
                    let srcHash = try offloadHashOfFile(path: entry.fullPath, model: model, cancel: cancel, chunkSize: chunkSize)
                    let dstHash = try offloadHashOfFile(path: dstPath, model: model, cancel: cancel, chunkSize: chunkSize)
                    if srcHash == dstHash {
                        ok += 1
                        logRow(OffloadReportRow(relPath: entry.relPath, sizeBytes: entry.size, srcHash: srcHash, dstHash: dstHash, status: "OK", error: ""))
                    } else {
                        mismatch += 1
                        logRow(OffloadReportRow(relPath: entry.relPath, sizeBytes: entry.size, srcHash: srcHash, dstHash: dstHash, status: "NEPOTRIVIRE", error: "hash diferit"))
                        onActivity(String(format: L.t("offload.log.mismatch"), entry.relPath))
                    }
                }
            } catch {
                errors += 1
                let isPerm = offloadIsPermissionError(error)
                logRow(OffloadReportRow(relPath: entry.relPath, sizeBytes: entry.size, srcHash: "", dstHash: "", status: "EROARE", error: error.localizedDescription))
                onActivity(String(format: L.t(isPerm ? "offload.log.permError" : "offload.log.error"), entry.relPath, error.localizedDescription))
            }

            onFileDone(entry.size)
        }

        return OffloadDestinationResult(destination: destination, okCount: ok, mismatchCount: mismatch, errorCount: errors, csvPath: csvPath)
    }

    private static func timestamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd_HHmmss"
        return f.string(from: Date())
    }
}

/// Orchestrează un `OffloadDestinationJob` per destinație, în paralel —
/// expune stare `@Published` pentru SwiftUI.
@MainActor
final class OffloadRunner: ObservableObject {
    @Published var isRunning = false
    @Published var isPaused = false
    @Published var progressPercent: Double = 0
    @Published var filesDone = 0
    @Published var totalFiles = 0
    @Published var statusText = ""
    @Published var speedText = ""
    @Published var activityLog: [String] = []
    @Published var lastResults: [OffloadDestinationResult] = []
    @Published var permissionErrorPath: String?

    private let activityLogLimit = 200
    private var cancelToken = CancelToken()
    private var pauseToken = PauseToken()
    private var startedAt: Date = .init()
    private var totalBytes: UInt64 = 0
    private var bytesDoneShared: UInt64 = 0
    private let bytesLock = NSLock()

    func togglePause() {
        if pauseToken.isPaused { pauseToken.resume(); isPaused = false }
        else { pauseToken.pause(); isPaused = true }
    }

    func cancel() {
        cancelToken.cancel()
        statusText = L.t("offload.status.cancelling")
    }

    func start(sourceRoot: String, destinations: [String], model: VerificationModel) {
        guard !destinations.isEmpty else { return }
        cancelToken = CancelToken()
        pauseToken = PauseToken()
        isPaused = false
        activityLog.removeAll()
        lastResults.removeAll()
        permissionErrorPath = nil

        let files = offloadListAllFiles(root: sourceRoot)
        guard !files.isEmpty else {
            statusText = L.t("offload.status.noFiles")
            return
        }
        totalFiles = files.count * destinations.count
        totalBytes = files.reduce(0) { $0 + $1.size } * UInt64(destinations.count)
        filesDone = 0
        bytesDoneShared = 0
        progressPercent = 0
        isRunning = true
        startedAt = Date()
        statusText = String(format: L.t("offload.status.running"), files.count, destinations.count)

        let cancel = cancelToken
        let pause = pauseToken
        let group = DispatchGroup()
        var results: [OffloadDestinationResult] = []
        let resultsLock = NSLock()

        for dest in destinations {
            group.enter()
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                let job = OffloadDestinationJob(
                    destination: dest, files: files, sourceRoot: sourceRoot, model: model,
                    cancel: cancel, pause: pause,
                    onFileDone: { size in
                        Task { @MainActor in self?.advance(bytes: size) }
                    },
                    onActivity: { line in
                        Task { @MainActor in self?.logActivity(line) }
                    }
                )
                let result = job.run()
                resultsLock.lock(); results.append(result); resultsLock.unlock()
                group.leave()
            }
        }

        group.notify(queue: .main) { [weak self] in
            guard let self else { return }
            self.isRunning = false
            self.lastResults = results
            let totalOK = results.reduce(0) { $0 + $1.okCount }
            let totalMismatch = results.reduce(0) { $0 + $1.mismatchCount }
            let totalErrors = results.reduce(0) { $0 + $1.errorCount }
            if cancel.isCancelled {
                self.statusText = L.t("offload.status.cancelled")
            } else {
                self.statusText = String(format: L.t("offload.status.done"), totalOK, totalMismatch, totalErrors)
            }
        }
    }

    private func advance(bytes: UInt64) {
        filesDone += 1
        bytesLock.lock(); bytesDoneShared += bytes; bytesLock.unlock()
        progressPercent = totalFiles > 0 ? (Double(filesDone) / Double(totalFiles)) * 100 : 0
        let elapsed = max(Date().timeIntervalSince(startedAt), 0.001)
        let bps = Double(bytesDoneShared) / elapsed
        speedText = Self.formatSpeed(bps)
    }

    private func logActivity(_ line: String) {
        activityLog.append(line)
        if activityLog.count > activityLogLimit { activityLog.removeFirst(activityLog.count - activityLogLimit) }
    }

    private static func formatSpeed(_ bytesPerSecond: Double) -> String {
        let mb = bytesPerSecond / (1024 * 1024)
        if mb >= 1024 { return String(format: "%.1f GB/s", mb / 1024) }
        return String(format: "%.1f MB/s", mb)
    }
}
