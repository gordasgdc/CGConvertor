import Foundation

/// Metadatele producției, atașate unui offload — port din DataMover
/// (`~/Developer/DataMover/mac-native/Sources/DataMoverMac/ProductionMeta.swift`),
/// cerut explicit de Cristi: "raportul unui offload nu e un log tehnic, e
/// un DOCUMENT DE PREDARE" — ajunge la producător, la casa de post, uneori
/// la asigurator, și trebuie să identifice proiectul/clientul/cardul/
/// camera/operatorul, cu logo-ul companiei în antet, ca să poată fi trimis
/// mai departe ca atare.
struct ProductionMeta: Equatable {
    var project = ""
    var card = ""
    var client = ""
    var operatorName = ""
    var camera = ""
    var notes = ""
    /// Cale către un fișier imagine (PNG/JPG) folosit ca logo în antetul
    /// rapoartelor. Gol = fără logo, raportul rămâne la fel de valid.
    var logoPath = ""

    var hasAnyBranding: Bool {
        !(client.isEmpty && operatorName.isEmpty && camera.isEmpty && notes.isEmpty && logoPath.isEmpty)
    }

    /// Perechile completate, gata de afișat în antetul unui raport.
    /// Câmpurile goale NU apar deloc.
    func headerFields() -> [(String, String)] {
        var fields: [(String, String)] = []
        if !project.isEmpty { fields.append(("Proiect", project)) }
        if !client.isEmpty { fields.append(("Client", client)) }
        if !card.isEmpty { fields.append(("Card", card)) }
        if !camera.isEmpty { fields.append(("Cameră", camera)) }
        if !operatorName.isEmpty { fields.append(("Operator / DIT", operatorName)) }
        return fields
    }
}

/// Raport HTML brandat — pe lângă CSV-ul deja existent (offload_report_*.csv).
/// Un singur fișier auto-conținut (logo ca data URI), deschis automat la
/// final, la fel ca raportul de conversie din Convertor.
enum OffloadHTMLReport {
    static func write(path: String, destination: String, folderName: String, rows: [OffloadReportRow],
                       meta: ProductionMeta, startedAt: Date, finishedAt: Date,
                       okCount: Int, mismatchCount: Int, errorCount: Int,
                       verificationLabel: String, mhlPath: String?, truncatedNote: String?) -> Bool {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm:ss"

        var html = """
        <!doctype html>
        <html lang="ro"><head><meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>Raport offload — \(escape(folderName))</title>
        <style>
        :root { color-scheme: dark; }
        body { margin:0; padding:24px; background:#14161A; color:#EDEFF2;
               font: 14px/1.5 -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; }
        .wrap { max-width: 1100px; margin: 0 auto; }
        header { display:flex; align-items:center; gap:16px; border-bottom:1px solid #2A2F36; padding-bottom:16px; }
        header img { max-height:56px; max-width:200px; }
        h1 { font-size:20px; margin:0 0 4px; }
        .sub { color:#9AA3AE; font-size:13px; }
        .meta { display:grid; grid-template-columns:repeat(auto-fit,minmax(200px,1fr)); gap:8px 24px; margin:18px 0; }
        .meta div span { color:#9AA3AE; display:block; font-size:11px; text-transform:uppercase; letter-spacing:.04em; }
        .cards { display:flex; flex-wrap:wrap; gap:12px; margin:18px 0; }
        .card { background:#1A1D22; border:1px solid #2A2F36; border-radius:8px; padding:12px 16px; min-width:110px; }
        .card b { display:block; font-size:22px; }
        .ok b { color:#4ADE80; } .mismatch b { color:#D08C40; } .fail b { color:#F87171; }
        .notes { background:#1A1D22; border-left:3px solid #D08C40; padding:10px 14px; border-radius:4px; white-space:pre-wrap; }
        table { width:100%; border-collapse:collapse; margin-top:16px; font-size:12px; }
        th { text-align:left; color:#9AA3AE; font-weight:600; border-bottom:1px solid #2A2F36; padding:6px 8px; }
        td { padding:6px 8px; border-bottom:1px solid #20242A; word-break:break-all; }
        .s-ok { color:#4ADE80; } .s-fail { color:#F87171; } .s-mismatch { color:#D08C40; }
        footer { margin-top:24px; color:#6B737D; font-size:11px; }
        @media (max-width:700px){ body{padding:14px} table{font-size:11px} }
        </style></head><body><div class="wrap">
        """

        html += "<header>"
        if let logo = logoDataURI(meta.logoPath) {
            html += "<img src=\"\(logo)\" alt=\"logo\">"
        }
        html += "<div><h1>Raport de descărcare (offload)</h1>"
        html += "<div class=\"sub\">\(escape(folderName)) → \(escape(destination))</div></div></header>"

        html += "<div class=\"meta\">"
        for (label, value) in meta.headerFields() {
            html += "<div><span>\(escape(label))</span>\(escape(value))</div>"
        }
        html += "<div><span>Început</span>\(df.string(from: startedAt))</div>"
        html += "<div><span>Terminat</span>\(df.string(from: finishedAt))</div>"
        html += "<div><span>Verificare</span>\(escape(verificationLabel))</div>"
        if let mhlPath {
            html += "<div><span>MHL</span>\(escape((mhlPath as NSString).lastPathComponent))</div>"
        }
        html += "</div>"

        html += "<div class=\"cards\">"
        html += "<div class=\"card ok\"><b>\(okCount)</b>copiate OK</div>"
        if mismatchCount > 0 { html += "<div class=\"card mismatch\"><b>\(mismatchCount)</b>nepotriviri</div>" }
        html += "<div class=\"card fail\"><b>\(errorCount)</b>erori</div>"
        html += "</div>"

        if !meta.notes.isEmpty {
            html += "<div class=\"notes\">\(escape(meta.notes))</div>"
        }

        html += "<table><thead><tr><th>Fișier</th><th>Mărime</th><th>Status</th><th>Eroare</th></tr></thead><tbody>"
        for row in rows {
            let cls = row.status == "OK" ? "s-ok" : (row.status == "NEPOTRIVIRE" ? "s-mismatch" : "s-fail")
            html += "<tr><td>\(escape(row.relPath))</td><td>\(formatBytes(Int64(row.sizeBytes)))</td>"
            html += "<td class=\"\(cls)\">\(escape(row.status))</td><td>\(escape(row.error))</td></tr>"
        }
        html += "</tbody></table>"

        if let truncatedNote {
            html += "<p class=\"sub\">\(escape(truncatedNote))</p>"
        }
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        html += "<footer>Generat de CGConvertor \(escape(version)) — gordas.dev</footer>"
        html += "</div></body></html>"

        do {
            try html.write(toFile: path, atomically: true, encoding: .utf8)
            return true
        } catch {
            return false
        }
    }

    private static func logoDataURI(_ path: String) -> String? {
        guard !path.isEmpty, let data = FileManager.default.contents(atPath: path) else { return nil }
        guard data.count <= 3 * 1024 * 1024 else { return nil }
        let ext = (path as NSString).pathExtension.lowercased()
        let mime = (ext == "jpg" || ext == "jpeg") ? "image/jpeg" : (ext == "gif" ? "image/gif" : "image/png")
        return "data:\(mime);base64,\(data.base64EncodedString())"
    }

    private static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
         .replacingOccurrences(of: "<", with: "&lt;")
         .replacingOccurrences(of: ">", with: "&gt;")
         .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
