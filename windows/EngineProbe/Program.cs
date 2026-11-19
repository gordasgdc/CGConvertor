using CGConvertor.Core.Transcode;
using CGConvertor.Core.Licensing;

// Probă de motor/licență: dotnet run -- <ffmpeg> <ffprobe> <src> <outdir>
// Grefare: pista nativă din <grafted> pe o copie a <base>; verificare + comparație cu <grafted>
if (args.Length > 0 && args[0] == "graft")
{
    var baseF = args[1]; var grafted = args[2]; var tmp = args[3]; double gs = args.Length > 4 ? double.Parse(args[4], System.Globalization.CultureInfo.InvariantCulture) : 0; double? gd = args.Length > 5 ? double.Parse(args[5], System.Globalization.CultureInfo.InvariantCulture) : null;
    File.Copy(baseF, tmp, true);
    var rep = CGConvertor.Core.Transcode.TrackGrafter.Graft(grafted, tmp, gs, gd);
    foreach (var t in rep.Tracks) Console.WriteLine($"graft {t.FourCC}: {t.SampleCount} eșantioane, {t.PayloadBytes} B, sha {t.PayloadSha256[..12]}");
    var probs = CGConvertor.Core.Transcode.TrackGrafter.Verify(rep, tmp); Console.WriteLine("probleme verificare: " + (probs.Count == 0 ? "niciuna" : string.Join("; ", probs)));
    var a = new FileInfo(tmp).Length; var b = new FileInfo(grafted).Length;
    using var f1 = File.OpenRead(tmp); using var f2 = File.OpenRead(grafted);
    var h1 = System.Security.Cryptography.SHA256.HashData(f1); var h2 = System.Security.Cryptography.SHA256.HashData(f2);
    Console.WriteLine($"dimensiuni {a} vs {b}; fișiere identice: {h1.SequenceEqual(h2)}");
    return 0;
}


if (args.Length > 0 && args[0] == "pipe")
{
    var e2 = new TranscodeEngine(args[1], args[2]); var src2 = args[3]; var od2 = args[4]; Directory.CreateDirectory(od2);
    var pr = PresetsManager.Defaults().First(x => x.Id == "builtin_prores422hq");
    foreach (var iv in new (double?, double?)[] { (null, null), (1.0, 2.0) })
    {
        var dest = Path.Combine(od2, iv.Item1 == null ? "full.mov" : "int.mov"); if (File.Exists(dest)) File.Delete(dest);
        var r = e2.Run(new VideoJob(src2, iv.Item1, iv.Item2), pr, dest, new ConversionHandle(), null, true, false);
        Console.WriteLine($"{Path.GetFileName(dest)}: frames {r.FramesSource}->{r.FramesOutput} tc {r.TimecodeSource}->{r.TimecodeOutput} grafted=[{string.Join(",", r.Grafted.Select(g => g.FourCC + ":" + g.SampleCount))}] meta={r.Metadata} problems={r.Problems.Count}");
    }
    return 0;
}

var e = new TranscodeEngine(args[0], args[1]); var src = args[2]; var od = args[3]; Directory.CreateDirectory(od);
int fail = 0; void Check(string n, bool ok, string d = "") { Console.WriteLine($"{(ok ? "OK  " : "FAIL")} {n} {d}"); if (!ok) fail++; }
var presets = PresetsManager.Defaults();
foreach (var id in new[] { "builtin_rewrap", "builtin_prores422hq", "builtin_h264_web" })
{
    var p = presets.First(x => x.Id == id); var dest = Path.Combine(od, id + "." + p.Extension);
    try { var r = e.Run(new VideoJob(src, 0.0, 1.0), p, dest, new ConversionHandle(), null, true, false); }
    catch (ConversionException ex) when (p.IsRewrap) { Check(id + " interval refuzat pe rewrap", true, ex.Message); continue; }
    var s = e.Summarize(dest); Check(id + " interval 1s", File.Exists(dest) && s?.Frames is > 0, $"frames={s?.Frames} audio={s?.Audio}");
}
{ var p = presets.First(x => x.Id == "builtin_rewrap"); var dest = Path.Combine(od, "rw.mov");
  var r = e.Run(new VideoJob(src), p, dest, new ConversionHandle()); Check("rewrap integral", r.FramesOutput == r.FramesSource && r.TimecodeOutput == r.TimecodeSource, $"tc={r.TimecodeSource} frames={r.FramesSource}"); }
{ var h = new ConversionHandle(); var p = presets.First(x => x.Id == "builtin_h264_web"); var dest = Path.Combine(od, "cancel.mp4");
  var t = Task.Run(() => { try { e.Run(new VideoJob(src), p, dest, h); return false; } catch (ConversionCancelled) { return true; } });
  Thread.Sleep(700); h.Cancel(); Check("anulare", t.Result && !File.Exists(dest) && !Directory.GetFiles(od, ".*cgc-*").Any()); }
