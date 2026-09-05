// SonyMetadata.swift
// Extractie profunda de metadate specifice camerelor Sony — profil Log/Gamma,
// EI, si o aproximare a ISO/expunere/diafragma/balans de alb la momentul
// capturii, citite direct din containerul ISO-BMFF (MP4/MOV) sau dintr-un XML
// sidecar Sony separat. Portat 1:1 (logica, nu sintaxa) din parserul JS scris
// de mana in GDC_Metadata_View_Premium (~/Developer/GDC_Metadata_View_Premium/
// index.html) — acolo functiona pe File/ArrayBuffer in browser; aici citim
// direct de pe disc cu FileHandle, ceea ce e de fapt mai simplu (nu mai
// trebuie sa navigam sloturi de File.slice()).
//
// Pista "rtmd" (metadate per-cadru Sony) e un format binar KLV nedocumentat
// oficial de Sony, dedus prin efortul comunitatii open-source (vezi proiectul
// telemetry-parser) — citim DOAR primul esantion (primul cadru), suficient
// pentru o aproximare a setarilor de captura, nu o extractie completa
// cadru-cu-cadru (ar fi mult mai scump si nu aduce valoare pentru un
// instrument de inspectie/comparatie, nu de analiza per-cadru).

import Foundation

struct SonyMetadata {
    /// Chei -> valori, gata de afisat (eticheta RO deja aplicata, ca la restul aplicatiei).
    var cameraProfile: [String: String] = [:]
    var captureSettings: [String: String] = [:]

    var isEmpty: Bool { cameraProfile.isEmpty && captureSettings.isEmpty }
}

enum SonyMetadataReader {

    // MARK: - Punct de intrare

    /// `url` poate fi un clip video (se cauta XML embedat + pista rtmd) sau
    /// direct un fisier `.xml` sidecar Sony.
    static func read(from url: URL) -> SonyMetadata {
        var result = SonyMetadata()
        let ext = url.pathExtension.lowercased()

        if ext == "xml" {
            if let text = try? String(contentsOf: url, encoding: .utf8) {
                parseSonyXML(text, into: &result.cameraProfile)
            }
            return result
        }

        guard ["mp4", "mov", "m4v"].contains(ext),
              let handle = try? FileHandle(forReadingFrom: url) else { return result }
        defer { try? handle.close() }

        guard let fileSize = try? handle.seekToEnd() else { return result }
        handle.seek(toFileOffset: 0)

        var xmlText: String?
        var trackHandlers: [String] = []
        var rtmdSampleOffset: UInt64?
        var rtmdSampleSize: UInt32?

        walkIsoBoxes(handle: handle, start: 0, end: fileSize) { box in
            if box.type == "hdlr", let bytes = readBytes(handle, at: box.contentStart + 8, count: 4),
               let handlerType = String(bytes: bytes, encoding: .ascii) {
                trackHandlers.append(handlerType)
            }
            let lastHandler = trackHandlers.last

            if lastHandler == "rtmd", rtmdSampleSize == nil, box.type == "stsz" {
                if let bytes = readBytes(handle, at: box.contentStart + 4, count: 8) {
                    let sampleSize = readUInt32BE(bytes, 0)
                    let sampleCount = readUInt32BE(bytes, 4)
                    if sampleSize != 0 {
                        rtmdSampleSize = sampleSize
                    } else if sampleCount > 0, let sizeBytes = readBytes(handle, at: box.contentStart + 12, count: 4) {
                        rtmdSampleSize = readUInt32BE(sizeBytes, 0)
                    }
                }
            }
            if lastHandler == "rtmd", rtmdSampleOffset == nil, box.type == "stco" || box.type == "co64" {
                if let countBytes = readBytes(handle, at: box.contentStart + 4, count: 4) {
                    let entryCount = readUInt32BE(countBytes, 0)
                    if entryCount > 0 {
                        if box.type == "stco", let offBytes = readBytes(handle, at: box.contentStart + 8, count: 4) {
                            rtmdSampleOffset = UInt64(readUInt32BE(offBytes, 0))
                        } else if let offBytes = readBytes(handle, at: box.contentStart + 8, count: 8) {
                            rtmdSampleOffset = readUInt64BE(offBytes, 0)
                        }
                    }
                }
            }
            if box.type == "meta", xmlText == nil {
                xmlText = tryExtractSonyXMLBox(handle, box)
            }
        }

        if let text = xmlText {
            parseSonyXML(text, into: &result.cameraProfile)
        }
        if let offset = rtmdSampleOffset, let size = rtmdSampleSize, size > 0,
           let sampleBytes = readBytes(handle, at: offset, count: Int(size)) {
            result.captureSettings = parseSonyRtmdSample(sampleBytes)
        }

        return result
    }

