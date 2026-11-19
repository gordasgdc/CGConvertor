using System.Diagnostics;
using System.Globalization;
using System.Text;
using System.Text.Json;

namespace CGConvertor.Core.Transcode;

public sealed class ConversionException : Exception { public ConversionException(string m) : base(m) { } }
public sealed class ConversionCancelled : Exception { }

public sealed record VideoJob(string SourcePath, double? IntervalStart = null, double? IntervalEnd = null)
{
    public bool HasInterval => IntervalStart.HasValue || IntervalEnd.HasValue;
}

public enum MetadataOutcome { Off, NothingToCarry, Complete, Incomplete }

public sealed record ReportNote(string Key, string Arg);

public sealed class ConversionReport
{
    public string? TimecodeSource, TimecodeOutput;
    public int? FramesSource, FramesOutput;
    public int AudioStreamsSource, AudioStreamsOutput;
    public double? DurationSource, DurationOutput;
    public (int StartFrame, int Frames, double Fps)? Interval;
    public MetadataOutcome Metadata = MetadataOutcome.NothingToCarry;
    public List<ReportNote> Kept = new(), NotKept = new(), Problems = new();
    public SourceProfile? SourceProfile; public List<GraftedTrack> Grafted = new();
}

public readonly record struct StreamSummary(int? Frames, int Audio, double? Duration, double? Fps);

/// <summary>Instanță de rulare: o conversie, anulabilă (oprește procesul ffmpeg activ).</summary>
public sealed class ConversionHandle
{
    volatile Process? _active; volatile bool _cancelled;
    public bool Cancelled => _cancelled;
    internal void Attach(Process p) { _active = p; if (_cancelled) Kill(p); }
    public void Cancel() { _cancelled = true; var p = _active; if (p != null) Kill(p); }
    static void Kill(Process p) { try { if (!p.HasExited) p.Kill(true); } catch { } }
}

/// <summary>
/// Port al pipeline-ului MotorFFmpeg (Mac 3.18.0): 1) transcodare/rewrap pe fișier temporar, 2) timecode prin
/// re-wrap, 4) verificare independentă; destinația apare doar după verificare. Hardware decode rămâne oprit.
/// Pasul 3 = TrackGrafter (portat 1:1, verificat octet cu octet față de Swift).
/// </summary>
public sealed class TranscodeEngine
{
    public string Ffmpeg { get; }
    public string Ffprobe { get; }

    public TranscodeEngine(string ffmpeg, string ffprobe) { Ffmpeg = ffmpeg; Ffprobe = ffprobe; }

    public static TranscodeEngine? Locate(string? baseDir = null)
    {
        baseDir ??= AppContext.BaseDirectory;
        var dir = Path.Combine(baseDir, "tools");
        var ff = Path.Combine(dir, OperatingSystem.IsWindows() ? "ffmpeg.exe" : "ffmpeg");
        var fp = Path.Combine(dir, OperatingSystem.IsWindows() ? "ffprobe.exe" : "ffprobe");
        return File.Exists(ff) && File.Exists(fp) ? new TranscodeEngine(ff, fp) : null;
    }

    static string Inv(double d) => d.ToString("0.000000", CultureInfo.InvariantCulture);

    public static List<string> BuildArgs(VideoJob job, OutputPreset preset, string dest, bool keepLog, (double Start, double Duration)? interval)
    {
        var a = new List<string> { "-y" };
        if (interval is { } iv) { a.Add("-ss"); a.Add(Inv(iv.Start)); }
        a.Add("-i"); a.Add(job.SourcePath);
        if (interval is { } iv2) { a.Add("-t"); a.Add(Inv(iv2.Duration)); }
        if (preset.IsRewrap) { a.Add("-c"); a.Add("copy"); }
        else if (FormatRegistry.Profile(preset.ProfileId) is { } p)
        {
            a.AddRange(p.Args);
            if (!string.IsNullOrEmpty(preset.FrameRate)) { a.Add("-r"); a.Add(preset.FrameRate!); }
            if (preset.ColorSpace is { } cs) a.AddRange(cs.For());
            else if (keepLog) { a.Add("-vf"); a.Add("setparams=color_primaries=unknown:color_trc=unknown"); }
            var mxf = string.Equals(p.Container, "mxf", StringComparison.OrdinalIgnoreCase);
            // MXF acceptă doar PCM la 48 kHz: ieșirea se configurează compatibil ÎNAINTE de pornire (nu eșuează la mijloc).
            var am = mxf && (preset.Audio == AudioMode.Passthrough || preset.Audio == AudioMode.Aac) ? AudioMode.Pcm24 : preset.Audio;
            a.AddRange(am.For());
            if (mxf) { a.Add("-ar"); a.Add("48000"); }
            if (am != AudioMode.Passthrough) a.AddRange(preset.Channels.For());
            a.Add("-c:d"); a.Add("copy");
            if (p.ExtraMux != null) a.AddRange(p.ExtraMux);
        }
        a.Add("-map_metadata"); a.Add("0");
        a.Add("-map"); a.Add("0:v"); a.Add("-map"); a.Add("0:a?");
        a.Add(dest);
        return a;
    }

