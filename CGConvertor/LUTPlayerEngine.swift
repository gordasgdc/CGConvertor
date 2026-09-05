import Foundation
import Combine
import CoreImage
import AVFoundation

/// Parser pentru fisiere `.cube` (Adobe/Resolve, format text standard) —
/// NU exista inca niciun parser Swift in acest repo (LUT-ul era pana acum
/// doar o cale de fisier pasata direct catre `ffmpeg -vf lut3d=file=...`,
/// vezi `MediaInspector.genereazaThumbnail`). Playerul real-time (mai jos)
/// are nevoie de datele LUT-ului efectiv incarcate in memorie, ca sa le
/// dea unui `CIFilter` — de-asta apare acest parser abia acum.
struct CubeLUT {
    let dimension: Int
    /// RGBA, Float32, ordine row-major cu rosu variind cel mai repede —
    /// exact ordinea in care fisierul `.cube` insusi lista tripletele
    /// (spec Adobe), si exact formatul cerut de `CIColorCube`
    /// (`inputCubeData`) — nicio reordonare necesara.
    let rgbaData: [Float]

    /// Doar LUT-uri 3D (`LUT_3D_SIZE`) — un `.cube` 1D (`LUT_1D_SIZE`,
    /// rar in productie video) e respins explicit, esec silentios (`nil`),
    /// la fel ca restul cititoarelor de metadate din acest repo.
    static func load(from url: URL) -> CubeLUT? {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }

        var size: Int?
        var triples: [Float] = []
        triples.reserveCapacity(64 * 64 * 64 * 3)

        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }
            if line.hasPrefix("LUT_1D_SIZE") { return nil }
            if line.hasPrefix("LUT_3D_SIZE") {
                let parts = line.split(separator: " ")
                if parts.count >= 2 { size = Int(parts[1]) }
                continue
            }
            if line.hasPrefix("TITLE") || line.hasPrefix("DOMAIN_MIN") || line.hasPrefix("DOMAIN_MAX") { continue }

            let comps = line.split(separator: " ").compactMap { Float($0) }
            guard comps.count == 3 else { continue }
            triples.append(contentsOf: comps)
        }

        guard let dimension = size, dimension > 0, triples.count == dimension * dimension * dimension * 3 else {
            return nil
        }

        var rgba: [Float] = []
        rgba.reserveCapacity(triples.count / 3 * 4)
        var i = 0
        while i < triples.count {
            rgba.append(triples[i]); rgba.append(triples[i + 1]); rgba.append(triples[i + 2]); rgba.append(1.0)
            i += 3
        }
        return CubeLUT(dimension: dimension, rgbaData: rgba)
    }
}

/// Coordonatorul redarii cu LUT live — creat o data per fereastra de
/// player, referit (nu copiat) din closure-ul `AVMutableVideoComposition`
/// pasat catre AVFoundation, ca schimbarea LUT-ului in timpul redarii sa
/// se reflecte instant pe cadrul urmator, fara sa reconstruim compozitia.
final class LUTPlayerCoordinator: ObservableObject {
    @Published private(set) var lutFileName: String?

    private let ciContext = CIContext()
    private var filter: CIFilter?

    func setLUT(url: URL?) {
        guard let url else {
            filter = nil
            lutFileName = nil
            return
        }
        guard let lut = CubeLUT.load(from: url) else { return }
        let f = CIFilter(name: "CIColorCube")
        f?.setValue(lut.dimension, forKey: "inputCubeDimension")
        f?.setValue(Data(bytes: lut.rgbaData, count: lut.rgbaData.count * MemoryLayout<Float>.size), forKey: "inputCubeData")
        filter = f
        lutFileName = url.lastPathComponent
    }

    /// Apelat de AVFoundation pentru FIECARE cadru, in timpul redarii —
    /// trebuie sa fie rapid; `CIColorCube` e accelerat GPU prin CIContext,
    /// deci costul per cadru ramane mic chiar la 4K/60fps pe hardware Apple
    /// Silicon (Metal, implicit pentru CIContext fara parametri).
    func renderFrame(_ request: AVAsynchronousCIImageFilteringRequest) {
        guard let filter else {
            request.finish(with: request.sourceImage, context: ciContext)
            return
        }
        filter.setValue(request.sourceImage, forKey: kCIInputImageKey)
        let output = filter.outputImage ?? request.sourceImage
        request.finish(with: output, context: ciContext)
    }
}
