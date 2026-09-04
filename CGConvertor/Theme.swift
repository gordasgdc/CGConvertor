import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

/// Identitatea vizuală "Shift" — dark, pro, inspirată de paletele de
/// lucru din DaVinci Resolve (accent cupru/amber, ca pagina de Color, la
/// fel ca restul culorilor de mai jos). Din Faza 1 v3.0.0, paleta e
/// REZOLVATĂ dinamic (System/Dark/Light — Regula 18), nu mai e un set fix
/// de constante — `Shift.bg` etc. rămân accesibile EXACT la fel din tot
/// codul existent (`static var`, nu `static let`), doar valoarea
/// returnată se schimbă cu preferința curentă din `AppSettings.shared`.
enum Shift {
    private static var activePalette: Palette {
        switch AppSettings.shared.themePreference {
        case .dark: return .dark
        case .light: return .light
        case .system: return prefersLightSystemAppearance() ? .light : .dark
        }
    }

    private static func prefersLightSystemAppearance() -> Bool {
        #if canImport(AppKit)
        // Verificată la fiecare acces (nu printr-un observator KVO dedicat)
        // — același compromis pragmatic ca varianta Windows/Python
        // (theme.py, `_system_prefers_light`): suficient pentru că
        // `Shift.*` e citit din `body`-uri SwiftUI, reevaluate frecvent
        // oricum (progres coadă, schimbări de stare) — o schimbare de
        // temă a sistemului în timp ce fereastra e complet inactivă poate
        // întârzia până la următorul re-render, nu instant prin KVO.
        let appearance = NSApp?.effectiveAppearance ?? NSAppearance.currentDrawing()
        return appearance.bestMatch(from: [.aqua, .darkAqua]) == .aqua
        #else
        return false
        #endif
    }

    static var bg: Color { activePalette.bg }
    static var panel: Color { activePalette.panel }
    static var elevated: Color { activePalette.elevated }
    static var border: Color { activePalette.border }
    static var text: Color { activePalette.text }
    static var muted: Color { activePalette.muted }
    static var faint: Color { activePalette.faint }
    static var accent: Color { activePalette.accent }
    static var accentInk: Color { activePalette.accentInk }
    static var success: Color { activePalette.success }
    static var error: Color { activePalette.error }

    fileprivate struct Palette {
        let bg: Color, panel: Color, elevated: Color, border: Color
        let text: Color, muted: Color, faint: Color
        let accent: Color, accentInk: Color, success: Color, error: Color

        static let dark = Palette(
            bg: Color(hex: 0x14161A), panel: Color(hex: 0x1A1D22), elevated: Color(hex: 0x23262C),
            border: Color(hex: 0x2B2F36), text: Color(hex: 0xEDEFF2), muted: Color(hex: 0x93989F),
            faint: Color(hex: 0x5C6169), accent: Color(hex: 0xE8963C), accentInk: Color(hex: 0x1A1108),
            success: Color(hex: 0x4CAF7D), error: Color(hex: 0xE2584A)
        )

        // Varianta Light — ACELAȘI rol semantic per câmp ca `dark`, doar
        // valori coborâte spre un fundal deschis; accentul cupru/amber
        // rămâne recognoscibil, dar puțin mai închis pentru contrast pe alb.
        static let light = Palette(
            bg: Color(hex: 0xF5F4F2), panel: Color(hex: 0xFFFFFF), elevated: Color(hex: 0xEBEAE7),
            border: Color(hex: 0xD8D6D2), text: Color(hex: 0x1D1F23), muted: Color(hex: 0x5B5E64),
            faint: Color(hex: 0x9498A0), accent: Color(hex: 0xC97A22), accentInk: Color(hex: 0xFFFFFF),
            success: Color(hex: 0x2F8F5B), error: Color(hex: 0xC7402F)
        )
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

/// Card generic — panou elevat cu bordură subțire, folosit peste tot în
/// UI-ul Shift (setări, joburi, activare).
struct ShiftCard<Content: View>: View {
    var padding: CGFloat = 14
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .background(Shift.panel)
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Shift.border, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct ShiftSectionLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10.5, weight: .semibold))
            .tracking(0.6)
            .foregroundStyle(Shift.faint)
    }
}
