import Foundation
import SwiftUI
import Combine

// MARK: - Coada de operații Offload
//
// O operație = un set de surse + destinații + opțiuni, rulat de același motor verificat
// (`OffloadRunner`). Coada rulează O SINGURĂ operație la un moment dat; când una se termină,
// următoarea în așteptare pornește automat. O anulare oprește coada (nu continuă pe tăcute).
// Starea se păstrează pe disc (domeniul aplicației de test e separat de cel al aplicației instalate).

struct OffloadQueueJob: Identifiable, Codable, Equatable {
    enum State: String, Codable { case waiting, running, done, doneWithIssues, failed, cancelled, interrupted }
    var id = UUID()
    var title: String
    var sources: [String]
    var destinations: [String]
    var model: VerificationModel
    var project = ""
    var card = ""
    var camera = ""
    var operatorName = ""
    var client = ""
    var notes = ""
    var namingTemplate = ""
    var extractMetadata = false
    var state: State = .waiting
    var detail = ""
    var addedAt = Date()

    var meta: ProductionMeta {
        var m = ProductionMeta()
        m.project = project; m.card = card; m.camera = camera
        m.operatorName = operatorName; m.client = client; m.notes = notes
        return m
    }
    var isFinished: Bool { [.done, .doneWithIssues, .failed, .cancelled, .interrupted].contains(state) }
}

@MainActor
final class OffloadQueue: ObservableObject {
    @Published private(set) var jobs: [OffloadQueueJob] = []
    /// Coada pornește operațiile în așteptare una după alta.
    @Published var isActive = false
    private let fileURL: URL

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? Self.defaultURL()
        load()
    }

    static func defaultURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent(Bundle.main.bundleIdentifier ?? AppIsolation.folderName, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("offload_queue.json")
    }

    var waitingCount: Int { jobs.filter { $0.state == .waiting }.count }
    var running: OffloadQueueJob? { jobs.first { $0.state == .running } }
    var nextWaiting: OffloadQueueJob? { jobs.first { $0.state == .waiting } }

    func add(_ job: OffloadQueueJob) { jobs.append(job); save() }

    func remove(_ id: UUID) {
        guard let j = jobs.first(where: { $0.id == id }), j.state != .running else { return }
        jobs.removeAll { $0.id == id }; save()
    }

    func move(_ id: UUID, by delta: Int) {
        guard let i = jobs.firstIndex(where: { $0.id == id }), jobs[i].state == .waiting else { return }
        let j = i + delta
        guard jobs.indices.contains(j), jobs[j].state == .waiting else { return }
        jobs.swapAt(i, j); save()
    }

    func retry(_ id: UUID) {
        guard let i = jobs.firstIndex(where: { $0.id == id }), jobs[i].isFinished else { return }
        jobs[i].state = .waiting; jobs[i].detail = ""; save()
    }

    func clearFinished() { jobs.removeAll { $0.isFinished }; save() }

    func markRunning(_ id: UUID) { set(id, .running, ""); }
    func finish(_ id: UUID, state: OffloadQueueJob.State, detail: String) { set(id, state, detail) }

    private func set(_ id: UUID, _ state: OffloadQueueJob.State, _ detail: String) {
        guard let i = jobs.firstIndex(where: { $0.id == id }) else { return }
        jobs[i].state = state; jobs[i].detail = detail; save()
    }

    private func load() {
        guard let d = try? Data(contentsOf: fileURL),
              var list = try? JSONDecoder().decode([OffloadQueueJob].self, from: d) else { return }
        // O operație „în curs” la o închidere neașteptată nu e nici terminată, nici în așteptare.
        for i in list.indices where list[i].state == .running { list[i].state = .interrupted; list[i].detail = "" }
        jobs = list
    }

    private func save() {
        if let d = try? JSONEncoder().encode(jobs) { try? d.write(to: fileURL, options: .atomic) }
    }
}

struct OffloadQueueSheet: View {
    @ObservedObject var queue: OffloadQueue
    let transferRunning: Bool
    let canAddCurrent: Bool
    let onAddCurrent: () -> Void
    let onStart: () -> Void
    let onStop: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: DM.Space.m) {
            HStack {
                Text(L.t("queue.title")).font(DM.Font.sectionTitle)
                Spacer()
                Button(L.t("queue.addCurrent"), action: onAddCurrent).disabled(!canAddCurrent)
            }
            if queue.jobs.isEmpty {
                Text(L.t("queue.empty")).foregroundStyle(DM.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                List {
                    ForEach(Array(queue.jobs.enumerated()), id: \.element.id) { idx, job in
                        row(job, index: idx + 1)
                    }
                }
                .frame(minHeight: 200)
            }
            HStack {
                Button(L.t("queue.clearFinished")) { queue.clearFinished() }
                    .disabled(!queue.jobs.contains { $0.isFinished })
                Spacer()
                if queue.isActive {
                    Button(L.t("queue.stop"), role: .destructive, action: onStop)
                } else {
                    Button(L.t("queue.start"), action: onStart)
                        .buttonStyle(.borderedProminent).tint(DM.accent)
                        .disabled(queue.waitingCount == 0)
                }
                Button(L.t("queue.close")) { dismiss() }.keyboardShortcut(.cancelAction)
            }
        }
        .padding(DM.Space.l)
        .frame(minWidth: 620, minHeight: 360)
    }

    private func row(_ job: OffloadQueueJob, index: Int) -> some View {
        HStack(spacing: DM.Space.m) {
            Text("\(index)").font(DM.Font.mono).foregroundStyle(DM.textTertiary).frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(job.title).font(DM.Font.label).lineLimit(1)
                Text(String(format: L.t("queue.summary"), job.sources.count, job.destinations.count)
                     + (job.extractMetadata ? " · " + L.t("queue.withMetadata") : ""))
                    .font(DM.Font.detail).foregroundStyle(DM.textSecondary).lineLimit(1)
                if !job.detail.isEmpty { Text(job.detail).font(DM.Font.detail).foregroundStyle(DM.textTertiary).lineLimit(2) }
            }
            Spacer()
            Text(L.t("queue.state.\(job.state.rawValue)")).font(DM.Font.detail)
                .foregroundStyle(color(job.state))
            if job.state == .waiting {
                Button { queue.move(job.id, by: -1) } label: { Image(systemName: "chevron.up") }.buttonStyle(.borderless)
                Button { queue.move(job.id, by: 1) } label: { Image(systemName: "chevron.down") }.buttonStyle(.borderless)
            }
            if job.isFinished {
                Button(L.t("queue.retry")) { queue.retry(job.id) }.buttonStyle(.borderless)
            }
            if job.state != .running {
                Button { queue.remove(job.id) } label: { Image(systemName: "xmark.circle") }
                    .buttonStyle(.borderless).help(L.t("queue.remove"))
            }
        }
    }

    private func color(_ s: OffloadQueueJob.State) -> Color {
        switch s {
        case .done: return DM.verified
        case .doneWithIssues: return DM.warning
        case .failed, .interrupted: return DM.failure
        case .running: return DM.accent
        default: return DM.textSecondary
        }
    }
}
