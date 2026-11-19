using System.Security.Cryptography;
using System.Text;

namespace CGConvertor.Core.Transcode;

public sealed class TrackGrafterException : Exception { public TrackGrafterException(string m) : base(m) { } }

public sealed record GraftedTrack(string FourCC, int SampleCount, int FirstSourceSample, long PayloadBytes, string PayloadSha256);
public sealed class GraftReport { public List<GraftedTrack> Tracks = new(); public List<string> Absent = new(); }

/// <summary>
/// Port 1:1 al TrackGrafter.swift (Mac 3.18.0): copiază piste native de metadate (cndm, rtmd) dintr-un MP4/MOV sursă
/// într-un MOV rezultat, fără recodare, selectând eșantioanele după TIMP (edit list) și scriind o pistă nouă cu edit list propriu.
/// </summary>
public static class TrackGrafter
{
    public static readonly string[] NativeFourCCs = { "cndm", "rtmd" };

    public static GraftReport Graft(string source, string dest, double start = 0, double? duration = null, string[]? fourCCs = null)
    {
        fourCCs ??= NativeFourCCs;
        using var src = new MP4File(source, false);
        using var dst = new MP4File(dest, true);
        if (dst.TopLevel.Count == 0 || dst.TopLevel[^1].Type != "moov") throw new TrackGrafterException("moov nu e ultimul în fișierul rezultat");
        var dMoov = dst.TopLevel[^1];
        var sMoovBytes = src.MoovBytes();
        var dMoovBytes = dst.Read(dMoov.Offset + (ulong)dMoov.HeaderSize, (int)dMoov.Size - dMoov.HeaderSize);
        var sMovie = new MovieInfo(sMoovBytes);
        var dMovieTS = new MovieInfo(dMoovBytes).Timescale;

        long t0 = (long)Math.Round(start * sMovie.Timescale, MidpointRounding.AwayFromZero);
        long total = sMovie.Duration;
        long t1 = duration.HasValue ? t0 + (long)Math.Round(duration.Value * sMovie.Timescale, MidpointRounding.AwayFromZero) : total;
        if (t1 <= t0) throw new TrackGrafterException("interval gol");

        var report = new GraftReport();
        var pend = new List<(TrakInfo Trak, (int Lo, int Hi) Picks, long M0)>();
        foreach (var fcc in fourCCs)
        {
            var tr = sMovie.Traks.FirstOrDefault(t => t.SampleEntry == fcc);
            if (tr == null) { report.Absent.Add(fcc); continue; }
            long m0 = tr.MediaTime(t0, sMovie.Timescale), m1 = tr.MediaTime(t1, sMovie.Timescale);
            var r = tr.SamplesOverlapping(m0, m1);
            if (r.Hi <= r.Lo) { report.Absent.Add(fcc); continue; }
            pend.Add((tr, r, m0));
        }
        if (pend.Count == 0) return report;

        ulong oldMoovEnd = dMoov.Offset + dMoov.Size, originalEnd = dst.Size;
        if (oldMoovEnd != originalEnd) throw new TrackGrafterException("date după moov în rezultat");
        ulong mdatStart = dMoov.Offset, sizeFieldPos = mdatStart;
        try
        {
            dst.TruncateAndSeek(mdatStart);
            dst.Write(new byte[] { 0, 0, 0, 1, (byte)'m', (byte)'d', (byte)'a', (byte)'t', 0, 0, 0, 0, 0, 0, 0, 0 });
            ulong cursor = mdatStart + 16;
            var newTraks = new List<byte>();
            uint nextId = MovieInfo.NextTrackId(dMoovBytes);
            foreach (var p in pend)
            {
                ulong chunkOffset = cursor;
                using var sha = IncrementalHash.CreateHash(HashAlgorithmName.SHA256);
                long bytes = 0;
                src.CopySamples(p.Trak, p.Picks.Lo, p.Picks.Hi, b => dst.Write(b), sha, ref bytes);
                cursor += (ulong)bytes;
                long outDurTicks = Math.Max(1, (t1 - t0) * dMovieTS / sMovie.Timescale);
                newTraks.AddRange(p.Trak.BuildGraftedTrak(nextId, p.Picks, chunkOffset, p.M0, dMovieTS, outDurTicks));
                nextId++;
                report.Tracks.Add(new GraftedTrack(p.Trak.SampleEntry, p.Picks.Hi - p.Picks.Lo, p.Picks.Lo, bytes, Convert.ToHexString(sha.GetHashAndReset()).ToLowerInvariant()));
            }
            dst.WriteAt(sizeFieldPos + 8, Bin.Be64(cursor - mdatStart));
            var moovBody = MovieInfo.RewriteMoov(dMoovBytes, newTraks.ToArray(), nextId);
            var header = Bin.Cat(Bin.Be32((uint)(moovBody.Length + 8)), Encoding.ASCII.GetBytes("moov"));
            dst.SeekTo(cursor);
            dst.Write(Bin.Cat(header, moovBody));
            dst.Flush();
        }
        catch
        {
            try
            {
                dst.TruncateAndSeek(mdatStart);
                dst.Write(Bin.Cat(Bin.Be32((uint)(dMoovBytes.Length + 8)), Encoding.ASCII.GetBytes("moov"), dMoovBytes));
                dst.Flush();
            }
            catch { }
            throw;
        }
        return report;
    }