    /// <summary>True dacă presetul MXF schimbă audio (copy/AAC → PCM 24-bit 48 kHz) pentru compatibilitate.</summary>
    public static bool MxfAudioAdjusted(OutputPreset preset) =>
        !preset.IsRewrap && FormatRegistry.Profile(preset.ProfileId) is { } p && string.Equals(p.Container, "mxf", StringComparison.OrdinalIgnoreCase)
        && (preset.Audio == AudioMode.Passthrough || preset.Audio == AudioMode.Aac);

    public static bool IsLog(string curve) { var c = curve.ToLowerInvariant(); return c.Contains("log") || c.Contains("film"); }

    // ── ffprobe ────────────────────────────────────────────────────────────────
    string RunCapture(string exe, IEnumerable<string> args, int timeoutMs = 60000)
    {
        var psi = new ProcessStartInfo(exe) { RedirectStandardOutput = true, RedirectStandardError = true, UseShellExecute = false, CreateNoWindow = true, StandardOutputEncoding = Encoding.UTF8 };
        foreach (var x in args) psi.ArgumentList.Add(x);
        using var p = Process.Start(psi)!;
        var err = p.StandardError.ReadToEndAsync();
        var o = p.StandardOutput.ReadToEndAsync();
        if (!p.WaitForExit(timeoutMs)) { try { p.Kill(true); } catch { } return ""; }
        return o.Result;
    }

    public StreamSummary? Summarize(string path)
    {
        var json = RunCapture(Ffprobe, new[] { "-v", "error", "-show_entries", "stream=codec_type,nb_frames,r_frame_rate:format=duration", "-of", "json", path });
        if (json.Length == 0) return null;
        try
        {
            using var d = JsonDocument.Parse(json);
            int? frames = null; int audio = 0; double? fps = null;
            bool seenVideo = false;
            if (d.RootElement.TryGetProperty("streams", out var ss))
                foreach (var s in ss.EnumerateArray())
                {
                    var t = s.TryGetProperty("codec_type", out var ct) ? ct.GetString() : null;
                    if (t == "audio") audio++;
                    else if (t == "video" && !seenVideo)
                    {
                        seenVideo = true;
                        if (s.TryGetProperty("nb_frames", out var nf) && int.TryParse(nf.GetString(), out var n)) frames = n;
                        if (s.TryGetProperty("r_frame_rate", out var r) && r.GetString() is { } rs && rs.Split('/') is { Length: 2 } q
                            && double.TryParse(q[0], CultureInfo.InvariantCulture, out var num) && double.TryParse(q[1], CultureInfo.InvariantCulture, out var den) && den > 0) fps = num / den;
                    }
                }
            double? dur = d.RootElement.TryGetProperty("format", out var f) && f.TryGetProperty("duration", out var du) && double.TryParse(du.GetString(), CultureInfo.InvariantCulture, out var dd) ? dd : null;
            return new StreamSummary(frames, audio, dur, fps);
        }
        catch (JsonException) { return null; }
    }

    public string? ProbeTimecode(string path)
    {
        var o = RunCapture(Ffprobe, new[] { "-v", "error", "-select_streams", "d", "-show_entries", "stream_tags=timecode:format_tags=timecode", "-of", "default=noprint_wrappers=1:nokey=1", path });
        return o.Split('\n', StringSplitOptions.RemoveEmptyEntries).Select(l => l.Trim()).FirstOrDefault(l => l.Length > 0);
    }

