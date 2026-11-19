using System.Security.Cryptography;
using System.Text;
using System.Text.RegularExpressions;

namespace CGConvertor.Core.Diagnostics;

/// <summary>
/// Redactare pentru jurnal si pachetul de diagnostic — aceleasi reguli ca
/// `Redactor.swift` (Mac). `RedactSecrets` se aplica mereu, la scriere;
/// `AnonymizePaths` la export (implicit), cu hash stabil si extensia pastrata.
/// </summary>
public static class Redactor
{
    private static readonly Regex Email = new(@"[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}", RegexOptions.Compiled);
    private static readonly Regex KeyValue = new(@"(?i)\b(token|access[_-]?token|refresh[_-]?token|api[_-]?key|apikey|secret|password|passwd|pwd|licen[cs]e(?:[_-]?code)?|serial|authorization|bearer|cookie|session[_-]?key)\b(\s*[:=]\s*|\s+)(""[^""]*""|'[^']*'|[^\s,;]+)", RegexOptions.Compiled);
    // Material de activare/licenta gen3 (vezi Redactor.swift): cerere de activare si plicuri JSON semnate.
    private static readonly Regex StrictKeyValue = new(@"(?i)\b(machine[_-]?id|device[_-]?key|request[_-]?id|nonce|activation[_-]?id|signature)\b(\s*[:=]\s*)(""[^""]*""|'[^']*'|[^\s,;]+)", RegexOptions.Compiled);
    private static readonly Regex JsonSensitive = new(@"(?i)(""(?:machine[_-]?id|device[_-]?key|request[_-]?id|nonce|activation[_-]?id|signature|payload|licen[cs]e|token|secret|password|email|whatsapp)"")(\s*:\s*)(""[^""]*"")", RegexOptions.Compiled);
    private static readonly Regex LongToken = new(@"\b(?=[A-Za-z0-9+/=_\-]*[0-9])(?=[A-Za-z0-9+/=_\-]*[A-Za-z])[A-Za-z0-9+/=_\-]{24,}\b", RegexOptions.Compiled);
    private static readonly Regex HomeWin = new(@"(?i)[A-Z]:\\Users\\[^\\\s""']+", RegexOptions.Compiled);
    private static readonly Regex HomeUnix = new(@"/Users/[^/\s""']+", RegexOptions.Compiled);
    private static readonly Regex AbsolutePath = new(
        @"(?<![\w])((?:[A-Za-z]:\\|\\\\)[^\s""',;|<>]+|/(?:Volumes|Users|private|tmp|var|home|mnt)(?:/[^\s""',;:|<>]+)+|~(?:[\\/][^\s""',;:|<>]+)+)",
        RegexOptions.Compiled);

    private static readonly string[] SensitiveKeys =
        { "token", "secret", "password", "passwd", "pwd", "licen", "serial", "authorization", "bearer",
          "cookie", "apikey", "api_key", "email", "machineid", "machine_id", "devicekey", "device_key", "nonce", "signature",
          "payload", "request_id", "requestid", "activation" };

    public static bool IsSensitiveKey(string key) =>
        SensitiveKeys.Any(k => key.ToLowerInvariant().Contains(k));

    public static Dictionary<string, string> RedactFields(IDictionary<string, string> fields) =>
        fields.ToDictionary(kv => kv.Key, kv => IsSensitiveKey(kv.Key) ? "<redacted>" : RedactSecrets(kv.Value));

    public static string RedactSecrets(string s)
    {
        s = Email.Replace(s, "<email>");
        s = JsonSensitive.Replace(s, "$1$2\"<redacted>\"");
        s = StrictKeyValue.Replace(s, "$1$2<redacted>");
        s = KeyValue.Replace(s, "$1$2<redacted>");
        s = LongToken.Replace(s, "<secret>");
        s = HomeWin.Replace(s, "~");
        s = HomeUnix.Replace(s, "~");
        return s;
    }

    public static string PathToken(string path)
    {
        var hash = SHA256.HashData(Encoding.UTF8.GetBytes(path));
        var shortHex = Convert.ToHexString(hash, 0, 4).ToLowerInvariant();
        var ext = Path.GetExtension(path).TrimStart('.');
        return string.IsNullOrEmpty(ext) || ext.Length > 8 ? $"<path#{shortHex}>" : $"<path#{shortHex}>.{ext.ToLowerInvariant()}";
    }

    public static string AnonymizePaths(string s) => AbsolutePath.Replace(s, m => PathToken(m.Value));

    public static string DestinationId(string path) => "d-" + PathToken(path).Substring(6, 8);
}