    // MARK: - Cutii ISO-BMFF (parser generic de container MP4/MOV)

    private struct IsoBox {
        let type: String
        let size: UInt64
        let start: UInt64
        let contentStart: UInt64
        let end: UInt64
    }

    private static let containerTypes: Set<String> =
        ["moov", "trak", "mdia", "minf", "stbl", "udta", "edts", "dinf", "meta"]

    private static func readBytes(_ handle: FileHandle, at offset: UInt64, count: Int) -> [UInt8]? {
        guard count > 0 else { return nil }
        handle.seek(toFileOffset: offset)
        guard let data = try? handle.read(upToCount: count), data.count == count else { return nil }
        return [UInt8](data)
    }

    private static func readUInt32BE(_ bytes: [UInt8], _ offset: Int) -> UInt32 {
        (UInt32(bytes[offset]) << 24) | (UInt32(bytes[offset + 1]) << 16) |
        (UInt32(bytes[offset + 2]) << 8) | UInt32(bytes[offset + 3])
    }

    private static func readUInt16BE(_ bytes: [UInt8], _ offset: Int) -> UInt16 {
        (UInt16(bytes[offset]) << 8) | UInt16(bytes[offset + 1])
    }

    private static func readUInt64BE(_ bytes: [UInt8], _ offset: Int) -> UInt64 {
        var v: UInt64 = 0
        for i in 0..<8 { v = (v << 8) | UInt64(bytes[offset + i]) }
        return v
    }

    private static func readBoxHeader(_ handle: FileHandle, at offset: UInt64) -> IsoBox? {
        guard let head = readBytes(handle, at: offset, count: 8) else { return nil }
        var size = UInt64(readUInt32BE(head, 0))
        guard let type = String(bytes: head[4..<8], encoding: .ascii) else { return nil }
        var headerSize: UInt64 = 8
        if size == 1 {
            guard let ext = readBytes(handle, at: offset + 8, count: 8) else { return nil }
            size = readUInt64BE(ext, 0)
            headerSize = 16
        } else if size == 0 {
            return nil // "pana la sfarsitul fisierului" — nu se intampla la boxurile pe care le cautam
        }
        guard size >= 8 else { return nil }
        return IsoBox(type: type, size: size, start: offset,
                      contentStart: offset + headerSize, end: offset + size)
    }

    /// Traverseaza recursiv arborele de cutii, apeland `body` pentru fiecare —
    /// identic ca strategie cu `walkIsoBoxes` din JS.
    private static func walkIsoBoxes(handle: FileHandle, start: UInt64, end: UInt64, body: (IsoBox) -> Void) {
        var offset = start
        while offset + 8 <= end {
            guard let box = readBoxHeader(handle, at: offset), box.end <= end, box.end > box.start else { break }
            body(box)
            if containerTypes.contains(box.type) {
                var childStart: UInt64? = box.contentStart
                if box.type == "meta" {
                    // boxul "meta" clasic (non-QuickTime) are 4 octeti de flags
                    // inainte de copii — dar daca gasim XML Sony direct in
                    // continutul lui, tratam boxul ca frunza (nu mai coboram).
                    if tryExtractSonyXMLBox(handle, box) == nil {
                        childStart = box.contentStart + 4
                    } else {
                        childStart = nil
                    }
                }
                if let childStart {
                    walkIsoBoxes(handle: handle, start: childStart, end: box.end, body: body)
                }
            }
            offset = box.end
        }
    }

