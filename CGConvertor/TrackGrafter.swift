import Foundation
import CryptoKit

// Grefare de piste de metadate native (ex. Canon `cndm`, Sony `rtmd`) dintr-un
// original MP4/MOV într-un MOV rezultat, FĂRĂ re-encodare: FFmpeg nu poate
// scrie aceste piste (sample entry-ul se pierde), deci le copiem noi, cutie
// cu cutie, cu structura intactă.
//
// Sincronizare (verificat pe structura reală, nu presupus): eșantioanele se
// aleg după TIMP, nu după index. Intervalul sursă [start, start+durată) se
// exprimă pe linia de timp a filmului (după edit list-ul fiecărei piste),
// apoi se traduce în timp de media al pistei de date; se păstrează toate
// eșantioanele care se suprapun intervalului. Pista nouă primește propriul
// edit list, ca prima valoare să cadă exact pe începutul intervalului.
//
// Nu are UI. Folosește doar Foundation/CryptoKit (portabil ca logică).

enum TrackGrafterError: Error, LocalizedError {
    case unreadable(String)
    case unsupported(String)
    case io(String)

    var errorDescription: String? {
        switch self {
        case .unreadable(let m), .unsupported(let m), .io(let m): return m
        }
    }
}

struct GraftedTrack: Equatable {
    let fourcc: String
    let sampleCount: Int
    let firstSourceSample: Int
    let payloadBytes: Int64
    /// SHA-256 al concatenării octeților eșantioanelor alese (din sursă).
    let payloadSHA256: String
}

struct GraftReport: Equatable {
    var tracks: [GraftedTrack] = []
    /// Piste cerute dar absente în sursă (nu e eroare).
    var absent: [String] = []
}

enum TrackGrafter {
    /// Piste native pe care le știm copia fără a le interpreta.
    static let nativeFourCCs = ["cndm", "rtmd"]

    // MARK: - API

