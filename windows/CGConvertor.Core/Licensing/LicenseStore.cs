using System.Security.Cryptography;
using System.Text;

namespace CGConvertor.Core.Licensing;

public enum LicenseState { Licensed, Trial, TrialExpired }

public sealed record LicenseStatus(LicenseState State, double TrialDaysLeft, LicenseResult? License);

/// <summary>
/// Stocare licență + probă. Compatibilă cu clientul Python 3.15 (fișierele ~/.cgconvertor_license și
/// ~/.cgconvertor_trial rămân sursa de adevăr pentru starea existentă); în plus o copie protejată DPAPI
/// în %APPDATA%\CGConvertor. Probe vechi = 15 zile (nescurtate), probe noi = 5 zile.
/// CGC_ISOLATED_HOME mută TOT (licență, probă, DPAPI, loguri) într-un folder de test.
/// </summary>
public sealed class LicenseStore
{
    public const int LegacyTrialDays = 15, NewTrialDays = 5;
    readonly string _home, _appData;
    readonly Func<DateTimeOffset> _now;

    public LicenseStore(string? home = null, Func<DateTimeOffset>? now = null)
    {
        _home = home ?? AppPaths.Home;
        _appData = home is null ? AppPaths.Roaming : Path.Combine(_home, "AppData", "CGConvertor");
        _now = now ?? (() => DateTimeOffset.UtcNow);
        Directory.CreateDirectory(_appData);
    }

    string LicensePath => Path.Combine(_home, $".{LicenseCore.ProductId}_license");
    string TrialPath => Path.Combine(_home, $".{LicenseCore.ProductId}_trial");
    string TrialDaysPath => Path.Combine(_home, $".{LicenseCore.ProductId}_trial_days");
    string ProtectedPath => Path.Combine(_appData, "license.dpapi");

    static byte[] Entropy => Encoding.UTF8.GetBytes("dev.gordas.CGConvertor.license");

    public LicenseResult Activate(string serial)
    {
        var r = LicenseCore.Validate(serial.Trim(), LicenseCore.MachineIdDisplay());
        if (!r.Valid) return r;
        File.WriteAllText(LicensePath, serial.Trim());
        try
        {
            if (OperatingSystem.IsWindows())
                File.WriteAllBytes(ProtectedPath, ProtectedData.Protect(Encoding.UTF8.GetBytes(serial.Trim()), Entropy, DataProtectionScope.CurrentUser));
        }
        catch { }
        return r;
    }

    string? ReadSerial()
    {
        if (File.Exists(LicensePath)) { var s = File.ReadAllText(LicensePath).Trim(); if (s.Length > 0) return s; }
        try
        {
            if (OperatingSystem.IsWindows() && File.Exists(ProtectedPath))
                return Encoding.UTF8.GetString(ProtectedData.Unprotect(File.ReadAllBytes(ProtectedPath), Entropy, DataProtectionScope.CurrentUser));
        }
        catch { }
        return null;
    }

    public LicenseStatus Status()
    {
        var serial = ReadSerial();
        if (serial is not null)
        {
            var r = LicenseCore.Validate(serial, LicenseCore.MachineIdDisplay(), _now().ToUnixTimeSeconds());
            if (r.Valid) return new(LicenseState.Licensed, 0, r);
        }
        var left = TrialDaysLeft();
        return new(left > 0 ? LicenseState.Trial : LicenseState.TrialExpired, left, null);
    }

    public bool IsUnlocked => Status().State != LicenseState.TrialExpired;

    double TrialDaysLeft()
    {
        long start;
        int days;
        if (!File.Exists(TrialPath))
        {
            start = _now().ToUnixTimeSeconds(); days = NewTrialDays;
            try { File.WriteAllText(TrialPath, start.ToString()); File.WriteAllText(TrialDaysPath, days.ToString()); } catch { }
            return days;
        }
        if (!long.TryParse(File.ReadAllText(TrialPath).Trim(), out start)) start = _now().ToUnixTimeSeconds();
        days = LegacyTrialDays;
        if (File.Exists(TrialDaysPath) && int.TryParse(File.ReadAllText(TrialDaysPath).Trim(), out var d) && d is > 0 and <= LegacyTrialDays) days = d;
        return days - (_now().ToUnixTimeSeconds() - start) / 86400.0;
    }
}
