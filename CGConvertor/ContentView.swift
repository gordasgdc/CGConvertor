import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var vm = ConvertorViewModel()
    @ObservedObject private var license = LicenseManager.shared
    @ObservedObject private var deps = DependencyManager.shared
    @ObservedObject private var revocation = RevocationCheck.shared
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var watchFolders = WatchFolderManager.shared
    @State private var seAfiseazaDropTarget = false
    @State private var showActivation = false
    @State private var showUpdateAlert = false
    @State private var updateAlertVersion = ""
    @State private var updateAlertPkgURL: URL?
    @State private var showDependencyPanel = false
    @State private var showPresetsManager = false
    @State private var showSettingsSheet = false
    @State private var mainMode: MainMode = .convert

    enum MainMode: String, CaseIterable, Identifiable {
        case convert, offload
        var id: String { rawValue }
        var label: String { self == .convert ? L.t("mainMode.convert") : L.t("mainMode.offload") }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }

    var body: some View {
        VStack(spacing: 0) {
            antet
            if !license.isLicensed || revocation.isRevoked {
                trialBanner
            }

            if mainMode == .convert {
                HStack(spacing: 0) {
                    panouSetari
                        .frame(width: 300)
                    Divider().overlay(Shift.border)
                    panouListaJoburi
                }
            } else {
                OffloadView()
            }
        }
        .background(Shift.bg)
        .foregroundStyle(Shift.text)
        .dynamicTypeSize(settings.textScale.dynamicTypeSize)
        .onAppear {
            vm.verificaFFmpeg()
            deps.refreshAll()
            watchFolders.onNewFiles = { urls in vm.adaugaFisiere(urls) }
            watchFolders.start()
            UpdateChecker.checkSilentlyOnLaunch { newVersion, pkgURL in
                updateAlertVersion = newVersion
                updateAlertPkgURL = pkgURL
                showUpdateAlert = true
            }
            // Regula 12 — revocare online, fail-open (vezi RevocationCheck.swift).
            revocation.refreshOnce()
            revocation.startPeriodicRefresh()
        }
        .sheet(isPresented: $showActivation) {
            ActivationSheet(license: license, isPresented: $showActivation)
        }
        .sheet(isPresented: $showDependencyPanel) {
            DependencyPanel(deps: deps, isPresented: $showDependencyPanel)
        }
        .sheet(isPresented: $showPresetsManager) {
            PresetsManagerSheet(presets: vm.presets, isPresented: $showPresetsManager) { updated in
                PresetsManager.save(updated)
                vm.reincarcaPresets()
            }
        }
        .sheet(isPresented: $showSettingsSheet) {
            SettingsSheet(isPresented: $showSettingsSheet)
        }
        .alert(L.t("update.available.title"), isPresented: $showUpdateAlert) {
            Button(L.t("update.download")) {
                UpdateChecker.markDismissed(updateAlertVersion)
                if let pkgURL = updateAlertPkgURL {
                    Task { await SelfUpdater.downloadAndInstall(pkgURL: pkgURL, version: updateAlertVersion) }
                }
            }
            Button(L.t("update.later"), role: .cancel) {
                UpdateChecker.markDismissed(updateAlertVersion)
            }
        } message: {
            Text(String(format: L.t("update.available.body"), updateAlertVersion, appVersion))
        }
    }

    // ── Antet ────────────────────────────────────────────────────────────────
    private var antet: some View {
        HStack(spacing: 14) {
            Image(systemName: "film.stack")
                .font(.system(size: 20))
                .foregroundStyle(Shift.accent)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(L.t("app.title")).font(.system(size: 16, weight: .bold))
                    Text("v\(appVersion)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Shift.faint)
                }
                Text(L.t("app.subtitle"))
                    .font(.system(size: 11))
                    .foregroundStyle(Shift.muted)
            }
            Spacer()
            Picker("", selection: $mainMode) {
                ForEach(MainMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 180)
            if vm.seRuleazaCoada {
                ProgressView().controlSize(.small).tint(Shift.accent)
            }
            DependencyBadge(deps: deps, showPanel: $showDependencyPanel)
            langSwitch
            Button { UpdateChecker.checkAndShowAlert() } label: {
                Image(systemName: "arrow.triangle.2.circlepath")
            }
            .buttonStyle(.plain)
            .foregroundStyle(Shift.muted)
            .help(L.t("menu.checkForUpdates"))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(Shift.panel)
        .overlay(Rectangle().frame(height: 1).foregroundStyle(Shift.border), alignment: .bottom)
    }

    private var langSwitch: some View {
        HStack(spacing: 3) {
            ForEach(AppLanguage.allCases) { lang in
                Button(lang.rawValue.uppercased()) { L.current = lang }
                    .buttonStyle(.plain)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .background(L.current == lang ? Shift.accent : Shift.elevated)
                    .foregroundStyle(L.current == lang ? Shift.accentInk : Shift.muted)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
            }
        }
    }

    private var trialBanner: some View {
        HStack {
            Text(revocation.isRevoked
                 ? L.t("license.revoked")
                 : (license.isTrialActive
                    ? String(format: L.t("trial.daysLeft"), license.trialDaysRemaining)
                    : L.t("trial.expired")))
                .font(.system(size: 11.5))
                .foregroundStyle((revocation.isRevoked || !license.isTrialActive) ? Shift.error : Shift.muted)
            Spacer()
            if !revocation.isRevoked {
                Button(L.t("trial.activate")) { showActivation = true }
                    .buttonStyle(.plain)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(Shift.accent)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 7)
        .background((revocation.isRevoked || !license.isTrialActive) ? Shift.error.opacity(0.12) : Shift.elevated)
        .overlay(Rectangle().frame(height: 1).foregroundStyle(Shift.border), alignment: .bottom)
    }

    // ── Panou setari (stanga) ───────────────────────────────────────────────
    private var panouSetari: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ShiftCard {
                        VStack(alignment: .leading, spacing: 8) {
                            ShiftSectionLabel(text: L.t("preset.title"))
                            Picker("", selection: $vm.presetSelectatID) {
                                ForEach(vm.presets) { preset in
                                    Text(preset.label).tag(preset.id)
                                }
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                            .tint(Shift.text)

                            if let hint = presetHint {
                                Text(hint)
                                    .font(.system(size: 11))
                                    .foregroundStyle(Shift.muted)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            Button(L.t("preset.edit")) { showPresetsManager = true }
                                .buttonStyle(ShiftGhostButtonStyle())

                            // Accelerare hardware — pe Mac e mereu VideoToolbox
                            // (Faza 1, secțiunea B); spre deosebire de Windows,
                            // nu există alt vânzător de ales.
                            Text("\(L.t("gpu.accel.prefix")) Apple VideoToolbox")
                                .font(.system(size: 10))
                                .foregroundStyle(Shift.faint)
                        }
                    }

                    ShiftCard {
                        VStack(alignment: .leading, spacing: 8) {
                            ShiftSectionLabel(text: L.t("destination.title"))
                            Text(vm.folderDestinatie?.path ?? L.t("destination.sameAsSource"))
                                .font(.system(size: 11.5, design: .monospaced))
                                .foregroundStyle(Shift.muted)
                                .lineLimit(2)
                                .truncationMode(.middle)
                            Button(L.t("destination.choose")) { vm.alegeFolderDestinatie() }
                                .buttonStyle(ShiftGhostButtonStyle())
                        }
                    }

                    watchFoldersCard

                    Text(L.t("shortcuts.hint"))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Shift.faint)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 0)

                    actiuneButon
                }
                .padding(16)
            }
            .background(Shift.bg)

            // Sidebar Profil + Setari (Regula 12 — sidebar obligatoriu,
            // FRATE al ScrollView-ului de mai sus, nu safeAreaInset direct
            // pe scroll — Regula 24, evită bug-ul de suprapunere la resize).
            Divider().overlay(Shift.border)
            profilSidebar
        }
    }

    private var watchFoldersCard: some View {
        ShiftCard {
            VStack(alignment: .leading, spacing: 8) {
                ShiftSectionLabel(text: L.t("watchFolders.title"))
                if watchFolders.folders.isEmpty {
                    Text(L.t("watchFolders.empty"))
                        .font(.system(size: 11))
                        .foregroundStyle(Shift.faint)
                } else {
                    ForEach(watchFolders.folders) { folder in
                        HStack(spacing: 6) {
                            Toggle("", isOn: Binding(
                                get: { folder.enabled },
                                set: { _ in watchFolders.toggle(folder) }
                            ))
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .controlSize(.mini)
                            Text((folder.path as NSString).lastPathComponent)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(Shift.muted)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Button {
                                watchFolders.removeFolder(folder)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(Shift.faint)
                        }
                    }
                }
                Button(L.t("watchFolders.add")) { alegeWatchFolder() }
                    .buttonStyle(ShiftGhostButtonStyle())
            }
        }
    }

    private func alegeWatchFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Adaugă"
        if panel.runModal() == .OK, let path = panel.url?.path {
            watchFolders.addFolder(path)
        }
    }

    private var presetHint: String? {
        guard let preset = vm.presetSelectat, preset.profileID != FormatRegistry.rewrapProfileID,
              let profil = FormatRegistry.profile(id: preset.profileID) else { return nil }
        return L.t(profil.hintKey)
    }

    private var profilSidebar: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(AppSettings.shared.userName.isEmpty ? L.t("sidebar.anonymous") : AppSettings.shared.userName)
                    .font(.system(size: 11, weight: .semibold))
                Text("\(L.t("sidebar.machineID")): \(MachineID.display)")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(Shift.faint)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            Button { showSettingsSheet = true } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.plain)
            .foregroundStyle(Shift.muted)
            .help(L.t("sidebar.settings"))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Shift.elevated)
    }

    private var actiuneButon: some View {
        Group {
            if vm.seRuleazaCoada {
                VStack(spacing: 6) {
                    Button { vm.comutaPauza() } label: {
                        Label(vm.estePauza ? L.t("resume.action") : L.t("pause.action"),
                              systemImage: vm.estePauza ? "play.fill" : "pause.fill")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(ShiftGhostButtonStyle())

                    Button { vm.opresteCoada() } label: {
                        Label(L.t("action.stop"), systemImage: "stop.fill")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 8)
                    .background(Shift.error)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .font(.system(size: 13, weight: .semibold))
                }
            } else {
                Button {
                    guard !revocation.isRevoked else { return }
                    guard license.isUnlocked else { showActivation = true; return }
                    vm.pornesteCoada()
                } label: {
                    Label(L.t("action.start"), systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
                .padding(.vertical, 8)
                .background(pornireDezactivata ? Shift.elevated : Shift.accent)
                .foregroundStyle(pornireDezactivata ? Shift.faint : Shift.accentInk)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .font(.system(size: 13, weight: .semibold))
                .disabled(vm.joburi.isEmpty || !deps.isReady || revocation.isRevoked)
                .keyboardShortcut(.return, modifiers: [.command])
            }
        }
    }

    private var pornireDezactivata: Bool {
        vm.joburi.isEmpty || !deps.isReady
    }

    // ── Panou lista joburi (dreapta) ────────────────────────────────────────
    private var panouListaJoburi: some View {
        VStack(spacing: 0) {
            if vm.joburi.isEmpty {
                zonaDropGoala
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(vm.joburi) { job in
                            RandJob(job: job, seRuleazaCoada: vm.seRuleazaCoada,
                                    onSterge: { vm.stergeJob(job) },
                                    onMutaSus: { vm.mutaJob(job, delta: -1) },
                                    onMutaJos: { vm.mutaJob(job, delta: 1) })
                        }
                    }
                    .padding(14)
                }

                HStack {
                    Button(L.t("queue.clear")) { vm.golesteLista() }
                        .buttonStyle(ShiftGhostButtonStyle())
                        .disabled(vm.seRuleazaCoada)
                        .keyboardShortcut("k", modifiers: [.command])
                    Button(L.t("queue.report")) {
                        if let url = vm.genereazaRaportHTML() { NSWorkspace.shared.open(url) }
                    }
                    .buttonStyle(ShiftGhostButtonStyle())
                    Spacer()
                    Button { deschideSelectorFisiere() } label: {
                        Label(L.t("queue.addFiles"), systemImage: "plus")
                    }
                    .buttonStyle(ShiftGhostButtonStyle())
                    .keyboardShortcut("o", modifiers: [.command])
                }
                .padding(12)
                .overlay(Rectangle().frame(height: 1).foregroundStyle(Shift.border), alignment: .top)
            }
        }
        .background(Shift.bg)
        .onDrop(of: [.fileURL], isTargeted: $seAfiseazaDropTarget) { providers in
            primesteFisiereDinDrop(providers)
            return true
        }
        .overlay {
            if seAfiseazaDropTarget {
                RoundedRectangle(cornerRadius: 0)
                    .strokeBorder(Shift.accent, lineWidth: 2)
                    .background(Shift.accent.opacity(0.06))
            }
        }
    }

    private var zonaDropGoala: some View {
        VStack(spacing: 14) {
            Image(systemName: "arrow.down.doc")
                .font(.system(size: 40))
                .foregroundStyle(Shift.faint)
            Text(L.t("queue.empty.title"))
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Shift.text)
            Text(L.t("queue.empty.or"))
                .font(.system(size: 11))
                .foregroundStyle(Shift.muted)
            Button(L.t("queue.chooseFiles")) { deschideSelectorFisiere() }
                .buttonStyle(ShiftGhostButtonStyle())
                .keyboardShortcut("o", modifiers: [.command])
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Shift.bg)
    }

    private func deschideSelectorFisiere() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.movie, .video, .mpeg4Movie, .quickTimeMovie]
        if panel.runModal() == .OK {
            vm.adaugaFisiere(panel.urls)
        }
    }

    private func primesteFisiereDinDrop(_ providers: [NSItemProvider]) {
        for provider in providers {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url else { return }
                DispatchQueue.main.async {
                    vm.adaugaFisiere([url])
                }
            }
        }
    }
}