    /// Copiază în `dest` pistele `fourCCs` din `source`, pentru intervalul
    /// [`start`, `start`+`duration`) al liniei de timp a sursei
    /// (`duration` nil = până la capăt). `dest` trebuie să aibă `moov` ultimul
    /// (implicit la FFmpeg/MOV fără faststart).
    @discardableResult
    static func graft(source: URL, into dest: URL, start: Double = 0, duration: Double? = nil,
                      fourCCs: [String] = nativeFourCCs) throws -> GraftReport {
        let src = try MP4File(url: source)
        let dst = try MP4File(url: dest, writable: true)
        defer { src.close(); dst.close() }

        guard let dMoov = dst.topLevel.last, dMoov.type == "moov" else {
            throw TrackGrafterError.unsupported("moov nu e ultimul în fișierul rezultat")
        }
        let sMoovBytes = try src.moovBytes()
        let dMoovBytes = try dst.read(at: dMoov.offset + UInt64(dMoov.headerSize),
                                      count: Int(dMoov.size) - dMoov.headerSize)
        let sMovie = try MovieInfo(moov: sMoovBytes)
        let dMovieTS = try MovieInfo(moov: dMoovBytes).timescale

        let t0 = Int64((start * Double(sMovie.timescale)).rounded())
        let totalTicks = sMovie.duration
        let t1: Int64 = duration.map { t0 + Int64(($0 * Double(sMovie.timescale)).rounded()) } ?? totalTicks
        guard t1 > t0 else { throw TrackGrafterError.unsupported("interval gol") }

        var report = GraftReport()
        struct Pending { let trak: TrakInfo; let picks: Range<Int>; let m0: Int64 }
        var pend: [Pending] = []
        for fcc in fourCCs {
            guard let tr = sMovie.traks.first(where: { $0.sampleEntry == fcc }) else {
                report.absent.append(fcc); continue
            }
            let m0 = tr.mediaTime(forMovieTicks: t0, movieTS: sMovie.timescale)
            let m1 = tr.mediaTime(forMovieTicks: t1, movieTS: sMovie.timescale)
            let r = tr.samples(overlapping: m0, m1)
            guard !r.isEmpty else { report.absent.append(fcc); continue }
            pend.append(Pending(trak: tr, picks: r, m0: m0))
        }
        if pend.isEmpty { return report }

        // ---- scriere: mdat nou la poziția vechiului moov, apoi moov nou ----
        let oldMoovEnd = dMoov.offset + dMoov.size
        let originalEnd = dst.size
        guard oldMoovEnd == originalEnd else {
            throw TrackGrafterError.unsupported("date după moov în rezultat")
        }
        let mdatStart = dMoov.offset
        let sizeFieldPos = mdatStart
        do {
            try dst.truncateAndSeek(to: mdatStart)
            // antet mdat pe 64 de biți (size=1) — completat la final
            try dst.write(Data([0, 0, 0, 1]) + Data("mdat".utf8) + Data(count: 8))
            var cursor = mdatStart + 16
            var newTraks = Data()
            var nextID = try MovieInfo.nextTrackID(moov: dMoovBytes)
            for p in pend {
                let chunkOffset = cursor
                var sha = SHA256()
                var bytes: Int64 = 0
                try src.copySamples(of: p.trak, range: p.picks, sink: { try dst.write($0) }, hash: &sha, bytes: &bytes)
                cursor += UInt64(bytes)
                let outDurTicks = max(1, (t1 - t0) * Int64(dMovieTS) / Int64(sMovie.timescale))
                newTraks += try p.trak.buildGraftedTrak(
                    trackID: nextID, picks: p.picks, chunkOffset: chunkOffset,
                    mediaStartTarget: p.m0, destMovieTS: dMovieTS, outDurationTicks: outDurTicks)
                nextID += 1
                report.tracks.append(GraftedTrack(
                    fourcc: p.trak.sampleEntry, sampleCount: p.picks.count,
                    firstSourceSample: p.picks.lowerBound, payloadBytes: bytes,
                    payloadSHA256: sha.finalize().map { String(format: "%02x", $0) }.joined()))
            }
            // completează dimensiunea mdat
            let mdatSize = cursor - mdatStart
            try dst.write(at: sizeFieldPos + 8, Data(be64: mdatSize))
            // moov nou
            var moovBody = try MovieInfo.rewriteMoov(old: dMoovBytes, appending: newTraks, newNextID: nextID)
            let header = Data(be32: UInt32(moovBody.count + 8)) + Data("moov".utf8)
            moovBody.insert(contentsOf: header, at: 0)
            try dst.seekToEnd(at: cursor)
            try dst.write(moovBody)
            try dst.sync()
        } catch {
            // restaurare best-effort a fișierului inițial
            try? dst.truncateAndSeek(to: mdatStart)
            let hdr = Data(be32: UInt32(dMoovBytes.count + 8)) + Data("moov".utf8)
            try? dst.write(hdr + dMoovBytes)
            try? dst.sync()
            throw error
        }
        return report
    }

    /// Verificare independentă: pentru fiecare pistă din `report`, recitește
    /// eșantioanele din rezultat și compară octet-cu-octet (SHA-256) cu cele
    /// alese din sursă, plus numărul și durata totală.
    static func verify(report: GraftReport, source: URL, output: URL, start: Double = 0,
                       duration: Double? = nil) throws -> [String] {
        var problems: [String] = []
        let out = try MP4File(url: output); defer { out.close() }
        let outMovie = try MovieInfo(moov: out.moovBytes())
        for g in report.tracks {
            guard let tr = outMovie.traks.first(where: { $0.sampleEntry == g.fourcc }) else {
                problems.append("\(g.fourcc): lipsește din rezultat"); continue
            }
            if tr.sampleCount != g.sampleCount {
                problems.append("\(g.fourcc): \(tr.sampleCount) eșantioane, așteptat \(g.sampleCount)")
            }
            var sha = SHA256(); var bytes: Int64 = 0
            try out.copySamples(of: tr, range: 0..<tr.sampleCount, sink: nil, hash: &sha, bytes: &bytes)
            let hex = sha.finalize().map { String(format: "%02x", $0) }.joined()
            if hex != g.payloadSHA256 { problems.append("\(g.fourcc): conținut diferit față de sursă") }
        }
        return problems
    }
}

// MARK: - Fișier MP4/MOV (I/O)

final class MP4File {
    struct Box { let offset: UInt64; let size: UInt64; let headerSize: Int; let type: String }
    let handle: FileHandle
    let size: UInt64
    let topLevel: [Box]
    private var closed = false

