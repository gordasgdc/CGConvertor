import Foundation
import Combine

/// Verificare ONLINE, opțională, peste licențierea existentă (Ed25519,
/// 100% offline) — CLAUDE.md, Partea 1, Regula 12. Port 1:1 al
/// `RevocationCheck.swift` (gdc-plugin-manager-catalog-vendor) pentru CG
/// Convertor — aplicație standalone, fără dependință de pachetul
/// `GDCPluginManagerCore`, deci constantele Supabase sunt copiate direct
/// aici (byte-for-byte, Regula 3: "aceeași cheie publică... copiată
/// byte-for-byte, NU printr-o dependință de pachet între repo-uri").
///
/// FAIL-OPEN, niciodată fail-closed: absența unui răspuns POZITIV de
/// revocare (eroare de rețea, offline, request eșuat) înseamnă NErevocat.
/// O licență deja activată local nu se blochează NICIODATĂ doar pentru că
/// utilizatorul e offline — revocarea se aplică abia la următoarea
/// verificare online reușită care confirmă explicit `true`. Odată marcat
/// revocat, rămâne așa pentru restul acestei sesiuni (nu se "de-revocă"
/// pe un răspuns "false" ulterior).
final class RevocationCheck: ObservableObject {
    static let shared = RevocationCheck()

    private static let supabaseURL = "https://jvxrclpyngdcqnbwvtfn.supabase.co"
    private static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp2eHJjbHB5bmdkY3FuYnd2dGZuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODcwODMxMDksImV4cCI6MjEwMjY1OTEwOX0.uCLgrVPLhovwdBc82KermRbtWykquWoJmg9WmGk2L-s"
    private static let productID = "cgconvertor"
    private static let refreshIntervalSeconds: UInt64 = 6 * 3600

    // @Published (nu doar un lock intern) — bannerul din ContentView
    // trebuie sa reactioneze INSTANT daca o revocare soseste in timp ce
    // aplicatia ruleaza deja, nu doar la urmatoarea lansare.
    @Published private(set) var isRevoked = false

    private init() {}

    /// Verificare unică, fire-and-forget — apelată la lansare și, separat,
    /// din bucla periodică de mai jos.
    func refreshOnce() {
        Task { await checkOnce() }
    }

    /// Pornește o buclă de fundal care reverifică la fiecare 6 ore — o
    /// singură dată, la pornirea aplicației.
    func startPeriodicRefresh() {
        Task.detached { [weak self] in
            while true {
                await self?.checkOnce()
                try? await Task.sleep(nanoseconds: Self.refreshIntervalSeconds * 1_000_000_000)
            }
        }
    }

    private func checkOnce() async {
        guard let url = URL(string: Self.supabaseURL)?.appendingPathComponent("rest/v1/rpc/is_license_revoked") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Self.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(Self.anonKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 8
        let body: [String: String] = ["p_machine_id": MachineID.display, "p_product_id": Self.productID]
        guard let data = try? JSONSerialization.data(withJSONObject: body) else { return }
        request.httpBody = data

        guard let (respData, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            return // fail-open: orice eroare de retea/server -> NU revocat
        }
        // PostgREST pentru o functie ce intoarce `boolean` da inapoi
        // literal `true`/`false` ca body JSON.
        if let text = String(data: respData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
           text == "true" {
            await MainActor.run { self.isRevoked = true }
        }
    }
}
