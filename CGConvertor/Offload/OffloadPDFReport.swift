import AppKit
import Foundation

// MARK: - Raport PDF al copierii și verificării
//
// Generat local, cu CoreGraphics (fără servicii externe). Arată distinct fișierele sursă și
// copiile verificate pe fiecare destinație; extragerea metadatelor are secțiunea ei și nu
// influențează verdictul copiei.

struct OffloadPDFInput {
    var folderName: String
    var meta: ProductionMeta
    var sources: [String]
    var outcomeLabel: String
    var results: [OffloadDestinationResult]
    var metadata: MetadataSummary?
    var duration: Double
}

/// Hârtie = culori fixe: culorile dinamice ale sistemului (labelColor etc.) devin albe în modul Dark și textul ar dispărea pe pagina albă.
private extension NSColor {
    static let pdfInk = NSColor(srgbRed: 0.08, green: 0.08, blue: 0.09, alpha: 1)
    static let pdfSecondary = NSColor(srgbRed: 0.38, green: 0.38, blue: 0.41, alpha: 1)
    static let pdfAlert = NSColor(srgbRed: 0.78, green: 0.12, blue: 0.10, alpha: 1)
}

enum OffloadPDFReport {
    private static let pageW: CGFloat = 595, pageH: CGFloat = 842, margin: CGFloat = 40

    /// Rânduri de sursă: un rând per fișier (de pe prima destinație care îl are), în ordine alfabetică.
    static func sourceRows(_ results: [OffloadDestinationResult]) -> [OffloadReportRow] {
        var seen = Set<String>(); var out: [OffloadReportRow] = []
        for r in results { for row in r.rows where seen.insert(row.relPath).inserted { out.append(row) } }
        return out.sorted { $0.relPath.localizedStandardCompare($1.relPath) == .orderedAscending }
    }

    static func verifiedCopyCount(_ results: [OffloadDestinationResult]) -> Int {
        results.reduce(0) { $0 + $1.rows.filter { $0.status.hasPrefix("OK") }.count }
    }

    @discardableResult
    static func write(_ input: OffloadPDFInput, to url: URL) -> Bool {
        var box = CGRect(x: 0, y: 0, width: pageW, height: pageH)
        guard let ctx = CGContext(url as CFURL, mediaBox: &box, [
            kCGPDFContextTitle as String: L.t("pdf.docTitle") + " — \(input.folderName)",
            kCGPDFContextCreator as String: "CG Convertor"] as CFDictionary) else { return false }
        let w = Writer(ctx: ctx)
        w.newPage()
        w.text("CG Convertor — " + L.t("pdf.docTitle"), size: 18, bold: true)
        w.text(input.folderName, size: 11, mono: true, color: .pdfSecondary)
        w.space(6)
        let m = input.meta
        let ident = [(L.t("pdf.project"), m.project), (L.t("pdf.card"), m.card), (L.t("pdf.camera"), m.camera), (L.t("pdf.operator"), m.operatorName), (L.t("pdf.client"), m.client)]
            .filter { !$0.1.isEmpty }.map { "\($0.0): \($0.1)" }.joined(separator: "   ")
        if !ident.isEmpty { w.text(ident, size: 10) }
        w.text(L.t("pdf.verdict") + ": \(input.outcomeLabel)", size: 12, bold: true)
        let srcRows = sourceRows(input.results)
        let copies = verifiedCopyCount(input.results)
        w.text(String(format: L.t("pdf.summary"), srcRows.count, copies, input.results.count, Int(input.duration)),
               size: 10, color: .pdfSecondary)
        if let r = input.results.first, !r.verificationLabel.isEmpty { w.text(L.t("pdf.verification") + ": \(r.verificationLabel)", size: 10, color: .pdfSecondary) }
        w.space(10)

        w.text(L.t("pdf.sources"), size: 13, bold: true)
        for src in input.sources { w.text(src, size: 8, mono: true, color: .pdfSecondary) }
        w.space(3)
        w.row([L.t("pdf.file"), L.t("pdf.size"), L.t("pdf.srcSum")], widths: [300, 70, 145], header: true)
        for r in srcRows { w.row([r.relPath, formatBytes(Int64(r.sizeBytes)), String(r.srcHash.prefix(16))], widths: [300, 70, 145]) }
        w.space(10)

        for (i, res) in input.results.enumerated() {
            w.text(L.t("pdf.copy") + " \(i + 1) — \((res.destination as NSString).lastPathComponent)", size: 13, bold: true)
            w.text(res.targetRoot, size: 8, mono: true, color: .pdfSecondary)
            w.text(String(format: L.t("pdf.counts"), res.okCount, res.mismatchCount, res.errorCount, res.recoveredCount), size: 10)
            w.space(3)
            w.row([L.t("pdf.file"), L.t("pdf.state"), L.t("pdf.dstSum")], widths: [300, 70, 145], header: true)
            for r in res.rows {
                w.row([r.relPath, r.status.hasPrefix("OK") ? L.t("pdf.verified") : L.t("pdf.notVerified"), String(r.dstHash.prefix(16))],
                      widths: [300, 70, 145], alert: !r.status.hasPrefix("OK"))
                if !r.error.isEmpty { w.text("  \(r.error)", size: 8, color: .pdfAlert) }
            }
            w.space(10)
        }

        if let md = input.metadata {
            w.text(L.t("pdf.metaTitle"), size: 13, bold: true)
            w.text(String(format: L.t("pdf.metaCounts"), md.found, md.written, md.failed, md.notVerified),
                   size: 10)
            if md.refusedForeign > 0 { w.text(String(format: L.t("pdf.metaForeign"), md.refusedForeign), size: 9, color: .pdfSecondary) }
            if md.coreUnavailable { w.text(L.t("pdf.metaCore"), size: 9, color: .pdfSecondary) }
            for r in md.results where r.verdict != .found { w.text("  \(r.relPath): \(r.verdict.rawValue)\(r.error.map { " — \($0)" } ?? "")", size: 8, mono: true) }
        }
        w.finish()
        return true
    }

