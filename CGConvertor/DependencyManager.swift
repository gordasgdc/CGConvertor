import Foundation
import AppKit
import Combine

enum DependencyState: Equatable {
    case unknown, checking, ok, missing, optionalMissing
}

/// Un singur rand din panoul "Verificare & Dependente Sistem" — model
/// generic, nu hardcodat pe FFmpeg, ca sa fie usor de extins cu alte
/// componente in viitor (alte codecuri, unelte externe etc.) fara sa
/// schimbam forma UI-ului, doar lista de mai jos din DependencyManager.
struct DependencyItem: Identifiable {
    let id: String
    let name: String
    let isOptional: Bool
    var state: DependencyState = .unknown
    /// Verificare headless, rulata la deschiderea panoului (si la refresh).
    let check: () async -> DependencyState
    /// Actiunea butonului cand starea e missing/optionalMissing — nil daca
    /// nu exista nicio actiune automata (doar text informativ).
    let action: (@MainActor () -> Void)?
    let actionLabel: String

    static func == (lhs: DependencyItem, rhs: DependencyItem) -> Bool { lhs.id == rhs.id }
}

/// Manager modular, generic, al dependintelor native ale aplicatiei — nu
/// doar FFmpeg. Motivul de a exista: binarul `ffmpeg` bundle-uit in
/// Resources era anterior o copie bruta a build-ului Homebrew de pe
/// masina de dezvoltare, legata dinamic de cai `/opt/homebrew/Cellar/...`
/// — functioneaza DOAR pe masina care are exact acea versiune Homebrew
/// instalata, crapa cu `dyld: Library not loaded` pe orice alt Mac (sau
/// chiar pe aceeasi masina, dupa un `brew upgrade`). Fix real (2026-08-26):
/// binarul bundle-uit a fost inlocuit cu un build STATIC nativ arm64
/// (osxexperts.net, zero dependinte dylib externe, verificat cu `otool -L`)
/// — dar acest manager ramane, ca plasa de siguranta: daca binarul
/// bundle-uit tot esueaza dintr-un motiv neprevazut, userul poate
/// descarca din nou, fara sa astepte un fix de aplicatie viitor.
///
/// ARHITECTURA (directiva 2026-08-26, standard pentru tot ecosistemul
/// GDC de-acum): "Managerul Modular de Dependinte la Cerere" — aplicatia
/// de baza ramane usoara (NU bundle-uieste tot ce ar putea fi util),
/// panoul dedicat lasa userul sa aleaga ce instaleaza si cand, cu
/// transparenta totala asupra starii fiecarei componente.
@MainActor
final class DependencyManager: ObservableObject {
    static let shared = DependencyManager()

    @Published var items: [DependencyItem] = []
    @Published var isDownloadingFFmpeg = false
    @Published var downloadError: String?

    /// Indicatorul global (bulina din header) e verde DOAR pe baza
    /// componentelor OBLIGATORII — cele optionale (Homebrew) nu blocheaza
    /// starea "Sistem Optim", exact cum a cerut Cristi explicit.
    var isReady: Bool {
        items.filter { !$0.isOptional }.allSatisfy { $0.state == .ok }
    }

