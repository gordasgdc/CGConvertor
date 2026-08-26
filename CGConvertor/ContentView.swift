import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var vm = ConvertorViewModel()
    @ObservedObject private var license = LicenseManager.shared
    @ObservedObject private var deps = DependencyManager.shared
    @State private var seAfiseazaDropTarget = false
    @State private var showActivation = false
    @State private var showUpdateAlert = false
    @State private var updateAlertVersion = ""
    @State private var showDependencyPanel = false

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }

    var body: some View {
        VStack(spacing: 0) {
            antet
            if !license.isLicensed {
                trialBanner
            }

            HStack(spacing: 0) {
                panouSetari
                    .frame(width: 300)
                Divider().overlay(Shift.border)
                panouListaJoburi
            }
        }
        .background(Shift.bg)
        .foregroundStyle(Shift.text)
        .onAppear {
            vm.verificaFFmpeg()
            deps.refreshAll()
            UpdateChecker.checkSilentlyOnLaunch { newVersion in
                updateAlertVersion = newVersion
                showUpdateAlert = true
            }
        }
        .sheet(isPresented: $showActivation) {
            ActivationSheet(license: license, isPresented: $showActivation)
        }
        .sheet(isPresented: $showDependencyPanel) {
            DependencyPanel(deps: deps, isPresented: $showDependencyPanel)
        }
        .alert(L.t("update.available.title"), isPresented: $showUpdateAlert) {
            Button(L.t("update.download")) {
                NSWorkspace.shared.open(URL(string: "https://github.com/gordasgdc/CGConvertor/releases/latest")!)
                UpdateChecker.markDismissed(updateAlertVersion)
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
            Text(license.isTrialActive
                 ? String(format: L.t("trial.daysLeft"), license.trialDaysRemaining)
                 : L.t("trial.expired"))
                .font(.system(size: 11.5))
                .foregroundStyle(license.isTrialActive ? Shift.muted : Shift.error)
            Spacer()
            Button(L.t("trial.activate")) { showActivation = true }
                .buttonStyle(.plain)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(Shift.accent)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 7)
        .background(license.isTrialActive ? Shift.elevated : Shift.error.opacity(0.12))
        .overlay(Rectangle().frame(height: 1).foregroundStyle(Shift.border), alignment: .bottom)
    }

    // ── Panou setari (stanga) ───────────────────────────────────────────────
    private var sfatCodec: String {
        switch vm.codecAles {
        case .proRes422: return L.t("codec.hint.proRes422")
        case .proRes422HQ: return L.t("codec.hint.proRes422HQ")
        case .proRes422LT: return L.t("codec.hint.proRes422LT")
        case .proRes4444: return L.t("codec.hint.proRes4444")
        case .dnxhd, .dnxhr: return L.t("codec.hint.dnx")
        }
    }

    private var panouSetari: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ShiftCard {
                    VStack(alignment: .leading, spacing: 8) {
                        ShiftSectionLabel(text: L.t("mode.title"))
                        VStack(spacing: 6) {
                            modeRow(.rewrap, title: L.t("mode.rewrap"), hint: L.t("mode.rewrap.hint"), icon: "arrow.triangle.swap")
                            modeRow(.transcode, title: L.t("mode.transcode"), hint: L.t("mode.transcode.hint"), icon: "wand.and.stars")
                        }
                    }
                }

                if vm.modConversie == .transcode {
                    ShiftCard {
                        VStack(alignment: .leading, spacing: 8) {
                            ShiftSectionLabel(text: L.t("codec.title"))
                            Picker("", selection: $vm.codecAles) {
                                ForEach(CodecOutput.allCases) { codec in
                                    Text(codec.rawValue).tag(codec)
                                }
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                            .tint(Shift.text)

                            Text(sfatCodec)
                                .font(.system(size: 11))
                                .foregroundStyle(Shift.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
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
    }

    private func modeRow(_ mod: ModConversie, title: String, hint: String, icon: String) -> some View {
        Button { vm.modConversie = mod } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.system(size: 12.5, weight: .medium))
                    Text(hint).font(.system(size: 10.5)).foregroundStyle(Shift.muted)
                }
                Spacer()
                Image(systemName: vm.modConversie == mod ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(vm.modConversie == mod ? Shift.accent : Shift.faint)
            }
            .padding(9)
            .background(vm.modConversie == mod ? Shift.elevated : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .foregroundStyle(Shift.text)
    }

    private var actiuneButon: some View {
        Group {
            if vm.seRuleazaCoada {
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
            } else {
                Button {
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
                .disabled(vm.joburi.isEmpty || !deps.isReady)
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
                            RandJob(job: job) { vm.stergeJob(job) }
                        }
                    }
                    .padding(14)
                }

                HStack {
                    Button(L.t("queue.clear")) { vm.golesteLista() }
                        .buttonStyle(ShiftGhostButtonStyle())
                        .disabled(vm.seRuleazaCoada)
                        .keyboardShortcut("k", modifiers: [.command])
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
    let onSterge: () -> Void

    var body: some View {
        ShiftCard(padding: 12) {
            HStack(spacing: 12) {
                Image(systemName: "film")
                    .foregroundStyle(Shift.muted)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 4) {
                    Text(job.numeFisier)
                        .font(.system(size: 12.5))
                        .lineLimit(1)
                        .truncationMode(.middle)

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

                Button { onSterge() } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
                .foregroundStyle(Shift.faint)
            }
        }
    }
}

#Preview {
    ContentView()
}
