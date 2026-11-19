using System.Windows;
using CGConvertor.Core;
using CGConvertor.Core.Diagnostics;

namespace CGConvertor.Client;

public partial class App : Application
{
    /// <summary>Fișiere/foldere primite în linia de comandă („Deschide cu”, tragere pe exe).</summary>
    public static string[] StartupPaths { get; private set; } = Array.Empty<string>();

    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);
        StartupPaths = e.Args.Where(a => System.IO.File.Exists(a) || System.IO.Directory.Exists(a)).ToArray();
        AppSettings.Load();
        Loc.Instance.Language = AppSettings.Language;
        ThemeSettings.ApplySaved();
        CGConvertor.Core.Transcode.OutputPreset.Localizer = p => { var k = "preset." + p.Id; var v = Loc.T(k); return v == k ? null : v; };
        StructuredLog.Shared.AppVersion = BuildInfo.Version;
        StructuredLog.Shared.Log(LogLevel.Info, "app", "app.start", $"CG Convertor {BuildInfo.Version}" + (AppPaths.IsIsolated ? " [izolat]" : ""));
        DispatcherUnhandledException += (_, ex) =>
        {
            StructuredLog.Shared.Log(LogLevel.Error, "app", "app.crash", ex.Exception.Message);
            MessageBox.Show(ex.Exception.Message, "CG Convertor", MessageBoxButton.OK, MessageBoxImage.Error);
            ex.Handled = true;
        };
    }
}

public static class BuildInfo { public const string Version = "3.18.0"; }
