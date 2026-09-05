import Foundation
import Combine

/// Istoricul offload-urilor efectuate — port din DataMover
/// (`HistoryStore.swift`): data, folderul creat, sursele/destinațiile
/// folosite, câte fișiere OK/nepotrivire/eroare. Persistat în Application
/// Support, între lansări ale aplicației.
struct HistoryEntry: Codable, Identifiable {
    var id: String { "\(dateText)-\(folderName)" }
    let dateText: String
    let folderName: String
    let sourcesSummary: String
    let destSummary: String
    let okCount: Int
    let mismatchCount: Int
    let errorCount: Int
    var sourcePaths: [String] = []
    var destinationTargetPaths: [String] = []
}

final class HistoryStore: ObservableObject {
    static let shared = HistoryStore()

    private let fileURL: URL
    @Published private(set) var entries: [HistoryEntry] = []

    private init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("CGConvertor", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        fileURL = base.appendingPathComponent("offload_history.json")
        load()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([HistoryEntry].self, from: data) else { return }
        entries = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    func record(folderName: String, sourcePath: String, destinationTargets: [String],
                okCount: Int, mismatchCount: Int, errorCount: Int) {
        let df = DateFormatter()
        df.dateFormat = "dd.MM.yyyy HH:mm"
        let entry = HistoryEntry(
            dateText: df.string(from: Date()), folderName: folderName,
            sourcesSummary: (sourcePath as NSString).lastPathComponent,
            destSummary: destinationTargets.map { ($0 as NSString).lastPathComponent }.joined(separator: ", "),
            okCount: okCount, mismatchCount: mismatchCount, errorCount: errorCount,
            sourcePaths: [sourcePath], destinationTargetPaths: destinationTargets
        )
        entries.append(entry)
        if entries.count > 200 { entries.removeFirst(entries.count - 200) }
        save()
    }

    func delete(_ entry: HistoryEntry) {
        entries.removeAll { $0.id == entry.id }
        save()
    }

    func clearAll() {
        entries.removeAll()
        save()
    }
}
