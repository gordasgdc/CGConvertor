import SwiftUI
import UniformTypeIdentifiers

/// CRUD complet pentru Presets Manager (Faza 1 v3.0.0, secțiunea D) —
/// layout list-detail, port 1:1 al `presets_dialog.py` (Windows).
/// Presetările `isBuiltin` pot fi doar duplicate, nu editate/șterse
/// direct (un punct de plecare stabil, mereu disponibil).
struct PresetsManagerSheet: View {
    @State private var presets: [OutputPreset]
    @Binding var isPresented: Bool
    /// Al doilea parametru (2026-09-05, fix bug real raportat de Cristi:
    /// "dacă nu duplic nu pot seta fps... a exportat tot în fps-ul
    /// original") — presetarea pe care userul o vedea deschisă în acest
    /// panou când a închis fereastra. FĂRĂ asta, editarea/duplicarea unei
    /// presetări (ex. seta fps pe o copie) NU o făcea automat activă
    /// pentru conversie — presetarea folosită la Start rămânea cea VECHE,
    /// needitată, `presetSelectatID` din `ConvertorViewModel` nefiind
    /// niciodată actualizat de `reincarcaPresets()` (care doar recitește
    /// lista, nu schimbă selecția activă). Fix: presetarea pe care tocmai
    /// ai editat-o/dus-o devine automat cea activă la închidere.
    let onSave: ([OutputPreset], String?) -> Void

    @State private var selectedID: String?
    @State private var showImporter = false
    @State private var showExporter = false
    @State private var exportDocument: PresetsJSONDocument?

    init(presets: [OutputPreset], isPresented: Binding<Bool>, onSave: @escaping ([OutputPreset], String?) -> Void) {
        _presets = State(initialValue: presets)
        _isPresented = isPresented
        self.onSave = onSave
        _selectedID = State(initialValue: presets.first?.id)
    }