    /// <summary>Verificare independentă: recitește eșantioanele din rezultat și compară SHA-256, numărul de eșantioane.</summary>
    public static List<string> Verify(GraftReport report, string output)
    {
        var problems = new List<string>();
        using var o = new MP4File(output, false);
        var movie = new MovieInfo(o.MoovBytes());
        foreach (var g in report.Tracks)
        {
            var tr = movie.Traks.FirstOrDefault(t => t.SampleEntry == g.FourCC);
            if (tr == null) { problems.Add($"{g.FourCC}: lipsește din rezultat"); continue; }
            if (tr.SampleCount != g.SampleCount) problems.Add($"{g.FourCC}: {tr.SampleCount} eșantioane, așteptat {g.SampleCount}");
            using var sha = IncrementalHash.CreateHash(HashAlgorithmName.SHA256); long bytes = 0;
            o.CopySamples(tr, 0, tr.SampleCount, null, sha, ref bytes);
            if (!Convert.ToHexString(sha.GetHashAndReset()).Equals(g.PayloadSha256, StringComparison.OrdinalIgnoreCase)) problems.Add($"{g.FourCC}: conținut diferit față de sursă");
        }
        return problems;
    }
}

static class Bin
{
    public static uint B32(byte[] d, int i) => (uint)(d[i] << 24 | d[i + 1] << 16 | d[i + 2] << 8 | d[i + 3]);
    public static ulong B64(byte[] d, int i) => (ulong)B32(d, i) << 32 | B32(d, i + 4);
    public static byte[] Be32(uint v) => new[] { (byte)(v >> 24), (byte)(v >> 16), (byte)(v >> 8), (byte)v };
    public static byte[] Be64(ulong v) { var r = new byte[8]; for (int i = 0; i < 8; i++) r[i] = (byte)(v >> (56 - 8 * i)); return r; }
    public static byte[] Cat(params byte[][] parts) { var r = new byte[parts.Sum(p => p.Length)]; int o = 0; foreach (var p in parts) { Buffer.BlockCopy(p, 0, r, o, p.Length); o += p.Length; } return r; }
    public static byte[] Slice(byte[] d, int s, int e) { var r = new byte[e - s]; Buffer.BlockCopy(d, s, r, 0, r.Length); return r; }
    public static byte[] Box(string t, byte[] body) => Cat(Be32((uint)(body.Length + 8)), Encoding.ASCII.GetBytes(t), body);
    public static void Put(byte[] d, int at, byte[] v) => Buffer.BlockCopy(v, 0, d, at, v.Length);

    public static List<(string Type, int Start, int End)> BoxesIn(byte[] d)
    {
        var res = new List<(string, int, int)>(); int o = 0;
        while (o + 8 <= d.Length)
        {
            long s = B32(d, o); int hs = 8; var t = Encoding.ASCII.GetString(d, o + 4, 4);
            if (s == 1) { s = (long)B64(d, o + 8); hs = 16; }
            if (s < hs || o + s > d.Length) break;
            res.Add((t, o + hs, (int)(o + s))); o += (int)s;
        }
        return res;
    }
}

