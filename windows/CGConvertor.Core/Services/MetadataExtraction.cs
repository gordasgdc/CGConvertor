using System.Diagnostics;
using System.Text;
using System.Text.Json;
using CGConvertor.Core.Models;

namespace CGConvertor.Core.Services;

// Extragerea metadatelor (GDC Metadata) — port al contractului din macOS (`MetadataExtraction.swift`):
//  • extracția rulează DOAR din copii confirmate; sursa nu e atinsă;
//  • clip + fișiere asociate = UNITATE, citită o singură dată dintr-o copie în care toată unitatea e confirmată;
//  • `<clip>.gdc-metadata.json` se scrie lângă FIECARE copie confirmată;
//  • verdictul extracției nu influențează niciodată verdictul copiei;
//  • fișierele generate nu intră în MHL; un fișier străin cu același nume nu se suprascrie.

public enum MetadataVerdict { Found, Partial, NoMetadata, Failed, NotVerified }

public sealed record MetadataField(string Id, string? Value, string Status, string? Source, string? Kind);

public sealed class MetadataClipResult
{
    public string RelPath { get; set; } = "";
    public MetadataVerdict Verdict { get; set; } = MetadataVerdict.Failed;
    public string? Error { get; set; }
    public List<string> Readers { get; set; } = new();
    public List<MetadataField> Fields { get; set; } = new();
    /// destRoot → written · refused_foreign · error
    public Dictionary<string, string> Sidecars { get; } = new();
    public List<string> CopiesVerified { get; set; } = new();
}

public sealed class MetadataSummary
{
    public int Found, Partial, NoMetadata, Failed, NotVerified, RefusedForeign, KeptCopied, SidecarErrors;
    public List<string> ExcludedFromCsv { get; } = new();
    public Dictionary<string, string> CsvFiles { get; } = new();
    public Dictionary<string, string> ReportFiles { get; } = new();
    public string? HelperError;
    public bool ExiftoolMissing;
    public int Total => Found + Partial + NoMetadata + Failed + NotVerified;
    public bool NeedsAttention => Partial + Failed + NotVerified + RefusedForeign + KeptCopied + SidecarErrors > 0 || HelperError != null;

    public static MetadataVerdict ParseVerdict(string? v) => v switch
    {
        "found" => MetadataVerdict.Found,
        "partial" => MetadataVerdict.Partial,
        "no_metadata" => MetadataVerdict.NoMetadata,
        _ => MetadataVerdict.Failed,
    };
}

public static class MetadataUnits
{
    public static readonly HashSet<string> ClipExtensions = new(StringComparer.OrdinalIgnoreCase)
        { ".mov", ".mp4", ".m4v", ".mxf", ".braw", ".r3d", ".crm", ".mts", ".m2ts", ".avi", ".mkv", ".ari", ".mpg", ".mpeg", ".dng" };

    public static bool IsClip(string relPath)
    {
        var name = Path.GetFileName(relPath);
        return !name.StartsWith('.') && ClipExtensions.Contains(Path.GetExtension(name));
    }

    /// clip (RelPath) → RelPath-urile unității. Identitatea e calea relativă: două `C0001.mov` din foldere
    /// diferite rămân distincte. Asociat = aceeași denumire cu altă extensie care NU e clip, sau `<denumire>M01.xml`.
    public static Dictionary<string, List<string>> Units(IEnumerable<string> relPaths)
    {
        var all = relPaths.ToList();
        var byDir = all.GroupBy(p => Path.GetDirectoryName(p) ?? "", StringComparer.OrdinalIgnoreCase)
                       .ToDictionary(g => g.Key, g => g.ToList(), StringComparer.OrdinalIgnoreCase);
        var map = new Dictionary<string, List<string>>();
        foreach (var p in all.Where(IsClip))
        {
            var stem = Path.GetFileNameWithoutExtension(p);
            var members = new List<string> { p };
            foreach (var q in byDir[Path.GetDirectoryName(p) ?? ""])
            {
                if (q == p) continue;
                var name = Path.GetFileName(q);
                if (name.StartsWith('.')) continue;
                var qStem = Path.GetFileNameWithoutExtension(name);
                var ext = Path.GetExtension(name);
                bool sameStem = qStem.Equals(stem, StringComparison.OrdinalIgnoreCase) && !ClipExtensions.Contains(ext);
                bool sony = qStem.Equals(stem + "M01", StringComparison.OrdinalIgnoreCase) && ext.Equals(".xml", StringComparison.OrdinalIgnoreCase);
                if (sameStem || sony) members.Add(q);
            }
            map[p] = members;
        }
        return map;
    }
}

