import Foundation
import AppKit

/// Comparația de metadate — REFĂCUTĂ COMPLET (2026-09-06), cerut explicit
/// de Cristi după ce a folosit efectiv fereastra nativă anterioară (sheet
/// SwiftUI, eliminat complet din acest fișier): "nu pot să văd... trebuie
/// să fie ca un HTML sau ca un PDF... nu ca un pop-up mic". "Compară (N)"
/// generează acum direct o pagină HTML autonomă (căutare + evidențiere
/// diferențe + ascundere identice, toate în JS simplu, fără dependințe)
/// și o deschide în browser, exact ca „Generează raport" — un tab de
/// browser normal, redimensionabil/maximizabil ca orice fereastră.
/// Motorul de extragere (`MetadataCompareEngine.categorii`, tipul
/// `MetadataCategory`) rămâne în `MetadataCompare.swift` — acest fișier
/// adaugă DOAR generarea de HTML, ca extensie a aceluiași engine.
extension MetadataCompareEngine {
    static func deschideComparatie(jobs: [VideoJob]) {
        var categoriiPerJob: [UUID: [MetadataCategory]] = [:]
        for job in jobs {
            categoriiPerJob[job.id] = categorii(pentru: job.urlSursa)
        }

        var ordineCategorii: [String] = []
        var labeluriPeCategorie: [String: [String]] = [:]
        for job in jobs {
            guard let categorii = categoriiPerJob[job.id] else { continue }
            for cat in categorii {
                if !ordineCategorii.contains(cat.name) { ordineCategorii.append(cat.name) }
                var labeluri = labeluriPeCategorie[cat.name] ?? []
                for (label, _) in cat.rows where !labeluri.contains(label) { labeluri.append(label) }
                labeluriPeCategorie[cat.name] = labeluri
            }
        }

        func valoare(_ job: VideoJob, _ categorie: String, _ label: String) -> String? {
            categoriiPerJob[job.id]?.first(where: { $0.name == categorie })?.rows.first(where: { $0.label == label })?.value
        }

        var randuriHTML = ""
        for categorie in ordineCategorii {
            guard let labeluri = labeluriPeCategorie[categorie], !labeluri.isEmpty else { continue }
            randuriHTML += "<tr class=\"cat\"><td colspan=\"\(jobs.count + 1)\">\(escapeHTML(categorie.uppercased()))</td></tr>\n"
            for label in labeluri {
                let valori = jobs.map { valoare($0, categorie, label) ?? "—" }
                let identic = Set(valori).count <= 1
                let celule = valori.map { "<td>\(escapeHTML($0))</td>" }.joined()
                randuriHTML += "<tr class=\"row\(identic ? " identic" : " diferit")\" data-search=\"\(escapeHTML((categorie + " " + label).lowercased()))\"><td class=\"label\">\(escapeHTML(label))</td>\(celule)</tr>\n"
            }
        }

        // Thumbnail per coloana (2026-09-06, cerut de Cristi: "mi-ar fi
        // placut sa apara acel thumbnail deasupra la fiecare clip... ca sa
        // stie pe fiecare clip pe care sa se uite"). Reutilizeaza
        // thumbnail-ul deja generat pentru coada (`caleThumbnail`) daca
        // exista; altfel il genereaza pe loc (acelasi motor ca raportul).
        func thumbnailData(_ job: VideoJob) -> String {
            var cale = job.caleThumbnail
            if cale == nil || !FileManager.default.fileExists(atPath: cale!) {
                let iesire = MediaInspector.folderThumbnailuri().appendingPathComponent("compare_\(job.id.uuidString).jpg")
                if MediaInspector.genereazaThumbnail(url: job.urlSursa, lutPath: nil, iesire: iesire) {
                    cale = iesire.path
                }
            }
            guard let cale, let data = FileManager.default.contents(atPath: cale) else { return "" }
            return "<img class=\"thumb\" src=\"data:image/jpeg;base64,\(data.base64EncodedString())\">"
        }

        let antetColoane = jobs.map { "<th>\(thumbnailData($0))<div class=\"fname\">\(escapeHTML($0.numeFisier))</div></th>" }.joined()

        let html = """
        <!DOCTYPE html><html><head><meta charset="utf-8">
        <title>Comparație metadate — CG Convertor</title>
        <style>
        :root { color-scheme: dark; }
        body{font-family:-apple-system,Helvetica,Arial,sans-serif;background:#14161A;color:#EDEFF2;margin:0;padding:28px 32px 60px}
        h1{color:#E8963C;font-size:20px;margin:0 0 4px}
        .subtitle{color:#8A8F98;font-size:13px;margin:0 0 20px}
        .toolbar{position:sticky;top:0;background:#14161A;padding:10px 0 16px;display:flex;gap:16px;align-items:center;flex-wrap:wrap;border-bottom:1px solid #2B2F36;margin-bottom:10px}
        input[type=text]{background:#1A1D22;border:1px solid #2B2F36;color:#EDEFF2;border-radius:6px;padding:7px 10px;font-size:13px;width:240px}
        label{font-size:13px;color:#C9CDD3;display:flex;align-items:center;gap:6px;cursor:pointer}
        table{border-collapse:collapse;width:100%;font-size:12.5px}
        th,td{border-bottom:1px solid #23262C;padding:8px 10px;text-align:left;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;max-width:320px}
        th{position:sticky;top:56px;background:#1A1D22;color:#EDEFF2;font-size:11.5px;z-index:2;white-space:normal;vertical-align:top}
        th .thumb{display:block;width:100%;max-width:220px;height:auto;aspect-ratio:16/9;object-fit:cover;border-radius:6px;margin:0 0 6px;border:1px solid #2B2F36}
        th .fname{font-weight:600;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;max-width:220px}
        td.label{color:#9AA0A8;font-weight:500}
        tr.cat td{background:rgba(232,150,60,0.08);color:#E8963C;font-weight:700;font-size:10.5px;letter-spacing:.04em;position:sticky;left:0}
        tr.diferit.highlight td{background:rgba(232,150,60,0.10)}
        tr.hide-identical.identic{display:none}
        td{font-family:ui-monospace,SFMono-Regular,Menlo,monospace}
        </style></head><body>
        <h1>Comparație metadate</h1>
        <p class="subtitle">\(jobs.count) fișiere · generat \(dataCurenta())</p>
        <div class="toolbar">
          <input type="text" id="search" placeholder="Caută…" oninput="filtreaza()">
          <label><input type="checkbox" id="highlight" checked onchange="filtreaza()"> Evidențiază diferențele</label>
          <label><input type="checkbox" id="hideIdentical" onchange="filtreaza()"> Ascunde identice</label>
        </div>
        <table id="tbl">
        <thead><tr><th>Parametru</th>\(antetColoane)</tr></thead>
        <tbody>
        \(randuriHTML)
        </tbody>
        </table>
        <script>
        function filtreaza() {
          var q = document.getElementById('search').value.toLowerCase();
          var highlight = document.getElementById('highlight').checked;
          var hideIdentical = document.getElementById('hideIdentical').checked;
          document.querySelectorAll('tr.row').forEach(function(tr) {
            var matches = !q || tr.getAttribute('data-search').indexOf(q) !== -1;
            tr.style.display = matches ? '' : 'none';
            tr.classList.toggle('highlight', highlight);
            tr.classList.toggle('hide-identical', hideIdentical);
          });
          document.querySelectorAll('tr.cat').forEach(function(tr) {
            var next = tr.nextElementSibling, any = false;
            while (next && !next.classList.contains('cat')) {
              if (next.style.display !== 'none') any = true;
              next = next.nextElementSibling;
            }
            tr.style.display = any ? '' : 'none';
          });
        }
        filtreaza();
        </script>
        </body></html>
        """

        let path = FileManager.default.temporaryDirectory.appendingPathComponent("CGConvertor_Comparatie_\(Int(Date().timeIntervalSince1970)).html")
        try? html.write(to: path, atomically: true, encoding: .utf8)
        NSWorkspace.shared.open(path)
    }

    private static func dataCurenta() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: Date())
    }

    private static func escapeHTML(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}