sealed class MP4File : IDisposable
{
    public readonly record struct Box(ulong Offset, ulong Size, int HeaderSize, string Type);
    readonly FileStream _fs; public readonly ulong Size; public readonly List<Box> TopLevel = new();

    public MP4File(string path, bool writable)
    {
        try { _fs = new FileStream(path, FileMode.Open, writable ? FileAccess.ReadWrite : FileAccess.Read, writable ? FileShare.None : FileShare.Read, 1 << 16); }
        catch { throw new TrackGrafterException($"nu pot deschide {Path.GetFileName(path)}"); }
        Size = (ulong)_fs.Length; ulong off = 0; var h = new byte[16];
        while (off + 8 <= Size)
        {
            _fs.Position = (long)off; int n = _fs.Read(h, 0, 16); if (n < 8) break;
            ulong s = Bin.B32(h, 0); int hs = 8; var t = Encoding.ASCII.GetString(h, 4, 4);
            if (s == 1) { if (n < 16) break; s = Bin.B64(h, 8); hs = 16; } else if (s == 0) s = Size - off;
            if (s < (ulong)hs || off + s > Size) break;
            TopLevel.Add(new Box(off, s, hs, t)); off += s;
        }
    }

    public void Dispose() => _fs.Dispose();
    public byte[] Read(ulong off, int count)
    {
        _fs.Position = (long)off; var b = new byte[count]; int got = 0;
        while (got < count) { int n = _fs.Read(b, got, count - got); if (n <= 0) throw new TrackGrafterException("citire incompletă"); got += n; }
        return b;
    }
    public byte[] MoovBytes()
    {
        var m = TopLevel.FirstOrDefault(b => b.Type == "moov"); if (m.Type != "moov") throw new TrackGrafterException("fără moov");
        return Read(m.Offset + (ulong)m.HeaderSize, (int)m.Size - m.HeaderSize);
    }
    public void TruncateAndSeek(ulong off) { _fs.SetLength((long)off); _fs.Position = (long)off; }
    public void SeekTo(ulong off) => _fs.Position = (long)off;
    public void Write(byte[] d) => _fs.Write(d, 0, d.Length);
    public void WriteAt(ulong off, byte[] d) { var cur = _fs.Position; _fs.Position = (long)off; _fs.Write(d, 0, d.Length); _fs.Position = cur; }
    public void Flush() => _fs.Flush(true);

    public void CopySamples(TrakInfo tr, int lo, int hi, Action<byte[]>? sink, IncrementalHash sha, ref long bytes)
    {
        ulong runStart = 0; int runLen = 0; long total = bytes;
        void FlushRun()
        {
            if (runLen <= 0) return;
            int remaining = runLen; ulong pos = runStart;
            while (remaining > 0)
            {
                int n = Math.Min(remaining, 8 << 20);
                var d = Read(pos, n); sha.AppendData(d); sink?.Invoke(d);
                pos += (ulong)n; remaining -= n; total += n;
            }
            runLen = 0;
        }
        for (int i = lo; i < hi; i++)
        {
            var (o, s) = tr.SampleLocation(i);
            if (runLen > 0 && runStart + (ulong)runLen == o) runLen += s; else { FlushRun(); runStart = o; runLen = s; }
        }
        FlushRun(); bytes = total;
    }
}

sealed class MovieInfo
{
    public readonly uint Timescale; public readonly long Duration; public readonly List<TrakInfo> Traks = new();

    public MovieInfo(byte[] moov)
    {
        uint ts = 0; long dur = 0;
        foreach (var (t, s, e) in Bin.BoxesIn(moov))
        {
            if (t == "mvhd")
            {
                var b = Bin.Slice(moov, s, e);
                if (b[0] == 1) { ts = Bin.B32(b, 20); dur = (long)Bin.B64(b, 24); } else { ts = Bin.B32(b, 12); dur = Bin.B32(b, 16); }
            }
            else if (t == "trak") { try { Traks.Add(new TrakInfo(Bin.Slice(moov, s, e))); } catch (TrackGrafterException) { } }
        }
        if (ts == 0) throw new TrackGrafterException("mvhd lipsă");
        Timescale = ts; Duration = dur;
    }

