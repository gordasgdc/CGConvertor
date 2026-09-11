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
    /// [2026-09-11] Mesaj de eroare când AVFoundation nu poate reda fișierul.
    /// Raportat de Cristi: un ProRes de la RED nu se vedea în player (ecran
    /// gol), deși în previzualizarea foto apărea corect.
    ///
    /// CAUZA, verificată în cod: sunt DOUĂ căi de decodare complet diferite —
    /// previzualizarea foto (`MediaPreviewSheet`) extrage cadrul cu **ffmpeg**,
    /// care decodează practic orice; playerul acesta folosește **AVFoundation**,
    /// care e mult mai restrictiv (anumite variante ProRes/RAW, spații de
    /// culoare sau containere nestandard pur și simplu nu-i sunt suportate).
    /// Codul nu verifica NICIODATĂ dacă încărcarea a reușit, deci eșecul era
    /// complet tăcut: fereastră neagră, zero explicații.
    @State private var eroarePlayer: String?
    @State private var observerStatus: NSKeyValueObservation?

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
                if let eroarePlayer {
                    // Nu lăsăm o fereastră neagră: spunem CE s-a întâmplat și,
                    // mai important, care e calea care funcționează pentru
                    // fișierul ăsta (previzualizarea foto merge prin ffmpeg).
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.orange)
                        Text(eroarePlayer)
                            .multilineTextAlignment(.center)
                            .font(.callout)
                            .foregroundStyle(Shift.text)
                            .frame(maxWidth: 460)
                        Text(L.t("player.error.hint"))
                            .multilineTextAlignment(.center)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: 460)
                    }
                    .padding(24)
                } else if let player {
                    AVPlayerAppKitView(player: player)
                } else {
                    ProgressView().controlSize(.small)
                }
            }
            // Fix real (2026-09-06, cerut de Cristi): dimensiune FIXA
            // impiedica marirea ferestrei playerului - aspectRatio(16:9)
            // pastreaza proportia corecta indiferent cat de mult
            // redimensioneaza userul fereastra.
            .aspectRatio(16.0 / 9.0, contentMode: .fit)
            .frame(minWidth: 480, idealWidth: 900, minHeight: 270, idealHeight: 506)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            HStack {
                // Modificatorii se aplică pe FIECARE ramură: atașați după un
                // `if/else` în SwiftUI nu au un singur `View` pe care să se
                // aplice (de-asta a picat compilarea prima dată).
                if let eroareLUT = coordonator.eroareLUT {
                    Label(eroareLUT, systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.orange)
                        .lineLimit(2)
                } else {
                    Text(coordonator.lutFileName ?? L.t("preview.noLut"))
                        .font(.system(size: 11))
                        .foregroundStyle(Shift.muted)
                        .lineLimit(1)
                }
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
        .frame(minWidth: 560, idealWidth: 940)
        .background(Shift.bg)
        .onAppear {
            // [2026-09-11] Dacă acestui clip i s-a atribuit deja un LUT (din
            // meniul „Aplică LUT pe N clipuri"), playerul pornește DIRECT cu
            // el — fără să mai fie ales manual de fiecare dată.
            if let lut = LUTLibrary.shared.lut(pentru: job.id) {
                coordonator.setLUT(url: lut)
            }
            configureazaPlayer()
        }
        .onDisappear { player?.pause(); observerStatus?.invalidate() }
    }

    /// Codecul real al pistei, în forma pe care o recunoaște userul
    /// („DNxHR", „ProRes", „H.264"), derivată din tag-ul de 4 litere al
    /// formatului — aceeași convenție ca în orice unealtă de montaj.
    private static func numeCodec(_ track: AVAssetTrack?) async -> String {
        guard let track,
              let formate = try? await track.load(.formatDescriptions),
              let primul = formate.first else { return "" }
        let subtype = CMFormatDescriptionGetMediaSubType(primul)
        let tag = withUnsafeBytes(of: subtype.bigEndian) {
            String(bytes: $0, encoding: .ascii) ?? ""
        }.trimmingCharacters(in: .whitespaces)
        switch tag {
        case "AVdh", "AVdn": return "DNxHR / DNxHD (Avid)"
        case "apch", "apcn", "apcs", "apco", "ap4h", "ap4x": return "ProRes"
        case "aprh", "aprn": return "ProRes RAW"
        default: return tag
        }
    }

    private func configureazaPlayer() {
        eroarePlayer = nil
        let asset = AVURLAsset(url: job.urlSursa)

        Task { @MainActor in
            // Verificăm ÎNAINTE de a construi playerul: `isPlayable` fals
            // înseamnă că AVFoundation nu are cum să redea fișierul, oricât
            // am insista — mai bine spunem asta clar decât să pornim un
            // player care rămâne negru.
            let playabil = (try? await asset.load(.isPlayable)) ?? false
            let piste = (try? await asset.loadTracks(withMediaType: .video)) ?? []

            guard playabil, !piste.isEmpty else {
                if piste.isEmpty {
                    eroarePlayer = L.t("player.error.noVideoTrack")
                } else {
                    // Numim codecul CONCRET, nu „un format nesuportat".
                    // Verificat pe cazul real raportat de Cristi: fișierul lui
                    // nu era ProRes (cum părea după nume), ci DNxHR 444 12-bit
                    // — `isDecodable` fals, `AVdh`. Fără numele codecului,
                    // userul n-are cum să-și dea seama ce are de făcut.
                    let codec = await Self.numeCodec(piste.first)
                    eroarePlayer = codec.isEmpty
                        ? L.t("player.error.notPlayable")
                        : String(format: L.t("player.error.codec"), codec)
                }
                return
            }

            let item = AVPlayerItem(asset: asset)
            item.videoComposition = AVMutableVideoComposition(asset: asset) { request in
                coordonator.renderFrame(request)
            }

            // Decodarea poate eșua și DUPĂ ce fișierul pare valid (codec
            // nesuportat descoperit abia la primul cadru real). Observăm
            // statusul ca să nu rămână iar o fereastră neagră fără explicație.
            observerStatus = item.observe(\.status, options: [.new]) { observedItem, _ in
                Task { @MainActor in
                    if observedItem.status == .failed {
                        let detaliu = observedItem.error?.localizedDescription ?? ""
                        eroarePlayer = detaliu.isEmpty
                            ? L.t("player.error.notPlayable")
                            : L.t("player.error.notPlayable") + "\n\n" + detaliu
                    }
                }
            }

            let p = AVPlayer(playerItem: item)
            player = p
            p.play()
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
            coordonator.setLUT(url: url)
        }
    }
}
