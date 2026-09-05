import Foundation

/// Motorul comparativ de metadate — unifică ffprobe (`MediaInspector`),
/// Sony XML/rtmd (`SonyMetadataReader`), EXIF/GPS și ID3
/// (`ImageMetadataReader`/`ID3Reader`) într-un singur set de categorii
/// ordonate, pe modelul tabelului din `~/Developer/GDC_Metadata_View_Premium`
/// (index.html: `analyzeFile`/`categories`). Rulat la cerere (când userul
/// deschide comparația), NU la fiecare adăugare de fișier în coadă — a
/// citi un container ISO-BMFF întreg + EXIF + ID3 pentru fiecare fișier
/// automat ar fi cost inutil pentru fișierele niciodată comparate.
struct MetadataCategory: Identifiable {
    let id = UUID()
    let name: String
    let rows: [(label: String, value: String)]
}

/// Ordinea preferată a categoriilor — restul (dacă apar categorii
/// neprevăzute) ar veni după, alfabetic (nu e cazul azi, dar păstrăm
/// tiparul din index.html pentru consecvență).
private let ordineaCategoriilor = [
    "Fișier", "General", "Video", "Audio",
    "Imagine (EXIF)", "Audio (tag ID3)",
    "Setări captură (rtmd, primul cadru)", "Profil Cameră / Log (Sony XML)",
]

enum MetadataCompareEngine {
    static func categorii(pentru url: URL) -> [MetadataCategory] {
        var dict: [String: [(String, String)]] = [:]

        func adauga(_ categorie: String, _ label: String, _ valoare: String?) {
            guard let valoare, !valoare.isEmpty else { return }
            dict[categorie, default: []].append((label, valoare))
        }

        let dimensiune = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? nil
        adauga("Fișier", "Nume fișier", url.lastPathComponent)
        adauga("Fișier", "Dimensiune", formatBytes(dimensiune))

        if let meta = MediaInspector.probe(url: url) {
            adauga("General", "Durată", meta.durataSecunde.map { String(format: "%.1fs", $0) })
            adauga("Video", "Codec", meta.codecVideo?.uppercased())
            adauga("Video", "Rezoluție", meta.rezolutieText)
            adauga("Video", "Cadre/s", meta.frameRate)
            adauga("Video", "Bitrate", meta.bitrateVideo.map { formatBytes(Int64($0 / 8)) + "/s" })
            adauga("Video", "Format pixeli", meta.pixFmt)
            adauga("Video", "Spațiu de culoare", meta.colorSpace)
            adauga("Video", "Curbă de transfer", meta.colorTransfer)
            adauga("Video", "Gamut culoare", meta.colorPrimaries)
            adauga("Audio", "Codec", meta.codecAudio?.uppercased())
            adauga("Audio", "Canale", meta.canaleAudio.map(String.init))
            adauga("Audio", "Frecvență eșantionare", meta.sampleRateAudio.map { "\($0) Hz" })
            adauga("Audio", "Bitrate", meta.bitrateAudio.map { formatBytes(Int64($0 / 8)) + "/s" })
        }

        let sony = SonyMetadataReader.read(from: url)
        for (label, value) in sony.cameraProfile { adauga("Profil Cameră / Log (Sony XML)", label, value) }
        for (label, value) in sony.captureSettings { adauga("Setări captură (rtmd, primul cadru)", label, value) }

        for (label, value) in ImageMetadataReader.read(from: url) { adauga("Imagine (EXIF)", label, value) }
        for (label, value) in ID3Reader.read(from: url) { adauga("Audio (tag ID3)", label, value) }

        let numeCunoscute = Set(ordineaCategoriilor)
        let restul = dict.keys.filter { !numeCunoscute.contains($0) }.sorted()
        let ordineFinala = ordineaCategoriilor.filter { dict[$0] != nil } + restul

        return ordineFinala.map { MetadataCategory(name: $0, rows: dict[$0] ?? []) }
    }
}
