using System.IO;
using System.Text.Json;
using Wpf.Ui.Appearance;
using CGConvertor.Core;

namespace CGConvertor.Client;

public enum AppTheme { System, Light, Dark }

public static class ThemeSettings
{
    static string FilePath => Path.Combine(AppPaths.Roaming, "theme.json");
    public static AppTheme Current { get; private set; } = AppTheme.System;

    public static void ApplySaved()
    {
        try { if (File.Exists(FilePath)) Current = JsonSerializer.Deserialize<AppTheme>(File.ReadAllText(FilePath)); } catch { }
        Apply(Current, false);
    }

    public static void Apply(AppTheme t, bool persist = true)
    {
        Current = t;
        var eff = t switch
        {
            AppTheme.Light => ApplicationTheme.Light,
            AppTheme.Dark => ApplicationTheme.Dark,
            _ => SystemThemeManager.GetCachedSystemTheme() == SystemTheme.Light ? ApplicationTheme.Light : ApplicationTheme.Dark,
        };
        ApplicationThemeManager.Apply(eff);
        // Tokenii proprii ai aplicației (Theme.Dark/Light.xaml) înlocuiesc setul curent; pensulele se actualizează dinamic.
        var md = System.Windows.Application.Current.Resources.MergedDictionaries;
        for (int i = 0; i < md.Count; i++)
            if (md[i].Source?.OriginalString.Contains("Styles/Theme.", StringComparison.OrdinalIgnoreCase) == true && !md[i].Source!.OriginalString.Contains("Aliases"))
            { md[i] = new System.Windows.ResourceDictionary { Source = new Uri(eff == ApplicationTheme.Light ? "Styles/Theme.Light.xaml" : "Styles/Theme.Dark.xaml", UriKind.Relative) }; break; }
        if (!persist) return;
        try { Directory.CreateDirectory(AppPaths.Roaming); File.WriteAllText(FilePath, JsonSerializer.Serialize(t)); } catch { }
    }
}
