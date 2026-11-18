import SwiftUI
import AppKit

#if DEBUG
/// Doar pentru verificare locală (build Debug): setează starea din variabile de mediu, salvează o captură a ferestrei și închide aplicația.
@MainActor
enum UISnapshot {
    static func runIfRequested(vm: ConvertorViewModel, shell: ShellState) {
        let env = ProcessInfo.processInfo.environment
        guard let out = env["CGC_SNAP"] else { return }
        if let l = env["CGC_LANG"].flatMap(AppLanguage.init(rawValue:)) { L.current = l }
        if let t = env["CGC_THEME"].flatMap(ThemePreference.init(rawValue:)) { AppSettings.shared.themePreference = t }
        if let w = env["CGC_WS"].flatMap(Workspace.init(rawValue:)) { shell.workspace = w }
        if let v = env["CGC_VIEW"].flatMap(ClipViewMode.init(rawValue:)) { shell.viewMode = v }
        if let t = env["CGC_TAB"].flatMap(InspectorTab.init(rawValue:)) { shell.inspectorTab = t }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            if let sz = env["CGC_SIZE"]?.split(separator: "x").compactMap({ Double($0) }), sz.count == 2, let w = NSApp.windows.first {
                w.setContentSize(NSSize(width: sz[0], height: sz[1]))
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 12) {
            let n = Int(env["CGC_SELECT"] ?? "0") ?? 0
            if n > 0 { shell.selection = Set(vm.joburi.prefix(n).map(\.id)); shell.focusID = vm.joburi.first?.id }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 22) {
            guard let view = NSApp.windows.first(where: { $0.isVisible })?.contentView?.superview ?? NSApp.windows.first?.contentView,
                  let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { NSApp.terminate(nil); return }
            view.cacheDisplay(in: view.bounds, to: rep)
            if let png = rep.representation(using: .png, properties: [:]) { try? png.write(to: URL(fileURLWithPath: out)) }
            NSApp.terminate(nil)
        }
    }
}
#endif
