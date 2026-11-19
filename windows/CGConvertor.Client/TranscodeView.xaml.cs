using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Globalization;
using System.IO;
using System.Text;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using CGConvertor.Core.Diagnostics;
using CGConvertor.Core.Transcode;

namespace CGConvertor.Client;

public enum ClipState { Waiting, Running, Done, DoneWarn, Failed, Cancelled }

public sealed class ClipItem : INotifyPropertyChanged
{
    public event PropertyChangedEventHandler? PropertyChanged;
    void N(string n) => PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(n));
    public string Path { get; init; } = "";
    public string Name => System.IO.Path.GetFileName(Path);
    public override string ToString() => Name;   // nume accesibil (cititor de ecran / UIA), nu numele tipului
    string _info = ""; public string Info { get => _info; set { _info = value; N(nameof(Info)); } }
    ImageSource? _thumb; public ImageSource? Thumbnail { get => _thumb; set { _thumb = value; N(nameof(Thumbnail)); } }
    ClipState _state; public ClipState State { get => _state; set { _state = value; N(nameof(State)); N(nameof(StatusText)); N(nameof(StatusBrush)); N(nameof(Running)); } }
    double _progress; public double Progress { get => _progress; set { _progress = value; N(nameof(Progress)); } }
    string _error = ""; public string Error { get => _error; set { _error = value; N(nameof(StatusText)); } }
    public double? From, To;
    public ConversionReport? Report; public string? OutPath;
    public bool HasReport => Report != null;
    public void ReportChanged() { N(nameof(HasReport)); }
    public bool Running => State == ClipState.Running;
    public string StatusText => State switch
    {
        ClipState.Waiting => Loc.T("st.waiting"),
        ClipState.Running => Loc.T("st.running"),
        ClipState.Done => Loc.T("st.done"),
        ClipState.DoneWarn => Loc.T("st.doneWarn"),
        ClipState.Cancelled => Loc.T("st.cancelled"),
        _ => Loc.T("st.failed") + (Error.Length > 0 ? ": " + Error : ""),
    };
    public Brush StatusBrush => (Brush)Application.Current.FindResource(State switch
    {
        ClipState.Done => "StatusSuccessBrush", ClipState.DoneWarn => "StatusWarningBrush", ClipState.Failed => "StatusErrorBrush", _ => "TextSecondaryBrush",
    });
    public void Refresh() { N(nameof(StatusText)); N(nameof(StatusBrush)); }
}

public partial class TranscodeView : UserControl
{
    readonly ObservableCollection<ClipItem> _clips = new();
    List<OutputPreset> _presets = PresetsManager.Defaults();
    string _outDir = "";
    CancellationTokenSource? _cts; ConversionHandle? _handle;
    public bool IsBusy { get; private set; }

    public TranscodeView()
    {
        InitializeComponent();
        Clips.ItemsSource = _clips;
        _clips.CollectionChanged += (_, _) => { EmptyText.Visibility = _clips.Count == 0 ? Visibility.Visible : Visibility.Collapsed; UpdateCounts(); };
        PresetCombo.ItemsSource = _presets;
        PresetCombo.SelectedItem = _presets.FirstOrDefault(p => p.Id == AppSettings.PresetId) ?? _presets[1];
        KeepMeta.IsChecked = AppSettings.KeepMetadata; Sidecar.IsChecked = AppSettings.WriteSidecar;
        _outDir = AppSettings.LastOutputDir; UpdateOutBox();
        FillCombos(); UpdateCounts(); Loc.Instance.LanguageChanged += () => { FillCombos(); UpdateCounts(); RefreshPresetNames(); foreach (var c in _clips) c.Refresh(); UpdateOutBox(); OnPresetChanged(null, null!); };
        if (AppSettings.GridView) GridMode.IsChecked = true;
        if (Helpers.Engine.Value == null) { Summary.Text = Loc.T("tc.noEngine"); StartBtn.IsEnabled = false; }
        else DisableUnavailableProfiles();
    }

    void RefreshPresetNames()
    {
        var sel = PresetCombo.SelectedItem; PresetCombo.ItemsSource = null; PresetCombo.ItemsSource = _presets; PresetCombo.SelectedItem = sel;
    }

    void UpdateCounts()
    {
        int sel = Clips?.SelectedItems.Count ?? 0;
        CountText.Text = _clips.Count == 0 ? "" : Loc.F("tc.counts", _clips.Count, sel);
        int n = sel > 1 ? sel : _clips.Count;
        StartBtn.Content = Loc.F("tc.convert", n);
        StartBtn.IsEnabled = !IsBusy && _clips.Count > 0 && Helpers.Engine.Value != null;
        if (!IsBusy && Helpers.Engine.Value != null) Summary.Text = _clips.Count == 0 ? "" : Loc.F("tc.summary", n, Preset?.Display ?? "") + (Preset != null && CGConvertor.Core.Transcode.TranscodeEngine.MxfAudioAdjusted(Preset) ? "  ·  " + Loc.T("tc.mxfAudio") : "");
    }

