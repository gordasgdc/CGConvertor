import SwiftUI
import AppKit
import UniformTypeIdentifiers

// ── Valori introduse manual (doar în CGConvertor; originalul nu se modifică niciodată) ──
enum ManualField: String, CaseIterable, Identifiable {
    case cameraModel, lens, curve, gamut, note
    var id: String { rawValue }
    var label: String { L.t("mw.manual.\(rawValue)") }
}

enum ManualMetadataStore {
    private static let key = "cgconvertor_manual_metadata_v1"
    static func all() -> [String: [String: String]] {
        (UserDefaults.standard.dictionary(forKey: key) as? [String: [String: String]]) ?? [:]
    }
    static func values(for url: URL) -> [String: String] { all()[url.path] ?? [:] }
    static func set(_ values: [String: String], for url: URL) {
        var a = all()
        let cleaned = values.filter { !$0.value.trimmingCharacters(in: .whitespaces).isEmpty }
        if cleaned.isEmpty { a.removeValue(forKey: url.path) } else { a[url.path] = cleaned }
        UserDefaults.standard.set(a, forKey: key)
    }
}

/// Câmpuri brute din ffprobe (format + fluxuri + etichete), aplatizate.
enum RawMetadata {
    static func load(_ url: URL) -> [(key: String, value: String)] {
        guard let ff = MotorFFmpeg.gasesteBinar() else { return [] }
        let probe = ff.replacingOccurrences(of: "ffmpeg", with: "ffprobe")
        guard FileManager.default.fileExists(atPath: probe) else { return [] }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: probe)
        p.arguments = ["-v", "error", "-print_format", "json", "-show_format", "-show_streams", url.path]
        let out = Pipe(); p.standardOutput = out; p.standardError = Pipe()
        guard (try? p.run()) != nil else { return [] }
        let data = out.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [] }
        var rows: [(key: String, value: String)] = []
        func flat(_ prefix: String, _ v: Any) {
            if let d = v as? [String: Any] { for k in d.keys.sorted() { flat(prefix.isEmpty ? k : "\(prefix).\(k)", d[k]!) } }
            else if let a = v as? [Any] { for (i, x) in a.enumerated() { flat("\(prefix)[\(i)]", x) } }
            else { rows.append((key: prefix, value: "\(v)")) }
        }
        if let f = root["format"] { flat("format", f) }
        if let s = root["streams"] as? [[String: Any]] { for (i, st) in s.enumerated() { flat("stream\(i)", st) } }
        return rows
    }
}

struct MetaRow: Identifiable {
    enum Origin { case file, container, detected(kind: String, source: String), manual, derived }
    let id = UUID()
    let key: String
    let value: String
    var origin: Origin = .file
    var conflict: String?
}
struct MetaGroup: Identifiable {
    let id: String
    let title: String
    var rows: [MetaRow]
}

