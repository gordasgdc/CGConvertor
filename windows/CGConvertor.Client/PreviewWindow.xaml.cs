using System.Windows;
using CGConvertor.Core.Transcode;

namespace CGConvertor.Client;

public partial class PreviewWindow
{
    readonly TranscodeEngine _eng; readonly string _path; double _dur;
    public double? PickedFrom, PickedTo;
    CancellationTokenSource? _cts;

    public PreviewWindow(TranscodeEngine eng, string path)
    {
        InitializeComponent(); _eng = eng; _path = path; Bar.Title = System.IO.Path.GetFileName(path);
        BtnStart.Content = Loc.T("tc.from") + " ⟵"; BtnEnd.Content = Loc.T("tc.to") + " ⟶"; BtnClose.Content = Loc.T("close");
        _dur = _eng.Summarize(path)?.Duration ?? 0; Seek.Maximum = Math.Max(_dur, 0.1);
        Loaded += (_, _) => Show(0);
    }

    async void Show(double t)
    {
        _cts?.Cancel(); var cts = _cts = new(); TimeText.Text = TimeSpan.FromSeconds(t).ToString(@"h\:mm\:ss\.ff") + "  /  " + TimeSpan.FromSeconds(_dur).ToString(@"h\:mm\:ss");
        await Task.Delay(150, CancellationToken.None);
        if (cts.IsCancellationRequested) return;
        var bytes = await Task.Run(() => _eng.FrameBytes(_path, t, 1280));
        if (!cts.IsCancellationRequested) Frame.Source = Helpers.Image(bytes);
    }

    void OnSeek(object s, RoutedPropertyChangedEventArgs<double> e) { if (IsLoaded) Show(Seek.Value); }
    void OnSetStart(object s, RoutedEventArgs e) => PickedFrom = Math.Round(Seek.Value, 3);
    void OnSetEnd(object s, RoutedEventArgs e) => PickedTo = Math.Round(Seek.Value, 3);
    void OnClose(object s, RoutedEventArgs e) => Close();
}
