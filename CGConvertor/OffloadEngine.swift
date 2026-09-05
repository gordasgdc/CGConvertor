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

enum VerificationModel: String, CaseIterable, Identifiable, Codable {
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
    let targetRoot: String
    let okCount: Int
    let mismatchCount: Int
    let errorCount: Int
    let recoveredCount: Int
    let csvPath: String?
    let mhlPath: String?
    let htmlPath: String?
}

/// Verificare de spațiu liber, ÎNAINTE de primul octet copiat (port din
/// DataMover, Etapa 2026-09-03 — motiv real: un card mare pornit către un
/// disc aproape plin copia ore întregi și eșua la mijloc). Marjă: 1% din
/// transfer, minim 100 MB.
func offloadHasEnoughSpace(destinationRoot: String, neededBytes: UInt64) -> (ok: Bool, availableBytes: Int64?) {
    let url = URL(fileURLWithPath: destinationRoot)
    guard let values = try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]),
          let available = values.volumeAvailableCapacityForImportantUsage else {
        return (true, nil) // nu putem citi capacitatea — nu blocăm transferul pe o necunoscută
    }
    let margin = max(UInt64(Double(neededBytes) * 0.01), 100 * 1024 * 1024)
    return (available >= Int64(neededBytes + margin), available)
}

/// Copiază + verifică toate fișierele sursă către O destinație (rădăcina
/// deja construită cu șablonul de denumire — vezi `NamingTemplate` — de
/// `OffloadRunner`). Rulează pe un `DispatchQueue` de fundal, niciodată pe
/// thread-ul principal.
///
/// Port din DataMover (Etapa 2026-09-03): reîncercare automată a
/// fișierelor eșuate/nepotrivite, MHL (Media Hash List) alături de CSV, și
/// raport HTML brandat cu `ProductionMeta` — vezi `ProductionMeta.swift`.
final class OffloadDestinationJob {
    let destination: String
    let folderName: String
    let files: [OffloadFileEntry]
    let sourceRoot: String
    let model: VerificationModel
    let meta: ProductionMeta
    let cancel: CancelToken
    let pause: PauseToken
    let onFileDone: (UInt64) -> Void
    let onActivity: (String) -> Void

    private let startedAt = Date()

    init(destination: String, folderName: String, files: [OffloadFileEntry], sourceRoot: String, model: VerificationModel,
         meta: ProductionMeta, cancel: CancelToken, pause: PauseToken,
         onFileDone: @escaping (UInt64) -> Void, onActivity: @escaping (String) -> Void) {
        self.destination = destination
        self.folderName = folderName
        self.files = files
        self.sourceRoot = sourceRoot
        self.model = model
        self.meta = meta
        self.cancel = cancel
        self.pause = pause
        self.onFileDone = onFileDone
        self.onActivity = onActivity
    }

