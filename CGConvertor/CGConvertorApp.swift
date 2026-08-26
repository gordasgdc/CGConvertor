import SwiftUI
import AppKit

@main
struct CGConvertorApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 900, minHeight: 580)
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button(L.t("menu.about")) { showAboutPanel() }
            }
            CommandGroup(after: .appInfo) {
                Button(L.t("menu.checkForUpdates")) { UpdateChecker.checkAndShowAlert() }
            }
        }
    }

    private func showAboutPanel() {
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "CG Convertor",
            .applicationVersion: UpdateChecker.currentVersion,
            .credits: NSAttributedString(string: "© \(Calendar.current.component(.year, from: Date())) GDC. Toate drepturile rezervate."),
        ])
    }
}
