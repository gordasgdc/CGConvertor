import Foundation
import Combine

/// Watch Folders — orice fișier video nou apărut într-un folder urmărit
/// intră automat în coada de conversie. Scanare periodică (polling), NU
/// FSEvents/kqueue — decizie deliberată: comportament IDENTIC pe Mac și
/// Windows (Python nu are un echivalent nativ simplu al FSEvents fără o
/// dependință nouă), fără dependințe noi, suficient de rapid (interval
/// 2s) pentru un scenariu de offload/dropbox de fișiere video (nu evenimente
/// sistem de mare frecvență).
struct WatchedFolder: Codable, Identifiable, Equatable {
    let id: String
    var path: String
    var enabled: Bool

    init(path: String, enabled: Bool = true) {
        self.id = UUID().uuidString
        self.path = path
        self.enabled = enabled
    }
}

/// Extensii recunoscute — ACELAȘI set pe Mac și Windows (vezi
/// `python/watch_folders.py`), ca un fișier "văzut" de watcher să se
/// comporte identic indiferent de platformă.
let watchFolderExtensions: Set<String> = ["mov", "mp4", "mxf", "mkv", "avi", "m4v"]

@MainActor
final class WatchFolderManager: ObservableObject {
    static let shared = WatchFolderManager()

    @Published var folders: [WatchedFolder] {
        didSet { save() }
    }

    /// Apelat cu lista de căi noi, STABILE (mărime neschimbată între două
    /// scanări), gata de adăugat în coadă.
    var onNewFiles: (([URL]) -> Void)?

    private static let key = "cgconvertor_watch_folders"
    private var timer: Timer?
    /// path -> ultima mărime văzută (fișier încă în scriere dacă se schimbă)
    private var pendingSizes: [String: UInt64] = [:]
    /// path -> deja adăugat în coadă SAU ignorat ca preexistent la baseline
    private var knownPaths: Set<String> = []
    private var baselineDone: Set<String> = [] // id-uri de foldere care și-au stabilit deja baseline-ul

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let decoded = try? JSONDecoder().decode([WatchedFolder].self, from: data) {
            folders = decoded
        } else {
            folders = []
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(folders) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }

    func addFolder(_ path: String) {
        guard !folders.contains(where: { $0.path == path }) else { return }
        folders.append(WatchedFolder(path: path))
    }

    /// Listează (READ-ONLY, fără efecte secundare) fișierele deja
    /// existente într-un folder proaspăt adăugat — apelată la adăugare,
    /// ca userul să aleagă CE anume vrea să adauge acum în coadă
    /// (2026-09-05, feedback direct de la Cristi: fără asta, indicarea
    /// unui folder care deja conține clipurile lui nu făcea NIMIC —
    /// baseline-ul ignoră deliberat tot ce exista deja, ca să nu arunce
    /// orice folder ales în coadă. Cristi ar fi trebuit să copieze/mute
    /// fișierele ca să "pară noi" — exact duplicarea pe care n-o vrea).
    func listExistingFiles(forPath path: String) -> [URL] {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(atPath: path) else { return [] }
        return entries
            .filter { watchFolderExtensions.contains(($0 as NSString).pathExtension.lowercased()) }
            .map { URL(fileURLWithPath: (path as NSString).appendingPathComponent($0)) }
    }

    /// Marchează TOATE fișierele deja existente (indiferent ce a ales
    /// userul să adauge acum) ca "cunoscute" — apelată o singură dată,
    /// după ce userul a răspuns la sheet-ul de selecție (adaugă unele,
    /// toate, sau anulează), ca scanarea periodică să nu le mai
    /// re-detecteze ca fiind "noi".
    func markBaselineKnown(forPath path: String, files: [URL]) {
        guard let folder = folders.first(where: { $0.path == path }) else { return }
        knownPaths.formUnion(files.map { $0.path })
        baselineDone.insert(folder.id)
    }

    func removeFolder(_ folder: WatchedFolder) {
        folders.removeAll { $0.id == folder.id }
        baselineDone.remove(folder.id)
    }

    func toggle(_ folder: WatchedFolder) {
        guard let idx = folders.firstIndex(where: { $0.id == folder.id }) else { return }
        folders[idx].enabled.toggle()
    }

    func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.scanAll() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func scanAll() {
        let fm = FileManager.default
        var stableNewFiles: [URL] = []

        for folder in folders where folder.enabled {
            guard let entries = try? fm.contentsOfDirectory(atPath: folder.path) else { continue }
            let candidates = entries
                .filter { watchFolderExtensions.contains(($0 as NSString).pathExtension.lowercased()) }
                .map { (folder.path as NSString).appendingPathComponent($0) }

            if !baselineDone.contains(folder.id) {
                // Prima trecere pe acest folder — doar stabilim baseline-ul,
                // NU adaugam fisierele deja existente (altfel orice folder
                // ales ca "watch" ar arunca tot ce contine deja in coada).
                knownPaths.formUnion(candidates)
                baselineDone.insert(folder.id)
                continue
            }

            for path in candidates where !knownPaths.contains(path) {
                guard let attrs = try? fm.attributesOfItem(atPath: path),
                      let size = attrs[.size] as? UInt64 else { continue }
                if let lastSize = pendingSizes[path], lastSize == size {
                    // Marime neschimbata fata de trecerea anterioara — fisierul
                    // s-a terminat de scris (copiere de pe card, export etc.).
                    pendingSizes.removeValue(forKey: path)
                    knownPaths.insert(path)
                    stableNewFiles.append(URL(fileURLWithPath: path))
                } else {
                    pendingSizes[path] = size
                }
            }
        }

        if !stableNewFiles.isEmpty {
            onNewFiles?(stableNewFiles)
        }
    }
}
