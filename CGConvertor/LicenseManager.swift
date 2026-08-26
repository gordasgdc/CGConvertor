import Foundation
import Combine

/// Deține starea de probă/licență a CG Convertor: pornește o probă de 15
/// zile la prima lansare, persistă un cod activat odată introdus, și
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
    static let trialDurationDays = 15

    @Published private(set) var isLicensed = false
    @Published private(set) var licenseExpiresAt: Int64 = 0 // 0 = perpetuu
    @Published private(set) var licenseMachineLocked = false
    @Published var activationError: String?

    private let defaults = UserDefaults.standard
    private let trialStartKey = "cgconvertor_trial_start"

    private var activationFileURL: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("CGConvertor", isDirectory: true)
            .appendingPathComponent("license.txt")
    }

    private init() {
        if defaults.object(forKey: trialStartKey) == nil {
            defaults.set(Date().timeIntervalSince1970, forKey: trialStartKey)
        }
        loadSavedLicense()
    }

    var trialStartDate: Date {
        Date(timeIntervalSince1970: defaults.double(forKey: trialStartKey))
    }

    /// Zile întregi rămase din probă, rotunjit în sus.
    var trialDaysRemaining: Int {
        let elapsed = Date().timeIntervalSince(trialStartDate)
        let remaining = Double(Self.trialDurationDays) * 86400 - elapsed
        return max(0, Int(ceil(remaining / 86400)))
    }

    var isTrialActive: Bool { trialDaysRemaining > 0 }

    var isUnlocked: Bool { isLicensed || isTrialActive }

    @discardableResult
    func activate(code: String) -> Bool {
        activationError = nil
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        switch LicenseCore.validate(serial: trimmed, expectedProductID: Self.productID) {
        case .success(let payload):
            saveLicense(code: trimmed)
            applyLicense(payload: payload)
            return true
        case .failure(let error):
            activationError = Self.message(for: error)
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
