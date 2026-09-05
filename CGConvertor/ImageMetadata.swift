// ImageMetadata.swift
// EXIF/GPS pentru imagini + tag-uri ID3v2 pentru MP3 — completeaza
// SonyMetadata.swift in efortul de portare nativa a
// GDC_Metadata_View_Premium (index.html, functiile extractExifMetadata si
// extractId3Metadata). Pe Mac, EXIF vine gratuit din ImageIO (nicio
// dependinta noua, mai complet decat orice biblioteca terta) — echivalentul
// Windows (Python, `exifread`) e in `sony_metadata.py`/`image_metadata.py`.

import Foundation
import ImageIO
import CoreGraphics

enum ImageMetadataReader {

    private static let exifLabels: [CFString: String] = [
        kCGImagePropertyExifLensModel: "Obiectiv",
        kCGImagePropertyExifDateTimeOriginal: "Data capturare",
        kCGImagePropertyExifExposureTime: "Timp expunere",
        kCGImagePropertyExifFNumber: "Diafragmă",
        kCGImagePropertyExifISOSpeedRatings: "ISO",
        kCGImagePropertyExifFocalLength: "Distanță focală",
        kCGImagePropertyExifExposureProgram: "Program expunere",
        kCGImagePropertyExifWhiteBalance: "Balans de alb",
        kCGImagePropertyExifFlash: "Bliț",
    ]

    /// Citește EXIF/GPS/TIFF dintr-o imagine — gol daca `url` nu e o
    /// imagine sau nu are metadate (esec silentios, ca in JS/exifr).
    static func read(from url: URL) -> [String: String] {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        else { return [:] }

        var cat: [String: String] = [:]

        if let tiff = props[kCGImagePropertyTIFFDictionary] as? [CFString: Any] {
            if let make = tiff[kCGImagePropertyTIFFMake] as? String { cat["Producător cameră"] = make }
            if let model = tiff[kCGImagePropertyTIFFModel] as? String { cat["Model cameră"] = model }
            if let software = tiff[kCGImagePropertyTIFFSoftware] as? String { cat["Software"] = software }
        }

        if let exif = props[kCGImagePropertyExifDictionary] as? [CFString: Any] {
            for (key, label) in exifLabels {
                if let value = exif[key] {
                    cat[label] = Self.stringify(value)
                }
            }
            // ISO vine ca array (poate avea mai multe valori la bracketing) — pastram prima.
            if let isoArray = exif[kCGImagePropertyExifISOSpeedRatings] as? [Any], let first = isoArray.first {
                cat["ISO"] = Self.stringify(first)
            }
        }

        if let gps = props[kCGImagePropertyGPSDictionary] as? [CFString: Any],
           let lat = gps[kCGImagePropertyGPSLatitude] as? Double,
           let lon = gps[kCGImagePropertyGPSLongitude] as? Double {
            let latRef = (gps[kCGImagePropertyGPSLatitudeRef] as? String) ?? "N"
            let lonRef = (gps[kCGImagePropertyGPSLongitudeRef] as? String) ?? "E"
            let signedLat = latRef == "S" ? -lat : lat
            let signedLon = lonRef == "W" ? -lon : lon
            cat["Coordonate GPS"] = String(format: "%.5f, %.5f", signedLat, signedLon)
        }

        return cat
    }

    private static func stringify(_ value: Any) -> String {
        if let d = value as? Double { return String(format: "%g", d) }
        if let n = value as? NSNumber { return n.stringValue }
        return "\(value)"
    }
}

enum ID3Reader {
    private static let frameMap = ["TIT2": "Titlu", "TPE1": "Artist", "TALB": "Album",
                                    "TYER": "An", "TDRC": "Data", "TCON": "Gen"]

    /// Tag-uri ID3v2 (doar frame-urile text uzuale) — citește primii 512KB,
    /// suficient pentru header-ul ID3 de la începutul fișierului.
    static func read(from url: URL) -> [String: String] {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return [:] }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: 512 * 1024), data.count >= 10 else { return [:] }
        let bytes = [UInt8](data)

        guard bytes[0] == 0x49, bytes[1] == 0x44, bytes[2] == 0x33 else { return [:] } // "ID3"
        let version = bytes[3]
        let size = synchsafe(bytes[6], bytes[7], bytes[8], bytes[9])

        var cat: [String: String] = [:]
        var offset = 10
        let end = min(10 + Int(size), bytes.count)

        while offset + 10 <= end {
            guard let id = String(bytes: bytes[offset..<offset + 4], encoding: .ascii),
                  id.allSatisfy({ $0.isLetter || $0.isNumber }), id == id.uppercased() else { break }
            let frameSize: Int
            if version >= 4 {
                frameSize = Int(synchsafe(bytes[offset + 4], bytes[offset + 5], bytes[offset + 6], bytes[offset + 7]))
            } else {
                frameSize = Int(bytes[offset + 4]) << 24 | Int(bytes[offset + 5]) << 16 |
                            Int(bytes[offset + 6]) << 8 | Int(bytes[offset + 7])
            }
            guard frameSize > 0, offset + 10 + frameSize <= bytes.count else { break }

            if let label = frameMap[id] {
                let encoding = bytes[offset + 10]
                let textBytes = Data(bytes[(offset + 11)..<(offset + 10 + frameSize)])
                let text = (encoding == 1 || encoding == 2)
                    ? (String(data: textBytes, encoding: .utf16) ?? "")
                    : (String(data: textBytes, encoding: .utf8) ?? "")
                cat[label] = text.trimmingCharacters(in: CharacterSet(charactersIn: "\0")).trimmingCharacters(in: .whitespaces)
            }
            offset += 10 + frameSize
        }
        return cat
    }

    private static func synchsafe(_ b0: UInt8, _ b1: UInt8, _ b2: UInt8, _ b3: UInt8) -> UInt32 {
        (UInt32(b0) << 21) | (UInt32(b1) << 14) | (UInt32(b2) << 7) | UInt32(b3)
    }
}
