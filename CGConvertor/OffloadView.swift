import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// UI Offload/Checksum — vezi `OffloadEngine.swift` pentru scopul deliberat
/// redus al motorului față de `DataMover`. Layout simplu, cu o singură
/// coloană de setări + activitate, pe același model vizual "Shift" ca restul
/// aplicației.
struct OffloadView: View {
    @StateObject private var runner = OffloadRunner()
    @State private var sourcePath: String?
    @State private var destinations: [String] = []
    @State private var verificationModel: VerificationModel = .xxhash64
    @State private var chunkSizeMB = IOSettings.chunkSizeMB
    @State private var ramLimitMB = IOSettings.ramLimitMB
    @State private var voluri: [VolumeInfo] = []
    @State private var seTinteste_Sursa = false
    @State private var seTinteste_Destinatie = false

    // ── Port DataMover, Etapa 2026-09-03 (2026-09-05 pe CGConvertor) ──
    @State private var meta = ProductionMeta()
    @State private var namingTemplate = NamingTemplate.defaultTemplate
    @State private var cardInfo: CameraCardInfo?
    @State private var parentCardWarning: String?
    @StateObject private var profileStore = TransferProfileStore.shared
    @State private var showSaveProfileDialog = false
    @State private var newProfileName = ""
    @State private var showHistory = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                volumesSection
                sourceSection
                destinationsSection
                productionSection
                namingSection
                verificationSection
                ioSection
                profilesSection
                if !runner.activityLog.isEmpty { activitySection }
                if !runner.lastResults.isEmpty { resultsSection }
                footer
            }
            .padding(18)
        }
        .background(Shift.bg)
        .onAppear { voluri = VolumeInfo.detectAll() }
        .onChange(of: sourcePath) { _, newValue in atualizeazaDetectieCard(newValue) }
        .alert(L.t("offload.profiles.namePrompt"), isPresented: $showSaveProfileDialog) {
            TextField(L.t("offload.profiles.namePrompt"), text: $newProfileName)
            Button(L.t("offload.profiles.save")) { salveazaProfil() }
            Button(L.t("offload.cancel"), role: .cancel) {}
        }
        .alert(L.t("offload.status.insufficientSpace"), isPresented: .constant(runner.insufficientSpaceWarning != nil), presenting: runner.insufficientSpaceWarning) { _ in
            Button(L.t("offload.cancel"), role: .cancel) { runner.insufficientSpaceWarning = nil }
            Button(L.t("offload.start"), role: .destructive) {
                guard let src = sourcePath else { return }
                runner.insufficientSpaceWarning = nil
                runner.start(sourceRoot: src, destinations: destinations, model: verificationModel,
                             meta: meta, namingTemplate: namingTemplate, ignoreSpaceWarning: true)
            }
        } message: { text in
            Text(text)
        }
        .sheet(isPresented: $showHistory) {
            OffloadHistorySheet(isPresented: $showHistory)
        }
    }

    private func atualizeazaDetectieCard(_ path: String?) {
        guard let path else { cardInfo = nil; parentCardWarning = nil; return }
        cardInfo = CameraCardDetector.detect(root: path)
        parentCardWarning = CameraCardDetector.parentLooksLikeCard(path: path)
    }

    private func salveazaProfil() {
        let name = newProfileName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let profile = TransferProfile(
            name: name, sourcePaths: sourcePath.map { [$0] } ?? [], destinationPaths: destinations,
            verificationModel: verificationModel, chunkSizeMB: chunkSizeMB, ramLimitMB: ramLimitMB,
            namingTemplate: namingTemplate, project: meta.project, client: meta.client,
            camera: meta.camera, operatorName: meta.operatorName
        )
        profileStore.upsert(profile)
        newProfileName = ""
    }

    private func incarcaProfil(_ profile: TransferProfile) {
        sourcePath = profile.sourcePaths.first
        destinations = profile.destinationPaths
        verificationModel = profile.verificationModel
        chunkSizeMB = profile.chunkSizeMB
        ramLimitMB = profile.ramLimitMB
        namingTemplate = profile.namingTemplate
        meta.project = profile.project
        meta.client = profile.client
        meta.camera = profile.camera
        meta.operatorName = profile.operatorName
        IOSettings.chunkSizeMB = profile.chunkSizeMB
        IOSettings.ramLimitMB = profile.ramLimitMB
    }

    /// Discuri/carduri montate, detectate automat (2026-09-05, cerere
    /// explicită, repetată — vezi CLAUDE.md): mult mai profesional decât
    /// un simplu câmp de path text, exact cum arată DataMover. Click pe
    /// un disc îl setează ca sursă; butonul "+" mic îl adaugă la lista de
    /// destinații — restul aplicației (`NSOpenPanel` din `alegeSursa`/
    /// `adaugaDestinatie`) rămâne disponibil neschimbat, pentru orice
    /// folder care nu e rădăcina unui volum montat.
    private var volumesSection: some View {
        ShiftCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    ShiftSectionLabel(text: L.t("offload.volumes.title"))
                    Spacer()
                    Button {
                        voluri = VolumeInfo.detectAll()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Shift.muted)
                    .help(L.t("offload.volumes.refresh"))
                }
                if voluri.isEmpty {
                    Text(L.t("offload.volumes.empty")).font(.system(size: 12)).foregroundStyle(Shift.faint)
                } else {
                    Text(L.t("offload.volumes.dragHint"))
                        .font(.system(size: 10)).foregroundStyle(Shift.faint)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(voluri) { vol in
                                VStack(spacing: 4) {
                                    Image(nsImage: vol.icon).resizable().frame(width: 32, height: 32)
                                    Text(vol.name).font(.system(size: 11, weight: .medium)).lineLimit(1)
                                    Text(formatBytes(vol.freeBytes)).font(.system(size: 9.5, design: .monospaced)).foregroundStyle(Shift.faint)
                                    // Doua butoane clare, pe randuri separate — nu doar
                                    // "Sursă"/"+" lipite (2026-09-05: confuzie reala
                                    // semnalata de Cristi, tinte prea mici/apropiate,
                                    // dadea impresia ca apasa gresit pe destinatie).
                                    Button(L.t("offload.volumes.useAsSource")) { sourcePath = vol.path }
                                        .buttonStyle(.plain).font(.system(size: 9.5, weight: .semibold))
                                        .foregroundStyle(Shift.accent)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 3)
                                        .background(Shift.accent.opacity(0.1))
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                    Button(L.t("offload.volumes.useAsDestination")) {
                                        if !destinations.contains(vol.path) { destinations.append(vol.path) }
                                    }
                                    .buttonStyle(.plain).font(.system(size: 9.5, weight: .semibold))
                                    .foregroundStyle(Shift.muted)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 3)
                                    .background(Shift.elevated)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                }
                                .padding(8)
                                .frame(width: 118)
                                .background(sourcePath == vol.path ? Shift.accent.opacity(0.12) : Shift.elevated)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                // Drag propriu-zis (2026-09-05, cerere explicita): un
                                // chip se poate trage direct peste "Sursa" sau
                                // "Destinatii" mai jos, la fel ca orice fisier din
                                // Finder — nu doar butoanele fixe de mai sus.
                                .onDrag { NSItemProvider(contentsOf: URL(fileURLWithPath: vol.path)) ?? NSItemProvider() }
                            }
                        }
                    }
                }
            }
        }
    }

    private var sourceSection: some View {
        ShiftCard {
            VStack(alignment: .leading, spacing: 8) {
                ShiftSectionLabel(text: L.t("offload.source"))
                HStack {
                    Text(sourcePath ?? L.t("offload.source.choose"))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(sourcePath == nil ? Shift.faint : Shift.text)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    // Bug UX real, raportat de Cristi (2026-09-05): daca
                    // alegi gresit o Sursa, nu exista niciun buton de
                    // golire — trebuia sa navighezi in fata/spate sau sa
                    // repornesti aplicatia. Destinatiile au deja acest
                    // "✕" per rand; Sursa il capata acum, identic vizual,
                    // vizibil DOAR cand sourcePath nu e gol.
                    if sourcePath != nil {
                        Button {
                            sourcePath = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Shift.muted)
                    }
                    Button(L.t("offload.source.choose")) { alegeSursa() }
                        .buttonStyle(.plain)
                        .foregroundStyle(Shift.accent)
                }
                // Recunoașterea structurii de card (port DataMover) — pur
                // informativ, NU blochează niciodată transferul.
                if let cardInfo {
                    Text(cardInfo.summary).font(.system(size: 11, weight: .medium)).foregroundStyle(Shift.accent)
                    ForEach(cardInfo.warnings, id: \.self) { warning in
                        Label(warning, systemImage: "exclamationmark.triangle.fill")
                            .font(.system(size: 10.5)).foregroundStyle(.orange)
                    }
                }
                if let parentCardWarning {
                    Label(String(format: L.t("offload.card.parentWarning"), (parentCardWarning as NSString).lastPathComponent), systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 10.5)).foregroundStyle(.orange)
                }
            }
        }
        // Drop direct (2026-09-05, cerere explicita): un disc din lista de
        // mai sus SAU un folder din Finder tras aici devine sursa —
        // aceeasi conventie de UTType (.fileURL) ca drop-ul de fisiere din
        // coada Convertorului (vezi ContentView.primesteFisiereDinDrop).
        .overlay {
            if seTinteste_Sursa {
                RoundedRectangle(cornerRadius: 8).strokeBorder(Shift.accent, lineWidth: 2)
                    .background(Shift.accent.opacity(0.06))
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $seTinteste_Sursa) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url else { return }
                DispatchQueue.main.async { sourcePath = url.path }
            }
            return true
        }
    }

    private var destinationsSection: some View {
        ShiftCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    ShiftSectionLabel(text: L.t("offload.destinations"))
                    Spacer()
                    Button(L.t("offload.destinations.add")) { adaugaDestinatie() }
                        .buttonStyle(.plain)
                        .foregroundStyle(Shift.accent)
                }
                if destinations.isEmpty {
                    Text(L.t("offload.destinations.empty")).font(.system(size: 12)).foregroundStyle(Shift.faint)
                } else {
                    ForEach(destinations, id: \.self) { dest in
                        HStack {
                            Text(dest).font(.system(size: 12, design: .monospaced)).lineLimit(1).truncationMode(.middle)
                            Spacer()
                            Button {
                                destinations.removeAll { $0 == dest }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(Shift.muted)
                        }
                    }
                }
            }
        }
        .overlay {
            if seTinteste_Destinatie {
                RoundedRectangle(cornerRadius: 8).strokeBorder(Shift.accent, lineWidth: 2)
                    .background(Shift.accent.opacity(0.06))
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $seTinteste_Destinatie) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url else { return }
                DispatchQueue.main.async {
                    if !destinations.contains(url.path) { destinations.append(url.path) }
                }
            }
            return true
        }
    }

    /// Metadatele producției (Proiect/Client/Card/Cameră/Operator/Note +
    /// logo) — port DataMover `ProductionMeta`: alimentează ȘI numele
    /// folderului (secțiunea de mai jos), ȘI antetul rapoartelor HTML.
    /// Toate opționale — un offload fără niciun câmp completat arată
    /// identic ca înainte.
    private var productionSection: some View {
        ShiftCard {
            VStack(alignment: .leading, spacing: 8) {
                ShiftSectionLabel(text: L.t("offload.production.title"))
                Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 8) {
                    GridRow {
                        campText(L.t("offload.production.project"), $meta.project)
                        campText(L.t("offload.production.card"), $meta.card)
                    }
                    GridRow {
                        campText(L.t("offload.production.client"), $meta.client)
                        campText(L.t("offload.production.camera"), $meta.camera)
                    }
                    GridRow {
                        campText(L.t("offload.production.operator"), $meta.operatorName)
                        HStack(spacing: 8) {
                            Text(L.t("offload.production.logo")).font(.system(size: 11)).foregroundStyle(Shift.muted)
                            Button(L.t("offload.production.chooseLogo")) { alegeLogo() }
                                .buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(Shift.accent)
                            if !meta.logoPath.isEmpty {
                                Button(L.t("offload.production.clearLogo")) { meta.logoPath = "" }
                                    .buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(Shift.faint)
                            }
                        }
                    }
                }
                TextField(L.t("offload.production.notes"), text: $meta.notes, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...4)
                    .font(.system(size: 12))
            }
        }
    }

    private func campText(_ label: String, _ value: Binding<String>) -> some View {
        HStack(spacing: 8) {
            Text(label).font(.system(size: 11)).foregroundStyle(Shift.muted).frame(width: 90, alignment: .leading)
            TextField("", text: value).textFieldStyle(.roundedBorder).font(.system(size: 12))
        }
    }

    private func alegeLogo() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        if let png = UTType(filenameExtension: "png"), let jpg = UTType(filenameExtension: "jpg") {
            panel.allowedContentTypes = [png, jpg]
        }
        if panel.runModal() == .OK, let url = panel.url { meta.logoPath = url.path }
    }

    /// Șablon liber pentru numele folderului creat la fiecare destinație —
    /// port DataMover `NamingTemplate`. Gol → comportamentul vechi (nume
    /// fix `<data>_<Proiect>_<Card>`), deci nimeni nu e afectat dacă nu-l
    /// atinge. Previzualizare LIVE — un șablon greșit descoperit după TB-uri
    /// copiate nu se mai poate corecta fără mutare manuală.
    private var namingSection: some View {
        ShiftCard {
            VStack(alignment: .leading, spacing: 8) {
                ShiftSectionLabel(text: L.t("offload.naming.title"))
                TextField(NamingTemplate.defaultTemplate, text: $namingTemplate)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))
                HStack(spacing: 6) {
                    ForEach(NamingTemplate.tokens, id: \.self) { token in
                        Button(token) { namingTemplate += token }
                            .buttonStyle(.plain).font(.system(size: 10.5, design: .monospaced))
                            .padding(.horizontal, 6).padding(.vertical, 3)
                            .background(Shift.elevated).clipShape(RoundedRectangle(cornerRadius: 4))
                            .foregroundStyle(Shift.muted)
                    }
                }
                Text("\(L.t("offload.naming.preview")): \(numeFolderPreview)")
                    .font(.system(size: 11, design: .monospaced)).foregroundStyle(Shift.accent)
            }
        }
    }

    private var numeFolderPreview: String {
        NamingTemplate.render(namingTemplate, context: .init(
            project: meta.project, card: meta.card, camera: meta.camera, operatorName: meta.operatorName, date: Date()
        ))
    }

    /// Profile de transfer salvate — port DataMover `TransferProfile`:
    /// configurație completă (căi + verificare + buffer/RAM + șablon +
    /// producție), numită, reîncărcabilă dintr-un click.
    private var profilesSection: some View {
        ShiftCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    ShiftSectionLabel(text: L.t("offload.profiles.title"))
                    Spacer()
                    Button(L.t("offload.profiles.save")) { showSaveProfileDialog = true }
                        .buttonStyle(.plain).foregroundStyle(Shift.accent)
                }
                ForEach(profileStore.profiles) { profile in
                    HStack {
                        Text(profile.name).font(.system(size: 12)).lineLimit(1)
                        Spacer()
                        Button(L.t("offload.profiles.load")) { incarcaProfil(profile) }
                            .buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(Shift.accent)
                        Button { profileStore.delete(profile) } label: {
                            Image(systemName: "xmark.circle.fill")
                        }
                        .buttonStyle(.plain).foregroundStyle(Shift.muted)
                    }
                }
            }
        }
    }

    private var verificationSection: some View {
        ShiftCard {
            VStack(alignment: .leading, spacing: 8) {
                ShiftSectionLabel(text: L.t("offload.verify.title"))
                Picker("", selection: $verificationModel) {
                    ForEach(VerificationModel.allCases) { model in
                        Text(model.label).tag(model)
                    }
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()
            }
        }
    }

    private var ioSection: some View {
        ShiftCard {
            VStack(alignment: .leading, spacing: 10) {
                ShiftSectionLabel(text: L.t("offload.io.title"))
                HStack {
                    Text(L.t("offload.io.buffer")).font(.system(size: 12))
                    Spacer()
                    Picker("", selection: $chunkSizeMB) {
                        ForEach(IOSettings.chunkSizeChoicesMB, id: \.self) { mb in
                            Text(IOSettings.formattedMB(mb)).tag(mb)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 100)
                    .onChange(of: chunkSizeMB) { _, v in IOSettings.chunkSizeMB = v }
                }
                HStack {
                    Text(L.t("offload.io.ramLimit")).font(.system(size: 12))
                    Spacer()
                    Picker("", selection: $ramLimitMB) {
                        ForEach(IOSettings.ramLimitChoicesMB, id: \.self) { mb in
                            Text(mb == 0 ? "—" : IOSettings.formattedMB(mb)).tag(mb)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 100)
                    .onChange(of: ramLimitMB) { _, v in IOSettings.ramLimitMB = v }
                }
                HStack(spacing: 6) {
                    ForEach(IOSettings.presets, id: \.name) { preset in
                        Button(preset.name) {
                            chunkSizeMB = preset.chunkMB
                            ramLimitMB = preset.ramLimitMB
                            IOSettings.chunkSizeMB = preset.chunkMB
                            IOSettings.ramLimitMB = preset.ramLimitMB
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 11))
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Shift.elevated)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .foregroundStyle(Shift.muted)
                    }
                }
            }
        }
    }

    private var activitySection: some View {
        ShiftCard {
            VStack(alignment: .leading, spacing: 6) {
                ShiftSectionLabel(text: L.t("offload.activity.title"))
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(runner.activityLog.suffix(50).enumerated()), id: \.offset) { _, line in
                            Text(line).font(.system(size: 10.5, design: .monospaced)).foregroundStyle(Shift.muted)
                        }
                    }
                }
                .frame(height: 120)
            }
        }
    }

    private var resultsSection: some View {
        ShiftCard {
            VStack(alignment: .leading, spacing: 6) {
                ShiftSectionLabel(text: L.t("offload.results.title"))
                ForEach(runner.lastResults, id: \.destination) { result in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(format: L.t("offload.results.row"), (result.destination as NSString).lastPathComponent, result.okCount, result.mismatchCount, result.errorCount))
                            .font(.system(size: 12))
                        HStack(spacing: 12) {
                            if let htmlPath = result.htmlPath {
                                Button(L.t("offload.results.openReport")) { NSWorkspace.shared.open(URL(fileURLWithPath: htmlPath)) }
                                    .buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(Shift.accent)
                            } else if let csvPath = result.csvPath {
                                Button(L.t("offload.results.openReport")) {
                                    NSWorkspace.shared.selectFile(csvPath, inFileViewerRootedAtPath: "")
                                }
                                .buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(Shift.accent)
                            }
                            if result.mhlPath != nil {
                                Label("MHL", systemImage: "checkmark.seal.fill")
                                    .font(.system(size: 10.5)).foregroundStyle(Shift.success)
                            }
                            if result.recoveredCount > 0 {
                                Text(String(format: "↻ %d", result.recoveredCount))
                                    .font(.system(size: 10.5)).foregroundStyle(.orange)
                            }
                        }
                    }
                }
            }
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            if runner.isRunning {
                ProgressView(value: runner.progressPercent, total: 100)
                    .tint(Shift.accent)
                HStack {
                    Text(runner.statusText).font(.system(size: 11)).foregroundStyle(Shift.muted)
                    Spacer()
                    Text(runner.speedText).font(.system(size: 11, design: .monospaced)).foregroundStyle(Shift.faint)
                }
            } else if !runner.statusText.isEmpty {
                Text(runner.statusText).font(.system(size: 12)).foregroundStyle(Shift.text)
            }

            HStack {
                if runner.isRunning {
                    Button(runner.isPaused ? L.t("offload.resume") : L.t("offload.pause")) {
                        runner.togglePause()
                    }
                    .buttonStyle(.bordered)
                    Button(L.t("offload.cancel")) { runner.cancel() }
                        .buttonStyle(.bordered)
                } else {
                    Button(L.t("offload.start")) {
                        guard let src = sourcePath else { return }
                        runner.start(sourceRoot: src, destinations: destinations, model: verificationModel,
                                     meta: meta, namingTemplate: namingTemplate)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Shift.accent)
                    .disabled(sourcePath == nil || destinations.isEmpty)
                    Button(L.t("offload.history.button")) { showHistory = true }
                        .buttonStyle(ShiftGhostButtonStyle())
                }
            }
        }
    }

    private func alegeSursa() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Alege"
        if panel.runModal() == .OK {
            sourcePath = panel.url?.path
        }
    }

    private func adaugaDestinatie() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Adaugă"
        if panel.runModal() == .OK, let path = panel.url?.path, !destinations.contains(path) {
            destinations.append(path)
        }
    }
}
