import SwiftUI
import AppKit
import AVKit
import UniformTypeIdentifiers

/// Inspectorul din dreapta: previzualizare cu redare + file (Ieșire / Clip / Metadate).
struct TranscodeInspector: View {
    @ObservedObject var vm: ConvertorViewModel
    @ObservedObject var shell: ShellState
    @ObservedObject private var lutLibrary = LUTLibrary.shared
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var watchFolders = WatchFolderManager.shared
    let onPresets: () -> Void
    let onAddWatchFolder: () -> Void

    @State private var showInterval = false
    @State private var showReport = false
    @State private var showFramePreview = false
    @State private var showLUTPlayer = false
    @State private var suffixDraft = ""

    private static let mixed = "__mixed__"

    private var focusJob: VideoJob? {
        if let id = shell.focusID, let j = vm.joburi.first(where: { $0.id == id }) { return j }
        return vm.joburi.first(where: { shell.selection.contains($0.id) })
    }
    /// Clipurile asupra cărora se aplică modificările; gol = valorile implicite.
    private var tinta: [VideoJob] { vm.joburi.filter { shell.selection.contains($0.id) } }

    var body: some View {
        VStack(spacing: 0) {
            PlayerPane(url: focusJob?.urlSursa, thumb: focusJob?.caleThumbnail, onFrames: { showFramePreview = true })
                .frame(height: 190)
            Divider().overlay(Shift.border)
            Picker("", selection: $shell.inspectorTab) {
                ForEach(InspectorTab.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented).labelsHidden().padding(10)
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    switch shell.inspectorTab {
                    case .output: outputTab
                    case .clip: clipTab
                    case .metadata: metadataTab
                    }
                }
                .padding(.horizontal, 14).padding(.bottom, 16)
            }
        }
        .background(Shift.panel)
        .sheet(isPresented: $showInterval) {
            if let j = focusJob { IntervalSheet(job: j, isPresented: $showInterval) { a, b in vm.seteazaInterval(j, start: a, end: b) } }
        }
        .sheet(isPresented: $showReport) {
            if let j = focusJob, let r = j.raport { ReportSheet(fileName: j.numeFisier, report: r, isPresented: $showReport) }
        }
        .sheet(isPresented: $showFramePreview) {
            if let j = focusJob { MediaPreviewSheet(job: j, isPresented: $showFramePreview) }
        }
        .sheet(isPresented: $showLUTPlayer) {
            if let j = focusJob { LUTPlayerSheet(job: j, isPresented: $showLUTPlayer) }
        }
    }

    // ───────────── Ieșire ─────────────
    private var scopeBanner: some View {
        let n = tinta.count
        return HStack(alignment: .top, spacing: 6) {
            Image(systemName: n == 0 ? "slider.horizontal.3" : "checkmark.circle.fill").foregroundStyle(Shift.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(n == 0 ? L.t("tw.scope.default") : String(format: L.t("tw.scope.selected"), n))
                    .font(.system(size: 11.5, weight: .semibold))
                Text(n == 0 ? L.t("tw.scope.defaultHint") : tinta.prefix(3).map(\.numeFisier).joined(separator: ", ") + (n > 3 ? " …" : ""))
                    .font(.system(size: 10.5)).foregroundStyle(Shift.muted).lineLimit(2).truncationMode(.middle)
            }
        }
        .padding(10).frame(maxWidth: .infinity, alignment: .leading)
        .background(Shift.accent.opacity(0.10)).clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var presetBinding: Binding<String> {
        Binding(
            get: {
                if tinta.isEmpty { return vm.presetSelectatID }
                let ids = Set(tinta.map { vm.presetEfectiv($0)?.id ?? "" })
                return ids.count == 1 ? ids.first! : Self.mixed
            },
            set: { v in
                guard v != Self.mixed else { return }
                if tinta.isEmpty { vm.presetSelectatID = v } else { vm.aplicaPreset(v, pe: Set(tinta.map(\.id))) }
            })
    }

    private var presetShown: OutputPreset? {
        if tinta.isEmpty { return vm.presetSelectat }
        let ids = Set(tinta.compactMap { vm.presetEfectiv($0)?.id })
        return ids.count == 1 ? vm.presets.first { $0.id == ids.first } : nil
    }

    @ViewBuilder private var outputTab: some View {
        scopeBanner

        section(L.t("tw.sec.preset")) {
            Picker("", selection: presetBinding) {
                if presetBinding.wrappedValue == Self.mixed { Text(L.t("tw.mixed")).tag(Self.mixed) }
                ForEach(vm.presets) { Text($0.label).tag($0.id) }
            }
            .labelsHidden().pickerStyle(.menu)
            HStack {
                Button(L.t("preset.edit")) { onPresets() }.buttonStyle(ShiftGhostButtonStyle())
                if tinta.contains(where: { $0.presetOverrideID != nil }) {
                    Button(L.t("tw.resetToDefault")) { vm.aplicaPreset(nil, pe: Set(tinta.map(\.id))) }.buttonStyle(ShiftGhostButtonStyle())
                }
            }
        }

        if let p = presetShown {
            let profil = FormatRegistry.profile(id: p.profileID)
            let rewrap = p.profileID == FormatRegistry.rewrapProfileID
            section(L.t("tw.sec.video")) {
                kv(L.t("tw.codec"), rewrap ? L.t("tw.rewrapNoReencode") : (profil?.label ?? p.profileID))
                kv(L.t("tw.container"), ".\(MotorFFmpeg.extensieContainer(pentru: p))")
                if !rewrap, let h = profil { Text(L.t(h.hintKey)).font(.system(size: 10.5)).foregroundStyle(Shift.muted).fixedSize(horizontal: false, vertical: true) }
                if rewrap { Text(L.t("tw.rewrapHint")).font(.system(size: 10.5)).foregroundStyle(Shift.muted).fixedSize(horizontal: false, vertical: true) }
            }
            section(L.t("tw.sec.audio")) {
                kv(L.t("tw.audioCodec"), rewrap ? L.t("audio.passthrough") : L.t(p.audioMode.labelKey))
                kv(L.t("tw.channels"), rewrap ? L.t("channel.original") : L.t(p.channelLayout.labelKey))
            }
            section(L.t("tw.sec.timing")) {
                kv(L.t("tw.fps"), rewrap ? L.t("tw.fpsSource") : (p.frameRate.map { "\($0) fps" } ?? L.t("tw.fpsSource")))
                if !rewrap { Text(L.t("tw.fpsExplain")).font(.system(size: 10.5)).foregroundStyle(Shift.muted).fixedSize(horizontal: false, vertical: true) }
                kv(L.t("tw.timecode"), settings.preserveNativeMetadata ? L.t("tw.tcKept") : L.t("tw.tcNotKept"))
            }
            section(L.t("tw.sec.color")) {
                kv(L.t("tw.colorLabel"), p.colorSpace.map { L.t($0.labelKey) } ?? L.t("tw.colorUnchanged"))
                lutControls
            }
        } else {
            section(L.t("tw.sec.video")) { Text(L.t("tw.mixedDetails")).font(.system(size: 11)).foregroundStyle(Shift.muted) }
        }

        section(L.t("tw.sec.destination")) { destinationControls }
        section(L.t("tw.sec.naming")) { namingControls }
        section(L.t("tw.sec.range")) { rangeControls }
        section(L.t("tw.sec.metadataPolicy")) {
            Toggle(L.t("settings.keepMetadata"), isOn: $settings.preserveNativeMetadata).toggleStyle(.switch).controlSize(.small)
            Text(L.t("settings.keepMetadata.help")).font(.system(size: 10.5)).foregroundStyle(Shift.muted).fixedSize(horizontal: false, vertical: true)
            Text(L.t("tw.metaPolicyNote")).font(.system(size: 10.5)).foregroundStyle(Shift.muted).fixedSize(horizontal: false, vertical: true)
        }
        section(L.t("watchFolders.title")) { watchControls }
    }

    // LUT pe selecție (sau pe toate, dacă nu e nimic selectat) — mecanismul existent din LUTLibrary.
    @ViewBuilder private var lutControls: some View {
        let ids = tinta.isEmpty ? vm.joburi.map(\.id) : tinta.map(\.id)
        let used = Set(ids.map { lutLibrary.lutPerJob[$0] ?? "" })
        HStack {
            Menu {
                ForEach(lutLibrary.memorate) { lut in
                    Button(lut.numeAfisat + (lut.lipsesteFisierul ? " ⚠︎" : "")) { lutLibrary.aplica(url: lut.url, pe: ids) }.disabled(lut.lipsesteFisierul)
                }
                if !lutLibrary.memorate.isEmpty { Divider() }
                Button(L.t("lut.library.choose")) { chooseLUT(ids) }
                if used.contains(where: { !$0.isEmpty }) {
                    Divider()
                    Button(L.t("lut.library.clear"), role: .destructive) { lutLibrary.elimina(dePe: ids) }
                }
            } label: { Label(tinta.isEmpty ? String(format: L.t("lut.library.applyToAll"), ids.count) : String(format: L.t("lut.library.applyToSelected"), ids.count), systemImage: "swatchpalette") }
            .menuStyle(.borderlessButton).fixedSize()
        }
        if used.count > 1 { Text(L.t("tw.mixed")).font(.system(size: 10.5)).foregroundStyle(.orange) }
        else if let one = used.first, !one.isEmpty { Text((one as NSString).lastPathComponent).font(.system(size: 10.5, design: .monospaced)).foregroundStyle(Shift.muted) }
    }

    private func chooseLUT(_ ids: [UUID]) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true; panel.canChooseDirectories = false; panel.allowsMultipleSelection = false
        if let t = UTType(filenameExtension: "cube") { panel.allowedContentTypes = [t] }
        if panel.runModal() == .OK, let url = panel.url { lutLibrary.aplica(url: url, pe: ids) }
    }

    @ViewBuilder private var destinationControls: some View {
        let jobs = tinta
        let paths = Set(jobs.map { vm.folderEfectiv($0).path })
        let text: String = {
            if jobs.isEmpty { return vm.folderDestinatie?.path ?? L.t("destination.sameAsSource") }
            if paths.count > 1 { return L.t("tw.mixed") }
            return jobs.allSatisfy({ $0.destinatieOverride == nil }) && vm.folderDestinatie == nil ? L.t("destination.sameAsSource") : (paths.first ?? "")
        }()
        Text(text).font(.system(size: 11, design: .monospaced)).foregroundStyle(Shift.muted).lineLimit(2).truncationMode(.middle)
        HStack {
            Button(L.t("destination.choose")) {
                let panel = NSOpenPanel()
                panel.canChooseDirectories = true; panel.canChooseFiles = false; panel.canCreateDirectories = true
                guard panel.runModal() == .OK, let url = panel.url else { return }
                if jobs.isEmpty { vm.folderDestinatie = url } else { vm.aplicaDestinatie(url, pe: Set(jobs.map(\.id))) }
            }.buttonStyle(ShiftGhostButtonStyle())
            if jobs.isEmpty ? vm.folderDestinatie != nil : jobs.contains(where: { $0.destinatieOverride != nil }) {
                Button(L.t("tw.resetToDefault")) {
                    if jobs.isEmpty { vm.folderDestinatie = nil } else { vm.aplicaDestinatie(nil, pe: Set(jobs.map(\.id))) }
                }.buttonStyle(ShiftGhostButtonStyle())
            }
        }
        Text(L.t("tw.noOverwrite")).font(.system(size: 10.5)).foregroundStyle(Shift.muted).fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder private var namingControls: some View {
        let jobs = tinta
        if jobs.isEmpty {
            kv(L.t("tw.suffix"), vm.presetSelectat?.fileSuffix ?? "")
            Text(L.t("tw.suffixSelectHint")).font(.system(size: 10.5)).foregroundStyle(Shift.muted)
        } else {
            let distinct = Set(jobs.map { vm.sufixEfectiv($0) })
            TextField(distinct.count > 1 ? L.t("tw.mixed") : L.t("tw.suffix"), text: Binding(
                get: { suffixDraft.isEmpty && distinct.count == 1 ? distinct.first! : suffixDraft },
                set: { suffixDraft = $0 }))
                .textFieldStyle(.roundedBorder)
                .onSubmit { vm.aplicaSufix(suffixDraft, pe: Set(jobs.map(\.id))); suffixDraft = "" }
            Button(String(format: L.t("tw.applySuffix"), jobs.count)) { vm.aplicaSufix(suffixDraft.isEmpty && distinct.count == 1 ? distinct.first! : suffixDraft, pe: Set(jobs.map(\.id))); suffixDraft = "" }
                .buttonStyle(ShiftGhostButtonStyle()).disabled(suffixDraft.isEmpty)
        }
        if let ex = jobs.first ?? focusJob ?? vm.joburi.first {
            VStack(alignment: .leading, spacing: 2) {
                Text(L.t("tw.example")).font(.system(size: 10)).foregroundStyle(Shift.faint)
                Text(vm.numeRezultat(ex)).font(.system(size: 11, design: .monospaced)).lineLimit(2).truncationMode(.middle)
            }
        }
    }

    @ViewBuilder private var rangeControls: some View {
        if tinta.count > 1 {
            Text(L.t("tw.rangeSingleOnly")).font(.system(size: 11)).foregroundStyle(Shift.muted)
        } else if let j = focusJob {
            let rewrap = vm.presetEfectiv(j)?.profileID == FormatRegistry.rewrapProfileID
            if j.areInterval {
                Text("\(IntervalSheet.text(j.intervalStart)) → \(IntervalSheet.text(j.intervalEnd ?? j.metadataMedia?.durataSecunde))")
                    .font(.system(size: 11, design: .monospaced))
            } else {
                Text(L.t("tw.rangeWhole")).font(.system(size: 11)).foregroundStyle(Shift.muted)
            }
            HStack {
                Button(L.t("interval.title")) { showInterval = true }.buttonStyle(ShiftGhostButtonStyle()).disabled(rewrap)
                if j.areInterval { Button(L.t("tw.resetToDefault")) { vm.seteazaInterval(j, start: nil, end: nil) }.buttonStyle(ShiftGhostButtonStyle()) }
            }
            if rewrap { Text(L.t("tw.rangeNotRewrap")).font(.system(size: 10.5)).foregroundStyle(Shift.muted) }
        } else {
            Text(L.t("tw.pickClip")).font(.system(size: 11)).foregroundStyle(Shift.muted)
        }
    }

    @ViewBuilder private var watchControls: some View {
        if watchFolders.folders.isEmpty {
            Text(L.t("watchFolders.empty")).font(.system(size: 11)).foregroundStyle(Shift.faint)
        } else {
            ForEach(watchFolders.folders) { f in
                HStack(spacing: 6) {
                    Toggle("", isOn: Binding(get: { f.enabled }, set: { _ in watchFolders.toggle(f) })).labelsHidden().toggleStyle(.switch).controlSize(.mini)
                    Text((f.path as NSString).lastPathComponent).font(.system(size: 11, design: .monospaced)).lineLimit(1).truncationMode(.middle)
                    Spacer()
                    Button { watchFolders.removeFolder(f) } label: { Image(systemName: "xmark.circle.fill") }.buttonStyle(.plain).foregroundStyle(Shift.faint)
                }
            }
        }
        Button(L.t("watchFolders.add")) { onAddWatchFolder() }.buttonStyle(ShiftGhostButtonStyle())
    }

    // ───────────── Clip ─────────────
    @ViewBuilder private var clipTab: some View {
        if let j = focusJob {
            section(L.t("tw.sec.file")) {
                Text(j.numeFisier).font(.system(size: 12, weight: .semibold)).lineLimit(3).truncationMode(.middle)
                Text(j.urlSursa.deletingLastPathComponent().path).font(.system(size: 10.5, design: .monospaced)).foregroundStyle(Shift.muted).lineLimit(2).truncationMode(.middle)
                StareBadge(stare: j.stare)
                if case .eroare(let m) = j.stare { Text(m).font(.system(size: 10.5)).foregroundStyle(Shift.error) }
                if case .finalizatCuAvertisment(let m) = j.stare { Text(m).font(.system(size: 10.5)).foregroundStyle(.orange) }
            }
            if let m = j.metadataMedia {
                section(L.t("mw.sec.video")) {
                    kv(L.t("mw.resolution"), m.rezolutieText ?? "—"); kv(L.t("mw.codec"), m.codecVideo?.uppercased() ?? "—")
                    kv(L.t("tw.fps"), fpsText(m.frameRate) ?? "—"); kv(L.t("mw.duration"), formatDurata(m.durataSecunde) ?? "—")
                }
                section(L.t("mw.sec.audio")) {
                    kv(L.t("mw.codec"), m.codecAudio?.uppercased() ?? "—")
                    kv(L.t("mw.channels"), m.canaleAudio.map(String.init) ?? "—")
                }
            } else { ProgressView().controlSize(.small) }
            HStack {
                if j.raport != nil { Button(L.t("queue.report")) { showReport = true }.buttonStyle(ShiftGhostButtonStyle()) }
                Button(L.t("tw.framePreview")) { showFramePreview = true }.buttonStyle(ShiftGhostButtonStyle())
                Button("LUT") { showLUTPlayer = true }.buttonStyle(ShiftGhostButtonStyle())
            }
            if let d = j.urlDestinatie, case .finalizat = j.stare {
                Button(L.t("tw.revealResult")) { NSWorkspace.shared.activateFileViewerSelecting([d]) }.buttonStyle(ShiftGhostButtonStyle())
            }
        } else {
            Text(L.t("tw.pickClip")).font(.system(size: 11.5)).foregroundStyle(Shift.muted)
        }
    }

    // ───────────── Metadate (rezumat; spațiul Metadate are varianta completă) ─────────────
    @ViewBuilder private var metadataTab: some View {
        if let j = focusJob {
            MetadataDetail(job: j, vm: vm, compact: true)
            Button(L.t("tw.openMetadataWorkspace")) { shell.workspace = .metadata }.buttonStyle(ShiftGhostButtonStyle())
        } else {
            Text(L.t("tw.pickClip")).font(.system(size: 11.5)).foregroundStyle(Shift.muted)
        }
    }

    // ───────────── Piese comune ─────────────
    private func section<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            ShiftSectionLabel(text: title)
            content()
        }
    }
    private func kv(_ k: String, _ v: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(k).font(.system(size: 11)).foregroundStyle(Shift.muted)
            Spacer(minLength: 8)
            Text(v).font(.system(size: 11.5)).multilineTextAlignment(.trailing).lineLimit(2).truncationMode(.middle)
        }
    }
}

