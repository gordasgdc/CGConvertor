import SwiftUI
import UniformTypeIdentifiers

extension VerificationModel {
    /// Eticia scurtă afișată pe nodul de verificare.
    var shortLabel: String {
        switch self {
        case .xxhash64: return "xxHash64"
        case .md5: return "MD5"
        case .sha1: return "SHA-1"
        case .sha256: return "SHA-256"
        case .sizeOnly: return L.t("offload.verify.sizeOnly")
        }
    }
}

/// Opțiunile transferului (producție, denumire, verificare, buffer/RAM) — apărute în foaia „Opțiuni”.
struct OffloadOptionsSheet: View {
    @Binding var meta: ProductionMeta
    @Binding var namingTemplate: String
    @Binding var verificationModel: VerificationModel
    @Binding var chunkSizeMB: Int
    @Binding var ramLimitMB: Int
    @Binding var isPresented: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: DM.Space.l) {
            Text(L.t("offload.options")).font(DM.Font.title)
            ScrollView {
                VStack(alignment: .leading, spacing: DM.Space.l) {
                    DMPanel { production }
                    DMPanel { naming }
                    DMPanel { verification }
                    DMPanel { io }
                }
            }
            HStack { Spacer(); Button(L.t("offload.options.done")) { isPresented = false }.keyboardShortcut(.defaultAction) }
        }
        .padding(DM.Space.xl).frame(width: 600, height: 640)
    }

    private func field(_ label: String, _ value: Binding<String>) -> some View {
        HStack(spacing: DM.Space.s) {
            Text(label).font(DM.Font.detail).foregroundStyle(DM.textSecondary).frame(width: 90, alignment: .leading)
            TextField("", text: value).textFieldStyle(.roundedBorder)
        }
    }

    private var production: some View {
        VStack(alignment: .leading, spacing: DM.Space.s) {
            DMSectionHeader(title: L.t("offload.production.title"))
            field(L.t("offload.production.project"), $meta.project)
            field(L.t("offload.production.card"), $meta.card)
            field(L.t("offload.production.client"), $meta.client)
            field(L.t("offload.production.camera"), $meta.camera)
            field(L.t("offload.production.operator"), $meta.operatorName)
            HStack(spacing: DM.Space.s) {
                Text(L.t("offload.production.logo")).font(DM.Font.detail).foregroundStyle(DM.textSecondary).frame(width: 90, alignment: .leading)
                Button(L.t("offload.production.chooseLogo")) { chooseLogo() }
                if !meta.logoPath.isEmpty { Button(L.t("offload.production.clearLogo")) { meta.logoPath = "" } }
            }
            TextField(L.t("offload.production.notes"), text: $meta.notes, axis: .vertical)
                .textFieldStyle(.roundedBorder).lineLimit(2...4)
        }
    }

    private func chooseLogo() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        if let png = UTType(filenameExtension: "png"), let jpg = UTType(filenameExtension: "jpg") { panel.allowedContentTypes = [png, jpg] }
        if panel.runModal() == .OK, let url = panel.url { meta.logoPath = url.path }
    }

    private var naming: some View {
        VStack(alignment: .leading, spacing: DM.Space.s) {
            DMSectionHeader(title: L.t("offload.naming.title"))
            TextField(NamingTemplate.defaultTemplate, text: $namingTemplate).textFieldStyle(.roundedBorder).font(DM.Font.mono)
            HStack(spacing: DM.Space.xs) {
                ForEach(NamingTemplate.tokens, id: \.self) { token in
                    Button(token) { namingTemplate += token }.controlSize(.small).font(DM.Font.mono)
                }
            }
            Text("\(L.t("offload.naming.preview")): \(NamingTemplate.render(namingTemplate, context: .init(project: meta.project, card: meta.card, camera: meta.camera, operatorName: meta.operatorName, date: Date())))")
                .font(DM.Font.mono).foregroundStyle(DM.accent)
        }
    }

    private var verification: some View {
        VStack(alignment: .leading, spacing: DM.Space.s) {
            DMSectionHeader(title: L.t("offload.verify.title"))
            Picker("", selection: $verificationModel) {
                ForEach(VerificationModel.allCases) { Text($0.label).tag($0) }
            }.pickerStyle(.radioGroup).labelsHidden()
        }
    }

    private var io: some View {
        VStack(alignment: .leading, spacing: DM.Space.s) {
            DMSectionHeader(title: L.t("offload.io.title"))
            HStack {
                Text(L.t("offload.io.buffer"))
                Spacer()
                Picker("", selection: $chunkSizeMB) { ForEach(IOSettings.chunkSizeChoicesMB, id: \.self) { Text(IOSettings.formattedMB($0)).tag($0) } }
                    .labelsHidden().frame(width: 110)
                    .onChange(of: chunkSizeMB) { _, v in IOSettings.chunkSizeMB = v }
            }
            HStack {
                Text(L.t("offload.io.ramLimit"))
                Spacer()
                Picker("", selection: $ramLimitMB) { ForEach(IOSettings.ramLimitChoicesMB, id: \.self) { Text($0 == 0 ? "—" : IOSettings.formattedMB($0)).tag($0) } }
                    .labelsHidden().frame(width: 110)
                    .onChange(of: ramLimitMB) { _, v in IOSettings.ramLimitMB = v }
            }
        }
    }
}
