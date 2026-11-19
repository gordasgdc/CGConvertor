using System.Windows;
using System.Windows.Controls;
using CGConvertor.Core;
using CGConvertor.Core.Licensing;

namespace CGConvertor.Client;

public partial class MainWindow
{
    public static MainWindow? Current { get; private set; }
    public static LicenseStore Licenses { get; } = new();

    public MainWindow()
    {
        Current = this;
        InitializeComponent();
        // Fereastra nu depășește zona de lucru (ecrane mici / scalare mare).
        var wa = SystemParameters.WorkArea; Width = Math.Min(Width, wa.Width); Height = Math.Min(Height, wa.Height);
        MinWidth = Math.Min(MinWidth, wa.Width); MinHeight = Math.Min(MinHeight, wa.Height);
        Loc.Instance.LanguageChanged += () => { RefreshLicenseBar(); RefreshHeader(); };
        RefreshHeader();
        RefreshLicenseBar();
        Loaded += (_, _) => { if (App.StartupPaths.Length > 0) TranscodePage.AddFiles(App.StartupPaths); };
        OffloadPage.SendToTranscode += paths => { TranscodePage.AddFiles(paths); TabTranscode.IsChecked = true; };
        Closing += (_, e) =>
        {
            if (TranscodePage.IsBusy || OffloadPage.IsBusy)
            {
                if (MessageBox.Show(Loc.T("cancel") + "?", "CG Convertor", MessageBoxButton.YesNo, MessageBoxImage.Question) != MessageBoxResult.Yes) { e.Cancel = true; return; }
                TranscodePage.CancelAll(); OffloadPage.CancelRun();
            }
        };
    }

    /// <summary>Fereastră îngustă (ex. scalare 150 %): antetul se compactează ca nicio acțiune să nu fie tăiată.</summary>
    void OnWinSize(object sender, SizeChangedEventArgs e)
    {
        bool compact = ActualWidth < 1160, tight = ActualWidth < 1020;
        VersionText.Visibility = compact ? Visibility.Collapsed : Visibility.Visible;
        ReadyPill.Visibility = tight ? Visibility.Collapsed : Visibility.Visible;
        BrandPanel.Margin = new Thickness(0, 0, compact ? 16 : 32, 0);
    }

    void OnTab(object sender, RoutedEventArgs e)
    {
        if (Pages == null) return;
        int i = int.Parse((string)((RadioButton)sender).Tag);
        TranscodePage.Visibility = i == 0 ? Visibility.Visible : Visibility.Collapsed;
        OffloadPage.Visibility = i == 1 ? Visibility.Visible : Visibility.Collapsed;
        MetadataPage.Visibility = i == 2 ? Visibility.Visible : Visibility.Collapsed;
    }

    void RefreshHeader()
    {
        VersionText.Text = "v" + BuildInfo.Version + (AppPaths.IsIsolated ? " · " + Loc.T("st.isolated") : "");
        bool ready = CGConvertor.Core.Transcode.TranscodeEngine.Locate() != null;
        ReadyText.Text = Loc.T(ready ? "hdr.ready" : "hdr.notReady");
        ReadyDot.Fill = (System.Windows.Media.Brush)FindResource(ready ? "StatusSuccessBrush" : "StatusErrorBrush");
        LangBtn.Content = Loc.Instance.Language.ToUpperInvariant();
    }

    void OnThemeToggle(object sender, RoutedEventArgs e)
    {
        ThemeSettings.Apply(ThemeSettings.Current switch { AppTheme.System => AppTheme.Light, AppTheme.Light => AppTheme.Dark, _ => AppTheme.System });
        ThemeBtn.ToolTip = Loc.T("st.theme") + ": " + Loc.T(ThemeSettings.Current switch { AppTheme.Light => "st.light", AppTheme.Dark => "st.dark", _ => "st.system" });
    }
    void OnLangToggle(object sender, RoutedEventArgs e)
    {
        AppSettings.Language = Loc.Instance.Language switch { "ro" => "en", "en" => "es", _ => "ro" };
        Loc.Instance.Language = AppSettings.Language;
    }
    void OnUpdateClick(object sender, RoutedEventArgs e) => OnSettings(sender, e);
    void OnHelp(object sender, RoutedEventArgs e) => OnSettings(sender, e);

    void OnSettings(object sender, RoutedEventArgs e) { new SettingsWindow { Owner = this }.ShowDialog(); RefreshLicenseBar(); }

    public void RefreshLicenseBar()
    {
        var s = Licenses.Status();
        switch (s.State)
        {
            case LicenseState.Licensed:
                LicenseStatusText.Text = s.License!.Perpetual ? Loc.T("st.licensedPerm") : Loc.F("st.licensedUntil", DateTimeOffset.FromUnixTimeSeconds(s.License.ExpiresAt).ToString("yyyy-MM-dd"));
                LockBar.Visibility = Visibility.Collapsed; break;
            case LicenseState.Trial:
                LicenseStatusText.Text = Loc.F("lic.trialBar", Math.Ceiling(s.TrialDaysLeft)); LockBar.Visibility = Visibility.Collapsed; break;
            default:
                LicenseStatusText.Text = Loc.T("lic.locked"); LockText.Text = Loc.T("lic.locked.msg"); LockBar.Visibility = Visibility.Visible; break;
        }
    }

    public static bool RequireUnlocked()
    {
        if (Licenses.IsUnlocked) return true;
        Current?.RefreshLicenseBar();
        MessageBox.Show(Loc.T("lic.locked.msg"), "CG Convertor", MessageBoxButton.OK, MessageBoxImage.Information);
        return false;
    }
}
