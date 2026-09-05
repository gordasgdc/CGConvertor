import SwiftUI
import AVKit
import AppKit
import UniformTypeIdentifiers

/// Wrapper AppKit direct peste `AVPlayerView` — NU `VideoPlayer` (AVKit/
/// SwiftUI). BUG REAL GĂSIT, confirmat din 3 rapoarte de crash identice
/// (`~/Library/Logs/DiagnosticReports/CGConvertor-*.ips`, 2026-09-05):
/// `VideoPlayer` crapă STRICT reproductibil (SIGABRT, `swift::fatalError`
/// în timpul rezolvării de metadata generică pentru
/// `NSViewRepresentable._makeView`, chiar la prima afișare) pe această
/// versiune de macOS (26.6.2) — un bug de runtime Swift/AVKit, NU o
/// eroare în codul din acest fișier. `AVPlayerView` e exact view-ul
/// AppKit pe care `VideoPlayer` îl încapsulează intern — îl folosim
/// direct, ocolind complet stratul SwiftUI care crapă. Păstrează
/// controalele native (`controlsStyle = .floating`).
private struct AVPlayerAppKitView: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.player = player
        view.controlsStyle = .floating
        view.showsFullScreenToggleButton = true
        return view
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        if nsView.player !== player {
            nsView.player = player
        }
    }
}

/// Playerul real-time LUT/LOG — versiunea COMPLETĂ (redare video reală,
/// audio inclus, play/pause/scrub, LUT `.cube` aplicat LIVE prin Core
/// Image), cerută explicit de Cristi (2026-09-05) ca fereastră SEPARATĂ,
/// nouă, pe lângă preview-ul static existent (`MediaPreviewSheet` —
/// scrubbing static, un cadru regenerat cu ffmpeg per mișcare) — cele
/// două rămân ambele disponibile, niciuna nu o înlocuiește pe cealaltă.
///
/// Arhitectură: `AVMutableVideoComposition(asset:applyingCIFiltersWithHandler:)`
/// — API-ul standard AVFoundation pentru randare de cadre prin CoreImage
/// în timpul redării reale, NU un pipeline Metal scris de mână (care ar
/// însemna reimplementarea decodării video + sincronizării audio de la
/// zero). `VideoPlayer` (AVKit/SwiftUI) oferă transportul nativ complet
/// (play/pause, bară de scrub, volum, fullscreen) gratuit — construim
/// doar `LUTPlayerCoordinator` (LUTPlayerEngine.swift) care intervine
/// per-cadru, restul e infrastructură Apple deja matură.
///
/// **Doar Mac** — portul Windows (Media Foundation/echivalent) rămâne un
/// TODO separat, discuție de scop viitoare (vezi CLAUDE.md).
struct LUTPlayerSheet: View {
    let job: VideoJob
    @Binding var isPresented: Bool

    @StateObject private var coordonator = LUTPlayerCoordinator()
    @State private var player: AVPlayer?

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(String(format: L.t("player.title"), job.numeFisier))
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Spacer()
                Button {
                    player?.pause()
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(Shift.faint)
            }

            ZStack {
                Rectangle().fill(Shift.elevated)
                if let player {
                    AVPlayerAppKitView(player: player)
                } else {
                    ProgressView().controlSize(.small)
                }
            }
            .frame(width: 720, height: 405)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            HStack {
                Text(coordonator.lutFileName ?? L.t("preview.noLut"))
                    .font(.system(size: 11))
                    .foregroundStyle(Shift.muted)
                    .lineLimit(1)
                Spacer()
                Button(L.t("preview.chooseLut")) { alegeLUT() }
                    .buttonStyle(ShiftGhostButtonStyle())
                if coordonator.lutFileName != nil {
                    Button(L.t("preview.clearLut")) { coordonator.setLUT(url: nil) }
                        .buttonStyle(ShiftGhostButtonStyle())
                }
            }
        }
        .padding(20)
        .frame(width: 760)
        .background(Shift.bg)
        .onAppear { configureazaPlayer() }
        .onDisappear { player?.pause() }
    }

    private func configureazaPlayer() {
        let asset = AVURLAsset(url: job.urlSursa)
        let item = AVPlayerItem(asset: asset)
        item.videoComposition = AVMutableVideoComposition(asset: asset) { request in
            coordonator.renderFrame(request)
        }
        let p = AVPlayer(playerItem: item)
        player = p
        p.play()
    }

    private func alegeLUT() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        if let cubeType = UTType(filenameExtension: "cube") {
            panel.allowedContentTypes = [cubeType]
        }
        if panel.runModal() == .OK, let url = panel.url {
            coordonator.setLUT(url: url)
        }
    }
}