    void FillCombos()
    {
        int fi = Math.Max(0, FpsCombo.SelectedIndex), ci = Math.Max(0, ColorCombo.SelectedIndex);
        FpsCombo.ItemsSource = new[] { Loc.T("tc.fpsSource"), "23.976", "24", "25", "29.97", "30", "50", "59.94", "60" }; FpsCombo.SelectedIndex = fi;
        ColorCombo.ItemsSource = new[] { Loc.T("tc.colorNone"), "Rec.709", "Rec.2020" }; ColorCombo.SelectedIndex = ci;
    }

    HashSet<string> _missing = new();
    void DisableUnavailableProfiles()
    {
        var enc = Helpers.Engine.Value!.AvailableEncoders();
        _missing = FormatRegistry.All.Where(p => !enc.Contains(FormatRegistry.EncoderName(p))).Select(p => p.Id).ToHashSet();
        if (_missing.Count > 0)
            StructuredLog.Shared.Log(LogLevel.Warning, "convert", "encoders.missing", string.Join(",", _missing));
        _presets = _presets.Where(p => p.IsRewrap || !_missing.Contains(p.ProfileId)).ToList();
        PresetCombo.ItemsSource = _presets;
        PresetCombo.SelectedItem = _presets.FirstOrDefault(p => p.Id == AppSettings.PresetId) ?? _presets.FirstOrDefault();
    }

    OutputPreset? Preset => PresetCombo.SelectedItem as OutputPreset;

    void OnPresetChanged(object? s, SelectionChangedEventArgs e)
    {
        if (Preset is not { } p) return;
        AppSettings.PresetId = p.Id; UpdateCounts();
        PresetNote.Text = p.IsRewrap ? Loc.T("tc.rewrapNote") : "";
        FpsCombo.IsEnabled = ColorCombo.IsEnabled = IntFrom.IsEnabled = IntTo.IsEnabled = !p.IsRewrap;
    }

    void UpdateOutBox() => OutBox.Text = string.IsNullOrEmpty(_outDir) ? Loc.T("tc.nextToSource") : _outDir;
    void OnPickOut(object s, RoutedEventArgs e) { if (Helpers.PickFolder() is { } f) { _outDir = f; AppSettings.LastOutputDir = f; UpdateOutBox(); } }
    void OnOpts(object s, RoutedEventArgs e) { if (!IsLoaded) return; AppSettings.KeepMetadata = KeepMeta.IsChecked == true; AppSettings.WriteSidecar = Sidecar.IsChecked == true; }

    void OnViewMode(object s, RoutedEventArgs e)
    {
        if (Clips == null) return;
        bool grid = GridMode.IsChecked == true; AppSettings.GridView = grid;
        Clips.ItemTemplate = (DataTemplate)FindResource(grid ? "GridItem" : "ListItem");
        Clips.ItemsPanel = (ItemsPanelTemplate)FindResource(grid ? "GridPanel" : "ListPanel");
        ScrollViewer.SetHorizontalScrollBarVisibility(Clips, ScrollBarVisibility.Disabled);
    }

    void OnAdd(object s, RoutedEventArgs e) => AddFiles(Helpers.PickFiles());
    void OnAddFolder(object s, RoutedEventArgs e) { if (Helpers.PickFolder() is { } f) AddFiles(new[] { f }); }
    void OnDrop(object s, DragEventArgs e) { if (e.Data.GetData(DataFormats.FileDrop) is string[] a) AddFiles(a); }
    void OnClear(object s, RoutedEventArgs e) { if (!IsBusy) _clips.Clear(); }
    void OnRemove(object s, RoutedEventArgs e) { if (IsBusy) return; foreach (var c in Clips.SelectedItems.Cast<ClipItem>().ToList()) _clips.Remove(c); }

    public void AddFiles(IEnumerable<string> paths)
    {
        var added = new List<ClipItem>();
        foreach (var f in Helpers.ExpandVideo(paths))
        {
            if (_clips.Any(c => string.Equals(c.Path, f, StringComparison.OrdinalIgnoreCase))) continue;
            var it = new ClipItem { Path = f }; _clips.Add(it); added.Add(it);
        }
        if (added.Count == 0 || Helpers.Engine.Value is not { } eng) return;
        // Informații și miniaturi, în fundal, câte unul (memorie și concurență controlate).
        _ = Task.Run(() =>
        {
            foreach (var c in added)
            {
                var info = eng.Describe(c.Path);
                var img = Helpers.Image(eng.FrameBytes(c.Path, 1, 320));
                Dispatcher.BeginInvoke(() => { c.Info = info; c.Thumbnail = img; });
            }
        });
    }

