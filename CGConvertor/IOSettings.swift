import Foundation
#if canImport(Darwin)
import Darwin
#endif

/// Setări de buffer/RAM pentru Offload — port scopit din `DataMover`
/// (`IOSettings.swift`), aceeași filozofie: Regula 21 din CLAUDE.md
/// (Memory & I/O Performance) — buffer fix, configurabil, plus un plafon
/// orientativ de memorie cu backpressure (pauză scurtă între fișiere dacă
/// procesul depășește plafonul), nu o limită impusă strict de OS.
enum IOSettings {
    static let chunkSizeChoicesMB = [1, 2, 4, 8, 16, 32, 64, 128]
    static let ramLimitChoicesMB = [0, 512, 1024, 2048, 4096, 8192, 16384, 32768, 65536] // 0 = fără limită

    static var chunkSizeMB: Int {
        get {
            let v = UserDefaults.standard.integer(forKey: "cgconvertor_offload_chunk_mb")
            return chunkSizeChoicesMB.contains(v) ? v : 8
        }
        set { UserDefaults.standard.set(newValue, forKey: "cgconvertor_offload_chunk_mb") }
    }

    static var ramLimitMB: Int {
        get {
            let v = UserDefaults.standard.integer(forKey: "cgconvertor_offload_ram_limit_mb")
            return ramLimitChoicesMB.contains(v) ? v : 1024
        }
        set { UserDefaults.standard.set(newValue, forKey: "cgconvertor_offload_ram_limit_mb") }
    }

    static var chunkSizeBytes: Int { chunkSizeMB * 1024 * 1024 }
    static var ramLimitBytes: Int { ramLimitMB * 1024 * 1024 }

    struct Preset {
        let name: String
        let chunkMB: Int
        let ramLimitMB: Int
    }

    static let presets: [Preset] = [
        Preset(name: "Eco", chunkMB: 4, ramLimitMB: 1024),
        Preset(name: "Standard", chunkMB: 8, ramLimitMB: 4096),
        Preset(name: "High", chunkMB: 32, ramLimitMB: 16384),
        Preset(name: "Extreme", chunkMB: 64, ramLimitMB: 32768),
    ]

    static func formattedMB(_ mb: Int) -> String {
        if mb == 0 { return "—" }
        if mb >= 1024 { return String(format: "%.0f GB", Double(mb) / 1024.0) }
        return "\(mb) MB"
    }

    /// RSS curent al procesului (mach `task_info`) — folosit pentru backpressure,
    /// nu pentru o afișare de sistem generală.
    static func currentResidentMemoryBytes() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size)
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        return (kerr == KERN_SUCCESS) ? info.resident_size : 0
    }

    /// Backpressure: dacă memoria procesului depășește plafonul configurat,
    /// așteaptă în pași de 0.5s (max 30s), verificat între FIȘIERE (nu la
    /// mijlocul unuia) — la fel ca `DataMover`. `cancel` întrerupe imediat
    /// așteptarea dacă userul apasă Anulează.
    static func waitIfOverRAMLimit(cancel: CancelToken, onWarning: (() -> Void)? = nil) {
        guard ramLimitMB > 0 else { return }
        let limit = UInt64(ramLimitBytes)
        var warned = false
        var waited = 0.0
        while currentResidentMemoryBytes() > limit && waited < 30.0 {
            if cancel.isCancelled { return }
            if !warned {
                onWarning?()
                warned = true
            }
            Thread.sleep(forTimeInterval: 0.5)
            waited += 0.5
        }
    }
}