/// Helperul `gdc-metadata-core.exe` (x64), rulat ca proces separat: un crash în metadate nu oprește o copie.
public sealed class MetadataHelper
{
    public string Path { get; }
    private MetadataHelper(string path) => Path = path;
    private static readonly object Gate = new();
    private static Process? _running;

    /// 1) DM_METADATA_CORE (dezvoltare/teste) 2) `gdc-metadata-core.exe` lângă aplicație.
    public static MetadataHelper? Locate()
    {
        var env = Environment.GetEnvironmentVariable("DM_METADATA_CORE");
        if (!string.IsNullOrEmpty(env) && File.Exists(env)) return new MetadataHelper(env);
        var bundled = System.IO.Path.Combine(AppContext.BaseDirectory, "gdc-metadata-core.exe");
        return File.Exists(bundled) ? new MetadataHelper(bundled) : null;
    }

    public static void TerminateRunning()
    {
        lock (Gate) { try { _running?.Kill(true); } catch { } }
    }

    public List<JsonElement> Run(IEnumerable<string> args, int timeoutSeconds = 300)
    {
        var psi = new ProcessStartInfo(Path)
        {
            RedirectStandardOutput = true, RedirectStandardError = true, UseShellExecute = false, CreateNoWindow = true,
            StandardOutputEncoding = Encoding.UTF8, StandardErrorEncoding = Encoding.UTF8,
        };
        // ExifTool ales/găsit de DataMover (fără editarea PATH): helperul îl citește din GDC_EXIFTOOL
        var et = ExifToolSetup.DetectCached(System.IO.Path.GetDirectoryName(Path));
        if (et.IsAvailable && et.Path != null) psi.Environment["GDC_EXIFTOOL"] = et.Path;
        foreach (var a in args) psi.ArgumentList.Add(a);   // ArgumentList: diacriticele și spațiile trec intacte
        using var p = Process.Start(psi) ?? throw new IOException("helper nepornit");
        lock (Gate) _running = p;
        var errTask = p.StandardError.ReadToEndAsync();
        var outTask = p.StandardOutput.ReadToEndAsync();
        if (!p.WaitForExit(timeoutSeconds * 1000)) { try { p.Kill(true); } catch { } }
        p.WaitForExit();
        lock (Gate) _running = null;
        var lines = new List<JsonElement>();
        foreach (var l in outTask.Result.Split('\n', StringSplitOptions.RemoveEmptyEntries))
        {
            try { lines.Add(JsonDocument.Parse(l).RootElement.Clone()); } catch { }
        }
        if (lines.Count == 0 && p.ExitCode != 0)
        {
            var e = errTask.Result.Trim();
            throw new IOException(e.Length == 0 ? $"helper exit {p.ExitCode}" : e);
        }
        return lines;
    }
}

public sealed class MetadataCoordinator
{
    private readonly object _lock = new();
    private readonly MetadataHelper _helper;
    private readonly Dictionary<string, DestinationContext> _contexts;
    private readonly List<string> _order;
    private readonly Dictionary<string, List<string>> _units;
    private readonly Dictionary<string, List<string>> _memberToClips = new();
    private readonly bool _wantCsv;
    private readonly HashSet<string> _relPathSet;
    private readonly string _jobId;
    private readonly Action<string> _onLine;
    private readonly Action<string> _onProgress;
    private readonly HashSet<string> _done = new();
    private readonly Dictionary<string, HashSet<string>> _confirmedOn = new();
    private readonly Dictionary<string, HashSet<string>> _queued = new();
    private readonly Dictionary<string, MetadataClipResult> _results = new();
    private readonly System.Collections.Concurrent.BlockingCollection<Action> _queue = new();
    private readonly Thread _worker;
    private int _processed;
    private bool _cancelled;
    private bool _exiftoolMissing;

