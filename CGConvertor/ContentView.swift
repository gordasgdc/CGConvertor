import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var vm = ConvertorViewModel()
    @State private var seAfiseazaDropTarget = false

    var body: some View {
        VStack(spacing: 0) {
            antet
            Divider()

            if !vm.ffmpegInstalat {
                avertismentFFmpeg
            }

            HStack(spacing: 0) {
                panouSetari
                    .frame(width: 280)
                Divider()
                panouListaJoburi
            }
        }
        .onAppear { vm.verificaFFmpeg() }
        .background(Color(NSColor.windowBackgroundColor))
    }

    // ── Antet ────────────────────────────────────────────────────────────────
    // ── Sfat dinamic in functie de codecul ales ─────────────────────────────
    private var sfatCodec: String {
        switch vm.codecAles {
        case .proRes422:
            return "Recomandat pentru surse 4:2:0 (HEVC, H.264, majoritatea camerelor consumer/mirrorless). Pastreaza tot detaliul sursei fara sa umfle fisierul inutil."
        case .proRes422HQ:
            return "Recomandat pentru surse deja 4:2:2 (ProRes, DNxHD, camere broadcast/cinema). Pe surse 4:2:0 nu aduce calitate suplimentara fata de ProRes 422 simplu."
        case .proRes422LT:
            return "Bitrate redus, pentru proxy-uri sau preview rapid. Nu recomandat pentru grading final."
        case .proRes4444:
            return "Doar pentru surse 4:4:4 native sau cu canal alpha. Pe o sursa 4:2:0 (HEVC/H.264) nu adauga informatie reala — doar umfle fisierul."
        case .dnxhd, .dnxhr:
            return "Alternativa Avid la ProRes. Foloseste daca lucrezi si in Media Composer."
        }
    }

    private var antet: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("CG Convertor")
                    .font(.title2.bold())
                Text("Transcode & Rewrap pentru DaVinci Resolve")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if vm.seRuleazaCoada {
                ProgressView()
                    .controlSize(.small)
                Text("Se proceseaza...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }

    private var avertismentFFmpeg: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            (Text("FFmpeg nu este instalat. Deschide Terminal si ruleaza: ")
                + Text("brew install ffmpeg").bold().monospaced())
            Spacer()
            Button("Reverifica") { vm.verificaFFmpeg() }
        }
        .font(.callout)
        .padding(10)
        .background(Color.orange.opacity(0.15))
    }

    // ── Panou setari (stanga) ───────────────────────────────────────────────
    private var panouSetari: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Mod conversie")
                    .font(.headline)
                Picker("", selection: $vm.modConversie) {
                    ForEach(ModConversie.allCases) { mod in
                        Text(mod.rawValue).tag(mod)
                    }
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()
            }

            if vm.modConversie == .transcode {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Codec output")
                        .font(.headline)
                    Picker("", selection: $vm.codecAles) {
                        ForEach(CodecOutput.allCases) { codec in
                            Text(codec.rawValue).tag(codec)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()

                    Text(sfatCodec)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Folder destinatie")
                    .font(.headline)
                Text(vm.folderDestinatie?.path ?? "La fel ca sursa")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.middle)
                Button("Alege folder...") {
                    vm.alegeFolderDestinatie()
                }
            }

            Spacer()

            Button {
                vm.pornesteCoada()
            } label: {
                Label("Porneste conversia", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(vm.joburi.isEmpty || vm.seRuleazaCoada || !vm.ffmpegInstalat)
        }
        .padding()
    }

    // ── Panou lista joburi (dreapta) ────────────────────────────────────────
    private var panouListaJoburi: some View {
        VStack(spacing: 0) {
            if vm.joburi.isEmpty {
                zonaDropGoala
            } else {
                List {
                    ForEach(vm.joburi) { job in
                        RandJob(job: job) {
                            vm.stergeJob(job)
                        }
                    }
                }
                .listStyle(.plain)

                HStack {
                    Button("Goleste lista", role: .destructive) {
                        vm.golesteLista()
                    }
                    Spacer()
                    Button {
                        deschideSelectorFisiere()
                    } label: {
                        Label("Adauga fisiere...", systemImage: "plus")
                    }
                }
                .padding(10)
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $seAfiseazaDropTarget) { providers in
            primesteFisiereDinDrop(providers)
            return true
        }
        .overlay {
            if seAfiseazaDropTarget {
                Rectangle()
                    .strokeBorder(Color.accentColor, lineWidth: 3)
                    .background(Color.accentColor.opacity(0.08))
            }
        }
    }

    private var zonaDropGoala: some View {
        VStack(spacing: 14) {
            Image(systemName: "arrow.down.doc")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("Trage fisiere video aici")
                .font(.title3)
            Text("sau")
                .foregroundStyle(.secondary)
            Button("Alege fisiere...") {
                deschideSelectorFisiere()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

// ── Rand individual pentru un job ───────────────────────────────────────────
private struct RandJob: View {
    let job: VideoJob
    let onSterge: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "film")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                Text(job.numeFisier)
                    .lineLimit(1)
                    .truncationMode(.middle)

                switch job.stare {
                case .astept:
                    Text("In asteptare")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                case .inLucru(let progres):
                    ProgressView(value: progres)
                        .frame(maxWidth: 240)
                case .finalizat:
                    Label("Finalizat", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                case .eroare(let mesaj):
                    Label(mesaj, systemImage: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .lineLimit(2)
                }
            }

            Spacer()

            Button {
                onSterge()
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ContentView()
}
