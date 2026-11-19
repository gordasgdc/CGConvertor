using System.Collections.ObjectModel;
using System.ComponentModel;
using System.IO;
using System.Text;
using System.Windows;
using System.Windows.Controls;
using CGConvertor.Core.Diagnostics;
using CGConvertor.Core.Domain;
using CGConvertor.Core.Services;

namespace CGConvertor.Client;

public sealed class Endpoint
{
    public string Path { get; init; } = "";
    public string Name => System.IO.Path.GetFileName(Path.TrimEnd('\\', '/')) is { Length: > 0 } n ? n : Path;
    public DeviceKind Kind { get; init; } = DeviceKind.Folder;
    public string Line { get; init; } = "";
    public string Role { get; set; } = "";
}

public partial class OffloadView : UserControl
{
    readonly ObservableCollection<Endpoint> _src = new(), _dst = new(), _drives = new();
    readonly OffloadRunner _runner = new();
    public bool IsBusy => _runner.IsRunning;
    public event Action<IEnumerable<string>>? SendToTranscode;
    bool _ready;

    public OffloadView()
    {
        InitializeComponent();
        void Idle() { if (!PdfBtn.IsEnabled && !IsBusy) { ResultTitle.Text = Loc.T("of.readyTitle"); ResultText.Text = Loc.T("of.idle"); } }
        Idle(); Loc.Instance.LanguageChanged += Idle;
        _runner.ActivityLogged += line => Dispatcher.BeginInvoke(() =>
        {
            ActivityBox.AppendText(line + "\n");
            if (ActivityBox.LineCount > 400) ActivityBox.Text = string.Join("\n", ActivityBox.Text.Split('\n').TakeLast(300));
            ActivityBox.ScrollToEnd();
        });
        SizeChanged += (_, _) => { var v = ActualWidth < 1250 ? Visibility.Collapsed : Visibility.Visible; SendLbl.Visibility = PdfLbl.Visibility = OpenLbl.Visibility = v; };
        SourceList.ItemsSource = _src; DestList.ItemsSource = _dst; DriveList.ItemsSource = _drives;
        VerifyCombo.ItemsSource = Enum.GetValues<VerificationModel>(); VerifyCombo.SelectedItem = Enum.TryParse<VerificationModel>(AppSettings.Verification, out var vm) ? vm : VerificationModel.XxHash64;
        MhlCheck.IsChecked = AppSettings.GenerateMhl; MetaCheck.IsChecked = AppSettings.ExtractMetadata;
        ProjectBox.Text = AppSettings.Project; OperatorBox.Text = AppSettings.Operator;
        Status.Text = Loc.T("of.idle"); _ready = true; SetHub("idle");
        _runner.PropertyChanged += OnRunnerChanged;
        Loaded += (_, _) => RefreshDrives();
        Loc.Instance.LanguageChanged += () => { if (!IsBusy) Status.Text = Loc.T("of.idle"); RefreshDrives(); RelabelRoles(); SetHub(_hub); };
    }

    string _hub = "idle";
    void SetHub(string state)
    {
        _hub = state;
        var (sym, brushKey, title, sub) = state switch
        {
            "run" => (Wpf.Ui.Controls.SymbolRegular.ArrowSync24, "AccentBrush", Loc.T("of.hubRun"), ""),
            "ok" => (Wpf.Ui.Controls.SymbolRegular.CheckmarkCircle24, "StatusSuccessBrush", Loc.T("of.hubOk"), ""),
            "warn" => (Wpf.Ui.Controls.SymbolRegular.Warning24, "StatusWarningBrush", Loc.T("of.hubWarn"), ""),
            _ => (Wpf.Ui.Controls.SymbolRegular.ArrowRight24, "TextSecondaryBrush", Loc.T("of.hubIdle"), VerifyCombo.SelectedItem?.ToString() ?? ""),
        };
        HubIcon.Symbol = sym; HubIcon.Foreground = (System.Windows.Media.Brush)FindResource(brushKey);
        HubRing.BorderBrush = (System.Windows.Media.Brush)FindResource(state == "idle" ? "CardStrokeBrush" : brushKey);
        HubTitle.Text = title; HubSub.Text = sub;
    }

    void OnOpt(object s, RoutedEventArgs e)
    {
        if (!_ready) return;
        AppSettings.Verification = VerifyCombo.SelectedItem?.ToString() ?? "XxHash64"; AppSettings.GenerateMhl = MhlCheck.IsChecked == true;
        AppSettings.ExtractMetadata = MetaCheck.IsChecked == true; AppSettings.Project = ProjectBox.Text; AppSettings.Operator = OperatorBox.Text;
    }