enum MetadataModel {
    static func groups(job: VideoJob, manual: [String: String]) -> [MetaGroup] {
        var g: [MetaGroup] = []
        let attrs = try? FileManager.default.attributesOfItem(atPath: job.urlSursa.resolvingSymlinksInPath().path)
        var file = [MetaRow(key: L.t("mw.name"), value: job.numeFisier), MetaRow(key: L.t("mw.path"), value: job.urlSursa.deletingLastPathComponent().path)]
        if let s = attrs?[.size] as? Int64 { file.append(MetaRow(key: L.t("mw.size"), value: ByteCountFormatter.string(fromByteCount: s, countStyle: .file))) }
        if let d = attrs?[.modificationDate] as? Date { file.append(MetaRow(key: L.t("mw.modified"), value: d.formatted(date: .abbreviated, time: .shortened))) }
        g.append(MetaGroup(id: "file", title: L.t("mw.sec.file"), rows: file))

        let m = job.metadataMedia
        if let m {
            var v: [MetaRow] = []
            func add(_ k: String, _ x: String?) { if let x, !x.isEmpty { v.append(MetaRow(key: k, value: x)) } }
            add(L.t("mw.resolution"), m.rezolutieText); add(L.t("mw.codec"), m.codecVideo?.uppercased()); add(L.t("tw.fps"), fpsText(m.frameRate))
            add(L.t("mw.pixfmt"), m.pixFmt); add(L.t("mw.bitrate"), m.bitrateVideo.map { String(format: "%.1f Mb/s", Double($0) / 1_000_000) })
            add(L.t("mw.duration"), formatDurata(m.durataSecunde))
            g.append(MetaGroup(id: "video", title: L.t("mw.sec.video"), rows: v))
            var a: [MetaRow] = []
            if let c = m.codecAudio { a.append(MetaRow(key: L.t("mw.codec"), value: c.uppercased())) }
            if let c = m.canaleAudio { a.append(MetaRow(key: L.t("mw.channels"), value: "\(c)")) }
            if let sr = m.sampleRateAudio { a.append(MetaRow(key: L.t("mw.sampleRate"), value: "\(sr) Hz")) }
            if let b = m.bitrateAudio { a.append(MetaRow(key: L.t("mw.bitrate"), value: String(format: "%.0f kb/s", Double(b) / 1000))) }
            if !a.isEmpty { g.append(MetaGroup(id: "audio", title: L.t("mw.sec.audio"), rows: a)) }
        }

        let p = job.profilSursa
        var cam: [MetaRow] = []
        if let c = p?.cameraModel { cam.append(MetaRow(key: L.t("mw.manual.cameraModel"), value: c, origin: .detected(kind: "decoded", source: "gdc-metadata"))) }
        if let c = manual[ManualField.cameraModel.rawValue] {
            var r = MetaRow(key: L.t("mw.manual.cameraModel"), value: c, origin: .manual)
            if let d = p?.cameraModel, d.lowercased() != c.lowercased() { r.conflict = String(format: L.t("mw.conflict.manualVsDetected"), d) }
            cam.append(r)
        }
        if cam.isEmpty { cam.append(MetaRow(key: L.t("mw.manual.cameraModel"), value: job.scanTerminat ? L.t("mw.unknown") : L.t("mw.reading"))) }
        g.append(MetaGroup(id: "camera", title: L.t("mw.sec.camera"), rows: cam))

        var col: [MetaRow] = []
        func colorRow(_ label: String, _ det: SourceProfile.Detected?, _ man: String?) {
            if let det { col.append(MetaRow(key: label, value: det.value, origin: .detected(kind: det.kind, source: det.source))) }
            if let man {
                var r = MetaRow(key: label, value: man, origin: .manual)
                if let det, det.value.lowercased() != man.lowercased() { r.conflict = String(format: L.t("mw.conflict.manualVsDetected"), det.value) }
                col.append(r)
            }
            if det == nil && man == nil { col.append(MetaRow(key: label, value: job.scanTerminat ? L.t("mw.unknown") : L.t("mw.reading"))) }
        }
        colorRow(L.t("mw.gamut"), p?.gamut, manual[ManualField.gamut.rawValue])
        colorRow(L.t("mw.curve"), p?.curve, manual[ManualField.curve.rawValue])
        if let m {
            let tags = [m.colorPrimaries, m.colorTransfer, m.colorSpace].compactMap { $0 }.filter { $0 != "unknown" && $0 != "unspecified" }
            col.append(MetaRow(key: L.t("mw.containerTags"), value: tags.isEmpty ? L.t("mw.notDeclared") : tags.joined(separator: " / "), origin: .container))
            if let curve = p?.curve?.value.lowercased(), curve.contains("log"), let t = m.colorTransfer, ["bt709", "smpte170m", "bt470bg"].contains(t) {
                col.append(MetaRow(key: L.t("mw.conflictRow"), value: String(format: L.t("mw.conflict.containerVsCore"), t, p?.curve?.value ?? ""), origin: .derived,
                                   conflict: L.t("mw.conflict.containerVsCore.short")))
            }
        }
        g.append(MetaGroup(id: "color", title: L.t("mw.sec.color"), rows: col))

        var tc: [MetaRow] = []
        if let t = p?.timecode {
            tc.append(MetaRow(key: L.t("tw.timecode"), value: t, origin: .detected(kind: "decoded", source: "gdc-metadata")))
            tc.append(MetaRow(key: L.t("mw.tcType"), value: t.contains(";") ? L.t("mw.tcDrop") : L.t("mw.tcNonDrop"), origin: .derived))
        } else { tc.append(MetaRow(key: L.t("tw.timecode"), value: job.scanTerminat ? L.t("mw.unknown") : L.t("mw.reading"))) }
        if let f = p?.frameRate, let mf = m?.frameRate, let a = Double(f), let b = Double(mf), abs(a - b) > 0.01 {
            tc.append(MetaRow(key: L.t("mw.conflictRow"), value: "\(f) ≠ \(mf)", origin: .derived, conflict: L.t("mw.conflict.fps")))
        }
        g.append(MetaGroup(id: "tc", title: L.t("mw.sec.timecode"), rows: tc))

        var cap: [MetaRow] = []
        func addCap(_ k: String, _ v: String?) { if let v { cap.append(MetaRow(key: k, value: v, origin: .detected(kind: "decoded", source: "gdc-metadata"))) } }
        addCap(L.t("mw.manual.lens"), p?.lens); addCap(L.t("mw.focal"), p?.focalLength); addCap(L.t("mw.aperture"), p?.aperture)
        addCap(L.t("mw.iso"), p?.iso); addCap(L.t("mw.shutter"), p?.shutter); addCap(L.t("mw.wb"), p?.whiteBalance)
        if let l = manual[ManualField.lens.rawValue] {
            var r = MetaRow(key: L.t("mw.manual.lens"), value: l, origin: .manual)
            if let d = p?.lens, d.lowercased() != l.lowercased() { r.conflict = String(format: L.t("mw.conflict.manualVsDetected"), d) }
            cap.append(r)
        }
        if cap.isEmpty { cap.append(MetaRow(key: L.t("mw.capture"), value: job.scanTerminat ? L.t("mw.notAvailable") : L.t("mw.reading"))) }
        g.append(MetaGroup(id: "capture", title: L.t("mw.sec.capture"), rows: cap))

        if let n = manual[ManualField.note.rawValue] {
            g.append(MetaGroup(id: "note", title: L.t("mw.sec.note"), rows: [MetaRow(key: L.t("mw.manual.note"), value: n, origin: .manual)]))
        }
        return g
    }
}

