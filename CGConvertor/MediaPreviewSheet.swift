import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Preview interactiv — versiunea REDUSĂ, deliberat, a unui player real-time
/// LUT/LOG (vezi nota de scop din CLAUDE.md: acela rămâne un TODO separat,
/// pipeline GPU propriu). Aici: scrubbing pe o bară de progres regenerează
/// un thumbnail STATIC la momentul respectiv, cu un LUT `.cube` opțional
/// aplicat — nu e redare video, dar e util imediat, fără nicio construcție
/// nouă de decodare/randare.
///
/// Fullscreen (2026-09-05, cerere explicită): butonul de mărire extinde
/// panoul de imagine la dimensiunea ecranului curent, ȘI regenerează
/// cadrul la o lățime mult mai mare (`laLatime`) — un thumbnail de 320px
/// întins pe tot ecranul ar fi vizibil pixelat, deci nu e doar o mărire
/// CSS/SwiftUI a aceleiași imagini mici.
struct MediaPreviewSheet: View {
    let job: VideoJob
    @Binding var isPresented: Bool

    @State private var pozitieSecunde: Double = 1
    @State private var lutPath: String?
    @State private var previewImage: NSImage?
    @State private var seIncarca = false
    @State private var extractionTask: Task<Void, Never>?
    @State private var esteFullscreen = false

    private var durata: Double {
        max(job.metadataMedia?.durataSecunde ?? 10, 1)
    }

    /// 320px pentru panoul compact (rapid, suficient la 480x270); 1920px
    /// (Full HD) pentru fullscreen — suficient pentru orice ecran actual,
    /// fără sa generăm inutil la rezoluția nativă a sursei (poate fi 4K/6K,
    /// mult mai lent de extras pentru un simplu preview static).
    private var latimeExtractie: Int { esteFullscreen ? 1920 : 320 }

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Text(job.numeFisier)
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button {
                    esteFullscreen.toggle()
                    programeazaExtractie()
                } label: {
                    Image(systemName: esteFullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                }
                .buttonStyle(.plain)
                .foregroundStyle(Shift.muted)
                .help(L.t(esteFullscreen ? "preview.exitFullscreen" : "preview.fullscreen"))
                Button { isPresented = false } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(Shift.faint)
            }

            GeometryReader { geo in
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
                .frame(width: geo.size.width, height: geo.size.height)
            }
            .frame(
                width: esteFullscreen ? fullscreenSize.width : 480,
                height: esteFullscreen ? fullscreenSize.height : 270
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .animation(.easeInOut(duration: 0.18), value: esteFullscreen)

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
        .frame(width: esteFullscreen ? fullscreenSize.width + 40 : 520)
        .background(Shift.bg)
        .onAppear {
            pozitieSecunde = min(1, durata)
            programeazaExtractie()
        }
    }

    /// Dimensiunea panoului video în modul fullscreen — 90% din ecranul
    /// curent (nu 100%, ca sheet-ul să rămână vizibil ca fereastră, cu
    /// bara de titlu/controalele accesibile în jur), păstrând proporția
    /// 16:9 a zonei de preview.
    private var fullscreenSize: CGSize {
        let ecran = NSScreen.main?.frame.size ?? CGSize(width: 1440, height: 900)
        let latime = ecran.width * 0.9
        return CGSize(width: latime, height: latime * 9 / 16)
    }

    /// Debounce simplu: anulează extracția anterioară dacă userul continuă
    /// să tragă de slider — evită să lansăm zeci de procese ffmpeg pe
    /// secundă în timpul unui drag continuu.
    private func programeazaExtractie() {
        extractionTask?.cancel()
        let secunda = pozitieSecunde
        let lut = lutPath
        let latime = latimeExtractie
        seIncarca = true
        extractionTask = Task.detached(priority: .userInitiated) {
            try? await Task.sleep(nanoseconds: 150_000_000)
            if Task.isCancelled { return }
            let iesire = MediaInspector.folderThumbnailuri().appendingPathComponent("preview_\(job.id.uuidString).jpg")
            let ok = MediaInspector.genereazaThumbnail(url: job.urlSursa, lutPath: lut, iesire: iesire, laSecunda: secunda, laLatime: latime)
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
