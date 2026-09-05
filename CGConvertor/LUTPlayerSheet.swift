import SwiftUI
import AVKit
import UniformTypeIdentifiers

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
                    VideoPlayer(player: player)
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