    Endpoint Describe(string path, bool volumeHint = false)
    {
        string line = ""; var kind = DeviceKind.Folder;
        try
        {
            var cls = WindowsMediaProbe.Classify(path);
            kind = cls.Kind;
            var root = Path.GetPathRoot(Path.GetFullPath(path));
            if (root != null && new DriveInfo(root) is { IsReady: true } di) line = $"{Helpers.Bytes(di.AvailableFreeSpace)} {Loc.T("of.free")}" + (cls.Connection != null ? " · " + CGConvertor.Core.CoreText.Tr(cls.Connection) : "");
            if (CameraCardDetector.Detect(path) is { } card) line = CGConvertor.Core.CoreText.Tr(card.Summary) + (line.Length > 0 ? " · " + line : "");
        }
        catch { }
        return new Endpoint { Path = path, Kind = kind, Line = line };
    }

    void RefreshDrives()
    {
        _drives.Clear();
        foreach (var d in DriveInfo.GetDrives().Where(d => d.IsReady && d.DriveType is DriveType.Removable or DriveType.Fixed or DriveType.Network))
            _drives.Add(Describe(d.RootDirectory.FullName));
    }

    void AddTo(ObservableCollection<Endpoint> col, string path) { if (!col.Any(e => string.Equals(e.Path, path, StringComparison.OrdinalIgnoreCase))) { col.Add(Describe(path)); RelabelRoles(); } }
    void OnAddSource(object s, RoutedEventArgs e) { if (Helpers.PickFolder() is { } f) AddTo(_src, f); }
    void OnAddDest(object s, RoutedEventArgs e) { if (Helpers.PickFolder() is { } f) AddTo(_dst, f); }
    void OnRemoveEndpoint(object s, RoutedEventArgs e)
    {
        if (IsBusy || ((FrameworkElement)s).Tag is not Endpoint x) return;
        if (!_src.Remove(x)) _dst.Remove(x);
        RelabelRoles();
    }
    void RelabelRoles()
    {
        for (int i = 0; i < _src.Count; i++) _src[i].Role = Loc.F("of.roleSource", i + 1);
        for (int i = 0; i < _dst.Count; i++) _dst[i].Role = Loc.F("of.roleCopy", i + 1);
        SourceList.Items.Refresh(); DestList.Items.Refresh();
    }
    void OnDriveAsSource(object s, RoutedEventArgs e) { if (((FrameworkElement)s).Tag is Endpoint d) AddTo(_src, d.Path); }
    void OnDriveAsDest(object s, RoutedEventArgs e) { if (((FrameworkElement)s).Tag is Endpoint d) AddTo(_dst, d.Path); }
    void OnDriveClick(object s, System.Windows.Input.MouseButtonEventArgs e) { }
    void OnFolderName(object s, TextChangedEventArgs e)
    {
        if (FolderPreview == null) return;
        string Clean(string t) => string.Concat(t.Trim().Select(ch => Path.GetInvalidFileNameChars().Contains(ch) ? '_' : ch)).Replace(' ', '_');
        var parts = new[] { DateTime.Now.ToString("yyyy-MM-dd"), Clean(ProjectBox.Text), Clean(CardBox.Text) }.Where(p => p.Length > 0);
        FolderPreview.Text = string.Join("_", parts);
    }
    void OnDropSource(object s, DragEventArgs e) { if (e.Data.GetData(DataFormats.FileDrop) is string[] a) foreach (var p in a) if (Directory.Exists(p) || File.Exists(p)) AddTo(_src, p); }
    void OnDropDest(object s, DragEventArgs e) { if (e.Data.GetData(DataFormats.FileDrop) is string[] a) foreach (var p in a) if (Directory.Exists(p)) AddTo(_dst, p); }

    void OnStart(object s, RoutedEventArgs e)
    {
        if (IsBusy) return;
        if (_src.Count == 0 || _dst.Count == 0) { Status.Text = Loc.T("of.needSrcDst"); return; }
        if (!MainWindow.RequireUnlocked()) return;
        var meta = new ProductionMeta { Project = ProjectBox.Text, Card = CardBox.Text, Camera = CameraBox.Text, OperatorName = OperatorBox.Text, Client = ClientBox.Text, Notes = NotesBox.Text };
        ResultText.Text = ""; ResultTitle.Text = ""; PdfBtn.IsEnabled = OpenBtn.IsEnabled = SendBtn.IsEnabled = false;
        var model = (VerificationModel)VerifyCombo.SelectedItem;
        ActivityBox.Clear();
        StructuredLog.Shared.Log(LogLevel.Info, "offload", "offload.start", $"{_src.Count} surse, {_dst.Count} destinații");
        _runner.Start(_src.Select(x => x.Path).ToList(), _dst.Select(x => x.Path).ToList(), model, new List<string>(), false, meta,
            generateMhl: MhlCheck.IsChecked == true, appVersion: BuildInfo.Version, extractMetadata: MetaCheck.IsChecked == true);
    }

