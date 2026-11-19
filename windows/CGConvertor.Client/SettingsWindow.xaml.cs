using System.IO;
using System.Windows;
using System.Windows.Controls;
using CGConvertor.Core;
using CGConvertor.Core.Diagnostics;
using CGConvertor.Core.Licensing;

namespace CGConvertor.Client;

public partial class SettingsWindow
{
    UpdateOffer? _offer; bool _init;
    void OnCloseClick(object s, System.Windows.RoutedEventArgs e) => Close();
    public SettingsWindow()
    {
        InitializeComponent(); Bar.Title = Loc.T("settings");
        ThemeCombo.ItemsSource = new[] { Loc.T("st.system"), Loc.T("st.light"), Loc.T("st.dark") }; ThemeCombo.SelectedIndex = (int)ThemeSettings.Current;
        LangCombo.ItemsSource = new[] { "Română", "English", "Español" }; LangCombo.SelectedIndex = Loc.Instance.Language switch { "en" => 1, "es" => 2, _ => 0 };
        MachineIdBox.Text = LicenseCore.MachineIdDisplay();
        VersionLine.Text = $"CG Convertor {BuildInfo.Version}" + (AppPaths.IsIsolated ? "  ·  " + Loc.T("st.isolated") : "");
        SessionLine.Text = Loc.F("st.session", StructuredLog.Shared.SessionId);
        RefreshLicense(); _init = true;
    }

    void RefreshLicense()
    {
        var s = MainWindow.Licenses.Status();
        LicState.Text = s.State switch
        {
            LicenseState.Licensed => s.License!.Perpetual ? Loc.T("st.licensedPerm") : Loc.F("st.licensedUntil", DateTimeOffset.FromUnixTimeSeconds(s.License.ExpiresAt).ToString("yyyy-MM-dd")),
            LicenseState.Trial => Loc.F("st.trial", Math.Ceiling(s.TrialDaysLeft)),
            _ => Loc.T("st.expired"),
        };
    }

    void OnTheme(object s, SelectionChangedEventArgs e) { if (_init) ThemeSettings.Apply((AppTheme)ThemeCombo.SelectedIndex); }
    void OnLang(object s, SelectionChangedEventArgs e)
    {
        if (!_init) return;
        var l = LangCombo.SelectedIndex switch { 1 => "en", 2 => "es", _ => "ro" };
        AppSettings.Language = l; Loc.Instance.Language = l; Bar.Title = Loc.T("settings");
        ThemeCombo.ItemsSource = new[] { Loc.T("st.system"), Loc.T("st.light"), Loc.T("st.dark") }; ThemeCombo.SelectedIndex = (int)ThemeSettings.Current;
        RefreshLicense(); SessionLine.Text = Loc.F("st.session", StructuredLog.Shared.SessionId);
    }
    void OnCopyId(object s, RoutedEventArgs e) { try { Clipboard.SetText(MachineIdBox.Text); } catch { } }

    void OnActivate(object s, RoutedEventArgs e)
    {
        var r = MainWindow.Licenses.Activate(SerialBox.Text);
        ActMsg.Text = r.Valid ? Loc.T("st.activated") : CGConvertor.Core.CoreText.Tr(r.Error);
        StructuredLog.Shared.Log(r.Valid ? LogLevel.Info : LogLevel.Warning, "license", r.Valid ? "license.activated" : "license.rejected", r.Valid ? "ok" : (r.Expired ? "expired" : "invalid"));
        if (r.Valid) SerialBox.Clear();
        RefreshLicense();
    }

    async void OnUpdate(object s, RoutedEventArgs e)
    {
        UpdMsg.Text = "…"; UpdNow.Visibility = Visibility.Collapsed;
        var r = await UpdateService.CheckAsync(BuildInfo.Version);
        if (!r.Ok) UpdMsg.Text = Loc.F("st.updateFail", CGConvertor.Core.CoreText.Tr(r.Error));
        else if (r.Offer is { } o) { _offer = o; UpdMsg.Text = Loc.F("st.updateAvail", o.Version); UpdNow.Visibility = Visibility.Visible; }
        else UpdMsg.Text = Loc.F("st.upToDate", BuildInfo.Version);
    }

    async void OnUpdateNow(object s, RoutedEventArgs e)
    {
        if (_offer is null) return;
        UpdBar.Visibility = Visibility.Visible; UpdNow.IsEnabled = false;
        try
        {
            if (await UpdateService.DownloadAndInstallAsync(_offer, new Progress<double>(p => UpdBar.Value = p))) Application.Current.Shutdown();
        }
        catch (Exception ex) { UpdMsg.Text = Loc.F("st.updateFail", CGConvertor.Core.CoreText.Tr(ex.Message)); UpdNow.IsEnabled = true; UpdBar.Visibility = Visibility.Collapsed; }
    }

    void OnGuide(object s, RoutedEventArgs e)
    {
        var lang = Loc.Instance.Language;
        var name = lang switch { "en" => "Instructiuni_Utilizare_EN.pdf", "es" => "Instructiuni_Utilizare_ES.pdf", _ => "Instructiuni_Utilizare_RO.pdf" };
        var p = Path.Combine(AppContext.BaseDirectory, "guides", name);
        if (File.Exists(p)) Helpers.OpenFile(p);
    }
    void OnLogs(object s, RoutedEventArgs e) { Directory.CreateDirectory(AppPaths.Logs); Helpers.OpenFile(AppPaths.Logs); }
    void OnDiag(object s, RoutedEventArgs e)
    {
        try
        {
            var zip = new DiagnosticExporter(StructuredLog.Shared, new Dictionary<string, string>(), null, null).Export(DiagnosticExporter.DefaultFolder);
            UpdMsg.Text = Loc.F("st.diagDone", zip); Helpers.Reveal(zip);
        }
        catch (Exception ex) { UpdMsg.Text = Loc.F("err.generic", ex.Message); }
    }
}