    public MetadataCoordinator(IEnumerable<string> relPaths, IReadOnlyList<DestinationContext> contexts, MetadataHelper helper,
        bool wantCsv, string jobId, Action<string> onLine, Action<string> onProgress)
    {
        _helper = helper; _wantCsv = wantCsv; _jobId = jobId; _onLine = onLine; _onProgress = onProgress;
        _contexts = contexts.ToDictionary(c => c.DestRoot);
        _order = contexts.Select(c => c.DestRoot).ToList();
        var relList = relPaths.ToList();
        _relPathSet = new HashSet<string>(relList.Select(x => x.Replace('\\', '/').ToLowerInvariant()));
        _units = MetadataUnits.Units(relList);
        foreach (var (clip, members) in _units)
            foreach (var m in members) { if (!_memberToClips.TryGetValue(m, out var l)) _memberToClips[m] = l = new(); l.Add(clip); }
        // un singur lucrător, prioritate scăzută: nu încetinește copierea
        _worker = new Thread(() => { foreach (var job in _queue.GetConsumingEnumerable()) job(); })
            { IsBackground = true, Priority = ThreadPriority.BelowNormal, Name = "dm-metadata" };
        _worker.Start();
    }

    public int ClipCount => _units.Count;

    public void Confirmed(FileEntry entry, string dest)
    {
        lock (_lock) { if (!_confirmedOn.TryGetValue(entry.RelPath, out var s)) _confirmedOn[entry.RelPath] = s = new(); s.Add(dest); }
    }

    public void EntryDone(FileEntry entry)
    {
        List<string> clips;
        lock (_lock) { _done.Add(entry.RelPath); clips = _memberToClips.TryGetValue(entry.RelPath, out var c) ? c.ToList() : new(); }
        foreach (var c in clips) Evaluate(c);
    }

    public void Cancel()
    {
        lock (_lock) _cancelled = true;
        MetadataHelper.TerminateRunning();
    }

    private void Evaluate(string clip)
    {
        List<string> fresh, eligible;
        lock (_lock)
        {
            if (_cancelled || !_units.TryGetValue(clip, out var members) || !members.All(_done.Contains)) return;
            eligible = _order.Where(d => members.All(m => _confirmedOn.TryGetValue(m, out var s) && s.Contains(d))).ToList();
            _queued.TryGetValue(clip, out var already);
            fresh = eligible.Where(d => already == null || !already.Contains(d)).ToList();
            if (fresh.Count == 0) return;
            if (already == null) _queued[clip] = already = new();
            foreach (var f in fresh) already.Add(f);
        }
        _queue.Add(() => Extract(clip, fresh, eligible));
    }

    private void Extract(string clip, List<string> targets, List<string> allVerified)
    {
        lock (_lock) { if (_cancelled) return; }
        var entry = new FileEntry("", clip, 0);
        var paths = targets.Select(t => _contexts[t].DestPath(entry)).ToList();
        var args = new List<string> { "extract", paths[0] };
        foreach (var p in paths.Skip(1)) { args.Add("--also"); args.Add(p); }
        // sidecar-ul venit cu cardul e o copie verificată (în MHL): nu se rescrie
        if (_relPathSet.Contains((clip.Replace('\\', '/') + ".gdc-metadata.json").ToLowerInvariant()))
            foreach (var p in paths) { args.Add("--keep"); args.Add(p); }
        var r = new MetadataClipResult { RelPath = clip, Verdict = MetadataVerdict.Failed, CopiesVerified = allVerified };
        try
        {
            foreach (var ev in _helper.Run(args))
            {
                var kind = ev.TryGetProperty("event", out var k) ? k.GetString() : null;
                if (kind == "clip")
                {
                    r.Verdict = MetadataSummary.ParseVerdict(Str(ev, "verdict"));
                    r.Error = Str(ev, "error");
                    if (ev.TryGetProperty("readers", out var rd) && rd.ValueKind == JsonValueKind.Array) r.Readers = rd.EnumerateArray().Select(x => x.GetString() ?? "").ToList();
                    if (ev.TryGetProperty("fields", out var fs) && fs.ValueKind == JsonValueKind.Array)
                        r.Fields = fs.EnumerateArray().Select(f => new MetadataField(Str(f, "id") ?? "", Str(f, "value"), Str(f, "status") ?? "", Str(f, "source"), Str(f, "kind"))).ToList();
                    if (Str(ev, "exiftool") == "unavailable") lock (_lock) _exiftoolMissing = true;
                }
                else if (kind == "sidecar")
                {
                    var p = Str(ev, "clip");
                    int i = paths.FindIndex(x => string.Equals(x, p, StringComparison.OrdinalIgnoreCase));
                    if (i >= 0) r.Sidecars[targets[i]] = Str(ev, "result") ?? "error";
                }
            }
        }
        catch (Exception ex) { r.Verdict = MetadataVerdict.Failed; r.Error = ex.Message; }
        int n;
        lock (_lock)
        {
            if (_results.TryGetValue(clip, out var prev)) { foreach (var kv in r.Sidecars) prev.Sidecars[kv.Key] = kv.Value; prev.CopiesVerified = allVerified; }
            else _results[clip] = r;
            n = ++_processed;
        }
        if (r.Verdict == MetadataVerdict.Failed) _onLine($"Metadate: {Path.GetFileName(clip)} — eșuat: {r.Error ?? "?"}");
        _onProgress($"{n}/{ClipCount}");
    }

