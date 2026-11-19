using System.Security.Cryptography;
using System.Text;
using Org.BouncyCastle.Math.EC.Rfc8032;

namespace CGConvertor.Core.Licensing;

/// <summary>Rezultatul validării unui cod serial compact (format identic cu Python/Furnizor).</summary>
public sealed record LicenseResult(bool Valid, bool Expired, long ExpiresAt, string Error)
{
    public bool Perpetual => Valid && ExpiresAt == 0;
}

/// <summary>Port 1:1 al license_core.validate_serial_compact + machine_id.py (Ed25519, cheie publică comună GDC).</summary>
public static class LicenseCore
{
    public const string PublicKeyB64 = "I1h23MNMRbOhc0ObKJrfa3oFHKA9w+SzbNrroAIy8hs=";
    public const string ProductId = "cgconvertor";

    static readonly char[] B32 = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567".ToCharArray();

    public static string Base32Encode(byte[] data)
    {
        var sb = new StringBuilder(); int buffer = 0, bits = 0;
        foreach (var b in data)
        {
            buffer = (buffer << 8) | b; bits += 8;
            while (bits >= 5) { sb.Append(B32[(buffer >> (bits - 5)) & 31]); bits -= 5; }
        }
        if (bits > 0) sb.Append(B32[(buffer << (5 - bits)) & 31]);
        return sb.ToString();
    }

    public static byte[] Base32Decode(string s)
    {
        var cleaned = s.Replace("-", "").Replace(" ", "").Replace("=", "").ToUpperInvariant();
        var output = new List<byte>(); int buffer = 0, bits = 0;
        foreach (var c in cleaned)
        {
            int v = Array.IndexOf(B32, c);
            if (v < 0) throw new FormatException("caracter Base32 invalid");
            buffer = (buffer << 5) | v; bits += 5;
            if (bits >= 8) { output.Add((byte)((buffer >> (bits - 8)) & 0xFF)); bits -= 8; }
        }
        return output.ToArray();
    }

    /// <summary>Surogat pentru teste/izolare: dacă CGC_TEST_MACHINE_GUID e setat, înlocuiește MachineGuid.</summary>
    public static string RawMachineId()
    {
        var forced = Environment.GetEnvironmentVariable("CGC_TEST_MACHINE_GUID");
        if (!string.IsNullOrEmpty(forced)) return forced;
        try
        {
            if (OperatingSystem.IsWindows())
            {
                using var k = Microsoft.Win32.RegistryKey.OpenBaseKey(Microsoft.Win32.RegistryHive.LocalMachine, Microsoft.Win32.RegistryView.Registry64)
                    .OpenSubKey(@"SOFTWARE\Microsoft\Cryptography");
                if (k?.GetValue("MachineGuid") is string g && g.Length > 0) return g;
            }
        }
        catch { }
        return "windows-machine-id-unavailable";
    }

    public static string MachineIdDisplay(string? raw = null)
    {
        var digest = SHA512.HashData(Encoding.UTF8.GetBytes(raw ?? RawMachineId()));
        return Base32Encode(digest[..6]);
    }

    public static LicenseResult Validate(string serial, string? machineIdB32 = null, long? nowUnix = null, string? publicKeyB64 = null)
    {
        try
        {
            var packed = Base32Decode(serial);
            if (packed.Length != 22 + 64) return new(false, false, 0, "Format de cod serial invalid (lungime gresita).");
            var payload = packed[..22]; var sig = packed[22..];
            var pub = Convert.FromBase64String(publicKeyB64 ?? PublicKeyB64);
            if (!Ed25519.Verify(sig, 0, pub, 0, payload, 0, payload.Length))
                return new(false, false, 0, "Cod serial invalid — semnatura nu se potriveste.");
            var expected = SHA512.HashData(Encoding.UTF8.GetBytes(ProductId))[..4];
            if (!payload[..4].AsSpan().SequenceEqual(expected)) return new(false, false, 0, "Acest cod e pentru alt produs.");
            long expires = 0; for (int i = 4; i < 12; i++) expires = (expires << 8) | payload[i];
            var stored = payload[16..22];
            if (!stored.All(b => b == 0))
            {
                var cur = machineIdB32 is null ? null : Base32Decode(machineIdB32);
                if (cur is null || !cur.AsSpan().SequenceEqual(stored)) return new(false, false, 0, "Acest cod e activat pentru alt calculator.");
            }
            var now = nowUnix ?? DateTimeOffset.UtcNow.ToUnixTimeSeconds();
            if (expires != 0 && expires < now) return new(false, true, expires, "Codul serial a expirat.");
            return new(true, false, expires, "");
        }
        catch (Exception e) { return new(false, false, 0, $"Cod serial invalid sau corupt ({e.Message})."); }
    }
}