    static double? ParseTime(string text)
    {
        int i = text.LastIndexOf("time=", StringComparison.Ordinal); if (i < 0) return null;
        var rest = text[(i + 5)..]; int sp = rest.IndexOf(' '); if (sp < 0) return null;
        var c = rest[..sp].Split(':'); if (c.Length != 3) return null;
        return double.TryParse(c[0], CultureInfo.InvariantCulture, out var h) && double.TryParse(c[1], CultureInfo.InvariantCulture, out var m) && double.TryParse(c[2], CultureInfo.InvariantCulture, out var s) ? h * 3600 + m * 60 + s : null;
    }

    int RunProcess(IEnumerable<string> args, ConversionHandle h, Action<string>? onStderr)
    {
        var psi = new ProcessStartInfo(Ffmpeg) { RedirectStandardError = true, RedirectStandardOutput = true, UseShellExecute = false, CreateNoWindow = true };
        foreach (var x in args) psi.ArgumentList.Add(x);
        if (h.Cancelled) throw new ConversionCancelled();
        using var p = Process.Start(psi)!;
        h.Attach(p);
        p.OutputDataReceived += (_, _) => { };
        p.BeginOutputReadLine();
        var buf = new char[4096]; int n;
        while ((n = p.StandardError.Read(buf, 0, buf.Length)) > 0) onStderr?.Invoke(new string(buf, 0, n));
        p.WaitForExit();
        return p.ExitCode;
    }


    /// <summary>Un cadru PNG (pentru miniaturi/previzualizare). Decodare software, fără accelerare hardware.</summary>
    public byte[]? FrameBytes(string path, double seconds, int width)
    {
        var psi = new ProcessStartInfo(Ffmpeg) { RedirectStandardOutput = true, RedirectStandardError = true, UseShellExecute = false, CreateNoWindow = true };
        foreach (var x in new[] { "-v", "error", "-ss", Inv(Math.Max(0, seconds)), "-i", path, "-frames:v", "1", "-vf", $"scale={width}:-2", "-f", "image2pipe", "-vcodec", "png", "-" }) psi.ArgumentList.Add(x);
        try
        {
            using var p = Process.Start(psi)!;
            var err = p.StandardError.ReadToEndAsync();
            using var ms = new MemoryStream(); p.StandardOutput.BaseStream.CopyTo(ms);
            if (!p.WaitForExit(30000)) { try { p.Kill(true); } catch { } return null; }
            return ms.Length > 0 ? ms.ToArray() : null;
        }
        catch { return null; }
    }

    /// <summary>Rezumat lizibil: codec · rezoluție · cadre/s · durată.</summary>
    public string Describe(string path)
    {
        var json = RunCapture(Ffprobe, new[] { "-v", "error", "-select_streams", "v:0", "-show_entries", "stream=codec_name,width,height,r_frame_rate:format=duration", "-of", "json", path });
        try
        {
            using var d = JsonDocument.Parse(json);
            var parts = new List<string>();
            if (d.RootElement.TryGetProperty("streams", out var ss) && ss.GetArrayLength() > 0)
            {
                var s = ss[0];
                if (s.TryGetProperty("codec_name", out var c)) parts.Add(c.GetString()!.ToUpperInvariant());
                if (s.TryGetProperty("width", out var w) && s.TryGetProperty("height", out var h)) parts.Add($"{w.GetInt32()}×{h.GetInt32()}");
                if (s.TryGetProperty("r_frame_rate", out var r) && r.GetString()!.Split('/') is { Length: 2 } q && double.TryParse(q[0], CultureInfo.InvariantCulture, out var n) && double.TryParse(q[1], CultureInfo.InvariantCulture, out var dn) && dn > 0)
                    parts.Add($"{n / dn:0.###} fps");
            }
            if (d.RootElement.TryGetProperty("format", out var f) && f.TryGetProperty("duration", out var du) && double.TryParse(du.GetString(), CultureInfo.InvariantCulture, out var sec))
                parts.Add(TimeSpan.FromSeconds(sec).ToString(sec >= 3600 ? @"h\:mm\:ss" : @"m\:ss"));
            return string.Join(" · ", parts);
        }
        catch { return ""; }
    }

