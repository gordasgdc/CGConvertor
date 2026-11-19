using System.Diagnostics;
using System.IO;
using System.Windows.Media.Imaging;
using Microsoft.Win32;
using CGConvertor.Core.Transcode;

namespace CGConvertor.Client;

public static class Helpers
{
    public static readonly string[] VideoExt = { ".mov", ".mp4", ".mxf", ".mkv", ".avi", ".m4v", ".mts", ".m2ts", ".braw", ".r3d", ".ari", ".dng", ".wav" };
    public static readonly Lazy<TranscodeEngine?> Engine = new(() => TranscodeEngine.Locate());

    public static string[] PickFiles(string filter = "Video|*.mov;*.mp4;*.mxf;*.mkv;*.avi;*.m4v;*.mts;*.m2ts|*.*|*.*")
    {
        var d = new OpenFileDialog { Multiselect = true, Filter = filter, CheckFileExists = true };
        return d.ShowDialog() == true ? d.FileNames : Array.Empty<string>();
    }

    public static string? PickFolder()
    {
        var d = new OpenFolderDialog { Multiselect = false };
        return d.ShowDialog() == true ? d.FolderName : null;
    }

    public static IEnumerable<string> ExpandVideo(IEnumerable<string> paths)
    {
        foreach (var p in paths)
        {
            if (Directory.Exists(p))
                foreach (var f in Directory.EnumerateFiles(p, "*", SearchOption.AllDirectories).Where(f => VideoExt.Contains(Path.GetExtension(f).ToLowerInvariant())).OrderBy(f => f, StringComparer.OrdinalIgnoreCase))
                    yield return f;
            else if (File.Exists(p)) yield return p;
        }
    }

    public static BitmapImage? Image(byte[]? bytes)
    {
        if (bytes == null) return null;
        var bi = new BitmapImage();
        using var ms = new MemoryStream(bytes);
        bi.BeginInit(); bi.CacheOption = BitmapCacheOption.OnLoad; bi.StreamSource = ms; bi.EndInit(); bi.Freeze();
        return bi;
    }

    public static void Reveal(string path)
    {
        try { Process.Start(new ProcessStartInfo("explorer.exe", File.Exists(path) ? $"/select,\"{path}\"" : $"\"{path}\"") { UseShellExecute = true }); } catch { }
    }

    public static void OpenFile(string path) { try { Process.Start(new ProcessStartInfo(path) { UseShellExecute = true }); } catch { } }

    public static string UniquePath(string path)
    {
        if (!File.Exists(path)) return path;
        var dir = Path.GetDirectoryName(path)!; var n = Path.GetFileNameWithoutExtension(path); var e = Path.GetExtension(path);
        for (int i = 2; ; i++) { var c = Path.Combine(dir, $"{n} ({i}){e}"); if (!File.Exists(c)) return c; }
    }

    public static string Bytes(long b) => b >= 1L << 30 ? $"{b / (double)(1L << 30):0.0} GB" : b >= 1L << 20 ? $"{b / (double)(1L << 20):0.0} MB" : $"{b / 1024.0:0} KB";
}
