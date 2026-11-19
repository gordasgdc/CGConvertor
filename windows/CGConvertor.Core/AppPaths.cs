namespace CGConvertor.Core;

/// <summary>Căi de date ale aplicației. CGC_ISOLATED_HOME mută TOTUL (setări, licență, loguri) într-un folder de test.</summary>
public static class AppPaths
{
    static string? Iso => Environment.GetEnvironmentVariable("CGC_ISOLATED_HOME") is { Length: > 0 } s ? s : null;
    public static bool IsIsolated => Iso != null;
    public static string Home => Iso ?? Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
    public static string Roaming => Iso is { } i ? Path.Combine(i, "AppData", "Roaming", "CGConvertor") : Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "CGConvertor");
    public static string Logs => Iso is { } i ? Path.Combine(i, "AppData", "Local", "GDC", "CGConvertor", "Logs") : Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "GDC", "CGConvertor", "Logs");
}
