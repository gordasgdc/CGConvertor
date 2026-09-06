import SwiftUI

/// Istoricul offload-urilor anterioare — port din DataMover
/// (`HistoryView.swift`), stilizat "Shift" ca restul aplicației.
struct OffloadHistorySheet: View {
    @ObservedObject private var store = HistoryStore.shared
    @Binding var isPresented: Bool
    @State private var confirmClearAll = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L.t("history.title")).font(.system(size: 16, weight: .semibold))
                Spacer()
                if !store.entries.isEmpty {
                    Button(role: .destructive) { confirmClearAll = true } label: {
                        Label(L.t("history.clearAll"), systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                    .confirmationDialog(L.t("history.clearAllConfirm"), isPresented: $confirmClearAll) {
                        Button(L.t("history.clearAll"), role: .destructive) { store.clearAll() }
                        Button(L.t("offload.cancel"), role: .cancel) {}
                    }
                }
            }

            if store.entries.isEmpty {
                Spacer()
                Text(L.t("history.empty"))
                    .font(.system(size: 13))
                    .foregroundStyle(Shift.faint)
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(store.entries.reversed()) { entry in
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(entry.folderName).font(.system(size: 13, weight: .semibold))
                                    Text(entry.dateText).font(.system(size: 11)).foregroundStyle(Shift.faint)
                                    Text("\(L.t("history.source")): \(entry.sourcesSummary)")
                                        .font(.system(size: 11)).foregroundStyle(Shift.muted).lineLimit(2)
                                    Text("\(L.t("history.destination")): \(entry.destSummary)")
                                        .font(.system(size: 11)).foregroundStyle(Shift.muted).lineLimit(2)
                                    Text("\(L.t("history.ok")): \(entry.okCount)  \(L.t("history.mismatch")): \(entry.mismatchCount)  \(L.t("history.errors")): \(entry.errorCount)")
                                        .font(.system(size: 11))
                                        .foregroundStyle(entry.errorCount > 0 ? Shift.error : Shift.muted)
                                    if !entry.sourcePaths.isEmpty || !entry.destinationTargetPaths.isEmpty {
                                        VStack(alignment: .leading, spacing: 3) {
                                            ForEach(Array(entry.sourcePaths.enumerated()), id: \.offset) { _, path in
                                                Button("\(L.t("history.openSource")): \((path as NSString).lastPathComponent)") {
                                                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
                                                }
                                                .buttonStyle(.link).font(.system(size: 11))
                                            }
                                            ForEach(Array(entry.destinationTargetPaths.enumerated()), id: \.offset) { _, path in
                                                Button("\(L.t("history.openDestination")): \((path as NSString).lastPathComponent)") {
                                                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
                                                }
                                                .buttonStyle(.link).font(.system(size: 11))
                                            }
                                        }
                                        .padding(.top, 2)
                                    }
                                }
                                Spacer()
                                Button { store.delete(entry) } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(Shift.muted)
                            }
                            .padding(10)
                            .background(Shift.elevated)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            }

            HStack {
                Spacer()
                Button(L.t("history.close")) { isPresented = false }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(20)
        // Fix real (2026-09-06, cerut de Cristi): dimensiune FIXA
        // impiedica redimensionarea.
        .frame(minWidth: 480, idealWidth: 640, minHeight: 420, idealHeight: 560)
        .background(Shift.bg)
    }
}