/// Detalii metadate pentru un clip: grupat, cu proveniență și conflicte. `compact` = varianta din inspector.
struct MetadataDetail: View {
    let job: VideoJob
    @ObservedObject var vm: ConvertorViewModel
    var compact = false
    var query = ""

    @State private var manual: [String: String] = [:]
    @State private var editing = false
    @State private var raw: [(key: String, value: String)]?
    @State private var showRaw = false

    var body: some View {
        let groups = MetadataModel.groups(job: job, manual: manual)
            .filter { !compact || ["camera", "color", "tc"].contains($0.id) }
        VStack(alignment: .leading, spacing: 14) {
            ForEach(groups) { grp in
                let rows = grp.rows.filter { matches($0) }
                if !rows.isEmpty {
                    VStack(alignment: .leading, spacing: 5) {
                        ShiftSectionLabel(text: grp.title)
                        ForEach(rows) { r in rowView(r) }
                    }
                }
            }
            if !compact {
                manualSection
                rawSection
            } else {
                Text(L.t("mw.resolveLimit")).font(.system(size: 10.5)).foregroundStyle(Shift.muted).fixedSize(horizontal: false, vertical: true)
            }
        }
        .task(id: job.id) {
            manual = ManualMetadataStore.values(for: job.urlSursa)
            vm.scaneazaProfil(job)
            raw = nil; showRaw = false
        }
    }

    private func matches(_ r: MetaRow) -> Bool {
        query.isEmpty || r.key.localizedCaseInsensitiveContains(query) || r.value.localizedCaseInsensitiveContains(query)
    }