    private static string? Str(JsonElement e, string name) =>
        e.TryGetProperty(name, out var v) && v.ValueKind == JsonValueKind.String ? v.GetString() : null;

    public MetadataSummary Finish()
    {
        _queue.CompleteAdding();
        _worker.Join();
        Dictionary<string, MetadataClipResult> snapshot;
        bool exMissing;
        lock (_lock)
        {
            if (!_cancelled)
                foreach (var clip in _units.Keys.Where(c => !_results.ContainsKey(c)))
                    _results[clip] = new MetadataClipResult { RelPath = clip, Verdict = MetadataVerdict.NotVerified };
            snapshot = new(_results); exMissing = _exiftoolMissing;
        }
        var s = new MetadataSummary { ExiftoolMissing = exMissing };
        foreach (var r in snapshot.Values)
        {
            switch (r.Verdict)
            {
                case MetadataVerdict.Found: s.Found++; break;
                case MetadataVerdict.Partial: s.Partial++; break;
                case MetadataVerdict.NoMetadata: s.NoMetadata++; break;
                case MetadataVerdict.Failed: s.Failed++; break;
                case MetadataVerdict.NotVerified: s.NotVerified++; break;
            }
            s.RefusedForeign += r.Sidecars.Values.Count(v => v == "refused_foreign");
            s.KeptCopied += r.Sidecars.Values.Count(v => v == "kept_copied");
            s.SidecarErrors += r.Sidecars.Values.Count(v => v == "error");
        }
        foreach (var dest in _order) WriteReports(dest, snapshot, s);
        return s;
    }

    private static string VerdictName(MetadataVerdict v) => v switch
    {
        MetadataVerdict.Found => "found", MetadataVerdict.Partial => "partial", MetadataVerdict.NoMetadata => "noMetadata",
        MetadataVerdict.Failed => "failed", _ => "notVerified",
    };

    private void WriteReports(string dest, Dictionary<string, MetadataClipResult> results, MetadataSummary s)
    {
        var ctx = _contexts[dest];
        var sorted = results.Values.OrderBy(r => r.RelPath, StringComparer.Ordinal).ToList();
        var rows = sorted.Select(r => new Dictionary<string, object?>
        {
            ["path"] = r.RelPath.Replace('\\', '/'), ["copyVerified"] = r.CopiesVerified.Contains(dest),
            ["extraction"] = VerdictName(r.Verdict), ["readers"] = r.Readers,
            ["sidecar"] = r.Sidecars.TryGetValue(dest, out var sc) ? sc : "none", ["error"] = r.Error,
            ["fields"] = r.Fields.Select(f => new Dictionary<string, object?> { ["id"] = f.Id, ["value"] = f.Value, ["status"] = f.Status, ["source"] = f.Source, ["kind"] = f.Kind }).ToList(),
        }).ToList();
        var doc = new Dictionary<string, object?>
        {
            ["schema"] = "datamover-metadata/1", ["job"] = _jobId, ["folder"] = ctx.FolderName,
            ["note"] = "Verdictul copiei e în raportul de livrare/MHL; aici e doar extracția.", ["clips"] = rows,
        };
        var reportPath = FreeName(ctx.TargetRoot, "CGConvertor-metadata", ".json", IsOurReport);
        string? csvName = null;
        if (_wantCsv) csvName = WriteCsv(dest, ctx, sorted, s, reportPath);
        try
        {
            if (csvName != null) doc["csv"] = csvName;
            File.WriteAllText(reportPath, JsonSerializer.Serialize(doc, new JsonSerializerOptions { WriteIndented = true, Encoder = System.Text.Encodings.Web.JavaScriptEncoder.UnsafeRelaxedJsonEscaping }), new UTF8Encoding(false));
            s.ReportFiles[dest] = reportPath;
        }
        catch (Exception ex) { _onLine($"Metadate: raportul nu s-a putut scrie la {dest}: {ex.Message}"); }
    }

