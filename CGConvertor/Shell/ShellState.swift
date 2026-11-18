import Combine
import SwiftUI
import AppKit

/// Cele trei spații de lucru ale aplicației.
enum Workspace: String, CaseIterable, Identifiable {
    case transcode, offload, metadata
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .transcode: return "film.stack"
        case .offload: return "externaldrive.badge.checkmark"
        case .metadata: return "list.bullet.rectangle"
        }
    }
    var label: String { L.t("ws.\(rawValue)") }
}

enum ClipViewMode: String, CaseIterable, Identifiable {
    case grid, list
    var id: String { rawValue }
    var icon: String { self == .grid ? "square.grid.2x2" : "list.bullet" }
}

enum InspectorTab: String, CaseIterable, Identifiable {
    case output, clip, metadata
    var id: String { rawValue }
    var label: String { L.t("tw.tab.\(rawValue)") }
}

/// Starea comună a ferestrei: spațiul curent, selecția (partajată între spații) și modul de afișare.
@MainActor
final class ShellState: ObservableObject {
    private enum Keys { static let ws = "cgconvertor_workspace", view = "cgconvertor_clip_view", tab = "cgconvertor_inspector_tab" }

    @Published var workspace: Workspace { didSet { UserDefaults.standard.set(workspace.rawValue, forKey: Keys.ws) } }
    @Published var viewMode: ClipViewMode { didSet { UserDefaults.standard.set(viewMode.rawValue, forKey: Keys.view) } }
    @Published var inspectorTab: InspectorTab { didSet { UserDefaults.standard.set(inspectorTab.rawValue, forKey: Keys.tab) } }
    @Published var selection: Set<UUID> = []
    /// Clipul „în centru” (ultimul selectat): previzualizare și detalii.
    @Published var focusID: UUID?

    init() {
        let d = UserDefaults.standard
        workspace = d.string(forKey: Keys.ws).flatMap(Workspace.init(rawValue:)) ?? .transcode
        viewMode = d.string(forKey: Keys.view).flatMap(ClipViewMode.init(rawValue:)) ?? .grid
        inspectorTab = d.string(forKey: Keys.tab).flatMap(InspectorTab.init(rawValue:)) ?? .output
    }

    /// Selecție cu Cmd (comută) și Shift (interval) peste ordinea afișată.
    func click(_ id: UUID, ordered: [UUID]) {
        let flags = NSEvent.modifierFlags
        if flags.contains(.command) {
            if selection.contains(id) { selection.remove(id) } else { selection.insert(id) }
            focusID = id
        } else if flags.contains(.shift), let f = focusID, let a = ordered.firstIndex(of: f), let b = ordered.firstIndex(of: id) {
            selection = Set(ordered[min(a, b)...max(a, b)])
        } else {
            selection = [id]
            focusID = id
        }
    }

    func prune(existing: [UUID]) {
        let s = Set(existing)
        selection = selection.intersection(s)
        if let f = focusID, !s.contains(f) { focusID = selection.first }
    }
}

/// Miniaturi în cache, încărcate în afara firului principal.
enum ThumbCache {
    static let cache = NSCache<NSString, NSImage>()
    static func image(at path: String) -> NSImage? { cache.object(forKey: path as NSString) }
    static func load(_ path: String) async -> NSImage? {
        if let c = image(at: path) { return c }
        let img = await Task.detached(priority: .utility) { NSImage(contentsOfFile: path) }.value
        if let img { cache.setObject(img, forKey: path as NSString) }
        return img
    }
}

struct ClipThumb: View {
    let path: String?
    var contentMode: ContentMode = .fill
    @State private var img: NSImage?
    var body: some View {
        ZStack {
            Shift.elevated
            if let img {
                Image(nsImage: img).resizable().aspectRatio(contentMode: contentMode)
            } else {
                Image(systemName: "film").foregroundStyle(Shift.faint)
            }
        }
        .clipped()
        .task(id: path) {
            guard let path else { img = nil; return }
            img = ThumbCache.image(at: path)
            if img == nil { img = await ThumbCache.load(path) }
        }
    }
}

/// Eticheta de stare a unui clip (culoare + text) — aceeași în grilă, listă și inspector.
struct StareBadge: View {
    let stare: StareJob
    var body: some View {
        let (text, color): (String, Color) = {
            switch stare {
            case .astept: return (L.t("state.waiting"), Shift.muted)
            case .inLucru(let p): return (String(format: "%d%%", Int(p * 100)), Shift.accent)
            case .finalizat: return (L.t("state.done"), Shift.success)
            case .finalizatCuAvertisment: return (L.t("state.warn"), .orange)
            case .anulat: return (L.t("state.cancelled"), Shift.muted)
            case .eroare: return (L.t("state.error"), Shift.error)
            }
        }()
        Text(text)
            .font(.system(size: 10.5, weight: .semibold))
            .padding(.horizontal, 7).padding(.vertical, 2)
            .background(color.opacity(0.16))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

func formatDurata(_ s: Double?) -> String? {
    guard let s, s.isFinite else { return nil }
    let t = Int(s.rounded())
    return t >= 3600 ? String(format: "%d:%02d:%02d", t / 3600, (t / 60) % 60, t % 60) : String(format: "%d:%02d", t / 60, t % 60)
}

func fpsText(_ f: String?) -> String? {
    guard let f, let d = Double(f) else { return f.map { "\($0) fps" } }
    return String(format: "%g fps", (d * 100).rounded() / 100)
}

func rezumatMedia(_ m: MediaMetadata?) -> String? {
    guard let m else { return nil }
    let p = [m.rezolutieText, m.codecVideo?.uppercased(), fpsText(m.frameRate), formatDurata(m.durataSecunde)].compactMap { $0 }
    return p.isEmpty ? nil : p.joined(separator: " · ")
}