    @ViewBuilder private func rowView(_ r: MetaRow) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(r.key).font(.system(size: 11)).foregroundStyle(Shift.muted)
                Spacer(minLength: 8)
                Text(r.value).font(.system(size: 11.5)).multilineTextAlignment(.trailing).textSelection(.enabled)
            }
            HStack(spacing: 6) {
                Spacer()
                originTag(r.origin)
            }
            if let c = r.conflict {
                Label(c, systemImage: "exclamationmark.triangle.fill").font(.system(size: 10.5)).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder private func originTag(_ o: MetaRow.Origin) -> some View {
        switch o {
        case .file: EmptyView()
        case .container: tag(L.t("mw.origin.container"), Shift.muted)
        case .derived: tag(L.t("mw.origin.derived"), Shift.muted)
        case .manual: tag(L.t("mw.origin.manual"), Shift.accent)
        case .detected(let kind, let source):
            tag("\(L.t("mw.origin.kind." + kind)) · \(source)", Shift.success)
        }
    }
    private func tag(_ t: String, _ c: Color) -> some View {
        Text(t).font(.system(size: 9.5, weight: .medium)).padding(.horizontal, 6).padding(.vertical, 1).background(c.opacity(0.14)).foregroundStyle(c).clipShape(Capsule())
    }

    // Valori manuale — nu modifică niciodată fișierul sursă.
    @ViewBuilder private var manualSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                ShiftSectionLabel(text: L.t("mw.sec.manual"))
                Spacer()
                Button(editing ? L.t("mw.done") : L.t("mw.edit")) { editing.toggle(); if !editing { ManualMetadataStore.set(manual, for: job.urlSursa) } }
                    .buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(Shift.accent)
            }
            Text(L.t("mw.manual.scope")).font(.system(size: 10.5)).foregroundStyle(Shift.muted).fixedSize(horizontal: false, vertical: true)
            if editing {
                ForEach(ManualField.allCases) { f in
                    TextField(f.label, text: Binding(get: { manual[f.rawValue] ?? "" }, set: { manual[f.rawValue] = $0 }))
                        .textFieldStyle(.roundedBorder).font(.system(size: 11.5))
                }
                Text(L.t("mw.manual.unknownHint")).font(.system(size: 10.5)).foregroundStyle(Shift.faint)
            }
            Button(L.t("mw.exportSheet")) { exportJSON() }.buttonStyle(ShiftGhostButtonStyle())
        }
    }

    @ViewBuilder private var rawSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button { showRaw.toggle(); if showRaw && raw == nil { loadRaw() } } label: {
                HStack { Image(systemName: showRaw ? "chevron.down" : "chevron.right").font(.system(size: 9)); ShiftSectionLabel(text: L.t("mw.sec.raw")) }
            }.buttonStyle(.plain)
            if showRaw {
                if let raw {
                    let shown = raw.filter { query.isEmpty || $0.key.localizedCaseInsensitiveContains(query) || $0.value.localizedCaseInsensitiveContains(query) }
                    ForEach(Array(shown.prefix(400).enumerated()), id: \.offset) { _, r in
                        HStack(alignment: .firstTextBaseline) {
                            Text(r.key).font(.system(size: 10, design: .monospaced)).foregroundStyle(Shift.muted)
                            Spacer(minLength: 6)
                            Text(r.value).font(.system(size: 10, design: .monospaced)).multilineTextAlignment(.trailing).textSelection(.enabled)
                        }
                    }
                    if shown.count > 400 { Text(String(format: L.t("mw.rawTruncated"), shown.count)).font(.system(size: 10)).foregroundStyle(Shift.faint) }
                } else { ProgressView().controlSize(.small) }
            }
        }
    }

    private func loadRaw() {
        let url = job.urlSursa
        BackgroundWork.run {
            let r = RawMetadata.load(url)
            Task { @MainActor in raw = r }
        }
    }

    private func exportJSON() {
        let groups = MetadataModel.groups(job: job, manual: manual)
        var doc: [String: Any] = ["file": job.numeFisier, "note": "Generated by CG Convertor. The source file is not modified."]
        var gs: [[String: Any]] = []
        for g in groups {
            gs.append(["group": g.id, "rows": g.rows.map { r -> [String: Any] in
                var o: [String: Any] = ["key": r.key, "value": r.value]
                switch r.origin {
                case .manual: o["origin"] = "manual"
                case .detected(let k, let s): o["origin"] = "detected"; o["kind"] = k; o["source"] = s
                case .container: o["origin"] = "container"
                case .derived: o["origin"] = "derived"
                case .file: o["origin"] = "file"
                }
                if let c = r.conflict { o["conflict"] = c }
                return o
            }])
        }
        doc["groups"] = gs
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = job.urlSursa.deletingPathExtension().lastPathComponent + "-metadata.json"
        guard panel.runModal() == .OK, let url = panel.url,
              let data = try? JSONSerialization.data(withJSONObject: doc, options: [.prettyPrinted, .sortedKeys]) else { return }
        try? data.write(to: url)
    }
}

