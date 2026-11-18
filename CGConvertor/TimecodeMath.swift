import Foundation

/// Aritmetică de timecode (NDF și drop-frame 29,97/59,94) pentru intervalul ales.
enum TimecodeMath {
    /// `tc` = "HH:MM:SS:FF" sau "HH:MM:SS;FF" (';' = drop-frame). `fps` = cadre/s reale (ex. 29,97).
    static func offset(_ tc: String, frames delta: Int, fps: Double) -> String? {
        let drop = tc.contains(";")
        let parts = tc.split(whereSeparator: { ":;".contains($0) }).compactMap { Int($0) }
        guard parts.count == 4 else { return nil }
        let nominal = Int(fps.rounded())
        guard nominal > 0 else { return nil }
        var n = number(h: parts[0], m: parts[1], s: parts[2], f: parts[3], nominal: nominal, drop: drop) + delta
        if n < 0 { return nil }
        let day = 24 * 3600 * nominal
        n %= day
        return format(n, nominal: nominal, drop: drop)
    }

    private static func dropCount(_ nominal: Int) -> Int { nominal / 15 }   // 2 la 30, 4 la 60

    static func number(h: Int, m: Int, s: Int, f: Int, nominal: Int, drop: Bool) -> Int {
        var total = ((h * 3600 + m * 60 + s) * nominal) + f
        if drop {
            let d = dropCount(nominal), totalMinutes = h * 60 + m
            total -= d * (totalMinutes - totalMinutes / 10)
        }
        return total
    }

    static func format(_ number: Int, nominal: Int, drop: Bool) -> String {
        var n = number
        if drop {
            let d = dropCount(nominal)
            let per10 = nominal * 600 - d * 9, per1 = nominal * 60 - d
            let tens = n / per10, rem = n % per10
            n += d * 9 * tens
            if rem > d { n += d * ((rem - d) / per1) }
        }
        let f = n % nominal, s = (n / nominal) % 60, m = (n / (nominal * 60)) % 60, h = n / (nominal * 3600)
        return String(format: "%02d:%02d:%02d%@%02d", h, m, s, drop ? ";" : ":", f)
    }
}
