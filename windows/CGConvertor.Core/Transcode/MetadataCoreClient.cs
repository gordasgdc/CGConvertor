using System.Diagnostics;
using System.Text.Json;
using System.Text.Json.Nodes;

namespace CGConvertor.Core.Transcode;

public sealed record MdField(string Section, string Id, string Value, string Kind, string Source);

public sealed class SourceProfile
{
    public List<MdField> All { get; } = new();
    public string? CameraModel, Lens, FocalLength, Aperture, Iso, Shutter, WhiteBalance, Timecode, FrameRate, PartialReason;
    public (string Value, string Kind, string Source)? Curve, Gamut;
    public bool HasAnything => CameraModel != null || Curve != null || Gamut != null || Timecode != null;
}

/// <summary>Subproces gdc-metadata-core (contract NDJSON identic cu Mac).</summary>
public static class MetadataCoreClient
{
    public static string? BinaryPath { get; set; } =
        new[] { Path.Combine(AppContext.BaseDirectory, "gdc-metadata-core.exe"), Path.Combine(AppContext.BaseDirectory, "tools", "gdc-metadata-core.exe") }.FirstOrDefault(File.Exists);

    public static SourceProfile? Scan(string path, int timeoutSeconds = 60)
    {
        if (BinaryPath is null) return null;
        var psi = new ProcessStartInfo(BinaryPath) { StandardOutputEncoding = System.Text.Encoding.UTF8, StandardErrorEncoding = System.Text.Encoding.UTF8, RedirectStandardOutput = true, RedirectStandardError = true, UseShellExecute = false, CreateNoWindow = true };
        psi.ArgumentList.Add("scan"); psi.ArgumentList.Add(path);
        try
        {
            using var proc = Process.Start(psi)!;
            var err = proc.StandardError.ReadToEndAsync();
            var outTask = proc.StandardOutput.ReadToEndAsync();
            if (!proc.WaitForExit(timeoutSeconds * 1000)) { try { proc.Kill(true); } catch { } return null; }
            return Parse(outTask.Result);
        }
        catch { return null; }
    }

    public static SourceProfile? Parse(string ndjson)
    {
        foreach (var line in ndjson.Split('\n', StringSplitOptions.RemoveEmptyEntries))
        {
            try
            {
                using var doc = JsonDocument.Parse(line);
                if (!doc.RootElement.TryGetProperty("clip", out var clip) || !clip.TryGetProperty("fields", out var fields)) continue;
                JsonElement? Find(string id) { foreach (var f in fields.EnumerateArray()) if (f.TryGetProperty("id", out var i) && i.GetString() == id) return f.Clone(); return null; }
                string? Val(string id)
                {
                    var f = Find(id); if (f is null) return null;
                    if (f.Value.TryGetProperty("status", out var st) && st.GetString() == "unavailable") return null;
                    return f.Value.TryGetProperty("value", out var v) && v.ValueKind == JsonValueKind.String && v.GetString() is { Length: > 0 } s ? s : null;
                }
                (string, string, string)? Det(string id)
                {
                    var v = Val(id); if (v is null) return null; var f = Find(id)!.Value;
                    string kind = "declared", src = "";
                    if (f.TryGetProperty("primary", out var pr)) { kind = pr.TryGetProperty("kind", out var k) ? k.GetString() ?? kind : kind; src = pr.TryGetProperty("source", out var s) ? s.GetString() ?? "" : ""; }
                    return (v, kind, src);
                }
                var prof = new SourceProfile
                {
                    CameraModel = Val("camera_model"), Lens = Val("lens"), FocalLength = Val("focal_length"), Aperture = Val("aperture"),
                    Iso = Val("iso"), Shutter = Val("shutter"), WhiteBalance = Val("wb_temp") ?? Val("wb_mode"),
                    Curve = Det("curve"), Gamut = Det("gamut"), Timecode = Val("timecode"), FrameRate = Val("frame_rate"),
                };
                foreach (var f in fields.EnumerateArray())
                {
                    var id = f.TryGetProperty("id", out var i0) ? i0.GetString() ?? "" : "";
                    if (id.Length == 0 || Val(id) is not { } v0) continue;
                    var sec = f.TryGetProperty("section", out var s0) ? s0.GetString() ?? "file" : "file";
                    string kind = "", src = "";
                    if (f.TryGetProperty("primary", out var pr0) && pr0.ValueKind == JsonValueKind.Object)
                    { kind = pr0.TryGetProperty("kind", out var k0) ? k0.GetString() ?? "" : ""; src = pr0.TryGetProperty("source", out var so0) ? so0.GetString() ?? "" : ""; }
                    prof.All.Add(new MdField(sec, id, v0, kind, src));
                }
                if (clip.TryGetProperty("ok", out var ok) && ok.ValueKind == JsonValueKind.False)
                    prof.PartialReason = clip.TryGetProperty("error", out var e) ? e.GetString() : null;
                return prof;
            }
            catch (JsonException) { }
        }
        return null;
    }

