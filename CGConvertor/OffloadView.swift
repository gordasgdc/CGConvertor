import SwiftUI
import AppKit

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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                volumesSection
                sourceSection
                destinationsSection
                verificationSection
                ioSection
                if !runner.activityLog.isEmpty { activitySection }
                if !runner.lastResults.isEmpty { resultsSection }
                footer
            }
            .padding(18)
        }
        .background(Shift.bg)
        .onAppear { voluri = VolumeInfo.detectAll() }
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
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(voluri) { vol in
                                VStack(spacing: 4) {
                                    Image(nsImage: vol.icon).resizable().frame(width: 32, height: 32)
                                    Text(vol.name).font(.system(size: 11, weight: .medium)).lineLimit(1)
                                    Text(formatBytes(vol.freeBytes)).font(.system(size: 9.5, design: .monospaced)).foregroundStyle(Shift.faint)
                                    HStack(spacing: 6) {
                                        Button(L.t("offload.volumes.useAsSource")) { sourcePath = vol.path }
                                            .buttonStyle(.plain).font(.system(size: 9.5)).foregroundStyle(Shift.accent)
                                        Button("+") {
                                            if !destinations.contains(vol.path) { destinations.append(vol.path) }
                                        }
                                        .buttonStyle(.plain).font(.system(size: 11, weight: .bold)).foregroundStyle(Shift.accent)
                                        .help(L.t("offload.volumes.useAsDestination"))
                                    }
                                }
                                .padding(8)
                                .frame(width: 110)
                                .background(sourcePath == vol.path ? Shift.accent.opacity(0.12) : Shift.elevated)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
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
                    Button(L.t("offload.source.choose")) { alegeSursa() }
                        .buttonStyle(.plain)
                        .foregroundStyle(Shift.accent)
                }
            }
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
                        if let csvPath = result.csvPath {
                            Button(L.t("offload.results.openReport")) {
                                NSWorkspace.shared.selectFile(csvPath, inFileViewerRootedAtPath: "")
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 11))
                            .foregroundStyle(Shift.accent)
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
                        runner.start(sourceRoot: src, destinations: destinations, model: verificationModel)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Shift.accent)
                    .disabled(sourcePath == nil || destinations.isEmpty)
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
