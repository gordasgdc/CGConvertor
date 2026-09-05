import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Preview interactiv — versiunea REDUSĂ, deliberat, a unui player real-time
/// LUT/LOG (vezi nota de scop din CLAUDE.md: acela rămâne un TODO separat,
/// pipeline GPU propriu). Aici: scrubbing pe o bară de progres regenerează
/// un thumbnail STATIC la momentul respectiv, cu un LUT `.cube` opțional
/// aplicat — nu e redare video, dar e util imediat, fără nicio construcție
/// nouă de decodare/randare.
struct MediaPreviewSheet: View {
    let job: VideoJob
    @Binding var isPresented: Bool

    @State private var pozitieSecunde: Double = 1
    @State private var lutPath: String?
    @State private var previewImage: NSImage?
    @State private var seIncarca = false
    @State private var extractionTask: Task<Void, Never>?

    private var durata: Double {
        max(job.metadataMedia?.durataSecunde ?? 10, 1)
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Text(job.numeFisier)
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button { isPresented = false } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(Shift.faint)
            }

            ZStack {
                Rectangle().fill(Shift.elevated)
                if let previewImage {
                    Image(nsImage: previewImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                }
                if seIncarca {
                    ProgressView().controlSize(.small)
                }
            }
            .frame(width: 480, height: 270)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 6) {
                Slider(value: $pozitieSecunde, in: 0...durata, onEditingChanged: { editing in
                    if !editing { programeazaExtractie() }
                })
                .tint(Shift.accent)
                Text(String(format: "%.1fs / %.1fs", pozitieSecunde, durata))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Shift.faint)
            }

            HStack {
                Text(lutPath.map { ($0 as NSString).lastPathComponent } ?? L.t("preview.noLut"))
                    .font(.system(size: 11))
                    .foregroundStyle(Shift.muted)
                    .lineLimit(1)
                Spacer()
                Button(L.t("preview.chooseLut")) { alegeLUT() }
                    .buttonStyle(ShiftGhostButtonStyle())
                if lutPath != nil {
                    Button(L.t("preview.clearLut")) {
                        lutPath = nil
                        programeazaExtractie()
                    }
                    .buttonStyle(ShiftGhostButtonStyle())
                }
            }
        }
        .padding(20)
        .frame(width: 520)
        .background(Shift.bg)
        .onAppear {
            pozitieSecunde = min(1, durata)
            programeazaExtractie()
        }
    }

    /// Debounce simplu: anulează extracția anterioară dacă userul continuă
    /// să tragă de slider — evită să lansăm zeci de procese ffmpeg pe
    /// secundă în timpul unui drag continuu.
    private func programeazaExtractie() {
        extractionTask?.cancel()
        let secunda = pozitieSecunde
        let lut = lutPath
        seIncarca = true
        extractionTask = Task.detached(priority: .userInitiated) {
            try? await Task.sleep(nanoseconds: 150_000_000)
            if Task.isCancelled { return }
            let iesire = MediaInspector.folderThumbnailuri().appendingPathComponent("preview_\(job.id.uuidString).jpg")
            let ok = MediaInspector.genereazaThumbnail(url: job.urlSursa, lutPath: lut, iesire: iesire, laSecunda: secunda)
            if Task.isCancelled { return }
            await MainActor.run {
                if ok, let img = NSImage(contentsOfFile: iesire.path) {
                    previewImage = img
                }
                seIncarca = false
            }
        }
    }

    private func alegeLUT() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        if let cubeType = UTType(filenameExtension: "cube") {
            panel.allowedContentTypes = [cubeType]
        }
        if panel.runModal() == .OK, let url = panel.url {
            lutPath = url.path
            programeazaExtractie()
        }
    }
}