    private var downloadDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("CGConvertor", isDirectory: true)
            .appendingPathComponent("bin", isDirectory: true)
    }

    private init() {
        items = [
            DependencyItem(
                id: "ffmpeg", name: "FFmpeg", isOptional: false,
                check: { await Self.verifyRuns(MotorFFmpeg.gasesteBinar()) ? .ok : .missing },
                action: { [weak self] in self?.downloadAndInstallFFmpeg() },
                actionLabel: L.t("deps.ffmpeg.install")
            ),
            DependencyItem(
                id: "homebrew", name: "Homebrew", isOptional: true,
                check: {
                    let candidates = ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]
                    return candidates.contains { FileManager.default.isExecutableFile(atPath: $0) } ? .ok : .optionalMissing
                },
                action: { [weak self] in self?.copyHomebrewInstallCommand() },
                actionLabel: L.t("deps.homebrew.copy")
            ),
        ]
    }

    /// Rulat la deschiderea panoului + la apasarea "Reverifica" — fiecare
    /// componenta se testeaza singura, headless, independent de celelalte.
    func refreshAll() {
        for index in items.indices {
            items[index].state = .checking
            let check = items[index].check
            let id = items[index].id
            Task {
                let result = await check()
                if let idx = items.firstIndex(where: { $0.id == id }) {
                    items[idx].state = result
                }
            }
        }
    }

    var ffmpegState: DependencyState { items.first(where: { $0.id == "ffmpeg" })?.state ?? .unknown }

    private static func verifyRuns(_ path: String?) async -> Bool {
        guard let path, FileManager.default.isExecutableFile(atPath: path) else { return false }
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: path)
        proc.arguments = ["-version"]
        proc.standardOutput = Pipe()
        proc.standardError = Pipe()
        do {
            try proc.run()
            proc.waitUntilExit()
            return proc.terminationStatus == 0
        } catch {
            return false
        }
    }

    // MARK: - Descarcare automata FFmpeg (build static, potrivit arhitecturii curente)

    private struct StaticBuild {
        let ffmpegURL: URL
        let ffprobeURL: URL
    }

    private static var currentArchBuild: StaticBuild {
        #if arch(arm64)
        return StaticBuild(
            ffmpegURL: URL(string: "https://www.osxexperts.net/ffmpeg9arm.zip")!,
            ffprobeURL: URL(string: "https://www.osxexperts.net/ffprobe9arm.zip")!
        )
        #else
        return StaticBuild(
            ffmpegURL: URL(string: "https://www.osxexperts.net/ffmpeg80intel.zip")!,
            ffprobeURL: URL(string: "https://www.osxexperts.net/ffprobe80intel.zip")!
        )
        #endif
    }

    func downloadAndInstallFFmpeg() {
        guard !isDownloadingFFmpeg else { return }
        isDownloadingFFmpeg = true
        downloadError = nil

        Task {
            do {
                try FileManager.default.createDirectory(at: downloadDirectory, withIntermediateDirectories: true)
                let build = Self.currentArchBuild
                try await Self.downloadUnzipAndInstall(from: build.ffmpegURL, binaryName: "ffmpeg", into: downloadDirectory)
                try await Self.downloadUnzipAndInstall(from: build.ffprobeURL, binaryName: "ffprobe", into: downloadDirectory)
                isDownloadingFFmpeg = false
                if let idx = items.firstIndex(where: { $0.id == "ffmpeg" }) {
                    items[idx].state = .checking
                    let ok = await Self.verifyRuns(MotorFFmpeg.gasesteBinar())
                    items[idx].state = ok ? .ok : .missing
                }
            } catch {
                isDownloadingFFmpeg = false
                downloadError = error.localizedDescription
            }
        }
    }

    private static func downloadUnzipAndInstall(from url: URL, binaryName: String, into destinationDir: URL) async throws {
        let (tmpFileURL, response) = try await URLSession.shared.download(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw NSError(domain: "DependencyManager", code: 1,
                           userInfo: [NSLocalizedDescriptionKey: "Descărcarea a eșuat (\(binaryName))."])
        }

        let zipPath = tmpFileURL.path
        let extractDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: extractDir, withIntermediateDirectories: true)

        let unzip = Process()
        unzip.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        unzip.arguments = ["-o", zipPath, "-d", extractDir.path]
        unzip.standardOutput = Pipe()
        unzip.standardError = Pipe()
        try unzip.run()
        unzip.waitUntilExit()
        guard unzip.terminationStatus == 0 else {
            throw NSError(domain: "DependencyManager", code: 2,
                           userInfo: [NSLocalizedDescriptionKey: "Dezarhivarea a eșuat (\(binaryName))."])
        }

        let extractedBinary = extractDir.appendingPathComponent(binaryName)
        guard FileManager.default.fileExists(atPath: extractedBinary.path) else {
            throw NSError(domain: "DependencyManager", code: 3,
                           userInfo: [NSLocalizedDescriptionKey: "Arhiva nu conține \(binaryName)."])
        }

        let finalURL = destinationDir.appendingPathComponent(binaryName)
        try? FileManager.default.removeItem(at: finalURL)
        try FileManager.default.moveItem(at: extractedBinary, to: finalURL)

        // chmod +x + elimina carantina (fisierul a venit prin descarcare
        // directa din retea, macOS ii pune automat flag-ul de quarantine).
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: finalURL.path)
        let xattr = Process()
        xattr.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
        xattr.arguments = ["-d", "com.apple.quarantine", finalURL.path]
        xattr.standardOutput = Pipe()
        xattr.standardError = Pipe()
        try? xattr.run()
        xattr.waitUntilExit()

        try? FileManager.default.removeItem(at: extractDir)
        try? FileManager.default.removeItem(at: tmpFileURL)
    }

    // MARK: - Homebrew

    static let homebrewInstallCommand = #"/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)""#

    func copyHomebrewInstallCommand() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(Self.homebrewInstallCommand, forType: .string)
    }

    func openHomebrewSite() {
        NSWorkspace.shared.open(URL(string: "https://brew.sh")!)
    }
}