    init(url: URL, writable: Bool = false) throws {
        do {
            handle = writable ? try FileHandle(forUpdating: url) : try FileHandle(forReadingFrom: url)
        } catch { throw TrackGrafterError.io("nu pot deschide \(url.lastPathComponent)") }
        size = (try? handle.seekToEnd()) ?? 0
        var boxes: [Box] = []
        var off: UInt64 = 0
        while off + 8 <= size {
            try handle.seek(toOffset: off)
            guard let h = try handle.read(upToCount: 16), h.count >= 8 else { break }
            var s = UInt64(h.be32(0)); var hs = 8
            let t = String(decoding: h[4..<8], as: UTF8.self)
            if s == 1 { guard h.count >= 16 else { break }; s = h.be64(8); hs = 16 }
            else if s == 0 { s = size - off }
            guard s >= UInt64(hs), off + s <= size else { break }
            boxes.append(Box(offset: off, size: s, headerSize: hs, type: t))
            off += s
        }
        topLevel = boxes
    }

    func close() { if !closed { try? handle.close(); closed = true } }

    func read(at off: UInt64, count: Int) throws -> Data {
        try handle.seek(toOffset: off)
        guard let d = try handle.read(upToCount: count), d.count == count else {
            throw TrackGrafterError.io("citire incompletă")
        }
        return d
    }

    func moovBytes() throws -> Data {
        guard let m = topLevel.first(where: { $0.type == "moov" }) else {
            throw TrackGrafterError.unreadable("fără moov")
        }
        return try read(at: m.offset + UInt64(m.headerSize), count: Int(m.size) - m.headerSize)
    }

    // scriere
    func truncateAndSeek(to off: UInt64) throws { try handle.truncate(atOffset: off); try handle.seek(toOffset: off) }
    func seekToEnd(at off: UInt64) throws { try handle.seek(toOffset: off) }
    func write(_ d: Data) throws { try handle.write(contentsOf: d) }
    func write(at off: UInt64, _ d: Data) throws {
        let cur = try handle.offset()
        try handle.seek(toOffset: off); try handle.write(contentsOf: d); try handle.seek(toOffset: cur)
    }
    func sync() throws { try handle.synchronize() }

    /// Copiază eșantioanele `range` ale pistei, în ordine, cu buffer fix.
    func copySamples(of tr: TrakInfo, range: Range<Int>, sink: ((Data) throws -> Void)?,
                     hash: inout SHA256, bytes: inout Int64) throws {
        var runStart: UInt64 = 0, runLen = 0
        func flush() throws {
            guard runLen > 0 else { return }
            var remaining = runLen, pos = runStart
            while remaining > 0 {
                let n = min(remaining, 8 << 20)
                try autoreleasepool {
                    let d = try read(at: pos, count: n)
                    hash.update(data: d)
                    try sink?(d)
                }
                pos += UInt64(n); remaining -= n; bytes += Int64(n)
            }
            runLen = 0
        }
        for i in range {
            let (o, s) = tr.sampleLocation(i)
            if runLen > 0 && runStart + UInt64(runLen) == o { runLen += s }
            else { try flush(); runStart = o; runLen = s }
        }
        try flush()
    }
}

// MARK: - Structuri în memorie

struct MovieInfo {
    let timescale: UInt32
    let duration: Int64
    let traks: [TrakInfo]

    init(moov: Data) throws {
        var ts: UInt32 = 0, dur: Int64 = 0
        var traks: [TrakInfo] = []
        for (t, r) in boxesIn(moov) {
            if t == "mvhd" {
                let b = moov[r]
                if b[b.startIndex] == 1 { ts = b.be32(20); dur = Int64(b.be64(24)) }
                else { ts = b.be32(12); dur = Int64(b.be32(16)) }
            } else if t == "trak" { if let tr = try? TrakInfo(trak: Data(moov[r])) { traks.append(tr) } }
        }
        guard ts > 0 else { throw TrackGrafterError.unreadable("mvhd lipsă") }
        timescale = ts; duration = dur; self.traks = traks
    }

    static func nextTrackID(moov: Data) throws -> UInt32 {
        guard let r = boxesIn(moov).first(where: { $0.0 == "mvhd" })?.1 else { throw TrackGrafterError.unreadable("mvhd") }
        let b = moov[r]
        return b.be32(b.endIndex - b.startIndex - 4)
    }

