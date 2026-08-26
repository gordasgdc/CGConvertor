import SwiftUI

/// Identitatea vizuală "Shift" — dark, pro, inspirată de paletele de
/// lucru din DaVinci Resolve (accent cupru/amber, ca pagina de Color,
/// distinct de teal-ul folosit de restul ecosistemului GDC — CG
/// Convertor e un unealtă de imagine/codec, nu o unealtă administrativă).
enum Shift {
    static let bg = Color(hex: 0x14161A)
    static let panel = Color(hex: 0x1A1D22)
    static let elevated = Color(hex: 0x23262C)
    static let border = Color(hex: 0x2B2F36)
    static let text = Color(hex: 0xEDEFF2)
    static let muted = Color(hex: 0x93989F)
    static let faint = Color(hex: 0x5C6169)
    static let accent = Color(hex: 0xE8963C)
    static let accentInk = Color(hex: 0x1A1108)
    static let success = Color(hex: 0x4CAF7D)
    static let error = Color(hex: 0xE2584A)
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
