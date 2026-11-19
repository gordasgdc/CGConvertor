using System.Collections.ObjectModel;
using System.Diagnostics;
using System.IO;
using System.Text.Json;
using System.Windows;
using System.Windows.Controls;
using CGConvertor.Core.Transcode;

namespace CGConvertor.Client;

public sealed class MdClip
{
    public MdClip(string path) { Path = path; }
    public string Path { get; }
    public string Name => System.IO.Path.GetFileName(Path);
    public override string ToString() => Name;
    public SourceProfile? Profile { get; set; }
    public bool Scanned { get; set; }
    public string Status => !Scanned ? Loc.T("md.thumb.none") : Profile is null ? Loc.T("md.noCore") : Profile.PartialReason != null ? Loc.F("md.partial", CGConvertor.Core.CoreText.Tr(Profile.PartialReason)) : $"{Profile.All.Count} " + Loc.T("md.fields");
}
public sealed record MdRow(string Field, string Value, string Provenance);
public sealed record MdSection(string Title, List<MdRow> Rows);

public partial class MetadataView : UserControl
{
    readonly ObservableCollection<MdClip> _clips = new();
    public MetadataView()
    {
        InitializeComponent(); Clips.ItemsSource = _clips;
        Loc.Instance.LanguageChanged += () => { Clips.Items.Refresh(); OnSelect(null!, null!); };
        if (MetadataCoreClient.BinaryPath == null) { Msg.Text = Loc.T("md.noCore"); ScanBtn.IsEnabled = false; ExportBtn.IsEnabled = false; }
    }

    void OnAdd(object s, RoutedEventArgs e) => Add(Helpers.PickFiles());
    void OnDrop(object s, DragEventArgs e) { if (e.Data.GetData(DataFormats.FileDrop) is string[] a) Add(a); }
    void OnRemove(object s, RoutedEventArgs e) { foreach (var c in Clips.SelectedItems.Cast<MdClip>().ToList()) _clips.Remove(c); OnSelect(null!, null!); }
    void Add(IEnumerable<string> paths) { foreach (var f in Helpers.ExpandVideo(paths)) if (!_clips.Any(c => c.Path == f)) _clips.Add(new MdClip(f)); }

    async void OnScan(object s, RoutedEventArgs e)
    {
        ScanBtn.IsEnabled = false;
        var targets = (Clips.SelectedItems.Count > 0 ? Clips.SelectedItems.Cast<MdClip>() : _clips).ToList();
        foreach (var c in targets) { c.Profile = await Task.Run(() => MetadataCoreClient.Scan(c.Path)); c.Scanned = true; Clips.Items.Refresh(); }
        ScanBtn.IsEnabled = MetadataCoreClient.BinaryPath != null; OnSelect(null!, null!);
    }

    static string FieldName(string id)
    {
        var t = Loc.T("md.f." + id);
        if (t != "md.f." + id) return t;
        var h = id.Replace('_', ' ');
        return char.ToUpper(h[0]) + h[1..];
    }

    void OnSearch(object s, TextChangedEventArgs e) => OnSelect(null!, null!);

    void OnSelect(object s, SelectionChangedEventArgs e)
    {
        var secs = new List<MdSection>();
        Msg.Text = "";
        if (Clips.SelectedItem is MdClip { Scanned: true } c)
        {
            if (c.Profile is not { } p) secs.Add(new("—", new() { new("—", Loc.T("md.noCore"), "") }));
            else
            {
                var q = Search.Text?.Trim() ?? "";
                foreach (var g in new[] { "file", "camera", "lens", "exposure", "color" })
                {
                    var rows = p.All.Where(f => f.Section == g).Select(f =>
                        new MdRow(FieldName(f.Id), Loc.T("md.v." + f.Value) is var t && t != "md.v." + f.Value ? t : f.Value, string.Join(" · ", new[] { f.Kind, f.Source }.Where(x => x.Length > 0))))
                        .Where(r => q.Length == 0 || r.Field.Contains(q, StringComparison.CurrentCultureIgnoreCase) || r.Value.Contains(q, StringComparison.CurrentCultureIgnoreCase)).ToList();
                    if (rows.Count > 0) secs.Add(new(Loc.T("md.sec." + g), rows));
                }
                if (p.PartialReason != null) Msg.Text = Loc.F("md.partial", CGConvertor.Core.CoreText.Tr(p.PartialReason));
            }
        }
        Sections.ItemsSource = secs; EmptyText.Visibility = secs.Count == 0 ? Visibility.Visible : Visibility.Collapsed;
    }

    async void OnExport(object s, RoutedEventArgs e)
    {
        if (Clips.SelectedItem is not MdClip c || MetadataCoreClient.BinaryPath is not { } bin) return;
        var tmp = Path.Combine(Path.GetTempPath(), "cgc-sidecar-" + Guid.NewGuid().ToString("N")[..8]); Directory.CreateDirectory(tmp);
        try
        {
            await Task.Run(() =>
            {
                var psi = new ProcessStartInfo(bin) { UseShellExecute = false, CreateNoWindow = true, RedirectStandardOutput = true, RedirectStandardError = true };
                psi.ArgumentList.Add("export"); psi.ArgumentList.Add(c.Path); psi.ArgumentList.Add("--out-dir"); psi.ArgumentList.Add(tmp);
                using var p = Process.Start(psi)!; p.StandardOutput.ReadToEnd(); p.StandardError.ReadToEnd(); p.WaitForExit(60000);
            });
            var f = Directory.GetFiles(tmp, "*.gdc-metadata.json").FirstOrDefault();
            if (f == null) { Msg.Text = Loc.F("err.generic", "export"); return; }
            File.Copy(f, c.Path + ".gdc-metadata.json", true); Msg.Text = Loc.T("md.exported");
        }
        catch (Exception ex) { Msg.Text = Loc.F("err.generic", CGConvertor.Core.CoreText.Tr(ex.Message)); }
        finally { try { Directory.Delete(tmp, true); } catch { } }
    }
}
