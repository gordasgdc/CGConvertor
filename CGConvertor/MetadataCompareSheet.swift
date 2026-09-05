import SwiftUI
import AppKit

/// Tabel comparativ multi-fișier — pe modelul
/// `~/Developer/GDC_Metadata_View_Premium` (index.html): rânduri = un
/// parametru tehnic, coloane = fișierele selectate, cu evidențierea
/// diferențelor și ascunderea rândurilor identice. SwiftUI nu are un
/// `Table` cu coloane dinamice practic pentru acest caz (numărul de
/// fișiere variază) — construit manual: ScrollView orizontal (peste
/// întregul grid, antet + rânduri) în interiorul unui ScrollView
/// vertical, cu celule de lățime fixă aliniate pe coloane.
struct MetadataCompareSheet: View {
    let jobs: [VideoJob]
    @Binding var isPresented: Bool

    @State private var categoriiPerJob: [UUID: [MetadataCategory]] = [:]
    @State private var seIncarca = true
    @State private var cautare = ""
    @State private var ascundeIdentice = false
    @State private var evidentiazaDiferente = true

    private let latimeLabel: CGFloat = 220
    private let latimeColoana: CGFloat = 200

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(Shift.border)
            if seIncarca {
                VStack {
                    Spacer()
                    ProgressView(L.t("compare.loading"))
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                tabel
            }
            Divider().overlay(Shift.border)
            footer
        }
        .frame(width: 900, height: 620)
        .background(Shift.bg)
        .task {
            var rezultat: [UUID: [MetadataCategory]] = [:]
            for job in jobs {
                rezultat[job.id] = await Task.detached(priority: .userInitiated) {
                    MetadataCompareEngine.categorii(pentru: job.urlSursa)
                }.value
            }
            categoriiPerJob = rezultat
            seIncarca = false
        }
    }

    private var header: some View {
        HStack {
            Text(L.t("compare.title"))
                .font(.system(size: 14, weight: .semibold))
            Spacer()
            Button { isPresented = false } label: {
                Image(systemName: "xmark.circle.fill")
            }
            .buttonStyle(.plain)
            .foregroundStyle(Shift.faint)
        }
        .padding(16)
    }

    private var randuriMerge: [(categorie: String, labeluri: [String])] {
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
        return ordineCategorii.map { (categorie: $0, labeluri: labeluriPeCategorie[$0] ?? []) }
    }

    private func valoare(job: VideoJob, categorie: String, label: String) -> String? {
        categoriiPerJob[job.id]?.first(where: { $0.name == categorie })?.rows.first(where: { $0.label == label })?.value
    }

    private func esteIdentic(categorie: String, label: String) -> Bool {
        let valori = Set(jobs.map { valoare(job: $0, categorie: categorie, label: label) ?? "—" })
        return valori.count <= 1
    }

    private func potriveste(_ text: String) -> Bool {
        cautare.isEmpty || text.localizedCaseInsensitiveContains(cautare)
    }

    private var tabel: some View {
        ScrollView([.horizontal, .vertical]) {
            VStack(alignment: .leading, spacing: 0) {
                antetColoane
                ForEach(randuriMerge, id: \.categorie) { grup in
                    let randuriVizibile = grup.labeluri.filter { label in
                        guard potriveste(label) || potriveste(grup.categorie) else { return false }
                        if ascundeIdentice, esteIdentic(categorie: grup.categorie, label: label) { return false }
                        return true
                    }
                    if !randuriVizibile.isEmpty {
                        randCategorie(grup.categorie)
                        ForEach(randuriVizibile, id: \.self) { label in
                            randValoare(categorie: grup.categorie, label: label)
                        }
                    }
                }
            }
        }
    }

    private var antetColoane: some View {
        HStack(spacing: 0) {
            Text(L.t("compare.parameter"))
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Shift.accent)
                .frame(width: latimeLabel, alignment: .leading)
                .padding(8)
            ForEach(jobs) { job in
                Text(job.numeFisier)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(2)
                    .frame(width: latimeColoana, alignment: .leading)
                    .padding(8)
            }
        }
        .background(Shift.elevated)
    }

    private func randCategorie(_ nume: String) -> some View {
        Text(nume.uppercased())
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(Shift.accent)
            .frame(width: latimeLabel + latimeColoana * CGFloat(jobs.count), alignment: .leading)
            .padding(.horizontal, 8).padding(.vertical, 6)
            .background(Shift.accent.opacity(0.06))
    }

    private func randValoare(categorie: String, label: String) -> some View {
        let diferit = evidentiazaDiferente && !esteIdentic(categorie: categorie, label: label)
        return HStack(spacing: 0) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Shift.muted)
                .frame(width: latimeLabel, alignment: .leading)
                .padding(8)
            ForEach(jobs) { job in
                Text(valoare(job: job, categorie: categorie, label: label) ?? "—")
                    .font(.system(size: 11, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(width: latimeColoana, alignment: .leading)
                    .padding(8)
            }
        }
        .background(diferit ? Color.orange.opacity(0.12) : Color.clear)
        .overlay(Rectangle().frame(height: 1).foregroundStyle(Shift.border), alignment: .bottom)
    }

    private var footer: some View {
        HStack {
            TextField(L.t("compare.search"), text: $cautare)
                .textFieldStyle(.roundedBorder)
                .frame(width: 220)
            Toggle(L.t("compare.highlightDiffs"), isOn: $evidentiazaDiferente)
                .toggleStyle(.checkbox)
            Toggle(L.t("compare.hideIdentical"), isOn: $ascundeIdentice)
                .toggleStyle(.checkbox)
            Spacer()
            Button(L.t("compare.exportCsv")) { exportaCSV() }
                .buttonStyle(ShiftGhostButtonStyle())
        }
        .padding(12)
    }

    private func exportaCSV() {
        var linii = ["Categorie,Parametru," + jobs.map { "\"\($0.numeFisier)\"" }.joined(separator: ",")]
        for grup in randuriMerge {
            for label in grup.labeluri {
                let valori = jobs.map { "\"\(valoare(job: $0, categorie: grup.categorie, label: label) ?? "")\"" }
                linii.append("\"\(grup.categorie)\",\"\(label)\"," + valori.joined(separator: ","))
            }
        }
        let continut = linii.joined(separator: "\n")
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "Comparatie_Metadata.csv"
        if panel.runModal() == .OK, let url = panel.url {
            try? continut.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}
