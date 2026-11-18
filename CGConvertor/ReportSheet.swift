import SwiftUI

/// Rând de raport cu una din cele patru stări distincte. „Citit automat de
/// Resolve” NU apare aici ca verificare per clip: e doar compatibilitate
/// demonstrată pe probe (vezi nota din fereastră).
struct ReportRow: Identifiable {
    enum State { case detected, embeddedVerified, needsSeparate, unknown, notKept }
    let id = UUID()
    let label: String
    let value: String
    let state: State
    let detail: String?
}

enum ReportBuilder {
    static func rows(_ r: ConversionReport, sidecarWritten: Bool) -> [ReportRow] {
        var out: [ReportRow] = []
        func det(_ d: SourceProfile.Detected?) -> (String, String)? {
            guard let d else { return nil }
            return (d.value, L.t("report.kind.\(d.kind)"))
        }
        if let p = r.sourceProfile {
            if let (v, k) = det(p.gamut) { out.append(.init(label: L.t("report.field.gamut"), value: v, state: .detected, detail: k)) }
            else { out.append(.init(label: L.t("report.field.gamut"), value: "—", state: .unknown, detail: nil)) }
            if let (v, k) = det(p.curve) { out.append(.init(label: L.t("report.field.curve"), value: v, state: .detected, detail: k)) }
            else { out.append(.init(label: L.t("report.field.curve"), value: "—", state: .unknown, detail: nil)) }
            let extras: [(String, String?)] = [
                (L.t("report.field.camera"), p.cameraModel), (L.t("report.field.lens"), p.lens),
                (L.t("report.field.focal"), p.focalLength), (L.t("report.field.exposure"),
                 [p.aperture, p.shutter, p.iso.map { "ISO " + $0.replacingOccurrences(of: "ISO", with: "").trimmingCharacters(in: .whitespaces) }].compactMap { $0 }.joined(separator: " · ").nilIfEmpty),
                (L.t("report.field.wb"), p.whiteBalance)]
            for (l, v) in extras {
                guard let v else { continue }
                out.append(.init(label: l, value: v,
                                 state: sidecarWritten ? .needsSeparate : .detected,
                                 detail: sidecarWritten ? L.t("report.inSidecarOnly") : nil))
            }
        } else {
            out.append(.init(label: L.t("report.field.profile"), value: "—", state: .unknown, detail: L.t("report.noProfile")))
        }
        if let tc = r.timecodeSource {
            let ok = r.timecodeOutput == tc
            out.append(.init(label: L.t("report.field.timecode"), value: tc,
                             state: ok ? .embeddedVerified : .notKept,
                             detail: ok ? L.t("report.tcVerified") : L.t("report.tcMismatch")))
        }
        for g in r.kept where g.key == "report.keptTrack" {
            out.append(.init(label: L.t("report.field.nativeTrack"), value: g.arg, state: .embeddedVerified, detail: L.t("report.keptTrack")))
        }
        for n in r.notKept {
            out.append(.init(label: L.t("report.field.nativeTrack"), value: n.arg.isEmpty ? "" : (L.reportTable[n.arg] != nil ? L.t(n.arg) : n.arg),
                             state: .notKept, detail: L.t(n.key)))
        }
        for m in r.metadataProblems {
            out.append(.init(label: L.t("report.field.problem"), value: m.text, state: .notKept, detail: nil))
        }
        return out
    }
}

private extension String { var nilIfEmpty: String? { isEmpty ? nil : self } }

struct ReportSheet: View {
    let fileName: String
    let report: ConversionReport
    @Binding var isPresented: Bool

    private var rows: [ReportRow] {
        ReportBuilder.rows(report, sidecarWritten: report.kept.contains { $0.key == "report.keptSidecar" })
    }

    private func style(_ s: ReportRow.State) -> (String, Color, String) {
        switch s {
        case .detected: return ("eye.circle.fill", Shift.muted, L.t("report.state.detected"))
        case .embeddedVerified: return ("checkmark.seal.fill", Shift.success, L.t("report.state.embedded"))
        case .needsSeparate: return ("doc.badge.arrow.up.fill", Shift.accent, L.t("report.state.separate"))
        case .unknown: return ("questionmark.circle", Shift.faint, L.t("report.state.unknown"))
        case .notKept: return ("exclamationmark.triangle.fill", Shift.error, L.t("report.state.notKept"))
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L.t("report.title")).font(.title3).bold()
            Text(fileName).font(.caption).foregroundStyle(Shift.muted).lineLimit(2).truncationMode(.middle)
            Text(L.t("report.metadataState.\(String(describing: report.metadata))"))
                .font(.callout).foregroundStyle(report.metadata == .incomplete ? Shift.error : Shift.text)

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(rows) { row in
                        let (icon, color, stateText) = style(row.state)
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: icon).foregroundStyle(color).frame(width: 18)
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(alignment: .firstTextBaseline) {
                                    Text(row.label).font(.system(size: 12, weight: .semibold))
                                    Text(row.value).font(.system(size: 12)).textSelection(.enabled)
                                }
                                Text([stateText, row.detail].compactMap { $0 }.joined(separator: " — "))
                                    .font(.system(size: 10.5)).foregroundStyle(Shift.muted)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                        }
                    }
                }
            }
            .frame(maxHeight: 320)

            Text(L.t("report.resolveNote")).font(.caption2).foregroundStyle(Shift.faint)
                .fixedSize(horizontal: false, vertical: true)

            HStack { Spacer(); Button(L.t("report.close")) { isPresented = false }.buttonStyle(.borderedProminent) }
        }
        .padding(20).frame(width: 520)
        .background(Shift.bg).foregroundStyle(Shift.text)
    }
}