    public static uint NextTrackId(byte[] moov)
    {
        var r = Bin.BoxesIn(moov).FirstOrDefault(x => x.Type == "mvhd"); if (r.Type != "mvhd") throw new TrackGrafterException("mvhd");
        return Bin.B32(moov, r.End - 4);
    }

    public static byte[] RewriteMoov(byte[] old, byte[] appending, uint newNextId)
    {
        var o = new List<byte>();
        foreach (var (t, s, e) in Bin.BoxesIn(old))
        {
            var b = Bin.Slice(old, s, e);
            if (t == "mvhd") Bin.Put(b, b.Length - 4, Bin.Be32(newNextId));
            o.AddRange(Bin.Box(t, b));
        }
        o.AddRange(appending); return o.ToArray();
    }
}

sealed class TrakInfo
{
    public readonly uint TrackId, MediaTimescale; public readonly long MediaDuration; public readonly string SampleEntry, Handler;
    readonly byte[] _tkhd, _mdhd, _hdlr, _stsd, _minfOthers;
    readonly uint[] _sizes; readonly long[] _starts, _durs; readonly ulong[] _offs;
    readonly (long Dur, long MediaTime)[]? _elst;
    public int SampleCount => _sizes.Length;

    public TrakInfo(byte[] trak)
    {
        byte[] tkhd = Array.Empty<byte>(), mdhd = Array.Empty<byte>(), hdlr = Array.Empty<byte>(), stsd = Array.Empty<byte>(), stts = Array.Empty<byte>(), stsz = Array.Empty<byte>(), stscB = Array.Empty<byte>(), stco = Array.Empty<byte>();
        byte[]? co64 = null, elstD = null; var minfOthers = new List<byte>();
        foreach (var (t, s, e) in Bin.BoxesIn(trak))
        {
            if (t == "tkhd") tkhd = Bin.Slice(trak, s, e);
            else if (t == "edts") { var edts = Bin.Slice(trak, s, e); foreach (var (t2, s2, e2) in Bin.BoxesIn(edts)) if (t2 == "elst") elstD = Bin.Slice(edts, s2, e2); }
            else if (t == "mdia")
            {
                var mdia = Bin.Slice(trak, s, e);
                foreach (var (t2, s2, e2) in Bin.BoxesIn(mdia))
                {
                    if (t2 == "mdhd") mdhd = Bin.Slice(mdia, s2, e2);
                    else if (t2 == "hdlr") hdlr = Bin.Slice(mdia, s2, e2);
                    else if (t2 == "minf")
                    {
                        var minf = Bin.Slice(mdia, s2, e2);
                        foreach (var (t3, s3, e3) in Bin.BoxesIn(minf))
                        {
                            if (t3 == "stbl")
                            {
                                var stbl = Bin.Slice(minf, s3, e3);
                                foreach (var (t4, s4, e4) in Bin.BoxesIn(stbl))
                                    switch (t4)
                                    {
                                        case "stsd": stsd = Bin.Slice(stbl, s4, e4); break;
                                        case "stts": stts = Bin.Slice(stbl, s4, e4); break;
                                        case "stsz": stsz = Bin.Slice(stbl, s4, e4); break;
                                        case "stsc": stscB = Bin.Slice(stbl, s4, e4); break;
                                        case "stco": stco = Bin.Slice(stbl, s4, e4); break;
                                        case "co64": co64 = Bin.Slice(stbl, s4, e4); break;
                                    }
                            }
                            else minfOthers.AddRange(Bin.Box(t3, Bin.Slice(minf, s3, e3)));
                        }
                    }
                }
            }
        }
        if (tkhd.Length == 0 || mdhd.Length == 0 || stsd.Length < 16 || stts.Length == 0 || stsz.Length == 0 || stscB.Length == 0) throw new TrackGrafterException("pistă incompletă");
        _tkhd = tkhd; _mdhd = mdhd; _hdlr = hdlr; _stsd = stsd; _minfOthers = minfOthers.ToArray();
        TrackId = tkhd[0] == 1 ? Bin.B32(tkhd, 20) : Bin.B32(tkhd, 12);
        if (mdhd[0] == 1) { MediaTimescale = Bin.B32(mdhd, 20); MediaDuration = (long)Bin.B64(mdhd, 24); } else { MediaTimescale = Bin.B32(mdhd, 12); MediaDuration = Bin.B32(mdhd, 16); }
        SampleEntry = Encoding.ASCII.GetString(stsd, 12, 4);
        Handler = hdlr.Length >= 12 ? Encoding.ASCII.GetString(hdlr, 8, 4) : "";
        int n = (int)Bin.B32(stts, 4); var runs = new (uint Count, uint Delta)[n];
        for (int i = 0; i < n; i++) runs[i] = (Bin.B32(stts, 8 + 8 * i), Bin.B32(stts, 12 + 8 * i));
        uint fixedSz = Bin.B32(stsz, 4); int cnt = (int)Bin.B32(stsz, 8);
        _sizes = new uint[cnt]; for (int i = 0; i < cnt; i++) _sizes[i] = fixedSz != 0 ? fixedSz : Bin.B32(stsz, 12 + 4 * i);
        ulong[] chunkOffsets;
        if (co64 != null) { int k = (int)Bin.B32(co64, 4); chunkOffsets = new ulong[k]; for (int i = 0; i < k; i++) chunkOffsets[i] = Bin.B64(co64, 8 + 8 * i); }
        else { int k = (int)Bin.B32(stco, 4); chunkOffsets = new ulong[k]; for (int i = 0; i < k; i++) chunkOffsets[i] = Bin.B32(stco, 8 + 4 * i); }
        int ne = (int)Bin.B32(stscB, 4); var stsc = new (uint First, uint PerChunk)[ne];
        for (int i = 0; i < ne; i++) stsc[i] = (Bin.B32(stscB, 8 + 12 * i), Bin.B32(stscB, 12 + 12 * i));
        if (elstD != null)
        {
            byte v = elstD[0]; int c = (int)Bin.B32(elstD, 4); _elst = new (long, long)[c];
            for (int i = 0; i < c; i++)
                _elst[i] = v == 1 ? ((long)Bin.B64(elstD, 8 + 20 * i), (long)Bin.B64(elstD, 16 + 20 * i)) : (Bin.B32(elstD, 8 + 12 * i), (int)Bin.B32(elstD, 12 + 12 * i));
        }
        var s_ = new List<long>(); var d_ = new List<long>(); long acc = 0;
        foreach (var (c, dl) in runs) for (uint j = 0; j < c; j++) { s_.Add(acc); d_.Add(dl); acc += dl; }
        _starts = s_.ToArray(); _durs = d_.ToArray();
        var offs = new List<ulong>(); int si = 0;
        for (int ci = 0; ci < chunkOffsets.Length; ci++)
        {
            uint per = 0; foreach (var e in stsc) if (e.First <= (uint)(ci + 1)) per = e.PerChunk;
            ulong o = chunkOffsets[ci];
            for (uint j = 0; j < per && si < _sizes.Length; j++) { offs.Add(o); o += _sizes[si]; si++; }
        }
        _offs = offs.ToArray();
        if (_starts.Length != _sizes.Length || _offs.Length != _sizes.Length) throw new TrackGrafterException($"tabele inconsistente ({_starts.Length}/{_sizes.Length}/{_offs.Length})");
    }

