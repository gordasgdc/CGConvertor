import Foundation
import Combine
import Security

/// Deține starea de probă/licență a CG Convertor: pornește o probă de 5
/// zile la prima lansare (utilizatori noi; probele deja începute își
/// păstrează durata acordată inițială, 15 zile), persistă un cod activat odată introdus, și
/// expune dacă aplicația ar trebui deblocată acum. Port 1:1 al
/// `LicenseManager.swift` din GDCVault/DataMover — același `LicenseCore`/
/// cheie de semnare, doar productID și durata diferite.
///
/// DECIZIE DE PRODUS: spre deosebire de GDC Vault (unde proba expirată
/// tot lasă acces la datele existente), aici — la fel ca DataMover —
/// `isUnlocked` blochează direct butonul "Pornește conversia": un
/// convertor de fișiere nu are "date vechi" de protejat, doar o
/// funcționalitate activă/inactivă.
final class LicenseManager: ObservableObject {
    static let shared = LicenseManager()
    static let productID = "cgconvertor"
    /// Utilizatori noi: exact 5 zile.
    static let newTrialDays = 5
    /// Probele începute înainte de această versiune au primit 15 zile; nu se scurtează.
    static let legacyTrialDays = 15

    @Published private(set) var isLicensed = false
    @Published private(set) var licenseExpiresAt: Int64 = 0 // 0 = perpetuu
    @Published private(set) var licenseMachineLocked = false
    @Published var activationError: String?

    private let defaults: UserDefaults
    private let trialStartKey = "cgconvertor_trial_start"
    private let trialDaysKey = "cgconvertor_trial_days_granted"
    private let markerService: String
    private let now: () -> Date
    /// Durata efectiv acordată acestei probe (5 la utilizatori noi, 15 la cele vechi).
    private(set) var trialGrantedDays: Int

