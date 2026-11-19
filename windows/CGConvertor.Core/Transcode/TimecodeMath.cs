namespace CGConvertor.Core.Transcode;

/// <summary>Port 1:1 al TimecodeMath.swift (drop-frame inclus).</summary>
public static class TimecodeMath
{
    public static string? Offset(string tc, int frames, double fps)
    {
        bool drop = tc.Contains(';');
        var parts = tc.Split(new[] { ':', ';' }).Select(p => int.TryParse(p, out var v) ? (int?)v : null).Where(v => v.HasValue).Select(v => v!.Value).ToArray();
        if (parts.Length != 4) return null;
        int nominal = (int)Math.Round(fps, MidpointRounding.AwayFromZero);
        if (nominal <= 0) return null;
        long n = Number(parts[0], parts[1], parts[2], parts[3], nominal, drop) + frames;
        if (n < 0) return null;
        n %= 24L * 3600 * nominal;
        return Format(n, nominal, drop);
    }

    static int DropCount(int nominal) => nominal / 15;

    public static long Number(int h, int m, int s, int f, int nominal, bool drop)
    {
        long total = ((long)(h * 3600 + m * 60 + s)) * nominal + f;
        if (drop) { int d = DropCount(nominal), tm = h * 60 + m; total -= d * (tm - tm / 10); }
        return total;
    }

    public static string Format(long number, int nominal, bool drop)
    {
        long n = number;
        if (drop)
        {
            int d = DropCount(nominal); long per10 = nominal * 600L - d * 9, per1 = nominal * 60L - d;
            long tens = n / per10, rem = n % per10;
            n += d * 9 * tens;
            if (rem > d) n += d * ((rem - d) / per1);
        }
        long f = n % nominal, s = (n / nominal) % 60, m = (n / (nominal * 60L)) % 60, h = n / (nominal * 3600L);
        return $"{h:00}:{m:00}:{s:00}{(drop ? ';' : ':')}{f:00}";
    }
}