    public (ulong Offset, int Size) SampleLocation(int i) => (_offs[i], (int)_sizes[i]);

    public long MediaTime(long t, uint movieTs)
    {
        if (_elst == null || _elst.Length == 0) return t * MediaTimescale / movieTs;
        long seg = 0, last = 0;
        foreach (var e in _elst)
        {
            if (e.MediaTime >= 0)
            {
                if (t < seg + e.Dur) return e.MediaTime + (t - seg) * MediaTimescale / movieTs;
                last = e.MediaTime + e.Dur * MediaTimescale / movieTs;
            }
            seg += e.Dur;
        }
        return last;
    }

    public (int Lo, int Hi) SamplesOverlapping(long m0, long m1)
    {
        int lo = -1, hi = -1;
        for (int i = 0; i < _starts.Length; i++) { long s = _starts[i], e = s + _durs[i]; if (e > m0 && s < m1) { if (lo < 0) lo = i; hi = i; } }
        return lo < 0 ? (0, 0) : (lo, hi + 1);
    }

    public byte[] BuildGraftedTrak(uint trackId, (int Lo, int Hi) picks, ulong chunkOffset, long m0, uint destMovieTs, long outDurationTicks)
    {
        var tk = (byte[])_tkhd.Clone();
        if (tk[0] == 1) { Bin.Put(tk, 20, Bin.Be32(trackId)); Bin.Put(tk, 28, Bin.Be64((ulong)outDurationTicks)); }
        else { Bin.Put(tk, 12, Bin.Be32(trackId)); Bin.Put(tk, 20, Bin.Be32(unchecked((uint)outDurationTicks))); }
        long firstStart = _starts[picks.Lo]; var entries = new List<byte>(); uint count = 0;
        long mediaTime = m0 - firstStart, segDur = outDurationTicks;
        if (mediaTime < 0)
        {
            long gap = (-mediaTime) * destMovieTs / MediaTimescale;
            entries.AddRange(Bin.Cat(Bin.Be32(unchecked((uint)gap)), Bin.Be32(0xFFFFFFFF), Bin.Be32(0x00010000))); count++;
            segDur = Math.Max(1, segDur - gap); mediaTime = 0;
        }
        entries.AddRange(Bin.Cat(Bin.Be32(unchecked((uint)segDur)), Bin.Be32(unchecked((uint)mediaTime)), Bin.Be32(0x00010000))); count++;
        var edts = Bin.Box("edts", Bin.Box("elst", Bin.Cat(Bin.Be32(0), Bin.Be32(count), entries.ToArray())));
        var md = (byte[])_mdhd.Clone(); long total = 0; for (int i = picks.Lo; i < picks.Hi; i++) total += _durs[i];
        if (md[0] == 1) Bin.Put(md, 24, Bin.Be64((ulong)total)); else Bin.Put(md, 16, Bin.Be32(unchecked((uint)total)));
        var runs = new List<(uint C, uint D)>();
        for (int i = picks.Lo; i < picks.Hi; i++) { uint d = (uint)_durs[i]; if (runs.Count > 0 && runs[^1].D == d) runs[^1] = (runs[^1].C + 1, d); else runs.Add((1, d)); }
        var sttsB = new List<byte>(); sttsB.AddRange(Bin.Be32(0)); sttsB.AddRange(Bin.Be32((uint)runs.Count)); foreach (var r in runs) { sttsB.AddRange(Bin.Be32(r.C)); sttsB.AddRange(Bin.Be32(r.D)); }
        int n = picks.Hi - picks.Lo; var stszB = new List<byte>(); stszB.AddRange(Bin.Be32(0)); stszB.AddRange(Bin.Be32(0)); stszB.AddRange(Bin.Be32((uint)n));
        for (int i = picks.Lo; i < picks.Hi; i++) stszB.AddRange(Bin.Be32(_sizes[i]));
        var stscNew = Bin.Cat(Bin.Be32(0), Bin.Be32(1), Bin.Be32(1), Bin.Be32((uint)n), Bin.Be32(1));
        var co = chunkOffset > uint.MaxValue ? Bin.Box("co64", Bin.Cat(Bin.Be32(0), Bin.Be32(1), Bin.Be64(chunkOffset))) : Bin.Box("stco", Bin.Cat(Bin.Be32(0), Bin.Be32(1), Bin.Be32((uint)chunkOffset)));
        var stbl = Bin.Box("stbl", Bin.Cat(Bin.Box("stsd", _stsd), Bin.Box("stts", sttsB.ToArray()), Bin.Box("stsc", stscNew), Bin.Box("stsz", stszB.ToArray()), co));
        var minf = Bin.Box("minf", Bin.Cat(_minfOthers, stbl));
        var mdia = Bin.Box("mdia", Bin.Cat(Bin.Box("mdhd", md), Bin.Box("hdlr", _hdlr), minf));
        return Bin.Box("trak", Bin.Cat(Bin.Box("tkhd", tk), edts, mdia));
    }
}