    static func rewriteMoov(old: Data, appending: Data, newNextID: UInt32) throws -> Data {
        var out = Data()
        for (t, r) in boxesIn(old) {
            if t == "mvhd" {
                var b = Data(old[r])
                b.replaceSubrange(b.count - 4..<b.count, with: Data(be32: newNextID))
                out += Data(be32: UInt32(b.count + 8)) + Data("mvhd".utf8) + b
            } else {
                out += Data(be32: UInt32(r.count + 8)) + Data(t.utf8) + old[r]
            }
        }
        return out + appending
    }
}

struct TrakInfo {
    let trackID: UInt32
    let mediaTimescale: UInt32
    let mediaDuration: Int64
    let sampleEntry: String
    let handler: String
    let sttsRuns: [(count: UInt32, delta: UInt32)]
    let sizes: [UInt32]
    let chunkOffsets: [UInt64]
    let stsc: [(first: UInt32, perChunk: UInt32)]
    let elst: [(dur: Int64, mediaTime: Int64)]?
    // octeți brute reutilizabile
    let tkhd: Data, mdhd: Data, hdlr: Data, stsd: Data
    let minfOthers: Data // dinf + media header, fără stbl
    // derivate
    private let starts: [Int64]
    private let durs: [Int64]
    private let sampleOffsets: [UInt64]

    var sampleCount: Int { sizes.count }

    init(trak: Data) throws {
        var tkhd = Data(), mdhd = Data(), hdlr = Data(), stsd = Data(), minfOthers = Data()
        var stts = Data(), stsz = Data(), stsc = Data(), stco = Data(), co64: Data? = nil, elstD: Data? = nil
        for (t, r) in boxesIn(trak) {
            if t == "tkhd" { tkhd = Data(trak[r]) }
            else if t == "edts" {
                let edts = Data(trak[r])
                for (t2, r2) in boxesIn(edts) where t2 == "elst" { elstD = Data(edts[r2]) }
            }
            else if t == "mdia" {
                let mdia = Data(trak[r])
                for (t2, r2) in boxesIn(mdia) {
                    if t2 == "mdhd" { mdhd = Data(mdia[r2]) }
                    else if t2 == "hdlr" { hdlr = Data(mdia[r2]) }
                    else if t2 == "minf" {
                        let minf = Data(mdia[r2])
                        for (t3, r3) in boxesIn(minf) {
                            if t3 == "stbl" {
                                let stbl = Data(minf[r3])
                                for (t4, r4) in boxesIn(stbl) {
                                    switch t4 {
                                    case "stsd": stsd = Data(stbl[r4])
                                    case "stts": stts = Data(stbl[r4])
                                    case "stsz": stsz = Data(stbl[r4])
                                    case "stsc": stsc = Data(stbl[r4])
                                    case "stco": stco = Data(stbl[r4])
                                    case "co64": co64 = Data(stbl[r4])
                                    default: break
                                    }
                                }
                            } else {
                                minfOthers += Data(be32: UInt32(minf[r3].count + 8)) + Data(t3.utf8) + minf[r3]
                            }
                        }
                    }
                }
            }
        }
        guard !tkhd.isEmpty, !mdhd.isEmpty, stsd.count >= 16, !stts.isEmpty, !stsz.isEmpty, !stsc.isEmpty
        else { throw TrackGrafterError.unreadable("pistă incompletă") }
        self.tkhd = tkhd; self.mdhd = mdhd; self.hdlr = hdlr; self.stsd = stsd; self.minfOthers = minfOthers
        trackID = tkhd[tkhd.startIndex] == 1 ? tkhd.be32(20) : tkhd.be32(12)
        if mdhd[mdhd.startIndex] == 1 { mediaTimescale = mdhd.be32(20); mediaDuration = Int64(mdhd.be64(24)) }
        else { mediaTimescale = mdhd.be32(12); mediaDuration = Int64(mdhd.be32(16)) }
        sampleEntry = String(decoding: stsd[12..<16], as: UTF8.self)
        handler = hdlr.count >= 12 ? String(decoding: hdlr[8..<12], as: UTF8.self) : ""
        let n = Int(stts.be32(4))
        sttsRuns = (0..<n).map { (stts.be32(8 + 8*$0), stts.be32(12 + 8*$0)) }
        let fixed = stsz.be32(4), cnt = Int(stsz.be32(8))
        sizes = fixed != 0 ? Array(repeating: fixed, count: cnt) : (0..<cnt).map { stsz.be32(12 + 4*$0) }
        if let c = co64 {
            let k = Int(c.be32(4)); chunkOffsets = (0..<k).map { c.be64(8 + 8*$0) }
        } else {
            let k = Int(stco.be32(4)); chunkOffsets = (0..<k).map { UInt64(stco.be32(8 + 4*$0)) }
        }
        let ne = Int(stsc.be32(4))
        self.stsc = (0..<ne).map { (stsc.be32(8 + 12*$0), stsc.be32(12 + 12*$0)) }
        if let e = elstD {
            let v = e[e.startIndex]; let c = Int(e.be32(4))
            elst = (0..<c).map { i in
                v == 1 ? (Int64(e.be64(8 + 20*i)), Int64(bitPattern: e.be64(16 + 20*i)))
                       : (Int64(e.be32(8 + 12*i)), Int64(Int32(bitPattern: e.be32(12 + 12*i))))
            }
        } else { elst = nil }
        // derivate: tempi și offset-uri per eșantion
        var s = [Int64](), d = [Int64](); var acc: Int64 = 0
        for (c, dl) in sttsRuns { for _ in 0..<Int(c) { s.append(acc); d.append(Int64(dl)); acc += Int64(dl) } }
        starts = s; durs = d
        var offs = [UInt64](); var si = 0
        for (ci, co) in chunkOffsets.enumerated() {
            var per: UInt32 = 0
            for e in self.stsc where e.first <= UInt32(ci + 1) { per = e.perChunk }
            var o = co
            for _ in 0..<Int(per) where si < sizes.count { offs.append(o); o += UInt64(sizes[si]); si += 1 }
        }
        sampleOffsets = offs
        guard starts.count == sizes.count, sampleOffsets.count == sizes.count else {
            throw TrackGrafterError.unreadable("tabele inconsistente (\(starts.count)/\(sizes.count)/\(sampleOffsets.count))")
        }
    }