    /// CSV-ul se înlocuiește doar dacă raportul propriu îl declară (reluare); altfel nume liber, nimic străin suprascris.
    private string? WriteCsv(string dest, DestinationContext ctx, List<MetadataClipResult> sorted, MetadataSummary s, string reportPath)
    {
        var csvClips = sorted.Where(r => (r.Verdict == MetadataVerdict.Found || r.Verdict == MetadataVerdict.Partial) && r.CopiesVerified.Contains(dest)).ToList();
        if (csvClips.Count == 0) return null;
        var outPath = FreeName(ctx.TargetRoot, "GDC-Metadata-Resolve", ".csv", null);
        try
        {
            if (File.Exists(reportPath))
            {
                using var d = JsonDocument.Parse(File.ReadAllText(reportPath));
                if (d.RootElement.TryGetProperty("schema", out var sc) && (sc.GetString() ?? "").StartsWith("datamover-metadata/")
                    && d.RootElement.TryGetProperty("csv", out var cv) && cv.ValueKind == JsonValueKind.String)
                {
                    var prev = cv.GetString() ?? "";
                    if (prev.Length > 0 && prev.IndexOfAny(new[] { '/', '\\' }) < 0) outPath = Path.Combine(ctx.TargetRoot, prev);
                }
            }
        }
        catch { }
        try
        {
            var args = new List<string> { "resolve-csv" };
            args.AddRange(csvClips.Select(r => ctx.DestPath(new FileEntry("", r.RelPath, 0))));
            args.AddRange(new[] { "--unique-only", "--out", outPath });
            var ev = _helper.Run(args).FirstOrDefault();
            s.CsvFiles[dest] = outPath;
            if (ev.ValueKind == JsonValueKind.Object && ev.TryGetProperty("excluded_ambiguous", out var ex) && ex.ValueKind == JsonValueKind.Array)
                foreach (var x in ex.EnumerateArray())
                {
                    var v = x.GetString();
                    if (v == null) continue;
                    var prefix = ctx.TargetRoot.TrimEnd('\\', '/') + Path.DirectorySeparatorChar;
                    if (v.StartsWith(prefix, StringComparison.OrdinalIgnoreCase)) v = v.Substring(prefix.Length);
                    if (!s.ExcludedFromCsv.Contains(v)) s.ExcludedFromCsv.Add(v);
                }
            return Path.GetFileName(outPath);
        }
        catch (Exception e) { _onLine($"Metadate: CSV-ul Resolve nu s-a generat la {dest}: {e.Message}"); return null; }
    }

    private static bool IsOurReport(string path)
    {
        try { using var d = JsonDocument.Parse(File.ReadAllText(path)); return d.RootElement.TryGetProperty("schema", out var sc) && (sc.GetString() ?? "").StartsWith("datamover-metadata/"); }
        catch { return false; }
    }

    /// `baza.ext`, apoi `baza-2.ext`… — nu suprascrie un fișier străin; un raport propriu se înlocuiește (reluare).
    public static string FreeName(string dir, string baseName, string ext, Func<string, bool>? ours)
    {
        for (int n = 1; ; n++)
        {
            var p = Path.Combine(dir, n == 1 ? baseName + ext : $"{baseName}-{n}{ext}");
            if (!File.Exists(p)) return p;
            if (ours != null && ours(p)) return p;
        }
    }
}
