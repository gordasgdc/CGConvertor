using System.Diagnostics;
using System.IO;
using System.Net.Http;
using System.Security.Cryptography;
using System.Text.Json;
using CGConvertor.Core.Diagnostics;

namespace CGConvertor.Client;

public sealed record UpdateOffer(string Version, string Url, string? Sha256, string Notes);
public sealed record UpdateResult(bool Ok, UpdateOffer? Offer, string Error);

/// <summary>
/// Actualizare Windows (Regula 20/35). Sursa: update.json, blocul `windows` {version, download_url, sha256}.
/// Se oferă doar o versiune pentru care URL-ul instalatorului Windows există (HEAD 200) — ultimul tag macOS nu contează.
/// </summary>
public static class UpdateService
{
    public static string ManifestUrl { get; set; } = Environment.GetEnvironmentVariable("CGC_UPDATE_URL") ?? "https://gordasgdc.github.io/CGConvertor/update.json";
    static readonly HttpClient Http = new() { Timeout = TimeSpan.FromSeconds(20) };

    static Version? Parse(string? v) => Version.TryParse(v, out var r) ? r : null;

    public static async Task<UpdateResult> CheckAsync(string current)
    {
        try
        {
            using var req = new HttpRequestMessage(HttpMethod.Get, ManifestUrl);
            req.Headers.UserAgent.ParseAdd("CGConvertor-Windows");
            using var resp = await Http.SendAsync(req);
            resp.EnsureSuccessStatusCode();
            using var doc = JsonDocument.Parse(await resp.Content.ReadAsStringAsync());
            var root = doc.RootElement;
            if (!root.TryGetProperty("windows", out var w)) return new(true, null, "");
            var ver = w.TryGetProperty("version", out var vv) ? vv.GetString() : null;
            var url = w.TryGetProperty("download_url", out var uu) ? uu.GetString() : null;
            if (Parse(ver) is not { } nv || Parse(current) is not { } cv || url is null) return new(true, null, "");
            if (nv <= cv) return new(true, null, "");
            using var head = new HttpRequestMessage(HttpMethod.Head, url);
            using var hr = await Http.SendAsync(head);
            if (!hr.IsSuccessStatusCode) { StructuredLog.Shared.Log(LogLevel.Warning, "update", "update.assetMissing", $"{(int)hr.StatusCode}"); return new(true, null, ""); }
            var sha = w.TryGetProperty("sha256", out var ss) ? ss.GetString() : null;
            var notes = root.TryGetProperty("changes", out var ch) ? ch.GetString() ?? "" : "";
            return new(true, new UpdateOffer(ver!, url, sha, notes), "");
        }
        catch (Exception ex)
        {
            StructuredLog.Shared.Log(LogLevel.Warning, "update", "update.checkFailed", ex.Message);
            return new(false, null, ex.Message);
        }
    }

    /// <summary>Descarcă, verifică suma SHA-256 (dacă e publicată), pornește instalatorul cu UAC. Intoarce true dacă aplicația trebuie să se închidă.</summary>
    public static async Task<bool> DownloadAndInstallAsync(UpdateOffer o, IProgress<double> progress)
    {
        var dir = Path.Combine(Path.GetTempPath(), "cgconvertor-update-" + Guid.NewGuid().ToString("N")[..8]); Directory.CreateDirectory(dir);
        var file = Path.Combine(dir, $"CGConvertor-Setup-{o.Version}.exe");
        using var resp = await Http.SendAsync(new HttpRequestMessage(HttpMethod.Get, o.Url), HttpCompletionOption.ResponseHeadersRead);
        resp.EnsureSuccessStatusCode();
        var total = resp.Content.Headers.ContentLength ?? 0;
        using (var src = await resp.Content.ReadAsStreamAsync())
        using (var dst = File.Create(file))
        {
            var buf = new byte[1 << 20]; long done = 0; int n;
            while ((n = await src.ReadAsync(buf)) > 0) { await dst.WriteAsync(buf.AsMemory(0, n)); done += n; if (total > 0) progress.Report(done * 100.0 / total); }
        }
        if (!string.IsNullOrEmpty(o.Sha256))
        {
            using var fs = File.OpenRead(file);
            var got = Convert.ToHexString(await SHA256.HashDataAsync(fs));
            if (!got.Equals(o.Sha256, StringComparison.OrdinalIgnoreCase)) { File.Delete(file); throw new InvalidDataException("SHA-256 nu se potrivește"); }
        }
        // Integritate: versiunea din fișierul descărcat trebuie să fie cea oferită (prinde un asset greșit, ex. build vechi sub nume nou).
        var fv = FileVersionInfo.GetVersionInfo(file).FileVersion ?? "";
        if (!(Version.TryParse(fv, out var fileVer) && Version.TryParse(o.Version, out var want) && fileVer.Major == want.Major && fileVer.Minor == want.Minor && fileVer.Build == want.Build))
        { File.Delete(file); throw new InvalidDataException($"versiune în fișier {fv}, oferită {o.Version}"); }
        StructuredLog.Shared.Log(LogLevel.Info, "update", "update.install", o.Version);
        Process.Start(new ProcessStartInfo(file) { UseShellExecute = true, Verb = "runas" });
        return true;
    }
}