Check("TC drop-frame +30", TimecodeMath.Offset("01:00:00;00", 1800, 29.97) == "01:01:00;02", TimecodeMath.Offset("01:00:00;00", 1800, 29.97));
Check("TC non-drop +24", TimecodeMath.Offset("00:00:00:00", 24, 24) == "00:00:01:00");
// licență
var home = Path.Combine(od, "home"); Directory.CreateDirectory(home);
var now = DateTimeOffset.UtcNow; var st = new LicenseStore(home, () => now);
var s1 = st.Status(); Check("proba noua 5 zile", s1.State == LicenseState.Trial && Math.Abs(s1.TrialDaysLeft - 5) < 0.01);
var st2 = new LicenseStore(home, () => now.AddDays(6)); Check("proba expira dupa 5 zile", st2.Status().State == LicenseState.TrialExpired);
var home2 = Path.Combine(od, "home2"); Directory.CreateDirectory(home2);
File.WriteAllText(Path.Combine(home2, ".cgconvertor_trial"), now.AddDays(-10).ToUnixTimeSeconds().ToString());
var s3 = new LicenseStore(home2, () => now).Status(); Check("proba veche 15 zile nescurtata", s3.State == LicenseState.Trial && Math.Abs(s3.TrialDaysLeft - 5) < 0.1, s3.TrialDaysLeft.ToString("F2"));
Check("cod invalid respins", !new LicenseStore(home, () => now).Activate("AAAA-BBBB").Valid);
Check("machine id Base32 8 car", LicenseCore.MachineIdDisplay("abc").Length == 10, LicenseCore.MachineIdDisplay("abc"));

// Offload: copiere verificată, 2 destinații, raport PDF
{
    var o = Path.Combine(od, "offload"); if (Directory.Exists(o)) Directory.Delete(o, true);
    var srcDir = Path.GetDirectoryName(src)!; var d1 = Path.Combine(o, "D1"); var d2 = Path.Combine(o, "D2"); Directory.CreateDirectory(d1); Directory.CreateDirectory(d2);
    var sub = Path.Combine(o, "SRC"); Directory.CreateDirectory(sub); foreach (var f in Directory.GetFiles(srcDir).Take(4)) File.Copy(f, Path.Combine(sub, Path.GetFileName(f)));
    var runner = new CGConvertor.Core.Services.OffloadRunner();
    runner.Start(new List<string> { sub }, new List<string> { d1, d2 }, CGConvertor.Core.Services.VerificationModel.XxHash64, new List<string>(), false,
        new CGConvertor.Core.Services.ProductionMeta { Project = "Probe", Card = "A001" }, appVersion: "3.18.0-test");
    var sw = System.Diagnostics.Stopwatch.StartNew(); Thread.Sleep(300); while (runner.IsRunning && sw.Elapsed.TotalMinutes < 5) Thread.Sleep(200);
    var res = runner.LastResults;
    Check("offload 2 destinații", res.Count == 2 && res.All(r => r.FailCount == 0 && r.OkCount == 4), string.Join(" | ", res.Select(r => $"ok={r.OkCount} fail={r.FailCount} pdf={(r.PdfPath != null && File.Exists(r.PdfPath))} mhl={(r.MhlPath != null)}")));
    Check("raport PDF scris", res.All(r => r.PdfPath != null && File.Exists(r.PdfPath) && new FileInfo(r.PdfPath).Length > 2000));
    var ctx = runner.Contexts.First(); var rows = ctx.BuildReport(4).Rows;
    Check("rânduri verificate cu cale", rows.Count(r => r.Status.StartsWith("OK") && File.Exists(r.DestPath)) == 4, $"{rows.Count}");
}


