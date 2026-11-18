import SwiftUI

/// Alegerea unui interval din clip. Valori: secunde ("90"), "mm:ss" sau "hh:mm:ss[.zecimale]".
struct IntervalSheet: View {
    let job: VideoJob
    @Binding var isPresented: Bool
    let onApply: (Double?, Double?) -> Void
    @State private var start = ""
    @State private var end = ""
    @State private var duration: Double?

    static func parse(_ t: String) -> Double? {
        let t = t.trimmingCharacters(in: .whitespaces)
        if t.isEmpty { return nil }
        let p = t.split(separator: ":").map(String.init)
        guard p.count <= 3 else { return nil }
        var total = 0.0
        for c in p { guard let v = Double(c.replacingOccurrences(of: ",", with: ".")), v >= 0 else { return nil }; total = total * 60 + v }
        return total
    }
    static func text(_ v: Double?) -> String {
        guard let v else { return "" }
        let h = Int(v) / 3600, m = (Int(v) / 60) % 60, s = v - Double(h * 3600 + m * 60)
        return String(format: "%02d:%02d:%06.3f", h, m, s)
    }

    private var s: Double? { Self.parse(start) }
    private var e: Double? { Self.parse(end) }
    private var invalid: Bool {
        if !start.isEmpty && s == nil { return true }
        if !end.isEmpty && e == nil { return true }
        if let a = s, let b = e, b <= a { return true }
        if let d = duration, let b = e, b > d + 0.5 { return true }
        if let d = duration, let a = s, a >= d { return true }
        return false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L.t("interval.title")).font(.title3).bold()
            Text(job.numeFisier).font(.caption).foregroundStyle(Shift.muted).lineLimit(1).truncationMode(.middle)
            if let d = duration { Text("\(L.t("interval.clipLength")): \(Self.text(d))").font(.caption).foregroundStyle(Shift.muted) }
            TextField(L.t("interval.start"), text: $start).textFieldStyle(.roundedBorder)
            TextField(L.t("interval.end"), text: $end).textFieldStyle(.roundedBorder)
            Text(L.t("interval.help")).font(.caption2).foregroundStyle(Shift.faint).fixedSize(horizontal: false, vertical: true)
            if invalid { Text(L.t("interval.invalid")).font(.caption).foregroundStyle(Shift.error) }
            HStack {
                Button(L.t("interval.clear")) { onApply(nil, nil); isPresented = false }
                Spacer()
                Button(L.t("interval.cancel")) { isPresented = false }
                Button(L.t("interval.apply")) { onApply(s, e); isPresented = false }
                    .buttonStyle(.borderedProminent).disabled(invalid || (s == nil && e == nil))
            }
        }
        .padding(20).frame(width: 400)
        .background(Shift.bg).foregroundStyle(Shift.text)
        .onAppear {
            start = Self.text(job.intervalStart); end = Self.text(job.intervalEnd)
            duration = job.metadataMedia?.durataSecunde
        }
    }
}