// ── Redare reală (AVPlayer) cu deplasare în clip; fallback la cadre pentru formate neredabile ──
struct PlayerPane: View {
    let url: URL?
    let thumb: String?
    let onFrames: () -> Void
    @State private var player: AVPlayer?
    @State private var playable = true

    var body: some View {
        ZStack {
            Color.black
            if let player, playable {
                InlinePlayer(player: player)
            } else if url != nil {
                ClipThumb(path: thumb, contentMode: .fit)
                VStack {
                    Spacer()
                    Button(L.t("tw.framePreview"), action: onFrames).buttonStyle(ShiftGhostButtonStyle()).padding(8)
                }
                if !playable { VStack { Text(L.t("tw.cannotPlay")).font(.system(size: 10.5)).foregroundStyle(.white.opacity(0.8)).padding(6); Spacer() } }
            } else {
                Text(L.t("tw.pickClip")).font(.system(size: 11.5)).foregroundStyle(.white.opacity(0.7))
            }
        }
        .task(id: url) {
            player?.pause()
            player = nil
            playable = true
            guard let url else { return }
            let asset = AVURLAsset(url: url)
            let ok = (try? await asset.load(.isPlayable)) ?? false
            guard !Task.isCancelled else { return }
            playable = ok
            if ok { player = AVPlayer(playerItem: AVPlayerItem(asset: asset)) }
        }
        .onDisappear { player?.pause() }
    }
}

struct InlinePlayer: NSViewRepresentable {
    let player: AVPlayer
    func makeNSView(context: Context) -> AVPlayerView {
        let v = AVPlayerView()
        v.controlsStyle = .inline
        v.showsFullScreenToggleButton = true
        v.player = player
        return v
    }
    func updateNSView(_ v: AVPlayerView, context: Context) { if v.player !== player { v.player = player } }
}