/// Spațiul „Metadate”: lista clipurilor (aceeași ca la Transcodare) și detalii complete, cu căutare.
struct MetadataWorkspace: View {
    @ObservedObject var vm: ConvertorViewModel
    @ObservedObject var shell: ShellState
    @State private var query = ""
    @State private var dropTarget = false

    private var ordered: [UUID] { vm.joburi.map(\.id) }
    private var focus: VideoJob? { shell.focusID.flatMap { id in vm.joburi.first { $0.id == id } } ?? vm.joburi.first }

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                HStack {
                    Button { open() } label: { Label(L.t("queue.addFiles"), systemImage: "plus") }.buttonStyle(ShiftGhostButtonStyle())
                    Spacer()
                    if shell.selection.count >= 2 {
                        Button(String(format: L.t("compare.button"), shell.selection.count)) {
                            MetadataCompareEngine.deschideComparatie(jobs: vm.joburi.filter { shell.selection.contains($0.id) })
                        }.buttonStyle(ShiftGhostButtonStyle())
                    }
                }.padding(10).background(Shift.panel)
                Divider().overlay(Shift.border)
                if vm.joburi.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "list.bullet.rectangle").font(.system(size: 34)).foregroundStyle(Shift.faint)
                        Text(L.t("mw.empty")).font(.system(size: 12)).foregroundStyle(Shift.muted).multilineTextAlignment(.center).padding(.horizontal, 20)
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(vm.joburi) { job in
                                HStack(spacing: 8) {
                                    ClipThumb(path: job.caleThumbnail).frame(width: 56, height: 32).clipShape(RoundedRectangle(cornerRadius: 4))
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(job.numeFisier).font(.system(size: 12)).lineLimit(1).truncationMode(.middle)
                                        Text(rezumatMedia(job.metadataMedia) ?? " ").font(.system(size: 10)).foregroundStyle(Shift.muted).lineLimit(1)
                                    }
                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background((shell.focusID == job.id || shell.selection.contains(job.id)) ? Shift.accent.opacity(0.14) : Color.clear)
                                .contentShape(Rectangle())
                                .onTapGesture { shell.click(job.id, ordered: ordered) }
                            }
                        }
                    }
                }
            }
            .frame(width: 280)
            .modifier(DropOverlay(dropTarget: $dropTarget, onDrop: { vm.adaugaFisiere($0) }))
            Divider().overlay(Shift.border)
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(Shift.faint)
                    TextField(L.t("mw.search"), text: $query).textFieldStyle(.plain)
                    if !query.isEmpty { Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }.buttonStyle(.plain).foregroundStyle(Shift.faint) }
                }.padding(10).background(Shift.panel)
                Divider().overlay(Shift.border)
                ScrollView {
                    if let j = focus {
                        MetadataDetail(job: j, vm: vm, compact: false, query: query).padding(18).frame(maxWidth: 760, alignment: .leading).frame(maxWidth: .infinity)
                        Text(L.t("mw.resolveLimit")).font(.system(size: 10.5)).foregroundStyle(Shift.muted).padding(.horizontal, 18).padding(.bottom, 16)
                    }
                }
            }
        }
        .background(Shift.bg)
    }

    private func open() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true; panel.canChooseDirectories = false; panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.movie, .video, .mpeg4Movie, .quickTimeMovie]
        if panel.runModal() == .OK { vm.adaugaFisiere(panel.urls) }
    }
}
