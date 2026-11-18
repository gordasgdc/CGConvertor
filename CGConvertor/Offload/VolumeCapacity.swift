import Foundation

/// Capacitatea unui volum (total + liber), citită o singură dată per
/// actualizare de listă. Liber = capacitate utilizabilă reală pe APFS.
/// Spațiu liber real pe volumul lui `url`. `volumeAvailableCapacityForImportantUsage` întoarce 0 (nu nil)
/// pe unele volume externe/exFAT — atunci se folosește `volumeAvailableCapacity`. nil = necitibil.
nonisolated func freeSpaceBytes(at url: URL) -> Int64? {
    if let v = try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]),
       let important = v.volumeAvailableCapacityForImportantUsage, important > 0 { return important }
    // statfs = sursa autoritară când API-urile de resurse întorc 0/lipsă; 0 de aici înseamnă disc cu adevărat plin.
    var st = statfs()
    if statfs(url.path, &st) == 0 { return Int64(st.f_bavail) * Int64(st.f_bsize) }
    if let v = try? url.resourceValues(forKeys: [.volumeAvailableCapacityKey]),
       let a = v.volumeAvailableCapacity, a > 0 { return Int64(a) }
    return nil // necunoscut ≠ plin: apelantul nu blochează
}

struct VolumeCapacity {
    let total: Int64
    let free: Int64

    static func of(_ path: String) -> VolumeCapacity? {
        let url = URL(fileURLWithPath: path)
        guard let v = try? url.resourceValues(forKeys: [.volumeTotalCapacityKey,
                                                         .volumeAvailableCapacityForImportantUsageKey,
                                                         .volumeAvailableCapacityKey]),
              let total = v.volumeTotalCapacity else { return nil }
        // exFAT/FAT: „important usage” vine 0 (nu nil) — vezi OffloadRunner.freeBytes.
        let free = freeSpaceBytes(at: url) ?? Int64(v.volumeAvailableCapacity ?? 0)
        return VolumeCapacity(total: Int64(total), free: free)
    }
}