    void OnSelectionChanged(object s, SelectionChangedEventArgs e)
    {
        var sel = Clips.SelectedItems.Cast<ClipItem>().ToList();
        UpdateCounts();
        PreviewImg.Source = sel.Count > 0 ? sel[0].Thumbnail : null; NoSel.Visibility = sel.Count > 0 ? Visibility.Collapsed : Visibility.Visible;
        if (sel.Count > 0) { var first = sel[0]; first.PropertyChanged -= OnFirstChanged; first.PropertyChanged += OnFirstChanged; }
        if (sel.Count == 1) { IntFrom.Text = sel[0].From?.ToString(CultureInfo.InvariantCulture) ?? ""; IntTo.Text = sel[0].To?.ToString(CultureInfo.InvariantCulture) ?? ""; }
        else { IntFrom.Text = ""; IntTo.Text = ""; }
    }

    void OnFirstChanged(object? s, PropertyChangedEventArgs e)
    {
        if (e.PropertyName == nameof(ClipItem.Thumbnail) && s is ClipItem c && Clips.SelectedItems.Count > 0 && ReferenceEquals(Clips.SelectedItems[0], c)) PreviewImg.Source = c.Thumbnail;
    }

    static double? ParseSeconds(string t)
    {
        t = t.Trim().Replace(',', '.'); if (t.Length == 0) return null;
        if (t.Contains(':'))
        {
            var p = t.Split(':'); double sec = 0; foreach (var x in p) { if (!double.TryParse(x, NumberStyles.Float, CultureInfo.InvariantCulture, out var v)) return null; sec = sec * 60 + v; }
            return sec;
        }
        return double.TryParse(t, NumberStyles.Float, CultureInfo.InvariantCulture, out var d) && d >= 0 ? d : null;
    }

    void OnIntervalChanged(object s, RoutedEventArgs e)
    {
        if (IsBusy) return;
        foreach (var c in Clips.SelectedItems.Cast<ClipItem>()) { c.From = ParseSeconds(IntFrom.Text); c.To = ParseSeconds(IntTo.Text); }
    }

    void OnPreview(object s, RoutedEventArgs e)
    {
        if (Clips.SelectedItem is not ClipItem c || Helpers.Engine.Value is not { } eng) return;
        var w = new PreviewWindow(eng, c.Path) { Owner = Window.GetWindow(this) };
        w.ShowDialog();
        if (w.PickedFrom is { } a) { IntFrom.Text = a.ToString("0.###", CultureInfo.InvariantCulture); }
        if (w.PickedTo is { } b) { IntTo.Text = b.ToString("0.###", CultureInfo.InvariantCulture); }
        if (w.PickedFrom != null || w.PickedTo != null) OnIntervalChanged(this, e);
    }

    OutputPreset EffectivePreset()
    {
        var p = Preset!;
        var clone = new OutputPreset { Id = p.Id, Label = p.Label, TargetApp = p.TargetApp, ProfileId = p.ProfileId, AudioModeRaw = p.AudioModeRaw, ChannelLayoutRaw = p.ChannelLayoutRaw, FileSuffix = p.FileSuffix, IsBuiltin = p.IsBuiltin, FrameRate = p.FrameRate, ColorSpaceRaw = p.ColorSpaceRaw };
        if (!p.IsRewrap)
        {
            if (FpsCombo.SelectedIndex > 0) clone.FrameRate = (string)FpsCombo.SelectedItem;
            if (ColorCombo.SelectedIndex == 1) clone.ColorSpaceRaw = "bt709"; else if (ColorCombo.SelectedIndex == 2) clone.ColorSpaceRaw = "bt2020";
        }
        return clone;
    }

    void OnCancel(object s, RoutedEventArgs e) => CancelAll();
    public void CancelAll() { _cts?.Cancel(); _handle?.Cancel(); }

