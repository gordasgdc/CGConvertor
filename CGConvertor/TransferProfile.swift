import Foundation
import Combine

/// Profil de transfer salvat — port din DataMover
/// (`~/Developer/DataMover/mac-native/Sources/DataMoverMac/TransferProfile.swift`):
/// o configurație completă, numită de user, reutilizabilă fără să
/// retastezi căi/opțiuni de fiecare dată ("Backup Proiecte RAW pe SSD
/// 3TB", "Transfer Rapid SD Card"). NU se portează câmpurile
/// `cloudRemote`/`cloudRemoteFolder` din original — CloudSyncService.swift
/// există în repo (port pregătit), dar NU e conectat încă la
/// OffloadEngine/OffloadView (vezi CLAUDE.md: cere un cont rclone real
/// pentru testare end-to-end, deliberat amânat).
struct TransferProfile: Codable, Identifiable, Equatable {
    var id: String { name }
    var name: String
    var sourcePaths: [String]
    var destinationPaths: [String]
    var verificationModel: VerificationModel
    var chunkSizeMB: Int
    var ramLimitMB: Int
    var namingTemplate: String
    var project: String
    var client: String
    var camera: String
    var operatorName: String
}

final class TransferProfileStore: ObservableObject {
    static let shared = TransferProfileStore()

    private let fileURL: URL
    @Published private(set) var profiles: [TransferProfile] = []

    private init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("CGConvertor", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        fileURL = base.appendingPathComponent("transfer_profiles.json")
        load()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([TransferProfile].self, from: data) else { return }
        profiles = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(profiles) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    func upsert(_ profile: TransferProfile) {
        if let idx = profiles.firstIndex(where: { $0.name == profile.name }) {
            profiles[idx] = profile
        } else {
            profiles.append(profile)
        }
        save()
    }

    func delete(_ profile: TransferProfile) {
        profiles.removeAll { $0.name == profile.name }
        save()
    }
}