    private var selected: OutputPreset? {
        presets.first { $0.id == selectedID }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                listPane
                Divider().overlay(Shift.border)
                detailPane
            }
            Divider().overlay(Shift.border)
            HStack {
                Spacer()
                Button(L.t("presets.close")) { close() }
                    .buttonStyle(ShiftGhostButtonStyle())
            }
            .padding(14)
        }
        // Fix real (2026-09-06, cerut de Cristi): dimensiune FIXA
        // impiedica redimensionarea - utila mai ales aici, unde etichete
        // lungi de presetari pot fi taiate la 760px.
        .frame(minWidth: 760, idealWidth: 940, minHeight: 480, idealHeight: 560)
        .background(Shift.bg)
        .foregroundStyle(Shift.text)
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
            guard case .success(let url) = result, let imported = try? PresetsManager.importFromFile(url: url) else { return }
            let existingIDs = Set(presets.map(\.id))
            for var preset in imported {
                if existingIDs.contains(preset.id) { preset.id = "custom_\(UUID().uuidString.prefix(8))" }
                preset.isBuiltin = false
                presets.append(preset)
            }
        }
        .fileExporter(isPresented: $showExporter, document: exportDocument ?? PresetsJSONDocument(presets: presets),
                      contentType: .json, defaultFilename: "cgconvertor_presets") { _ in }
    }

    private var listPane: some View {
        VStack(spacing: 0) {
            List(selection: $selectedID) {
                ForEach(presets) { preset in
                    HStack {
                        Text(preset.label)
                        if preset.isBuiltin {
                            Image(systemName: "star.fill").font(.system(size: 9)).foregroundStyle(Shift.accent)
                        }
                    }
                    .tag(preset.id)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Shift.elevated)

            HStack(spacing: 6) {
                Button(L.t("presets.new"), action: newPreset).buttonStyle(ShiftGhostButtonStyle())
                Button(L.t("presets.duplicate"), action: duplicateSelected).buttonStyle(ShiftGhostButtonStyle())
                    .disabled(selected == nil)
            }
            .padding(8)
            HStack(spacing: 6) {
                Button(L.t("presets.delete"), action: deleteSelected).buttonStyle(ShiftGhostButtonStyle())
                    .disabled(selected?.isBuiltin != false)
            }
            .padding(.horizontal, 8).padding(.bottom, 6)
            HStack(spacing: 6) {
                Button(L.t("presets.import")) { showImporter = true }.buttonStyle(ShiftGhostButtonStyle())
                Button(L.t("presets.export")) { exportDocument = PresetsJSONDocument(presets: presets); showExporter = true }
                    .buttonStyle(ShiftGhostButtonStyle())
            }
            .padding(.horizontal, 8).padding(.bottom, 8)
        }
        .frame(width: 260)
        .background(Shift.panel)
    }

    @ViewBuilder
    private var detailPane: some View {
        if let preset = selected, let idx = presets.firstIndex(where: { $0.id == preset.id }) {
            Form {
                if preset.isBuiltin {
                    Text(L.t("presets.builtinHint"))
                        .font(.system(size: 11))
                        .foregroundStyle(Shift.accent)
                        .padding(8)
                        .background(Shift.elevated)
                }
                TextField(L.t("presets.label"), text: $presets[idx].label)
                    .disabled(preset.isBuiltin)
                TextField(L.t("presets.suffix"), text: $presets[idx].fileSuffix)
                    .disabled(preset.isBuiltin)
                Picker(L.t("presets.targetApp"), selection: $presets[idx].targetApp) {
                    ForEach(TargetApp.allCases) { app in
                        Text(L.t(app.labelKey)).tag(app)
                    }
                }
                .disabled(preset.isBuiltin)
                Picker(L.t("presets.profile"), selection: $presets[idx].profileID) {
                    Text(L.t("mode.rewrap")).tag(FormatRegistry.rewrapProfileID)
                    ForEach(FormatRegistry.allProfiles, id: \.id) { profil in
                        Text(profil.label).tag(profil.id)
                    }
                }
                .disabled(preset.isBuiltin)
                if presets[idx].profileID != FormatRegistry.rewrapProfileID {
                    Picker(L.t("presets.frameRate"), selection: $presets[idx].frameRate) {
                        Text(L.t("presets.frameRate.source")).tag(String?.none)
                        ForEach(FrameRateOption.allValues, id: \.self) { fps in
                            Text(fps).tag(String?.some(fps))
                        }
                    }
                    .disabled(preset.isBuiltin)
                    Picker(L.t("presets.colorSpace"), selection: $presets[idx].colorSpace) {
                        Text(L.t("presets.colorSpace.unchanged")).tag(ColorSpaceOption?.none)
                        ForEach(ColorSpaceOption.allCases) { cs in
                            Text(L.t(cs.labelKey)).tag(ColorSpaceOption?.some(cs))
                        }
                    }
                    .disabled(preset.isBuiltin)
                    Picker(L.t("presets.audioMode"), selection: $presets[idx].audioMode) {
                        ForEach(AudioMode.allCases) { mode in
                            Text(L.t(mode.labelKey)).tag(mode)
                        }
                    }
                    .disabled(preset.isBuiltin)
                    if presets[idx].audioMode != .passthrough {
                        Picker(L.t("presets.channels"), selection: $presets[idx].channelLayout) {
                            ForEach(ChannelLayout.allCases) { layout in
                                Text(L.t(layout.labelKey)).tag(layout)
                            }
                        }
                        .disabled(preset.isBuiltin)
                    }
                }
            }
            .padding(16)
            .background(Shift.bg)
        } else {
            Color.clear
        }
    }

    private func newPreset() {
        let id = "custom_\(UUID().uuidString.prefix(8))"
        let preset = OutputPreset(id: id, label: L.t("presets.new"), targetApp: .custom,
                                   profileID: "prores422hq", fileSuffix: "_custom")
        presets.append(preset)
        selectedID = id
    }

    private func duplicateSelected() {
        guard let preset = selected else { return }
        let id = "custom_\(UUID().uuidString.prefix(8))"
        let clone = PresetsManager.duplicate(preset, newID: id, newLabel: "\(preset.label) (copie)")
        presets.append(clone)
        selectedID = id
    }

    private func deleteSelected() {
        guard let preset = selected, !preset.isBuiltin else { return }
        presets.removeAll { $0.id == preset.id }
        selectedID = presets.first?.id
    }

    private func close() {
        onSave(presets, selectedID)
        isPresented = false
    }
}

struct PresetsJSONDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var presets: [OutputPreset]

    init(presets: [OutputPreset]) { self.presets = presets }

    init(configuration: ReadConfiguration) throws {
        let data = configuration.file.regularFileContents ?? Data()
        presets = (try? JSONDecoder().decode([OutputPreset].self, from: data)) ?? []
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = try JSONEncoder().encode(presets)
        return FileWrapper(regularFileWithContents: data)
    }
}