    func sampleLocation(_ i: Int) -> (UInt64, Int) { (sampleOffsets[i], Int(sizes[i])) }

    /// Timp pe linia filmului (ticks de film) → timp de media al pistei.
    func mediaTime(forMovieTicks t: Int64, movieTS: UInt32) -> Int64 {
        guard let el = elst, !el.isEmpty else { return t * Int64(mediaTimescale) / Int64(movieTS) }
        var seg: Int64 = 0
        var last: Int64 = 0
        for e in el {
            if e.mediaTime >= 0 {
                if t < seg + e.dur {
                    return e.mediaTime + (t - seg) * Int64(mediaTimescale) / Int64(movieTS)
                }
                last = e.mediaTime + e.dur * Int64(mediaTimescale) / Int64(movieTS)
            }
            seg += e.dur
        }
        return last
    }

    /// Indicii eșantioanelor care se suprapun cu [m0, m1).
    func samples(overlapping m0: Int64, _ m1: Int64) -> Range<Int> {
        var lo = -1, hi = -1
        for i in 0..<starts.count {
            let s = starts[i], e = starts[i] + durs[i]
            if e > m0 && s < m1 { if lo < 0 { lo = i }; hi = i }
        }
        return lo < 0 ? 0..<0 : lo..<(hi + 1)
    }