    private final class Writer {
        let ctx: CGContext
        var y: CGFloat = 0
        var page = 0
        init(ctx: CGContext) { self.ctx = ctx }

        func newPage() {
            if page > 0 { footer(); ctx.endPDFPage() }
            ctx.beginPDFPage(nil)
            page += 1
            y = pageH - margin
        }
        func finish() { footer(); ctx.endPDFPage(); ctx.closePDF() }
        func footer() {
            draw("CG Convertor · " + L.t("pdf.page") + " \(page)", x: margin, baseline: 20, font: .systemFont(ofSize: 8), color: .pdfSecondary)
        }
        func space(_ h: CGFloat) { y -= h }
        func ensure(_ h: CGFloat) { if y - h < margin + 14 { newPage() } }

        func text(_ s: String, size: CGFloat, bold: Bool = false, mono: Bool = false, color: NSColor = .pdfInk) {
            let font: NSFont = mono ? .monospacedSystemFont(ofSize: size, weight: .regular)
                : (bold ? .boldSystemFont(ofSize: size) : .systemFont(ofSize: size))
            let h = size + 4
            ensure(h)
            y -= h
            draw(s, x: margin, baseline: y, font: font, color: color, maxWidth: pageW - 2 * margin)
        }
        func row(_ cols: [String], widths: [CGFloat], header: Bool = false, alert: Bool = false) {
            let size: CGFloat = 8
            ensure(size + 5)
            y -= size + 5
            var x = margin
            for (c, w) in zip(cols, widths) {
                let font: NSFont = header ? .boldSystemFont(ofSize: size) : .monospacedSystemFont(ofSize: size, weight: .regular)
                draw(c, x: x, baseline: y, font: font, color: alert ? .pdfAlert : .pdfInk, maxWidth: w - 6)
                x += w
            }
        }
        private func draw(_ s: String, x: CGFloat, baseline: CGFloat, font: NSFont, color: NSColor, maxWidth: CGFloat = .greatestFiniteMagnitude) {
            let style = NSMutableParagraphStyle(); style.lineBreakMode = .byTruncatingMiddle
            let attr = NSAttributedString(string: s, attributes: [.font: font, .foregroundColor: color, .paragraphStyle: style])
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
            attr.draw(in: CGRect(x: x, y: baseline, width: min(maxWidth, pageW - x - margin + 0), height: font.pointSize + 4))
            NSGraphicsContext.restoreGraphicsState()
        }
    }
}