    async void OnStart(object s, RoutedEventArgs e)
    {
        if (IsBusy || _clips.Count == 0 || Preset == null || Helpers.Engine.Value is not { } eng) return;
        if (!MainWindow.RequireUnlocked()) return;
        var preset = EffectivePreset(); bool keep = KeepMeta.IsChecked == true, side = Sidecar.IsChecked == true;
        var jobs = (Clips.SelectedItems.Count > 1 ? Clips.SelectedItems.Cast<ClipItem>().ToList() : _clips.ToList());
        foreach (var c in jobs) { c.State = ClipState.Waiting; c.Progress = 0; c.Error = ""; c.Report = null; c.ReportChanged(); }
        IsBusy = true; StartBtn.IsEnabled = false; CancelBtn.IsEnabled = true; Overall.Visibility = Visibility.Visible; _cts = new(); var ct = _cts.Token;
        int ok = 0, fail = 0, canc = 0, i = 0;
        var log = StructuredLog.Shared;
        foreach (var c in jobs)
        {
            i++; Overall.Value = (i - 1) * 100.0 / jobs.Count; Summary.Text = $"{i}/{jobs.Count} · {c.Name}";
            if (ct.IsCancellationRequested) { c.State = ClipState.Cancelled; canc++; continue; }
            c.State = ClipState.Running;
            var dir = string.IsNullOrEmpty(_outDir) ? Path.GetDirectoryName(c.Path)! : _outDir;
            var dest = Helpers.UniquePath(Path.Combine(dir, Path.GetFileNameWithoutExtension(c.Path) + preset.FileSuffix + "." + preset.Extension));
            if (string.Equals(dest, c.Path, StringComparison.OrdinalIgnoreCase)) dest = Helpers.UniquePath(Path.Combine(dir, Path.GetFileNameWithoutExtension(c.Path) + "_out." + preset.Extension));
            var handle = _handle = new ConversionHandle(); var job = new VideoJob(c.Path, c.From, c.To);
            var jid = StructuredLog.NewId(); var t0 = DateTime.UtcNow;
            log.Log(LogLevel.Info, "convert", "job.start", "Conversie pornită", job: jid, fields: new Dictionary<string, string> { ["preset"] = preset.Id });
            try
            {
                var rep = await Task.Run(() => eng.Run(job, preset, dest, handle, p => Dispatcher.BeginInvoke(() => { c.Progress = p * 100; Overall.Value = ((i - 1) + p) * 100.0 / jobs.Count; }), keep, side));
                c.Report = rep; c.OutPath = dest; c.State = rep.Metadata == MetadataOutcome.Incomplete ? ClipState.DoneWarn : ClipState.Done; c.Progress = 100; c.ReportChanged(); ok++;
                log.Log(LogLevel.Info, "convert", "job.finish", "Conversie terminată", job: jid, fields: new Dictionary<string, string> { ["ms"] = ((int)(DateTime.UtcNow - t0).TotalMilliseconds).ToString() });
            }
            catch (ConversionCancelled) { c.State = ClipState.Cancelled; canc++; log.Log(LogLevel.Info, "convert", "job.cancel", "Anulat", job: jid); }
            catch (Exception ex) { c.Error = CGConvertor.Core.CoreText.Tr(ex.Message); c.State = ClipState.Failed; fail++; log.Log(LogLevel.Error, "convert", "job.fail", "Conversie eșuată", job: jid, error: ex); }
        }
        Overall.Value = 100; Summary.Text = Loc.F("tc.queueDone", ok, fail, canc); DispatcherHide();
        IsBusy = false; _handle = null; CancelBtn.IsEnabled = false; UpdateCounts();
    }

    void DispatcherHide() { Overall.Visibility = Visibility.Collapsed; }

    void OnShowReport(object s, RoutedEventArgs e)
    {
        if (((FrameworkElement)s).Tag is not ClipItem c || c.Report is not { } r) return;
        var sb = new StringBuilder();
        sb.AppendLine(c.Name + "  →  " + c.OutPath);
        string R(ReportNote n) => Loc.T(n.Key) + (n.Arg.Length > 0 ? " " + (n.Arg.StartsWith("report.") ? Loc.T(n.Arg) : n.Arg) : "");
        sb.AppendLine($"{Loc.T("report.frames")}: {r.FramesSource} → {r.FramesOutput}   {Loc.T("report.audio")}: {r.AudioStreamsSource} → {r.AudioStreamsOutput}");
        sb.AppendLine($"Timecode: {r.TimecodeSource ?? "—"} → {r.TimecodeOutput ?? "—"}");
        if (r.Interval is { } iv) sb.AppendLine($"{Loc.T("report.interval")}: " + Loc.F("report.intervalLine", iv.StartFrame, iv.Frames, iv.Fps.ToString("0.###")));
        foreach (var k in r.Kept) sb.AppendLine("✓ " + R(k));
        foreach (var k in r.NotKept) sb.AppendLine("– " + R(k));
        foreach (var k in r.Problems) sb.AppendLine("! " + R(k));
        var res = MessageBox.Show(sb.ToString() + "\n\n" + Loc.T("tc.reveal") + "?", "CG Convertor — " + Loc.T("tc.report"), MessageBoxButton.YesNo, MessageBoxImage.Information);
        if (res == MessageBoxResult.Yes && c.OutPath != null) Helpers.Reveal(c.OutPath);
    }
}