    private var activationFileURL: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("CGConvertor", isDirectory: true)
            .appendingPathComponent("license.txt")
    }

    private convenience init() {
        self.init(defaults: .standard, markerService: "dev.gordas.CGConvertor.trial", now: Date.init)
    }

    /// `internal` doar pentru verificari izolate (suita de defaults + serviciu Keychain proprii).
    ///
    /// Inceputul probei si durata acordata se tin in DOUA locuri: UserDefaults si un
    /// element Keychain. Stergerea preferintelor sau reinstalarea nu reporneste proba;
    /// aceasta e o protectie LOCALA (un utilizator hotarat poate sterge si elementul
    /// Keychain), nu o garantie. Prioritate: Keychain.
    init(defaults: UserDefaults, markerService: String, now: @escaping () -> Date) {
        self.defaults = defaults
        self.markerService = markerService
        self.now = now
        let marker = TrialMarker.read(service: markerService)
        var start: Double
        var days: Int
        if let m = marker {
            start = m.start; days = m.days
        } else if defaults.object(forKey: trialStartKey) != nil {
            // proba inceputa inainte de aceasta versiune: pastreaza durata acordata initial
            start = defaults.double(forKey: trialStartKey)
            let saved = defaults.integer(forKey: trialDaysKey)
            days = saved > 0 ? saved : Self.legacyTrialDays
        } else {
            start = now().timeIntervalSince1970
            days = Self.newTrialDays
        }
        defaults.set(start, forKey: trialStartKey)
        defaults.set(days, forKey: trialDaysKey)
        if marker == nil { TrialMarker.write(service: markerService, start: start, days: days) }
        trialGrantedDays = days
        loadSavedLicense()
    }

    var trialStartDate: Date {
        Date(timeIntervalSince1970: defaults.double(forKey: trialStartKey))
    }

    /// Zile întregi rămase din probă, rotunjit în sus.
    var trialDaysRemaining: Int {
        let elapsed = now().timeIntervalSince(trialStartDate)
        let remaining = Double(trialGrantedDays) * 86400 - elapsed
        return max(0, Int(ceil(remaining / 86400)))
    }

    var isTrialActive: Bool { trialDaysRemaining > 0 }

    /// Stare de acces pentru diagnostic: fără cod de licență, serial sau identificatori.
    var diagnosticSummary: [String: String] {
        ["mode": isLicensed ? "licensed" : (isTrialActive ? "trial" : "demo"),
         "trialDaysRemaining": "\(trialDaysRemaining)", "trialGrantedDays": "\(trialGrantedDays)",
         "unlocked": "\(isUnlocked)"]
    }

    // Regula 12 — revocare online, fail-open (vezi RevocationCheck.swift):
    // o licenta deja activata local NU e blocata doar pentru ca userul e
    // offline, dar un "true" explicit primit de la server opreste imediat
    // butonul de start, indiferent de trial/licenta valida criptografic.
    var isUnlocked: Bool { (isLicensed || isTrialActive) && !RevocationCheck.shared.isRevoked }

    @discardableResult
    func activate(code: String) -> Bool {
        activationError = nil
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        switch LicenseCore.validate(serial: trimmed, expectedProductID: Self.productID) {
        case .success(let payload):
            saveLicense(code: trimmed)
            applyLicense(payload: payload)
            StructuredLog.shared.log(.info, "license", "license.activate.ok", "Licenta activata")
            return true
        case .failure(let error):
            activationError = Self.message(for: error)
            StructuredLog.shared.log(.warning, "license", "license.activate.fail", "Activare respinsa", fields: ["reason": "\(error)"])
            return false
        }
    }

    func deactivate() {
        isLicensed = false
        licenseExpiresAt = 0
        licenseMachineLocked = false
        if let url = activationFileURL {
            try? FileManager.default.removeItem(at: url)
        }
    }

    private func loadSavedLicense() {
        guard let url = activationFileURL,
              let code = try? String(contentsOf: url, encoding: .utf8) else { return }
        if case .success(let payload) = LicenseCore.validate(serial: code, expectedProductID: Self.productID) {
            applyLicense(payload: payload)
        }
    }

    private func applyLicense(payload: LicenseCore.Payload) {
        isLicensed = true
        licenseExpiresAt = payload.expiresAt
        licenseMachineLocked = payload.machineLocked
    }

    private func saveLicense(code: String) {
        guard let url = activationFileURL else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? code.write(to: url, atomically: true, encoding: .utf8)
    }

    private static func message(for error: LicenseCore.ValidationError) -> String {
        switch error {
        case .malformedCode: return L.t("license.error.malformed")
        case .badSignature: return L.t("license.error.badSignature")
        case .wrongProduct: return L.t("license.error.wrongProduct")
        case .wrongMachine: return L.t("license.error.wrongMachine")
        case .expired: return L.t("license.error.expired")
        }
    }
}

/// Marcaj persistent al probei in Keychain (generic password), independent de preferinte.
enum TrialMarker {
    static func read(service: String) -> (start: Double, days: Int)? {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                kSecAttrService as String: service, kSecAttrAccount as String: "trial",
                                kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var out: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let d = out as? Data,
              let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
              let s = j["start"] as? Double, let n = j["days"] as? Int else { return nil }
        return (s, n)
    }

    static func write(service: String, start: Double, days: Int) {
        guard let d = try? JSONSerialization.data(withJSONObject: ["start": start, "days": days]) else { return }
        let base: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                   kSecAttrService as String: service, kSecAttrAccount as String: "trial"]
        SecItemDelete(base as CFDictionary)
        var add = base; add[kSecValueData as String] = d
        SecItemAdd(add as CFDictionary, nil)
    }

    static func delete(service: String) {
        SecItemDelete([kSecClass as String: kSecClassGenericPassword,
                       kSecAttrService as String: service, kSecAttrAccount as String: "trial"] as CFDictionary)
    }
}