    private static func tryExtractSonyXMLBox(_ handle: FileHandle, _ box: IsoBox) -> String? {
        let length = Int(box.end - box.contentStart)
        guard length > 0, length < 8 * 1024 * 1024, let bytes = readBytes(handle, at: box.contentStart, count: length) else { return nil }
        guard let text = String(bytes: bytes, encoding: .utf8) else { return nil }
        guard let range = text.range(of: "<?xml") else { return nil }
        var xmlPart = String(text[range.lowerBound...])
        if let nul = xmlPart.firstIndex(of: "\0") { xmlPart = String(xmlPart[..<nul]) }
        return xmlPart.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Decodor rtmd (KLV binar, primul esantion/cadru)

    private static let exposureModeLabels: [UInt32: String] = [
        0x01010000: "Manual", 0x01020000: "Auto complet",
        0x01030000: "Auto cu prioritate câștig", 0x01040000: "Auto cu prioritate diafragmă",
        0x01050000: "Auto cu prioritate timp expunere",
    ]

    private static func parseSonyRtmdSample(_ bytes: [UInt8]) -> [String: String] {
        var pos = 0
        let end = bytes.count
        // primul bloc rtmd contine un header cu marker 0x06 urmat de un
        // "context data set" de lungime variabila (BER) — il sarim, nu ne
        // intereseaza continutul lui, doar KLV-urile Sony de dupa.
        if end >= 17, bytes[0] == 0x06 {
            pos = 16
            let b0 = bytes[pos]
            pos += (b0 & 0x80) != 0 ? Int(1 + (b0 & 0x7f)) : 1
        }
        var out: [String: String] = [:]
        while pos + 4 <= end {
            let tag = readUInt16BE(bytes, pos)
            let len = Int(readUInt16BE(bytes, pos + 2))
            pos += 4
            guard pos + len <= end else { break }
            if let (label, value) = decodeRtmdField(tag: tag, bytes: bytes, offset: pos, length: len),
               out[label] == nil {
                out[label] = value
            }
            pos += len
        }
        return out
    }

    private static func decodeRtmdField(tag: UInt16, bytes: [UInt8], offset: Int, length: Int) -> (String, String)? {
        switch tag {
        case 0x810B where length >= 2:
            return ("ISO (rtmd, primul cadru)", String(readUInt16BE(bytes, offset)))
        case 0x8119 where length >= 4, 0xE301 where length >= 4:
            return ("ISO (rtmd, primul cadru)", String(readUInt32BE(bytes, offset)))
        case 0x8109 where length >= 8:
            let num = readUInt32BE(bytes, offset), den = readUInt32BE(bytes, offset + 4)
            guard num != 0, den != 0 else { return nil }
            return ("Timp expunere (rtmd, primul cadru)", "1/\(Int((Double(den) / Double(num)).rounded())) s")
        case 0x8000 where length >= 2:
            let raw = readUInt16BE(bytes, offset)
            let fstop = pow(2.0, 8.0 * (1.0 - Double(raw) / 65536.0))
            return ("Diafragmă (rtmd, primul cadru)", String(format: "f/%.1f", fstop))
        case 0x810E where length >= 2:
            return ("Balans de alb (rtmd, primul cadru)", "\(readUInt16BE(bytes, offset)) K")
        case 0x8100 where length >= 16:
            let mode = readUInt32BE(bytes, offset + 12)
            guard let label = exposureModeLabels[mode] else { return nil }
            return ("Mod expunere (rtmd, primul cadru)", label)
        case 0x8106 where length >= 8:
            let num = readUInt32BE(bytes, offset), den = readUInt32BE(bytes, offset + 4)
            guard den != 0 else { return nil }
            return ("Cadre/s captură (rtmd, primul cadru)", String(format: "%.2f", Double(num) / Double(den)))
        default:
            return nil
        }
    }

    // MARK: - XML Sony (sidecar sau embedat) — parsare tolerantă cu XMLParser

    private static let itemLabels: [String: String] = [
        "CaptureGammaEquation": "Curbă Gamma (Log)", "CaptureColorPrimaries": "Gamut culoare (Log)",
        "CodingEquations": "Ecuații de codare (matrice)", "CaptureFrameRate": "Cadre/s la captură",
        "CaptureBitDepth": "Adâncime biți captură", "CodingEIFlag": "Flag EI (Exposure Index)",
        "ExposureIndexOfPictureProfile": "Exposure Index (EI)", "WhiteBalance": "Balans de alb",
        "ColorTemperature": "Temperatură culoare", "ElectricalExtenderMagnification": "Extender electronic",
        "ImagerDimension": "Dimensiune senzor", "MasterBlackLevel": "Nivel negru master",
        "MasterGainAdjustment": "Ajustare câștig master", "ImagerScanMode": "Mod scanare senzor",
        "AutoSlowShutter": "Slow shutter automat", "NDFilter": "Filtru ND",
    ]

    private static func parseSonyXML(_ text: String, into cat: inout [String: String]) {
        guard let data = text.data(using: .utf8) else { return }
        let delegate = SonyXMLParserDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        guard parser.parse() else { return }

        if let man = delegate.deviceAttrs["manufacturer"] ?? delegate.deviceAttrs["Manufacturer"] {
            cat["Producător cameră"] = man
        }
        if let model = delegate.deviceAttrs["modelName"] ?? delegate.deviceAttrs["ModelName"] {
            cat["Model cameră"] = model
        }
        if let serial = delegate.deviceAttrs["serialNo"] ?? delegate.deviceAttrs["SerialNo"] {
            cat["Serie cameră"] = serial
        }
        if let creationDate = delegate.creationDate { cat["Data creare clip"] = creationDate }
        if let codec = delegate.videoFrameAttrs["videoCodec"] ?? delegate.videoFrameAttrs["VideoCodec"] {
            cat["Codec video (XML)"] = codec
        }
        if let fps = delegate.videoFrameAttrs["captureFps"] ?? delegate.videoFrameAttrs["CaptureFps"] {
            cat["FPS captură (XML)"] = fps
        }
        if let fps = delegate.videoFrameAttrs["formatFps"] ?? delegate.videoFrameAttrs["FormatFps"] {
            cat["FPS format (XML)"] = fps
        }
        if let aspect = delegate.videoFrameAttrs["aspectRatio"] ?? delegate.videoFrameAttrs["AspectRatio"] {
            cat["Aspect ratio (XML)"] = aspect
        }
        if let w = delegate.videoLayoutAttrs["pixel"] ?? delegate.videoLayoutAttrs["Pixel"],
           let h = delegate.videoLayoutAttrs["numOfVerticalLine"] ?? delegate.videoLayoutAttrs["NumOfVerticalLine"] {
            cat["Rezoluție (XML)"] = "\(w) x \(h)"
        }
        for (name, value) in delegate.items where cat[itemLabels[name] ?? name] == nil {
            cat[itemLabels[name] ?? name] = value
        }
    }

    private final class SonyXMLParserDelegate: NSObject, XMLParserDelegate {
        var deviceAttrs: [String: String] = [:]
        var creationDate: String?
        var videoFrameAttrs: [String: String] = [:]
        var videoLayoutAttrs: [String: String] = [:]
        var items: [(String, String)] = []

        func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                    qualifiedName qName: String?, attributes attributeDict: [String: String]) {
            switch elementName {
            case "Device": deviceAttrs = attributeDict
            case "CreationDate": creationDate = attributeDict["value"] ?? attributeDict["Value"]
            case "VideoFrame": videoFrameAttrs = attributeDict
            case "VideoLayout": videoLayoutAttrs = attributeDict
            case "Item":
                if let name = attributeDict["name"] ?? attributeDict["Name"],
                   let value = attributeDict["value"] ?? attributeDict["Value"] {
                    items.append((name, value))
                }
            default: break
            }
        }
    }
}