// ── Stil de buton "ghost" (folosit peste tot in UI-ul Shift) ───────────────
struct ShiftGhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11.5, weight: .medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Shift.elevated.opacity(configuration.isPressed ? 0.6 : 1))
            .foregroundStyle(Shift.text)
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Shift.border, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// ── Rand individual pentru un job ───────────────────────────────────────────
private struct RandJob: View {
    let job: VideoJob
    let seRuleazaCoada: Bool
    let onSterge: () -> Void
    let onMutaSus: () -> Void
    let onMutaJos: () -> Void
    @State private var showPreview = false

    var body: some View {
        ShiftCard(padding: 12) {
            HStack(spacing: 12) {
                thumbnailJob

                VStack(alignment: .leading, spacing: 4) {
                    Text(job.numeFisier)
                        .font(.system(size: 12.5))
                        .lineLimit(1)
                        .truncationMode(.middle)

                    if let metaText = metadataText {
                        Text(metaText)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(Shift.faint)
                    }

                    switch job.stare {
                    case .astept:
                        Text(L.t("queue.status.waiting"))
                            .font(.system(size: 10.5))
                            .foregroundStyle(Shift.muted)
                    case .inLucru(let progres):
                        ProgressView(value: progres)
                            .frame(maxWidth: 260)
                            .tint(Shift.accent)
                    case .finalizat:
                        HStack(spacing: 10) {
                            Label(L.t("queue.status.done"), systemImage: "checkmark.circle.fill")
                                .font(.system(size: 10.5))
                                .foregroundStyle(Shift.success)
                            if let destinatie = job.urlDestinatie {
                                Button(L.t("job.openFile")) { NSWorkspace.shared.open(destinatie) }
                                    .buttonStyle(.plain)
                                    .font(.system(size: 10.5, weight: .medium))
                                    .foregroundStyle(Shift.accent)
                                Button(L.t("job.showInFinder")) { NSWorkspace.shared.activateFileViewerSelecting([destinatie]) }
                                    .buttonStyle(.plain)
                                    .font(.system(size: 10.5, weight: .medium))
                                    .foregroundStyle(Shift.accent)
                            }
                        }
                    case .anulat:
                        Label(L.t("queue.status.canceled"), systemImage: "xmark.circle")
                            .font(.system(size: 10.5))
                            .foregroundStyle(Shift.muted)
                    case .eroare(let mesaj):
                        Label(mesaj, systemImage: "xmark.circle.fill")
                            .font(.system(size: 10.5))
                            .foregroundStyle(Shift.error)
                            .lineLimit(2)
                    }
                }

                Spacer()

                if job.metadataMedia != nil {
                    Button { showPreview = true } label: {
                        Image(systemName: "eye")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Shift.muted)
                }

                Button { onSterge() } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
                .foregroundStyle(Shift.faint)
            }
        }
        // Reordonare (Faza 1, secțiunea F) — dezactivată cât timp coada rulează.
        .contextMenu {
            Button(L.t("queue.moveUp"), action: onMutaSus).disabled(seRuleazaCoada)
            Button(L.t("queue.moveDown"), action: onMutaJos).disabled(seRuleazaCoada)
        }
        .sheet(isPresented: $showPreview) {
            MediaPreviewSheet(job: job, isPresented: $showPreview)
        }
    }

    // Inspecție/Metadata (Faza 2) — thumbnail extras cu ffmpeg, populat
    // asincron de `ConvertorViewModel.analizeazaFisier`; icoana generică
    // rămâne fallback-ul cât timp analiza nu s-a terminat încă (sau a eșuat).
    @ViewBuilder
    private var thumbnailJob: some View {
        if let cale = job.caleThumbnail, let nsImage = NSImage(contentsOfFile: cale) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 48, height: 32)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        } else {
            Image(systemName: "film")
                .foregroundStyle(Shift.muted)
                .frame(width: 48, height: 32)
        }
    }

    private var metadataText: String? {
        guard let m = job.metadataMedia else { return nil }
        let parts = [
            m.rezolutieText,
            m.codecVideo?.uppercased(),
            m.frameRate.map { "\($0) fps" },
            m.durataSecunde.map { String(format: "%.1fs", $0) }
        ].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

#Preview {
    ContentView()
}