    func run() -> OffloadDestinationResult {
        let fm = FileManager.default
        let targetRoot = (destination as NSString).appendingPathComponent(folderName)
        try? fm.createDirectory(atPath: targetRoot, withIntermediateDirectories: true)

        let csvPath = (targetRoot as NSString).appendingPathComponent("offload_report_\(Self.timestamp()).csv")
        let csvHandle: FileHandle? = {
            fm.createFile(atPath: csvPath, contents: "fisier,marime_bytes,verificare_sursa,verificare_destinatie,status,eroare\n".data(using: .utf8))
            return FileHandle(forWritingAtPath: csvPath)
        }()
        defer { try? csvHandle?.close() }

        let mhlPath = (targetRoot as NSString).appendingPathComponent("\(folderName).mhl")
        let mhl = MHLWriter(path: mhlPath, model: model, toolName: "CGConvertor", startedAt: startedAt)

        var rows: [OffloadReportRow] = []
        func logRow(_ row: OffloadReportRow) {
            let line = "\"\(row.relPath)\",\(row.sizeBytes),\(row.srcHash),\(row.dstHash),\(row.status),\"\(row.error)\"\n"
            csvHandle?.seekToEndOfFile()
            csvHandle?.write(line.data(using: .utf8) ?? Data())
            rows.append(row)
        }

        let chunkSize = IOSettings.chunkSizeBytes
        var failedEntries: [(entry: OffloadFileEntry, wasError: Bool)] = []
        var ok = 0, mismatch = 0, errors = 0

        enum Outcome { case ok, mismatch, error }

        /// O singură trecere de copiere+verificare peste `entry` — folosită
        /// IDENTIC la prima trecere ȘI la reîncercarea automată (port din
        /// DataMover: cele două căi NU trebuie să diveargă, altfel un
        /// fișier recuperat ar fi verificat altfel decât unul copiat din
        /// prima). NU incrementează contoarele — apelantul decide cum
        /// contează rezultatul (prima trecere vs. reîncercare).
        func processOne(_ entry: OffloadFileEntry, isRetry: Bool) -> Outcome {
            if cancel.isCancelled { return .error }
            pause.waitWhilePaused(cancel: cancel)
            if cancel.isCancelled { return .error }
            IOSettings.waitIfOverRAMLimit(cancel: cancel) { [weak self] in
                self?.onActivity(L.t("offload.log.ramWait"))
            }

            let dstPath = (targetRoot as NSString).appendingPathComponent(entry.relPath)
            let dstDir = (dstPath as NSString).deletingLastPathComponent
            try? fm.createDirectory(atPath: dstDir, withIntermediateDirectories: true)
            if isRetry { try? fm.removeItem(atPath: dstPath) } // fisierul partial anterior nu trebuie sa induca in eroare verificarea

            do {
                try offloadCopyFile(src: entry.fullPath, dst: dstPath, cancel: cancel, chunkSize: chunkSize)
                let statusOK = isRetry ? "OK (reîncercat)" : "OK"
                if model == .sizeOnly {
                    let dstSize = (try? fm.attributesOfItem(atPath: dstPath)[.size] as? UInt64) ?? 0
                    if dstSize == entry.size {
                        logRow(OffloadReportRow(relPath: entry.relPath, sizeBytes: entry.size, srcHash: "", dstHash: "", status: statusOK, error: ""))
                        mhl?.add(relPath: entry.relPath, size: Int64(entry.size), modificationDate: nil, hashHex: "", hashedAt: Date())
                        return .ok
                    } else {
                        logRow(OffloadReportRow(relPath: entry.relPath, sizeBytes: entry.size, srcHash: "", dstHash: "", status: "NEPOTRIVIRE", error: "marime diferita"))
                        return .mismatch
                    }
                } else {
                    let srcHash = try offloadHashOfFile(path: entry.fullPath, model: model, cancel: cancel, chunkSize: chunkSize)
                    let dstHash = try offloadHashOfFile(path: dstPath, model: model, cancel: cancel, chunkSize: chunkSize)
                    if srcHash == dstHash {
                        logRow(OffloadReportRow(relPath: entry.relPath, sizeBytes: entry.size, srcHash: srcHash, dstHash: dstHash, status: statusOK, error: ""))
                        mhl?.add(relPath: entry.relPath, size: Int64(entry.size), modificationDate: nil, hashHex: srcHash, hashedAt: Date())
                        return .ok
                    } else {
                        logRow(OffloadReportRow(relPath: entry.relPath, sizeBytes: entry.size, srcHash: srcHash, dstHash: dstHash, status: "NEPOTRIVIRE", error: "hash diferit"))
                        onActivity(String(format: L.t("offload.log.mismatch"), entry.relPath))
                        return .mismatch
                    }
                }
            } catch {
                let isPerm = offloadIsPermissionError(error)
                logRow(OffloadReportRow(relPath: entry.relPath, sizeBytes: entry.size, srcHash: "", dstHash: "", status: "EROARE", error: error.localizedDescription))
                onActivity(String(format: L.t(isPerm ? "offload.log.permError" : "offload.log.error"), entry.relPath, error.localizedDescription))
                return .error
            }
        }

        for entry in files {
            if cancel.isCancelled { break }
            switch processOne(entry, isRetry: false) {
            case .ok: ok += 1
            case .mismatch: mismatch += 1; failedEntries.append((entry, false))
            case .error: errors += 1; failedEntries.append((entry, true))
            }
            onFileDone(entry.size)
        }

        // Reîncercare automată, O SINGURĂ dată — fișierele care mai eșuează
        // a doua oară rămân definitiv NEPOTRIVIRE/EROARE, fără dublă
        // numărare (port DataMover).
        var recovered = 0
        if !cancel.isCancelled, !failedEntries.isEmpty {
            onActivity(String(format: L.t("offload.log.retrying"), failedEntries.count))
            for (entry, wasError) in failedEntries {
                if cancel.isCancelled { break }
                switch processOne(entry, isRetry: true) {
                case .ok:
                    ok += 1; recovered += 1
                    if wasError { errors = max(0, errors - 1) } else { mismatch = max(0, mismatch - 1) }
                case .mismatch, .error: break // ramane in contorul deja adaugat la prima trecere
                }
            }
        }

        let mhlFinalPath = mhl?.close(finishedAt: Date())

        let htmlPath = (targetRoot as NSString).appendingPathComponent("Raport_\(Self.timestamp()).html")
        let htmlOK = OffloadHTMLReport.write(
            path: htmlPath, destination: destination, folderName: folderName, rows: rows,
            meta: meta, startedAt: startedAt, finishedAt: Date(),
            okCount: ok, mismatchCount: mismatch, errorCount: errors,
            verificationLabel: model.label, mhlPath: mhlFinalPath, truncatedNote: nil
        )

        return OffloadDestinationResult(
            destination: destination, targetRoot: targetRoot, okCount: ok, mismatchCount: mismatch,
            errorCount: errors, recoveredCount: recovered, csvPath: csvPath,
            mhlPath: mhlFinalPath, htmlPath: htmlOK ? htmlPath : nil
        )
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
    /// Port DataMover (Etapa 2026-09-03) — spațiu insuficient detectat
    /// ÎNAINTE de primul octet copiat; nil = totul e în regulă sau nu s-a
    /// putut verifica (nu blocăm transferul pe o necunoscută).
    @Published var insufficientSpaceWarning: String?

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

    /// `namingTemplate` gol → `NamingTemplate.defaultTemplate` (identic cu
    /// comportamentul vechi, un singur folder `<data>_<Proiect>_<Card>`
    /// per destinație — nimeni nu e afectat dacă nu schimbă șablonul).
    /// `ignoreSpaceWarning: true` forțează pornirea chiar dacă vreo
    /// destinație pare fără spațiu suficient (userul a confirmat explicit).
    func start(sourceRoot: String, destinations: [String], model: VerificationModel,
               meta: ProductionMeta = ProductionMeta(), namingTemplate: String = "",
               ignoreSpaceWarning: Bool = false) {
        guard !destinations.isEmpty else { return }
        cancelToken = CancelToken()
        pauseToken = PauseToken()
        isPaused = false
        activityLog.removeAll()
        lastResults.removeAll()
        permissionErrorPath = nil
        insufficientSpaceWarning = nil

        let files = offloadListAllFiles(root: sourceRoot)
        guard !files.isEmpty else {
            statusText = L.t("offload.status.noFiles")
            return
        }
        let neededBytes = files.reduce(UInt64(0)) { $0 + $1.size }
        let folderName = NamingTemplate.render(namingTemplate, context: .init(
            project: meta.project, card: meta.card, camera: meta.camera, operatorName: meta.operatorName, date: Date()
        ))

        if !ignoreSpaceWarning {
            for dest in destinations {
                try? FileManager.default.createDirectory(atPath: dest, withIntermediateDirectories: true)
                let check = offloadHasEnoughSpace(destinationRoot: dest, neededBytes: neededBytes)
                if !check.ok {
                    let availableText = formatBytes(check.availableBytes)
                    insufficientSpaceWarning = String(format: L.t("offload.status.insufficientSpace"),
                                                       (dest as NSString).lastPathComponent, formatBytes(Int64(neededBytes)), availableText)
                    return
                }
            }
        }

        totalFiles = files.count * destinations.count
        totalBytes = neededBytes * UInt64(destinations.count)
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
                    destination: dest, folderName: folderName, files: files, sourceRoot: sourceRoot, model: model,
                    meta: meta, cancel: cancel, pause: pause,
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
            let totalRecovered = results.reduce(0) { $0 + $1.recoveredCount }
            if cancel.isCancelled {
                self.statusText = L.t("offload.status.cancelled")
            } else {
                self.statusText = totalRecovered > 0
                    ? String(format: L.t("offload.status.doneWithRecovered"), totalOK, totalMismatch, totalErrors, totalRecovered)
                    : String(format: L.t("offload.status.done"), totalOK, totalMismatch, totalErrors)
                HistoryStore.shared.record(
                    folderName: folderName, sourcePath: sourceRoot,
                    destinationTargets: results.map { $0.targetRoot },
                    okCount: totalOK, mismatchCount: totalMismatch, errorCount: totalErrors
                )
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
