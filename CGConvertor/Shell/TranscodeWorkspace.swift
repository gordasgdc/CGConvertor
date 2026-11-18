import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Spațiul „Transcodare”: clipuri (grilă/listă) în centru, inspector în dreapta, bară de acțiune jos.
struct TranscodeWorkspace: View {
    @ObservedObject var vm: ConvertorViewModel
    @ObservedObject var shell: ShellState
    @ObservedObject private var license = LicenseManager.shared
    @ObservedObject private var deps = DependencyManager.shared
    @ObservedObject private var revocation = RevocationCheck.shared
    let onActivate: () -> Void
    let onPresets: () -> Void
    let onAddWatchFolder: () -> Void

    @State private var dropTarget = false
    @State private var pendingStart: (ids: Set<UUID>, prev: ConvertorViewModel.Previzualizare)?

    private var ordered: [UUID] { vm.joburi.map(\.id) }
    private var marcate: Set<UUID> { Set(vm.joburi.filter(\.marcat).map(\.id)) }

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                headerBar
                Divider().overlay(Shift.border)
                if vm.joburi.isEmpty { emptyState } else { clips }
                Divider().overlay(Shift.border)
                actionBar
            }
            Divider().overlay(Shift.border)
            TranscodeInspector(vm: vm, shell: shell, onPresets: onPresets, onAddWatchFolder: onAddWatchFolder)
                .frame(width: 340)
        }
        .background(Shift.bg)
        .onChange(of: vm.joburi.count) { _, _ in shell.prune(existing: ordered) }
        .alert(L.t("tw.confirm.title"), isPresented: Binding(get: { pendingStart != nil }, set: { if !$0 { pendingStart = nil } })) {
            Button(L.t("tw.confirm.start")) { if let p = pendingStart { realStart(p.ids) }; pendingStart = nil }
            Button(L.t("offload.cancel"), role: .cancel) { pendingStart = nil }
        } message: {
            Text((pendingStart?.prev.avertismente ?? []).joined(separator: "\n"))
        }
    }

    // ── Antet: adăugare, mod afișare, marcare ──
    private var headerBar: some View {
        HStack(spacing: 10) {
            Button { openFiles() } label: { Label(L.t("queue.addFiles"), systemImage: "plus") }
                .buttonStyle(ShiftGhostButtonStyle())
                .keyboardShortcut("o", modifiers: [.command])
            Picker("", selection: $shell.viewMode) {
                ForEach(ClipViewMode.allCases) { m in Image(systemName: m.icon).tag(m) }
            }
            .pickerStyle(.segmented).labelsHidden().frame(width: 84)
            .help(L.t("tw.viewMode"))
            Menu {
                Button(L.t("tw.markAll")) { vm.marcheaza(Set(ordered), true) }
                Button(L.t("tw.markNone")) { vm.marcheaza(Set(ordered), false) }
                if !shell.selection.isEmpty {
                    Divider()
                    Button(L.t("tw.markSelected")) { vm.marcheaza(shell.selection, true) }
                    Button(L.t("tw.unmarkSelected")) { vm.marcheaza(shell.selection, false) }
                }
                Divider()
                Button(L.t("queue.selectAll")) { shell.selection = Set(ordered) }
                    .keyboardShortcut("a", modifiers: [.command])
                Button(L.t("queue.selectNone")) { shell.selection.removeAll() }
            } label: { Label(L.t("tw.select"), systemImage: "checkmark.circle") }
            .menuStyle(.borderlessButton).fixedSize()
            Button { if let url = vm.genereazaRaportHTML() { NSWorkspace.shared.open(url) } } label: { Label(L.t("queue.report"), systemImage: "doc.text") }
                .buttonStyle(ShiftGhostButtonStyle()).disabled(vm.joburi.isEmpty)
            Spacer()
            Text(String(format: L.t("tw.counts"), vm.joburi.count, vm.joburi.filter(\.marcat).count, shell.selection.count))
                .font(.system(size: 11)).foregroundStyle(Shift.muted)
            Button { vm.golesteLista(); shell.selection.removeAll(); shell.focusID = nil } label: { Image(systemName: "trash") }
                .buttonStyle(.plain).foregroundStyle(Shift.faint).disabled(vm.seRuleazaCoada || vm.joburi.isEmpty)
                .help(L.t("queue.clear")).keyboardShortcut("k", modifiers: [.command])
        }
        .padding(.horizontal, 14).padding(.vertical, 9)
        .background(Shift.panel)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "arrow.down.doc").font(.system(size: 40)).foregroundStyle(Shift.faint)
            Text(L.t("queue.empty.title")).font(.system(size: 15, weight: .medium))
            Text(L.t("queue.empty.or")).font(.system(size: 11)).foregroundStyle(Shift.muted)
            Button(L.t("queue.chooseFiles")) { openFiles() }.buttonStyle(ShiftGhostButtonStyle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .modifier(DropOverlay(dropTarget: $dropTarget, onDrop: { vm.adaugaFisiere($0) }))
    }

    @ViewBuilder
    private var clips: some View {
        Group {
            if shell.viewMode == .grid {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 170, maximum: 240), spacing: 12)], spacing: 12) {
                        ForEach(vm.joburi) { job in
                            ClipCell(job: job, preset: vm.presetEfectiv(job), selected: shell.selection.contains(job.id),
                                     onTap: { shell.click(job.id, ordered: ordered) },
                                     onMark: { vm.marcheaza([job.id], !job.marcat) })
                                .contextMenu { clipMenu(job) }
                        }
                    }
                    .padding(14)
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(vm.joburi) { job in
                            ClipRow(job: job, preset: vm.presetEfectiv(job), selected: shell.selection.contains(job.id),
                                    onTap: { shell.click(job.id, ordered: ordered) },
                                    onMark: { vm.marcheaza([job.id], !job.marcat) })
                                .contextMenu { clipMenu(job) }
                            Divider().overlay(Shift.border.opacity(0.6))
                        }
                    }
                }
            }
        }
        .modifier(DropOverlay(dropTarget: $dropTarget, onDrop: { vm.adaugaFisiere($0) }))
    }

    @ViewBuilder
    private func clipMenu(_ job: VideoJob) -> some View {
        let ids: Set<UUID> = shell.selection.contains(job.id) ? shell.selection : [job.id]
        Button(L.t("tw.markSelected")) { vm.marcheaza(ids, true) }
        Button(L.t("tw.unmarkSelected")) { vm.marcheaza(ids, false) }
        Divider()
        Button(L.t("queue.moveUp")) { vm.mutaJob(job, delta: -1) }.disabled(vm.seRuleazaCoada)
        Button(L.t("queue.moveDown")) { vm.mutaJob(job, delta: 1) }.disabled(vm.seRuleazaCoada)
        Divider()
        Button(L.t("tw.reveal")) { NSWorkspace.shared.activateFileViewerSelecting([job.urlSursa]) }
        Button(L.t("tw.remove"), role: .destructive) {
            for id in ids { if let j = vm.joburi.first(where: { $0.id == id }) { vm.stergeJob(j) } }
        }
    }

    // ── Bara de acțiune: ce se va produce, progres total, Start/Pauză/Stop ──
    private var actionBar: some View {
        VStack(spacing: 8) {
            if vm.seRuleazaCoada { runningInfo } else { summary }
            HStack(spacing: 10) {
                if vm.seRuleazaCoada {
                    Button { vm.comutaPauza() } label: {
                        Label(vm.estePauza ? L.t("resume.action") : L.t("pause.action"), systemImage: vm.estePauza ? "play.fill" : "pause.fill")
                    }.buttonStyle(ShiftGhostButtonStyle())
                    Button { vm.opresteCoada() } label: { Label(L.t("action.stop"), systemImage: "stop.fill") }
                        .buttonStyle(ShiftGhostButtonStyle())
                } else {
                    startControl
                }
                Spacer()
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(Shift.panel)
    }

    private var targetIDs: Set<UUID> { !marcate.isEmpty ? marcate : (shell.selection.isEmpty ? Set(ordered) : shell.selection) }

    @ViewBuilder private var summary: some View {
        if vm.joburi.isEmpty {
            Text(L.t("tw.summary.empty")).font(.system(size: 11.5)).foregroundStyle(Shift.muted).frame(maxWidth: .infinity, alignment: .leading)
        } else {
            let ids = targetIDs
            let prev = vm.previzualizeaza(ids)
            let presets = Set(vm.joburi.filter { ids.contains($0.id) }.compactMap { vm.presetEfectiv($0)?.label })
            VStack(alignment: .leading, spacing: 3) {
                Text(String(format: L.t("tw.summary.line"), prev.clipuri, presets.sorted().joined(separator: ", ")))
                    .font(.system(size: 11.5, weight: .medium))
                ForEach(prev.avertismente, id: \.self) { a in
                    Label(a, systemImage: "exclamationmark.triangle.fill").font(.system(size: 10.5)).foregroundStyle(.orange)
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder private var runningInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            ProgressView(value: vm.progresTotal ?? 0).tint(Shift.accent)
            HStack(spacing: 14) {
                Text(String(format: L.t("tw.run.total"), Int((vm.progresTotal ?? 0) * 100))).font(.system(size: 11, weight: .medium))
                if let v = vm.vitezaRulare { Text(String(format: L.t("tw.run.speed"), v)).font(.system(size: 11)).foregroundStyle(Shift.muted) }
                if let t = vm.timpRamas { Text(String(format: L.t("tw.run.eta"), formatDurata(t) ?? "")).font(.system(size: 11)).foregroundStyle(Shift.muted) }
                Spacer()
            }
        }
    }

    private var startControl: some View {
        let disabled = vm.joburi.isEmpty || !deps.isReady || revocation.isRevoked
        return HStack(spacing: 0) {
            Button { startWith(marcate.isEmpty ? Set(ordered) : marcate) } label: {
                Label(String(format: L.t("tw.start.marked"), (marcate.isEmpty ? vm.joburi.count : marcate.count)), systemImage: "play.fill")
                    .padding(.horizontal, 14).padding(.vertical, 7)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.return, modifiers: [.command])
            Menu {
                Button(String(format: L.t("tw.start.selected"), shell.selection.count)) { startWith(shell.selection) }
                    .disabled(shell.selection.isEmpty)
                Button(String(format: L.t("tw.start.all"), vm.joburi.count)) { startWith(Set(ordered)) }
            } label: { Image(systemName: "chevron.down").padding(.horizontal, 8).padding(.vertical, 7) }
            .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
        }
        .font(.system(size: 13, weight: .semibold))
        .background(disabled ? Shift.elevated : Shift.accent)
        .foregroundStyle(disabled ? Shift.faint : Shift.accentInk)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .disabled(disabled)
    }

    private func startWith(_ ids: Set<UUID>) {
        guard !revocation.isRevoked else { return }
        guard license.isUnlocked else { onActivate(); return }
        guard !ids.isEmpty else { return }
        let prev = vm.previzualizeaza(ids)
        if prev.faraSpatiu.isEmpty && prev.existente == 0 && prev.avertismente.isEmpty { realStart(ids) }
        else { pendingStart = (ids, prev) }
    }
    private func realStart(_ ids: Set<UUID>) { vm.pornesteCoada(doarSelectate: ids) }

    private func openFiles() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.movie, .video, .mpeg4Movie, .quickTimeMovie]
        if panel.runModal() == .OK { vm.adaugaFisiere(panel.urls) }
    }
}

/// Drag & drop de fișiere cu evidențiere discretă.
struct DropOverlay: ViewModifier {
    @Binding var dropTarget: Bool
    let onDrop: ([URL]) -> Void
    func body(content: Content) -> some View {
        content
            .onDrop(of: [.fileURL], isTargeted: $dropTarget) { providers in
                for p in providers {
                    _ = p.loadObject(ofClass: URL.self) { url, _ in
                        guard let url else { return }
                        DispatchQueue.main.async { onDrop([url]) }
                    }
                }
                return true
            }
            .overlay {
                if dropTarget {
                    Rectangle().strokeBorder(Shift.accent, lineWidth: 2).background(Shift.accent.opacity(0.06)).allowsHitTesting(false)
                }
            }
    }
}

// ── Celulă de grilă ──
struct ClipCell: View {
    let job: VideoJob
    let preset: OutputPreset?
    let selected: Bool
    let onTap: () -> Void
    let onMark: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topLeading) {
                ClipThumb(path: job.caleThumbnail)
                    .aspectRatio(16.0 / 9.0, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                Button(action: onMark) {
                    Image(systemName: job.marcat ? "checkmark.square.fill" : "square")
                        .font(.system(size: 16))
                        .foregroundStyle(job.marcat ? Shift.accent : .white.opacity(0.9))
                        .shadow(color: .black.opacity(0.5), radius: 2)
                }
                .buttonStyle(.plain).padding(6).help(L.t("tw.mark.help"))
                VStack { Spacer(); HStack { Spacer(); StareBadge(stare: job.stare) }.padding(6) }
                if case .inLucru(let p) = job.stare {
                    VStack { Spacer(); ProgressView(value: p).tint(Shift.accent).padding(.horizontal, 6).padding(.bottom, 4) }
                }
            }
            Text(job.numeFisier).font(.system(size: 11.5, weight: .medium)).lineLimit(1).truncationMode(.middle)
            Text(rezumatMedia(job.metadataMedia) ?? " ").font(.system(size: 10)).foregroundStyle(Shift.muted).lineLimit(1)
            if let p = preset {
                Text(job.presetOverrideID != nil ? "● " + p.label : p.label)
                    .font(.system(size: 10)).foregroundStyle(job.presetOverrideID != nil ? Shift.accent : Shift.faint).lineLimit(1)
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 9).fill(selected ? Shift.accent.opacity(0.12) : Shift.panel))
        .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(selected ? Shift.accent : Shift.border, lineWidth: selected ? 2 : 1))
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .opacity(job.marcat ? 1 : 0.6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(job.numeFisier)
        .accessibilityAction(.default, onTap)
        .accessibilityAction(named: Text(L.t("tw.markSelected")), onMark)
    }
}