    void OnPause(object s, RoutedEventArgs e) => _runner.TogglePause();
    void OnCancel(object s, RoutedEventArgs e) => CancelRun();
    public void CancelRun() { if (_runner.IsRunning) _runner.Cancel(); }

    void OnRunnerChanged(object? s, PropertyChangedEventArgs e) => Dispatcher.BeginInvoke(() =>
    {
        bool run = _runner.IsRunning;
        StartBtn.IsEnabled = !run; CancelBtn.IsEnabled = run; PauseBtn.IsEnabled = run; Bar.Visibility = run ? Visibility.Visible : Visibility.Collapsed;
        if (run) SetHub("run");
        PauseBtn.Content = Loc.T(_runner.IsPaused ? "resume" : "pause");
        Bar.Value = _runner.ProgressPercent;
        if (run) { Status.Text = Loc.F("of.files", _runner.FilesDone, _runner.TotalUnits) + $" · {_runner.ProgressPercent}%"; Detail.Text = _runner.SpeedText + (string.IsNullOrEmpty(_runner.MemoryUsedText) ? "" : " · " + _runner.MemoryUsedText); }
        else if (e.PropertyName == nameof(OffloadRunner.IsRunning)) ShowResult();
    });

    void ShowResult()
    {
        var res = _runner.LastResults;
        if (res.Count == 0) { Status.Text = CGConvertor.Core.CoreText.Tr(_runner.StatusText); return; }
        var sb = new StringBuilder();
        foreach (var r in res) sb.AppendLine(Loc.F("of.destLine", r.DestRoot, r.OkCount, r.SkipCount, r.FailCount) + (r.Cancelled ? " — " + Loc.T("st.cancelled") : ""));
        if (_runner.MetadataSummary is { } m) { sb.AppendLine(Loc.F("of.metaSummary", m.Found, m.Partial, m.Failed));
            if (!CGConvertor.Core.Services.ExifToolSetup.DetectCached(AppContext.BaseDirectory + "tools").IsAvailable) sb.AppendLine(Loc.T("of.metaNoExif")); }
        ResultText.Text = sb.ToString();
        bool allOk = res.All(r => r.FailCount == 0 && !r.Cancelled);
        Status.Text = Loc.T(allOk ? "st.done" : "st.doneWarn"); ResultTitle.Text = Loc.T(allOk ? "of.resultOk" : "of.resultWarn"); SetHub(allOk ? "ok" : "warn");
        PdfBtn.IsEnabled = res.Any(r => r.PdfPath != null); OpenBtn.IsEnabled = true; SendBtn.IsEnabled = VerifiedVideo().Any();
        StructuredLog.Shared.Log(allOk ? LogLevel.Info : LogLevel.Warning, "offload", "offload.finish", allOk ? "verificat" : "cu probleme");
    }

    /// <summary>Numai fișierele cu verdict OK (sumă de control confirmată) de pe prima destinație cu rezultat complet.</summary>
    IEnumerable<string> VerifiedVideo()
    {
        foreach (var ctx in _runner.Contexts.Take(1))
        {
            var rows = ctx.BuildReport(ctx.OkCount + ctx.SkipCount + ctx.FailCount).Rows;
            foreach (var r in rows.Where(r => (r.Status.StartsWith("OK") || r.Status == "SARIT") && r.DestPath.Length > 0 && Helpers.VideoExt.Contains(Path.GetExtension(r.DestPath).ToLowerInvariant()) && File.Exists(r.DestPath)))
                yield return r.DestPath;
        }
    }

    void OnSend(object s, RoutedEventArgs e)
    {
        var files = VerifiedVideo().ToList();
        if (files.Count == 0) { Status.Text = Loc.T("of.nothingToSend"); return; }
        Status.Text = Loc.F("of.sent", files.Count); SendToTranscode?.Invoke(files);
    }

    void OnPdf(object s, RoutedEventArgs e) { if (_runner.LastResults.FirstOrDefault(r => r.PdfPath != null)?.PdfPath is { } p) Helpers.OpenFile(p); }
    void OnOpenDest(object s, RoutedEventArgs e) { if (_runner.LastResults.FirstOrDefault() is { } r) Helpers.Reveal(r.DestRoot); }
}
