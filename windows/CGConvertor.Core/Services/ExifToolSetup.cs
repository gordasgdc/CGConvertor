using System.Diagnostics;
using System.IO;

namespace CGConvertor.Core.Services;

public enum ExifToolState { Available, Missing, Invalid }

public sealed record ExifToolStatus(ExifToolState State, string? Path, string? Version, string Reason)
{
    public bool IsAvailable => State == ExifToolState.Available;
}

/// ExifTool nu face parte din DataMover (se obține separat, din sursa oficială). Aici: detectare, validare a executabilului ales
/// și a fișierelor lui auxiliare, fără editarea PATH. Calea aleasă (sau găsită) ajunge la helper prin GDC_EXIFTOOL.
public static class ExifToolSetup
{
    /// Calea aleasă de utilizator (din setări); are prioritate.
    public static string? Configured { get => _configured; set { _configured = value; Refresh(); } }
    private static string? _configured;
    private static ExifToolStatus? _cache; private static string? _cacheDir; private static readonly object CacheGate = new();

    /// Uită rezultatul memorat (după ce utilizatorul a ales alt fișier sau a instalat ExifTool).
    public static void Refresh() { lock (CacheGate) _cache = null; }

    /// Ca `Detect`, dar memorat: helperul îl cere la fiecare apel și nu are voie să plătească de fiecare dată un `-ver`.
    public static ExifToolStatus DetectCached(string? helperDir = null)
    {
        lock (CacheGate)
        {
            if (_cache != null && _cacheDir == helperDir && (_cache.IsAvailable ? File.Exists(_cache.Path!) : true)) return _cache;
        }
        var s = Detect(helperDir);
        lock (CacheGate) { _cache = s; _cacheDir = helperDir; }
        return s;
    }

    /// 1) calea aleasă  2) GDC_EXIFTOOL  3) lângă helper (exiftool.exe, exiftool(-k).exe)  4) PATH (exiftool.exe).
    public static ExifToolStatus Detect(string? helperDir = null)
    {
        if (!string.IsNullOrWhiteSpace(Configured))
        {
            var s = Validate(Configured!);
            if (s.IsAvailable) return s;
            // calea aleasă nu mai e bună: spune motivul, dar mai încearcă și celelalte locuri
            var alt = Candidates(helperDir).Select(Validate).FirstOrDefault(x => x.IsAvailable);
            return alt ?? s;
        }
        var found = Candidates(helperDir).ToList();
        foreach (var c in found) { var s = Validate(c); if (s.IsAvailable) return s; }
        var firstInvalid = found.Select(Validate).FirstOrDefault();
        return firstInvalid ?? new ExifToolStatus(ExifToolState.Missing, null, null, "ExifTool nu a fost găsit.");
    }

    private static IEnumerable<string> Candidates(string? helperDir)
    {
        var env = Environment.GetEnvironmentVariable("GDC_EXIFTOOL");
        if (!string.IsNullOrWhiteSpace(env)) yield return env!;
        var dirs = new List<string>();
        if (!string.IsNullOrEmpty(helperDir)) dirs.Add(helperDir!);
        dirs.Add(AppContext.BaseDirectory);
        foreach (var d in dirs.Distinct())
            foreach (var n in new[] { "exiftool.exe", "exiftool(-k).exe" })
            { var p = System.IO.Path.Combine(d, n); if (File.Exists(p)) yield return p; }
        foreach (var d in (Environment.GetEnvironmentVariable("PATH") ?? "").Split(System.IO.Path.PathSeparator, StringSplitOptions.RemoveEmptyEntries))
        { string p; try { p = System.IO.Path.Combine(d.Trim('"'), "exiftool.exe"); } catch { continue; } if (File.Exists(p)) yield return p; }
    }

    /// Verifică executabilul: există, e .exe, are fișierele auxiliare (exiftool_files pentru pachetul oficial) și răspunde la `-ver`.
    public static ExifToolStatus Validate(string path, int timeoutSeconds = 20)
    {
        try
        {
            if (!File.Exists(path)) return new(ExifToolState.Missing, path, null, "Fișierul nu există.");
            if (!path.EndsWith(".exe", StringComparison.OrdinalIgnoreCase)) return new(ExifToolState.Invalid, path, null, "Alege fișierul exiftool.exe.");
            var dir = System.IO.Path.GetDirectoryName(path) ?? "";
            var aux = System.IO.Path.Combine(dir, "exiftool_files");
            // Pachetul oficial Windows are un .exe mic (~60 KB) care nu merge fără exiftool_files alături; versiunea Perl completă nu are nevoie.
            if (new FileInfo(path).Length < 2_000_000 && !Directory.Exists(aux))
                return new(ExifToolState.Invalid, path, null, "Lipsește folderul exiftool_files de lângă exiftool.exe (se copiază împreună).");
            var psi = new ProcessStartInfo(path) { RedirectStandardOutput = true, RedirectStandardError = true, RedirectStandardInput = true, UseShellExecute = false, CreateNoWindow = true };
            psi.ArgumentList.Add("-ver");
            using var p = Process.Start(psi);
            if (p == null) return new(ExifToolState.Invalid, path, null, "ExifTool nu a pornit.");
            try { p.StandardInput.Close(); } catch { }
            var outTask = p.StandardOutput.ReadToEndAsync();
            if (!p.WaitForExit(timeoutSeconds * 1000))
            {
                try { p.Kill(true); } catch { }
                var hint = System.IO.Path.GetFileName(path).Contains("(-k)", StringComparison.OrdinalIgnoreCase)
                    ? "Varianta «exiftool(-k).exe» așteaptă o tastă: redenumește-o în exiftool.exe." : "ExifTool nu a răspuns la timp.";
                return new(ExifToolState.Invalid, path, null, hint);
            }
            var ver = outTask.Result.Trim();
            if (p.ExitCode != 0 || ver.Length == 0 || !char.IsDigit(ver[0]))
                return new(ExifToolState.Invalid, path, null, "Fișierul ales nu răspunde ca ExifTool (verifică și folderul exiftool_files).");
            return new(ExifToolState.Available, path, ver, "ExifTool disponibil.");
        }
        catch (Exception ex) { return new(ExifToolState.Invalid, path, null, ex.Message); }
    }
}
