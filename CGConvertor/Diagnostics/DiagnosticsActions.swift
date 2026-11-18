import AppKit

/// Acțiunile de diagnostic expuse în Setări. Exportul nu încarcă nimic nicăieri.
enum DiagnosticsActions {
    static func exportAndReveal() {
        let exporter = DiagnosticExporter(log: StructuredLog.shared, accessSummary: LicenseManager.shared.diagnosticSummary)
        do {
            let zip = try exporter.export(to: DiagnosticExporter.defaultFolder)
            NSWorkspace.shared.activateFileViewerSelecting([zip])
        } catch {
            StructuredLog.shared.log(.error, "diagnostics", "diagnostics.export.fail", "Exportul diagnosticului a esuat", error: error)
            NSSound.beep()
        }
    }

    static func openLogFolder() {
        NSWorkspace.shared.open(StructuredLog.shared.config.directory)
    }
}
