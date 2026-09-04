import Foundation
import SwiftUI
import Combine

/// Setări persistate (CLAUDE.md, Faza 1 v3.0.0) — echivalentul Swift al
/// `config.py` din varianta Windows/Python: temă (Regula 18), mărime text
/// (Regula 24), accelerare GPU (override manual — pe Mac accelerarea e
/// mereu VideoToolbox, câmpul rămâne pentru paritate de model cu Windows/
/// export-import de presets, nefolosit efectiv în UI Mac), joburi
/// simultane, și profilul afișat în sidebar (Nume/Email — Regula 12,
/// Machine ID vine direct din `MachineID.display`).
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published var themePreference: ThemePreference {
        didSet { UserDefaults.standard.set(themePreference.rawValue, forKey: Keys.theme) }
    }
    @Published var textScale: TextScale {
        didSet { UserDefaults.standard.set(textScale.rawValue, forKey: Keys.textScale) }
    }
    @Published var maxParallelJobs: Int {
        didSet { UserDefaults.standard.set(maxParallelJobs, forKey: Keys.maxParallelJobs) }
    }
    @Published var userName: String {
        didSet { UserDefaults.standard.set(userName, forKey: Keys.userName) }
    }
    @Published var userEmail: String {
        didSet { UserDefaults.standard.set(userEmail, forKey: Keys.userEmail) }
    }

    private enum Keys {
        static let theme = "cgconvertor_theme_pref"
        static let textScale = "cgconvertor_text_scale"
        static let maxParallelJobs = "cgconvertor_max_parallel_jobs"
        static let userName = "cgconvertor_user_name"
        static let userEmail = "cgconvertor_user_email"
    }

    private init() {
        let defaults = UserDefaults.standard
        themePreference = defaults.string(forKey: Keys.theme).flatMap(ThemePreference.init(rawValue:)) ?? .system
        textScale = defaults.string(forKey: Keys.textScale).flatMap(TextScale.init(rawValue:)) ?? .normal
        let savedJobs = defaults.integer(forKey: Keys.maxParallelJobs)
        maxParallelJobs = savedJobs > 0 ? savedJobs : 1
        userName = defaults.string(forKey: Keys.userName) ?? ""
        userEmail = defaults.string(forKey: Keys.userEmail) ?? ""
    }
}

enum ThemePreference: String, CaseIterable, Identifiable {
    case system, dark, light
    var id: String { rawValue }
    var label: String {
        switch self {
        case .system: return L.t("settings.theme.system")
        case .dark: return L.t("settings.theme.dark")
        case .light: return L.t("settings.theme.light")
        }
    }
}

enum TextScale: String, CaseIterable, Identifiable {
    case small, normal, large, xlarge
    var id: String { rawValue }
    var label: String {
        switch self {
        case .small: return L.t("settings.font.small")
        case .normal: return L.t("settings.font.normal")
        case .large: return L.t("settings.font.large")
        case .xlarge: return L.t("settings.font.xlarge")
        }
    }

    /// Regula 24 — infrastructură NATIVĂ de accesibilitate, aplicată la
    /// rădăcina ferestrei principale (`dynamicTypeSize(...)` în
    /// CGConvertorApp.swift), NU un multiplicator brut de font.
    var dynamicTypeSize: DynamicTypeSize {
        switch self {
        case .small: return .small
        case .normal: return .medium
        case .large: return .large
        case .xlarge: return .xLarge
        }
    }
}
