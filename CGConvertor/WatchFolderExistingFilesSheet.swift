import SwiftUI

/// Sheet de selecție a fișierelor deja existente într-un folder proaspăt
/// adăugat la Watch Folders (2026-09-05, feedback direct de la Cristi —
/// vezi `WatchFolders.swift`, `listExistingFiles`/`markBaselineKnown`).
/// "Selectează tot"/"Deselectează tot" cerute explicit, ca alternativă la
/// un simplu Da/Nu — userul vede EXACT ce fișiere există și alege liber.
struct WatchFolderExistingFilesSheet: View {
    let files: [URL]
    @Binding var isPresented: Bool
    let onDecide: ([URL]) -> Void

    @State private var selected: Set<URL>

    init(files: [URL], isPresented: Binding<Bool>, onDecide: @escaping ([URL]) -> Void) {
        self.files = files
        self._isPresented = isPresented
        self.onDecide = onDecide
        // Implicit toate selectate — cazul comun e "da, adaugă tot ce e deja acolo".
        self._selected = State(initialValue: Set(files))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L.t("watchFolders.existingSheet.title"))
                .font(.system(size: 14, weight: .semibold))
            Text(String(format: L.t("watchFolders.existingSheet.subtitle"), files.count))
                .font(.system(size: 11))
                .foregroundStyle(Shift.muted)

            HStack {
                Button(L.t("watchFolders.existingSheet.selectAll")) { selected = Set(files) }
                    .buttonStyle(ShiftGhostButtonStyle())
                Button(L.t("watchFolders.existingSheet.selectNone")) { selected.removeAll() }
                    .buttonStyle(ShiftGhostButtonStyle())
                Spacer()
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(files, id: \.self) { url in
                        Button {
                            if selected.contains(url) { selected.remove(url) } else { selected.insert(url) }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: selected.contains(url) ? "checkmark.square.fill" : "square")
                                    .foregroundStyle(selected.contains(url) ? Shift.accent : Shift.faint)
                                Text(url.lastPathComponent)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(Shift.muted)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(height: 220)

            HStack {
                Spacer()
                Button(L.t("watchFolders.existingSheet.cancel")) {
                    onDecide([])
                    isPresented = false
                }
                .buttonStyle(ShiftGhostButtonStyle())
                Button(String(format: L.t("watchFolders.existingSheet.add"), selected.count)) {
                    onDecide(Array(selected))
                    isPresented = false
                }
                .buttonStyle(ShiftGhostButtonStyle())
                .disabled(selected.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 420)
        .background(Shift.bg)
    }
}
