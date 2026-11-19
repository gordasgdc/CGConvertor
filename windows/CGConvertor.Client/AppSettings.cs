using System.IO;
using System.Text.Json;
using CGConvertor.Core;

namespace CGConvertor.Client;

/// <summary>Setări persistate (limbă, ultimele căi, opțiuni). Un singur fișier JSON în %APPDATA%\CGConvertor (sau în folderul izolat).</summary>
public static class AppSettings
{
    sealed class Data
    {
        public string Language { get; set; } = "";
        public string LastOutputDir { get; set; } = "";
        public bool KeepMetadata { get; set; } = true;
        public bool WriteSidecar { get; set; } = true;
        public string Verification { get; set; } = "XxHash64";
        public bool ExtractMetadata { get; set; } = true;
        public bool GenerateMhl { get; set; } = true;
        public string Project { get; set; } = "";
        public string Operator { get; set; } = "";
        public string PresetId { get; set; } = "builtin_prores422hq";
        public bool GridView { get; set; }
    }
    static Data _d = new();
    static string FilePath => Path.Combine(AppPaths.Roaming, "app-settings.json");

    public static void Load() { try { if (File.Exists(FilePath)) _d = JsonSerializer.Deserialize<Data>(File.ReadAllText(FilePath)) ?? new(); } catch { _d = new(); } }
    public static void Save() { try { Directory.CreateDirectory(AppPaths.Roaming); File.WriteAllText(FilePath, JsonSerializer.Serialize(_d)); } catch { } }

    public static string Language
    {
        get => _d.Language is "ro" or "en" or "es" ? _d.Language : System.Globalization.CultureInfo.CurrentUICulture.TwoLetterISOLanguageName is var c && (c == "en" || c == "es") ? c : "ro";
        set { _d.Language = value; Save(); }
    }
    public static string LastOutputDir { get => _d.LastOutputDir; set { _d.LastOutputDir = value; Save(); } }
    public static bool KeepMetadata { get => _d.KeepMetadata; set { _d.KeepMetadata = value; Save(); } }
    public static bool WriteSidecar { get => _d.WriteSidecar; set { _d.WriteSidecar = value; Save(); } }
    public static string Verification { get => _d.Verification; set { _d.Verification = value; Save(); } }
    public static bool ExtractMetadata { get => _d.ExtractMetadata; set { _d.ExtractMetadata = value; Save(); } }
    public static bool GenerateMhl { get => _d.GenerateMhl; set { _d.GenerateMhl = value; Save(); } }
    public static string Project { get => _d.Project; set { _d.Project = value; Save(); } }
    public static string Operator { get => _d.Operator; set { _d.Operator = value; Save(); } }
    public static string PresetId { get => _d.PresetId; set { _d.PresetId = value; Save(); } }
    public static bool GridView { get => _d.GridView; set { _d.GridView = value; Save(); } }
}
