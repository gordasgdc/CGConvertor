import SwiftUI
import AppKit

/// Port 1:1 al ActivationSheet.swift din GDCVault — introducere cod +
/// buton WhatsApp. Codul se generează manual din Furnizor
/// (GenerateSerialView.swift, `cgconvertor` în `gdcStandaloneProducts`),
/// NU un sistem de plată automatizat.
struct ActivationSheet: View {
    @ObservedObject var license: LicenseManager
    @Binding var isPresented: Bool
    @State private var code: String = ""
    @State private var justCopied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L.t("license.title")).font(.title2).bold()

            VStack(alignment: .leading, spacing: 4) {
                Text(L.t("license.machineID")).font(.system(size: 11)).foregroundStyle(.secondary)
                HStack {
                    Text(MachineID.display).font(.system(.body, design: .monospaced))
                    Button(justCopied ? L.t("license.copied") : L.t("license.copy")) {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(MachineID.display, forType: .string)
                        justCopied = true
                    }
                    .buttonStyle(.bordered)
                }
            }

            TextField(L.t("license.codePlaceholder"), text: $code)
                .textFieldStyle(.roundedBorder)

            if let error = license.activationError {
                Text(error).foregroundStyle(.red).font(.system(size: 12))
            }

            Text(L.t("license.note"))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            Button {
                NSWorkspace.shared.open(WhatsAppLink.url(text: "Bună, vreau să activez CG Convertor. ID calculator: \(MachineID.display)"))
            } label: {
                Label(L.t("license.whatsapp"), systemImage: "message.fill")
                    .font(.system(size: 12))
            }
            .buttonStyle(.bordered)
            .tint(.green)

            HStack {
                Button(L.t("license.cancel")) { isPresented = false }
                Spacer()
                Button(L.t("license.activate")) {
                    if license.activate(code: code) {
                        isPresented = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(code.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 440)
    }
}