    /// <summary>Encodere disponibile în ffmpeg-ul împachetat (ffmpeg -encoders), pentru dezactivarea profilelor indisponibile.</summary>
    public HashSet<string> AvailableEncoders()
    {
        var o = RunCapture(Ffmpeg, new[] { "-hide_banner", "-encoders" });
        var set = new HashSet<string>();
        foreach (var line in o.Split('\n')) { var t = line.TrimStart().Split(' ', StringSplitOptions.RemoveEmptyEntries); if (t.Length >= 2 && t[0].Length == 6 && t[0][0] == 'V') set.Add(t[1]); }
        return set;
    }

    // ── Pipeline ────────────────────────────────────────────────────────────────
    public ConversionReport Run(VideoJob job, OutputPreset preset, string dest, ConversionHandle handle, Action<double>? progress = null,
                                bool keepMetadata = true, bool writeSidecar = true)
    {
        var dir = Path.GetDirectoryName(Path.GetFullPath(dest))!;
        var baseName = Path.GetFileNameWithoutExtension(dest); var ext = Path.GetExtension(dest);
        var tmp1 = Path.Combine(dir, $".{baseName}.cgc-1{ext}"); var tmp2 = Path.Combine(dir, $".{baseName}.cgc-2{ext}");
        var rep = new ConversionReport();
        try
        {
            foreach (var t in new[] { tmp1, tmp2 }) if (File.Exists(t)) File.Delete(t);
            var srcInfo = new FileInfo(job.SourcePath); long size0 = srcInfo.Length; var m0 = srcInfo.LastWriteTimeUtc;

            var profile = MetadataCoreClient.Scan(job.SourcePath);
            var tc = profile?.Timecode ?? ProbeTimecode(job.SourcePath);
            rep.TimecodeSource = tc; rep.SourceProfile = profile;
            var src = Summarize(job.SourcePath);
            double total = src?.Duration ?? 0;

            (double Start, double Duration)? interval = null; int? expectedFrames = null;
            if (job.HasInterval)
            {
                if (preset.IsRewrap) throw new ConversionException("Intervalul cere transcodare (rewrap nu taie exact pe cadru).");
                if (src is not { Fps: > 0, Duration: not null } s0) throw new ConversionException("Nu pot citi cadrele/s sau durata sursei pentru interval.");
                int f0 = (int)Math.Round((job.IntervalStart ?? 0) * s0.Fps!.Value, MidpointRounding.AwayFromZero);
                int f1 = (int)Math.Round(Math.Min(job.IntervalEnd ?? s0.Duration!.Value, s0.Duration!.Value) * s0.Fps!.Value, MidpointRounding.AwayFromZero);
                if (f0 < 0 || f1 <= f0) throw new ConversionException("Interval invalid.");
                interval = (f0 / s0.Fps.Value, (f1 - f0) / s0.Fps.Value); expectedFrames = f1 - f0; total = (f1 - f0) / s0.Fps.Value;
                if (tc != null)
                {
                    var nt = TimecodeMath.Offset(tc, f0, s0.Fps.Value); tc = nt; rep.TimecodeSource = nt;
                    if (nt == null) rep.Problems.Add(new("report.tcFailed", tc ?? ""));
                }
                rep.Interval = (f0, f1 - f0, s0.Fps.Value);
            }
            rep.FramesSource = src?.Frames; rep.AudioStreamsSource = src?.Audio ?? 0; rep.DurationSource = src?.Duration;

            bool keepLog = profile?.Curve is { } cv && IsLog(cv.Value);
            string last = "";
            int c1 = RunProcess(BuildArgs(job, preset, tmp1, keepLog, interval), handle, t =>
            {
                last = (last + t); if (last.Length > 2000) last = last[^2000..];
                if (total > 0 && ParseTime(t) is { } sec) progress?.Invoke(Math.Min(sec / total, 1.0) * 0.9);
            });
            if (handle.Cancelled) throw new ConversionCancelled();
            if (c1 != 0) throw new ConversionException($"FFmpeg a esuat (cod {c1}): {string.Join(" ", last.Split('\n').Where(l => l.Trim().Length > 0).TakeLast(5))}");
            var current = tmp1;

            if (tc != null)
            {
                int c2 = RunProcess(new[] { "-y", "-i", tmp1, "-c", "copy", "-map", "0:v", "-map", "0:a?", "-map_metadata", "0", "-timecode", tc, tmp2 }, handle, null);
                if (handle.Cancelled) throw new ConversionCancelled();
                if (c2 == 0) current = tmp2; else rep.Problems.Add(new("report.tcFailed", tc));
            }
            progress?.Invoke(0.93);

            bool unchanged = preset.FrameRate == null && preset.ColorSpace == null;
            if (!keepMetadata) rep.Metadata = MetadataOutcome.Off;
            else if (!ext.Equals(".mov", StringComparison.OrdinalIgnoreCase)) { rep.Metadata = MetadataOutcome.NothingToCarry; rep.NotKept.Add(new("report.nativeNeedsMov", ext.TrimStart('.'))); }
            else if (!unchanged) { rep.Metadata = MetadataOutcome.NothingToCarry; rep.NotKept.Add(new("report.nativeSkipped", preset.ColorSpace != null ? "report.reasonColorRelabel" : "report.reasonFrameRate")); }
            else
            {
                try
                {
                    var g = TrackGrafter.Graft(job.SourcePath, current, interval?.Start ?? 0, interval?.Duration);
                    rep.Grafted = g.Tracks;
                    var probs = TrackGrafter.Verify(g, current);
                    if (probs.Count > 0) { rep.Metadata = MetadataOutcome.Incomplete; foreach (var pr in probs) rep.Problems.Add(new("report.graftVerify", pr)); }
                    else { rep.Metadata = g.Tracks.Count == 0 ? MetadataOutcome.NothingToCarry : MetadataOutcome.Complete; foreach (var t in g.Tracks) rep.Kept.Add(new("report.keptTrack", $"{t.FourCC} · {t.SampleCount}")); }
                }
                catch (Exception ex) when (ex is TrackGrafterException or IOException) { rep.Metadata = MetadataOutcome.Incomplete; rep.Problems.Add(new("report.graftFailed", ex.Message)); }
            }
            if (!preset.IsRewrap && preset.ColorSpace == null && profile?.Curve is { } c && IsLog(c.Value)) rep.Kept.Add(new("report.colorTagsNeutral", c.Value));
            if (rep.Problems.Count > 0 && rep.Metadata != MetadataOutcome.Off) rep.Metadata = MetadataOutcome.Incomplete;
            progress?.Invoke(0.97);

            var outS = Summarize(current);
            rep.FramesOutput = outS?.Frames; rep.AudioStreamsOutput = outS?.Audio ?? 0; rep.DurationOutput = outS?.Duration;
            rep.TimecodeOutput = tc == null ? null : ProbeTimecode(current);
            if (preset.FrameRate == null && (expectedFrames ?? rep.FramesSource) is { } a && rep.FramesOutput is { } b && a != b)
                throw new ConversionException($"Numar de cadre diferit: asteptat {a}, rezultat {b}.");
            if (rep.AudioStreamsOutput < rep.AudioStreamsSource && preset.Audio == AudioMode.Passthrough)
                throw new ConversionException($"Piste audio lipsa: sursa {rep.AudioStreamsSource}, rezultat {rep.AudioStreamsOutput}.");
            if (tc != null && rep.TimecodeOutput != tc)
            { rep.Problems.Add(new("report.tcMismatch", $"{tc} → {rep.TimecodeOutput ?? "—"}")); rep.Metadata = MetadataOutcome.Incomplete; }
            else if (tc != null) rep.Kept.Insert(0, new("report.keptTimecode", tc));

            var s1 = new FileInfo(job.SourcePath);
            if (s1.Length != size0 || s1.LastWriteTimeUtc != m0) throw new ConversionException("Originalul pare modificat in timpul conversiei.");

            if (File.Exists(dest)) File.Delete(dest);
            File.Move(current, dest);
            if (keepMetadata && writeSidecar && profile != null)
            {
                try { MetadataCoreClient.WriteSidecar(job.SourcePath, dest, rep.Kept.Select(k => k.Key + " " + k.Arg), rep.NotKept.Select(k => k.Key + " " + k.Arg)); rep.Kept.Add(new("report.keptSidecar", "")); }
                catch (Exception ex) { rep.Metadata = MetadataOutcome.Incomplete; rep.Problems.Add(new("report.sidecarFailed", ex.Message)); }
            }
            progress?.Invoke(1.0);
            return rep;
        }
        finally { foreach (var t in new[] { tmp1, tmp2 }) try { if (File.Exists(t)) File.Delete(t); } catch { } }
    }
}
