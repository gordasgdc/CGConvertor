import SwiftUI
import UniformTypeIdentifiers

/// Fereastra principală: toolbar comun + unul din cele trei spații de lucru (Transcodare, Offload, Metadate).
struct ContentView: View {
    @StateObject private var vm = ConvertorViewModel()
    @StateObject private var shell = ShellState()
    @ObservedObject private var license = LicenseManager.shared
    @ObservedObject private var deps = DependencyManager.shared
    @ObservedObject private var revocation = RevocationCheck.shared
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var watchFolders = WatchFolderManager.shared
    @State private var showActivation = false
    @State private var showUpdateAlert = false
    @State private var updateAlertVersion = ""
    @State private var updateAlertPkgURL: URL?
    @State private var showDependencyPanel = false
    @State private var showPresetsManager = false
    @State private var showSettingsSheet = false
    @State private var showWatchFolderExistingSheet = false
    @State private var pendingWatchFolderPath = ""
    @State private var pendingWatchFolderFiles: [URL] = []
    @State private var langVersion = 0

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            if !license.isLicensed || revocation.isRevoked {
                trialBanner
            }
            Group {
                switch shell.workspace {
                case .transcode:
                    TranscodeWorkspace(vm: vm, shell: shell,
                                       onActivate: { showActivation = true },
                                       onPresets: { showPresetsManager = true },
                                       onAddWatchFolder: { alegeWatchFolder() })
                case .offload:
                    OffloadView(onSendToTranscode: { urls in
                        vm.adaugaFisiere(urls)
                        shell.workspace = .transcode
                    })
                case .metadata:
                    MetadataWorkspace(vm: vm, shell: shell)
                }
            }
        }
        .id("\(langVersion)-\(settings.themePreference.rawValue)")
        .onReceive(DistributedNotificationCenter.default().publisher(for: Notification.Name("AppleInterfaceThemeChangedNotification"))) { _ in
            if settings.themePreference == .system { langVersion += 1 }
        }
        .background(Shift.bg)
        .foregroundStyle(Shift.text)
        .dynamicTypeSize(settings.textScale.dynamicTypeSize)
        .preferredColorScheme(settings.themePreference.colorScheme)
        .onAppear {
            #if DEBUG
            // Doar pentru verificari vizuale in build Debug: incarca fisiere in coada.
            if let pre = ProcessInfo.processInfo.environment["CGC_PRELOAD"] {
                let urls = pre.split(separator: "|").map { URL(fileURLWithPath: String($0)) }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    vm.adaugaFisiere(urls)
                    let env = ProcessInfo.processInfo.environment
                    if let pid = env["CGC_PRESET"] { vm.presetSelectatID = pid }
                    if let d = env["CGC_DEST"] { vm.folderDestinatie = URL(fileURLWithPath: d) }
                    if let st = env["CGC_STOP_AFTER"].flatMap(Double.init) {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3 + st) { vm.opresteCoada() }
                    }
                    if env["CGC_START"] == "1" {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            if let iv = env["CGC_INTERVAL"]?.split(separator: ",").compactMap({ Double($0) }), iv.count == 2 {
                                for j in vm.joburi { vm.seteazaInterval(j, start: iv[0], end: iv[1]) }
                            }
                            vm.pornesteCoada()
                        }
                    }
                }
            }
            #endif
            #if DEBUG
            if ProcessInfo.processInfo.environment["CGC_OPEN_SETTINGS"] == "1" {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { showSettingsSheet = true }
            }
            #endif
            #if DEBUG
            UISnapshot.runIfRequested(vm: vm, shell: shell)
            #endif
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
            PresetsManagerSheet(presets: vm.presets, isPresented: $showPresetsManager) { updated, lastSelectedID in
                PresetsManager.save(updated)
                vm.reincarcaPresets()
                // Fix bug real (2026-09-05): presetarea pe care userul
                // tocmai a editat-o/dus-o (ex. a setat fps pe o copie)
                // devine automat cea activa pentru conversie - altfel
                // Start foloseste in continuare presetarea veche, needitata.
                if let lastSelectedID, updated.contains(where: { $0.id == lastSelectedID }) {
                    vm.presetSelectatID = lastSelectedID
                }
            }
        }
        .sheet(isPresented: $showSettingsSheet) {
            SettingsSheet(isPresented: $showSettingsSheet)
        }
        .sheet(isPresented: $showWatchFolderExistingSheet) {
            WatchFolderExistingFilesSheet(files: pendingWatchFolderFiles, isPresented: $showWatchFolderExistingSheet) { selectate in
                watchFolders.markBaselineKnown(forPath: pendingWatchFolderPath, files: pendingWatchFolderFiles)
                if !selectate.isEmpty { vm.adaugaFisiere(selectate) }
            }
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

    // ── Toolbar comun ───────────────────────────────────────────────────────
    private var toolbar: some View {
        HStack(spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "film.stack").font(.system(size: 18)).foregroundStyle(Shift.accent)
                VStack(alignment: .leading, spacing: 0) {
                    Text(L.t("app.title")).font(.system(size: 14, weight: .bold))
                    Text("v\(appVersion)").font(.system(size: 9.5, design: .monospaced)).foregroundStyle(Shift.faint)
                }
            }
            Picker("", selection: $shell.workspace) {
                ForEach(Workspace.allCases) { w in Label(w.label, systemImage: w.icon).tag(w) }
            }
            .pickerStyle(.segmented).labelsHidden().frame(maxWidth: 420)
            .accessibilityLabel(L.t("ws.picker"))
            Spacer()
            if vm.seRuleazaCoada { ProgressView().controlSize(.small).tint(Shift.accent) }
            DependencyBadge(deps: deps, showPanel: $showDependencyPanel)
            themeMenu
            langMenu
            Button { UpdateChecker.checkAndShowAlert() } label: { Image(systemName: "arrow.triangle.2.circlepath") }
                .buttonStyle(.plain).foregroundStyle(Shift.muted).help(L.t("menu.checkForUpdates"))
            Button { HelpGuide.openPDF() } label: { Image(systemName: "questionmark.circle") }
                .buttonStyle(.plain).foregroundStyle(Shift.muted).help(L.t("menu.helpGuide"))
            Button { showSettingsSheet = true } label: { Image(systemName: "gearshape") }
                .buttonStyle(.plain).foregroundStyle(Shift.muted).help(L.t("sidebar.settings"))
        }
        .padding(.horizontal, 16).padding(.vertical, 9)
        .background(Shift.panel)
        .overlay(Rectangle().frame(height: 1).foregroundStyle(Shift.border), alignment: .bottom)
    }

    private var themeMenu: some View {
        Menu {
            ForEach(ThemePreference.allCases) { t in
                Button { settings.themePreference = t } label: {
                    if settings.themePreference == t { Label(t.label, systemImage: "checkmark") } else { Text(t.label) }
                }
            }
        } label: { Image(systemName: "circle.lefthalf.filled") }
        .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize().foregroundStyle(Shift.muted)
        .help(L.t("settings.theme"))
    }

    private var langMenu: some View {
        Menu {
            ForEach(AppLanguage.allCases) { lang in
                Button { L.current = lang; langVersion += 1 } label: {
                    if L.current == lang { Label(lang.displayName, systemImage: "checkmark") } else { Text(lang.displayName) }
                }
            }
        } label: { Text(L.current.rawValue.uppercased()).font(.system(size: 10.5, weight: .semibold, design: .monospaced)) }
        .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize().foregroundStyle(Shift.muted)
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

    private func alegeWatchFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Adaugă"
        if panel.runModal() == .OK, let path = panel.url?.path {
            watchFolders.addFolder(path)
            // Feedback direct de la Cristi (2026-09-05): fara acest pas,
            // indicarea unui folder cu clipuri deja existente nu facea
            // nimic (baseline ignora tot ce exista deja) - userul ar fi
            // trebuit sa copieze/mute fisierele ca sa "para noi", exact
            // duplicarea nedorita. Sheet-ul arata explicit lista, cu
            // Selecteaza tot/Deselecteaza tot (cerute explicit) - nu doar
            // un Da/Nu orb care ar arunca tacit un folder plin in coada.
            let existente = watchFolders.listExistingFiles(forPath: path)
            if !existente.isEmpty {
                pendingWatchFolderPath = path
                pendingWatchFolderFiles = existente
                showWatchFolderExistingSheet = true
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