// ── Rând de listă ──
struct ClipRow: View {
    let job: VideoJob
    let preset: OutputPreset?
    let selected: Bool
    let onTap: () -> Void
    let onMark: () -> Void
    var body: some View {
        HStack(spacing: 10) {
            Button(action: onMark) {
                Image(systemName: job.marcat ? "checkmark.square.fill" : "square").foregroundStyle(job.marcat ? Shift.accent : Shift.faint)
            }.buttonStyle(.plain).help(L.t("tw.mark.help"))
            ClipThumb(path: job.caleThumbnail).frame(width: 64, height: 36).clipShape(RoundedRectangle(cornerRadius: 4))
            VStack(alignment: .leading, spacing: 2) {
                Text(job.numeFisier).font(.system(size: 12.5)).lineLimit(1).truncationMode(.middle)
                Text(rezumatMedia(job.metadataMedia) ?? " ").font(.system(size: 10.5)).foregroundStyle(Shift.muted).lineLimit(1)
            }
            Spacer(minLength: 8)
            if let p = preset {
                Text(p.label).font(.system(size: 11)).foregroundStyle(job.presetOverrideID != nil ? Shift.accent : Shift.muted).lineLimit(1)
            }
            if case .inLucru(let pr) = job.stare { ProgressView(value: pr).frame(width: 70).tint(Shift.accent) }
            StareBadge(stare: job.stare)
        }
        .padding(.horizontal, 14).padding(.vertical, 7)
        .background(selected ? Shift.accent.opacity(0.14) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .opacity(job.marcat ? 1 : 0.6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(job.numeFisier)
        .accessibilityAction(.default, onTap)
        .accessibilityAction(named: Text(L.t("tw.markSelected")), onMark)
    }
}