    static JsonNode? Sorted(JsonNode? n) => n switch
    {
        JsonObject o => new JsonObject(o.OrderBy(kv => kv.Key, StringComparer.Ordinal).Select(kv => KeyValuePair.Create(kv.Key, Sorted(kv.Value?.DeepClone())))),
        JsonArray a => new JsonArray(a.Select(x => Sorted(x?.DeepClone())).ToArray()),
        _ => n?.DeepClone(),
    };

    /// <summary>Scrie `&lt;rezultat&gt;.gdc-metadata.json` (schema gdc-metadata/1): fișa clipului SURSĂ atribuită rezultatului, cu `converted` (port al MetadataCore.writeSidecar).</summary>
    public static string WriteSidecar(string source, string output, IEnumerable<string> kept, IEnumerable<string> notKept)
    {
        if (BinaryPath is null) throw new IOException("nucleul de metadate lipsește");
        var tmp = Path.Combine(Path.GetTempPath(), "cgc-sidecar-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(tmp);
        try
        {
            var psi = new ProcessStartInfo(BinaryPath) { UseShellExecute = false, CreateNoWindow = true, RedirectStandardOutput = true, RedirectStandardError = true };
            psi.ArgumentList.Add("export"); psi.ArgumentList.Add(source); psi.ArgumentList.Add("--out-dir"); psi.ArgumentList.Add(tmp);
            using (var p = Process.Start(psi)!) { var e = p.StandardError.ReadToEndAsync(); p.StandardOutput.ReadToEnd(); if (!p.WaitForExit(60000)) { try { p.Kill(true); } catch { } } }
            var f = Directory.GetFiles(tmp, "*.gdc-metadata.json").FirstOrDefault() ?? throw new IOException("sidecar-ul nucleului nu a putut fi citit");
            var json = JsonNode.Parse(File.ReadAllText(f)) as JsonObject ?? throw new IOException("sidecar invalid");
            var oldSource = json["source"]?.DeepClone() ?? throw new IOException("sidecar fără source");
            var fi = new FileInfo(output);
            long mtimeNs = (fi.LastWriteTimeUtc - DateTime.UnixEpoch).Ticks * 100;
            json["source"] = new JsonObject { ["dir"] = fi.DirectoryName, ["name"] = fi.Name, ["size"] = fi.Length, ["mtime_ns"] = mtimeNs.ToString() };
            json["converted"] = new JsonObject
            {
                ["by"] = "CG Convertor", ["origin"] = oldSource, ["origin_path"] = source,
                ["kept"] = new JsonArray(kept.Select(k => (JsonNode?)k).ToArray()), ["not_kept"] = new JsonArray(notKept.Select(k => (JsonNode?)k).ToArray()),
                ["note"] = "Valorile descriu captura originala; nu sunt re-masurate pe imaginea rezultata.",
            };
            var dest = output + ".gdc-metadata.json";
            File.WriteAllText(dest, Sorted(json)!.ToJsonString(new JsonSerializerOptions { WriteIndented = true }));
            return dest;
        }
        finally { try { Directory.Delete(tmp, true); } catch { } }
    }
}