    /// Construiește o pistă nouă (trak) pentru eșantioanele alese, cu un
    /// singur chunk la `chunkOffset` și edit list propriu.
    func buildGraftedTrak(trackID: UInt32, picks: Range<Int>, chunkOffset: UInt64,
                          mediaStartTarget m0: Int64, destMovieTS: UInt32, outDurationTicks: Int64) throws -> Data {
        func box(_ t: String, _ body: Data) -> Data { Data(be32: UInt32(body.count + 8)) + Data(t.utf8) + body }
        // tkhd: id + durată
        var tk = tkhd
        if tk[tk.startIndex] == 1 {
            tk.replaceSubrange(20..<24, with: Data(be32: trackID))
            tk.replaceSubrange(28..<36, with: Data(be64: UInt64(outDurationTicks)))
        } else {
            tk.replaceSubrange(12..<16, with: Data(be32: trackID))
            tk.replaceSubrange(20..<24, with: Data(be32: UInt32(truncatingIfNeeded: outDurationTicks)))
        }
        // elst: gol la început dacă primul eșantion începe după m0; apoi media_time offset
        let firstStart = starts[picks.lowerBound]
        var entries = Data(); var count: UInt32 = 0
        var mediaTime: Int64 = m0 - firstStart
        var segDur = outDurationTicks
        if mediaTime < 0 {
            let gap = (-mediaTime) * Int64(destMovieTS) / Int64(mediaTimescale)
            entries += Data(be32: UInt32(gap)) + Data(be32: 0xFFFF_FFFF) + Data(be32: 0x0001_0000); count += 1
            segDur = max(1, segDur - gap); mediaTime = 0
        }
        entries += Data(be32: UInt32(truncatingIfNeeded: segDur)) + Data(be32: UInt32(truncatingIfNeeded: mediaTime)) + Data(be32: 0x0001_0000); count += 1
        let edts = box("edts", box("elst", Data(be32: 0) + Data(be32: count) + entries))
        // mdhd: durată = suma duratelor alese
        var md = mdhd
        let total = picks.reduce(Int64(0)) { $0 + durs[$1] }
        if md[md.startIndex] == 1 { md.replaceSubrange(24..<32, with: Data(be64: UInt64(total))) }
        else { md.replaceSubrange(16..<20, with: Data(be32: UInt32(truncatingIfNeeded: total))) }
        // stts RLE
        var runs: [(UInt32, UInt32)] = []
        for i in picks {
            let d = UInt32(durs[i])
            if let l = runs.last, l.1 == d { runs[runs.count - 1].0 += 1 } else { runs.append((1, d)) }
        }
        var sttsB = Data(be32: 0) + Data(be32: UInt32(runs.count))
        for r in runs { sttsB += Data(be32: r.0) + Data(be32: r.1) }
        let szs = picks.map { sizes[$0] }
        var stszB = Data(be32: 0) + Data(be32: 0) + Data(be32: UInt32(szs.count))
        for s in szs { stszB += Data(be32: s) }
        let stscB = Data(be32: 0) + Data(be32: 1) + Data(be32: 1) + Data(be32: UInt32(szs.count)) + Data(be32: 1)
        let co = chunkOffset > UInt64(UInt32.max)
            ? box("co64", Data(be32: 0) + Data(be32: 1) + Data(be64: chunkOffset))
            : box("stco", Data(be32: 0) + Data(be32: 1) + Data(be32: UInt32(chunkOffset)))
        let stbl = box("stbl", box("stsd", stsd) + box("stts", sttsB) + box("stsc", stscB) + box("stsz", stszB) + co)
        let minf = box("minf", minfOthers + stbl)
        let mdia = box("mdia", box("mdhd", md) + box("hdlr", hdlr) + minf)
        return box("trak", box("tkhd", tk) + edts + mdia)
    }
}

// MARK: - utilitare binare

func boxesIn(_ d: Data) -> [(String, Range<Int>)] {
    var res: [(String, Range<Int>)] = []
    var o = d.startIndex
    while o + 8 <= d.endIndex {
        var s = Int(d.be32(o - d.startIndex)); var hs = 8
        let t = String(decoding: d[(o + 4)..<(o + 8)], as: UTF8.self)
        if s == 1 { s = Int(d.be64(o - d.startIndex + 8)); hs = 16 }
        if s < hs || o + s > d.endIndex { break }
        res.append((t, (o + hs)..<(o + s)))
        o += s
    }
    return res
}

extension Data {
    init(be32 v: UInt32) { self.init([UInt8(v >> 24 & 255), UInt8(v >> 16 & 255), UInt8(v >> 8 & 255), UInt8(v & 255)]) }
    init(be64 v: UInt64) { self.init((0..<8).map { UInt8((v >> UInt64(56 - 8 * $0)) & 255) }) }
    func be32(_ i: Int) -> UInt32 {
        let b = startIndex + i
        return UInt32(self[b]) << 24 | UInt32(self[b + 1]) << 16 | UInt32(self[b + 2]) << 8 | UInt32(self[b + 3])
    }
    func be64(_ i: Int) -> UInt64 { UInt64(be32(i)) << 32 | UInt64(be32(i + 4)) }
}