// Compatibilitate cu emitentul (Python license_core, pereche de chei DE TEST)
{
    var tk = "EdkHzm9rnpekP72r91TLMuSx8YysaU4btfY7wIeS71w="; var mid = "2SRT5NXUSU";
    Check("serial permanent valid", CGConvertor.Core.Licensing.LicenseCore.Validate("MFQX-KOAA-AAAA-AAAA-AAAO-6RZ4-HXKK-GPVW-6SK5-YQO3-ADYK-AHV6-DZDW-XBSF-3TTD-FBLZ-CNOZ-V6AY-2OG5-ZZWM-JTJQ-MF6L-HTDN-HSCQ-BII5-VRC2-4OME-DEMD-IQYH-BKCX-XPHQ-K6CB-LXDN-UIX6-BA", mid, null, tk) is { Valid: true, ExpiresAt: 0 });
    var r3 = CGConvertor.Core.Licensing.LicenseCore.Validate("MFQX-KOAA-AAAA-A23U-6IOB-K5FS-LLKK-GPVW-6SKW-A75N-EV6M-NORH-L42C-5HHX-QRIF-5WUA-BWHC-6PUP-AMT3-32NP-7U6H-H5MZ-J7AW-IBPT-7VPZ-GVYO-V6YF-PMSX-3UWD-MQO3-EIJL-FW4T-GLAR-NQGK-BU", mid, null, tk); Check("serial 3 luni valid", r3.Valid && !r3.Perpetual);
    Check("serial expirat respins", CGConvertor.Core.Licensing.LicenseCore.Validate("MFQX-KOAA-AAAA-A2X6-JK4I-6BBU-73KK-GPVW-6SK7-3JNQ-J5PJ-2VH7-2IZZ-UOTQ-RVME-SIIR-MNTS-AAFX-5ZK6-WXSM-BMNN-QBKK-LFPG-V3JB-47H6-J5VE-VUNF-U4W6-WX2O-OW5Y-YL4Z-EFAS-UCCL-5TN7-BQ", mid, null, tk) is { Valid: false, Expired: true });
    Check("alt produs respins", !CGConvertor.Core.Licensing.LicenseCore.Validate("TRPQ-B3YA-AAAA-AAAA-AAAF-SYMD-53KK-GPVW-6SKS-J2KR-KHMD-PDEP-BZQU-SF2E-OBTF-Q3PW-LRJT-TRSL-H6IL-RPLC-5KE7-5DQB-JYNZ-JTI3-XBO6-DJ3O-MN2H-6YGC-CHW7-W3OU-2MA4-UCFO-VF4D-64WJ-BU", mid, null, tk).Valid);
    Check("alt calculator respins", !CGConvertor.Core.Licensing.LicenseCore.Validate("MFQX-KOAA-AAAA-AAAA-AAAO-6RZ4-HXKK-GPVW-6SK5-YQO3-ADYK-AHV6-DZDW-XBSF-3TTD-FBLZ-CNOZ-V6AY-2OG5-ZZWM-JTJQ-MF6L-HTDN-HSCQ-BII5-VRC2-4OME-DEMD-IQYH-BKCX-XPHQ-K6CB-LXDN-UIX6-BA", "AAAAAAAAAA", null, tk).Valid);
    Check("nelegat valid oriunde", CGConvertor.Core.Licensing.LicenseCore.Validate("MFQX-KOAA-AAAA-AAAA-AAAL-5F4J-3MAA-AAAA-AAAI-CTW2-N3VW-SGLW-7DPI-QHKD-KWUY-ALDE-ZU7E-VJHD-LYRN-DEAV-FCI2-PZRU-ZTCD-P7K5-ILDR-DPJI-IIOE-XHD4-2CO6-N7A2-LPO3-HBFK-SHCE-A4U3-BI", "AAAAAAAAAA", null, tk).Valid);
    Check("cheie publică reală respinge cheia de test", !CGConvertor.Core.Licensing.LicenseCore.Validate("MFQX-KOAA-AAAA-AAAA-AAAO-6RZ4-HXKK-GPVW-6SK5-YQO3-ADYK-AHV6-DZDW-XBSF-3TTD-FBLZ-CNOZ-V6AY-2OG5-ZZWM-JTJQ-MF6L-HTDN-HSCQ-BII5-VRC2-4OME-DEMD-IQYH-BKCX-XPHQ-K6CB-LXDN-UIX6-BA", mid).Valid);
}
Console.WriteLine(fail == 0 ? "TOATE OK" : $"{fail} ESECURI"); return fail;
