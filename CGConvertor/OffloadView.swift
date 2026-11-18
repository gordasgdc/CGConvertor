import SwiftUI
import Combine
import UniformTypeIdentifiers

// Spațiul „Offload”: traseu sursă → verificare → copii, coloana de incidente și raftul de dispozitive.
// Organizare și componente adaptate din DataMover (același autor); motorul de copiere verificată e cel al CGConvertor.

struct OffloadView: View {
    /// Trimite fișierele copiate și verificate în coada de transcodare (nu pornește nimic automat).
    var onSendToTranscode: (([URL]) -> Void)? = nil

    private static let log = DiagnosticLog("offload")
    @StateObject private var runner = OffloadRunner()
    @StateObject private var profileStore = TransferProfileStore.shared
    @State private var sourcePaths: [String] = []
    @State private var destinationPaths: [String] = []
    @State private var verificationModel: VerificationModel = .xxhash64
    @State private var chunkSizeMB = IOSettings.chunkSizeMB
    @State private var ramLimitMB = IOSettings.ramLimitMB
    @State private var meta = ProductionMeta()
    @State private var namingTemplate = NamingTemplate.defaultTemplate

    @State private var volumes: [VolumeInfo] = []
    @State private var mediaByPath: [String: MediaClass] = [:]
    @State private var capacities: [String: VolumeCapacity] = [:]
    @State private var bytesBySource: [String: Int64] = [:]
    @State private var sourceBytes: Int64? = nil
    @State private var preflightIssues: [PreflightIssue] = []
    @State private var collisionIssues: [PreflightIssue] = []
    @State private var cardInfoBySource: [String: CameraCardInfo] = [:]

    @State private var showResult = false
    @AppStorage("cgconvertor_offload_extract_meta") private var extractMetadata = false
    @StateObject private var queue = OffloadQueue()
    @State private var showQueue = false
    @State private var pdfNote = ""
    /// Raftul de dispozitive: `nil` = automat (se strânge când înălțimea utilă e mică).
    @State private var shelfOpen: Bool? = nil
    @State private var contentHeight: CGFloat = 800
    @State private var headerWidth: CGFloat = 1200
    private var headerCompact: Bool { headerWidth < 1120 }
    private var shelfExpanded: Bool { shelfOpen ?? (contentHeight >= 520) }
    @State private var demoPausedOnce = false
    @State private var showHistory = false
    @State private var showOptions = false
    @State private var showSaveProfile = false
    @State private var newProfileName = ""
    @State private var logExpanded = false
    @State private var draggingDiskPath: String? = nil
    @State private var dragPoint: CGPoint = .zero
    @State private var sourcesFrame: CGRect = .zero
    @State private var destFrame: CGRect = .zero
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var depth: VerificationDepth { VerificationDepth.for(verificationModel, readBack: true) }
    private var isHoveringSource: Bool { draggingDiskPath != nil && sourcesFrame.contains(dragPoint) }
    private var isHoveringDest: Bool { draggingDiskPath != nil && destFrame.contains(dragPoint) }

    private var stage: RouteStage {
        if runner.isRunning { return .transfer }
        return showResult && runner.lastOutcome != nil ? .result : .prepare
    }
    private var stageKey: String {
        switch stage { case .prepare: return "prepare"; case .transfer: return "transfer"; case .result: return "result" }
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                headerBar
                Divider()
                GeometryReader { geo in
                    HStack(spacing: 0) {
                        VStack(spacing: 0) {
                            stageTitle
                            mainStage
                            if !runner.isRunning {
                                Divider()
                                deviceShelf
                            }
                        }
                        Divider()
                        incidentColumn
                            .frame(width: geo.size.width < DM.Layout.incidentsCompactBelow ? DM.Layout.incidentsWidthCompact : DM.Layout.incidentsWidth)
                    }
                }
                .frame(maxHeight: .infinity)
                .background(GeometryReader { g in Color.clear.onAppear { contentHeight = g.size.height }
                    .onChange(of: g.size.height) { _, h in contentHeight = h } })
                .onPreferenceChange(RouteZoneKey.self) { frames in
                    sourcesFrame = frames.sources
                    destFrame = frames.destinations
                }
                Divider()
                footer
            }
            .background(Color(nsColor: .windowBackgroundColor))
            .onAppear {
                refreshVolumes()
                #if DEBUG
                applyDemoIfRequested()
                #endif
            }
            #if DEBUG
            .onChange(of: runner.progressPercent) { _, pct in
                // Doar pentru capturi: oprește la un procent ales (CGC_OFFLOAD_DEMO_PAUSE_AT).
                if let at = ProcessInfo.processInfo.environment["CGC_OFFLOAD_DEMO_PAUSE_AT"].flatMap(Double.init),
                   pct >= at, runner.isRunning, !runner.isPaused, !demoPausedOnce { demoPausedOnce = true; runner.togglePause() }
            }
            #endif
            .onChange(of: runner.isRunning) { _, running in
                if !running, runner.lastOutcome != nil { showResult = true }
            }
            .onChange(of: verificationModel) { _, _ in refreshPreparation(scanSources: false) }
            .task { await classifyNewPaths() }
            .onChange(of: volumes) { _, _ in Task { await classifyNewPaths() } }
            .onChange(of: sourcePaths) { _, _ in Task { await classifyNewPaths() } }
            .onChange(of: destinationPaths) { _, _ in Task { await classifyNewPaths() } }
            .onReceive(Timer.publish(every: 4, on: .main, in: .common).autoconnect()) { _ in
                if !runner.isRunning { refreshVolumes() }
            }
            .alert(L.t("offload.profiles.namePrompt"), isPresented: $showSaveProfile) {
                TextField(L.t("offload.profiles.namePrompt"), text: $newProfileName)
                Button(L.t("offload.profiles.save")) { saveProfile() }
                Button(L.t("offload.cancel"), role: .cancel) {}
            }
            .alert(L.t("offload.status.insufficientSpace"), isPresented: .constant(runner.insufficientSpaceWarning != nil), presenting: runner.insufficientSpaceWarning) { _ in
                Button(L.t("offload.cancel"), role: .cancel) { runner.insufficientSpaceWarning = nil }
                Button(L.t("offload.start"), role: .destructive) { runner.insufficientSpaceWarning = nil; startTransfer(ignoreSpace: true) }
            } message: { Text($0) }
            .sheet(isPresented: $showHistory) { OffloadHistorySheet(isPresented: $showHistory) }
            .sheet(isPresented: $showQueue) {
                OffloadQueueSheet(queue: queue, transferRunning: runner.isRunning,
                                  canAddCurrent: !sourcePaths.isEmpty && !destinationPaths.isEmpty && !IncidentBuilder.blocksStart(prepareIncidents),
                                  onAddCurrent: { addCurrentToQueue() }, onStart: { startQueue() },
                                  onStop: { queue.isActive = false })
            }
            .onChange(of: runner.isRunning) { _, running in
                if !running { queueJobFinished() }
            }
            #if DEBUG
            .onChange(of: runner.isRunning) { _, running in
                // Doar pentru verificări: exportă automat PDF-ul (CGC_OFFLOAD_DEMO_PDF=<cale>) după rezultat.
                guard !running, let path = ProcessInfo.processInfo.environment["CGC_OFFLOAD_DEMO_PDF"] else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
                    guard let o = runner.lastOutcome else { return }
                    let input = OffloadPDFInput(folderName: runner.lastFolderName, meta: meta, sources: sourcePaths,
                                                outcomeLabel: L.t(o.labelKey), results: runner.lastResults,
                                                metadata: runner.metadataSummary, duration: runner.elapsedSeconds)
                    Self.log.info("demo pdf \(OffloadPDFReport.write(input, to: URL(fileURLWithPath: path)))")
                }
            }
            #endif
            .sheet(isPresented: $showOptions) {
                OffloadOptionsSheet(meta: $meta, namingTemplate: $namingTemplate, verificationModel: $verificationModel,
                                    chunkSizeMB: $chunkSizeMB, ramLimitMB: $ramLimitMB, isPresented: $showOptions)
            }

            if let path = draggingDiskPath {
                Text((path as NSString).lastPathComponent)
                    .font(.system(.caption, weight: .semibold))
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(DM.accent).foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                    .position(dragPoint).allowsHitTesting(false)
            }
        }
        .coordinateSpace(name: "root")
    }

    // MARK: Antet

    private var headerBar: some View {
        HStack(spacing: DM.Space.l) {
            HStack(spacing: DM.Space.s) {
                TextField(L.t("meta.project"), text: $meta.project)
                    .textFieldStyle(.roundedBorder).frame(width: DM.Layout.routeNodeWidth)
                Image(systemName: "chevron.right").foregroundStyle(DM.textTertiary).accessibilityHidden(true)
                TextField(L.t("meta.card"), text: $meta.card)
                    .textFieldStyle(.roundedBorder).frame(width: DM.Layout.routeNodeBlock + DM.Space.xl)
            }
            .disabled(runner.isRunning)
            Text(previewFolderName).font(DM.Font.mono).foregroundStyle(DM.textSecondary)
                .lineLimit(1).truncationMode(.middle).textSelection(.enabled).help(L.t("prep.folder"))
            Spacer(minLength: DM.Space.s)
            Button { showQueue = true } label: {
                Label(queue.waitingCount > 0 ? "\(L.t("queue.button")) (\(queue.waitingCount))" : L.t("queue.button"), systemImage: "square.stack.3d.up")
                    .labelStyle(HeaderLabelStyle(iconOnly: headerCompact && stage != .prepare))
            }
            .help(L.t("queue.title"))
            if runner.isRunning {
                Button(runner.isPaused ? L.t("footer.resume") : L.t("footer.pause")) { runner.togglePause() }
                Button(L.t("footer.cancel"), role: .destructive) { runner.cancel() }
                    .keyboardShortcut(".", modifiers: .command)
            } else if stage == .result {
                if let send = onSendToTranscode {
                    let media = verifiedMedia
                    Button { send(media) } label: {
                        Label(String(format: L.t(headerCompact ? "ow.sendToTranscode.short" : "ow.sendToTranscode"), media.count), systemImage: "arrow.right.square")
                    }
                    .disabled(media.isEmpty)
                    .help(media.isEmpty ? L.t("ow.notVerifiedHint") : L.t("ow.sendHelp"))
                }
                Button { exportPDF() } label: {
                    Label(L.t("report.pdf"), systemImage: "doc.richtext").labelStyle(HeaderLabelStyle(iconOnly: headerCompact))
                }
                    .help(L.t("report.pdf.help"))
                Button(L.t("result.newTransfer")) { newTransfer() }
            }
            Button { attemptStart() } label: {
                Label(runner.isRunning ? L.t("footer.copying") : L.t(headerCompact && stage == .result ? "action.startOffload.short" : "action.startOffload"), systemImage: "play.fill")
                    .padding(.horizontal, DM.Space.xs).lineLimit(1)
            }
            .buttonStyle(.borderedProminent).tint(DM.accent).controlSize(.large)
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(runner.isRunning || sourcePaths.isEmpty || destinationPaths.isEmpty || IncidentBuilder.blocksStart(prepareIncidents))
            .help(IncidentBuilder.blocksStart(prepareIncidents) ? L.t("action.startBlocked") : L.t("action.startHelp"))
        }
        .labelStyle(.titleAndIcon)
        .padding(.horizontal, DM.Space.l).padding(.vertical, DM.Space.m)
        .background(GeometryReader { g in Color.clear.onAppear { headerWidth = g.size.width }
            .onChange(of: g.size.width) { _, w in headerWidth = w } })
    }

    /// Fișierele video verificate prin sumă de control de pe PRIMA copie care are astfel de fișiere.
    private var verifiedMedia: [URL] {
        let ext: Set<String> = ["mov", "mp4", "mxf", "m4v", "mkv", "avi", "mts", "m2ts", "mpg", "mpeg", "webm"]
        guard let r = runner.lastResults.first(where: { !$0.verifiedFiles.isEmpty }) else { return [] }
        return r.verifiedFiles.filter { ext.contains(($0 as NSString).pathExtension.lowercased()) }.map { URL(fileURLWithPath: $0) }
    }

    private var previewFolderName: String {
        NamingTemplate.render(namingTemplate, context: .init(
            project: meta.project, card: meta.card, camera: meta.camera, operatorName: meta.operatorName, date: Date()))
    }

    // MARK: Etapa

    private var stageTitle: some View {
        HStack(alignment: .firstTextBaseline, spacing: DM.Space.m) {
            Text(L.t("screen.\(stageKey)")).font(DM.Font.screenTitle).lineLimit(1).minimumScaleFactor(0.8)
            Text(stageSubtitle).font(DM.Font.label).foregroundStyle(DM.textSecondary).lineLimit(1).truncationMode(.tail)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, DM.Space.xl).padding(.top, DM.Space.l)
        .accessibilityElement(children: .combine).accessibilityAddTraits(.isHeader)
    }

    private var stageSubtitle: String {
        switch stage {
        case .prepare: return L.t("screen.prepare.sub")
        case .transfer: return runner.isPaused ? L.t("footer.paused") : L.t(runner.phase.labelKey)
        case .result:
            let srcs = OffloadPDFReport.sourceRows(runner.lastResults).count
            let copies = OffloadPDFReport.verifiedCopyCount(runner.lastResults)
            let base = runner.lastOutcome.map { L.t("outcomeHelp.\($0.rawValue)") } ?? ""
            return srcs > 0 ? String(format: L.t("result.matrix"), srcs, copies, runner.lastResults.count) + " — " + base : base
        }
    }

    private var mainStage: some View {
        RouteView(stage: stage, sources: sourceEndpoints, destinations: destinationEndpoints, node: routeNode,
                  animateFlow: RouteMotion.animatesFlow(isRunning: runner.isRunning, isPaused: runner.isPaused, reduceMotion: reduceMotion),
                  writeSpeed: runner.isRunning && !runner.isPaused ? runner.writeBytesPerSecond : 0,
                  verifySpeed: runner.isRunning && !runner.isPaused ? runner.verifyReadBytesPerSecond : 0,
                  dropHighlight: (isHoveringSource, isHoveringDest),
                  onRemove: stage == .prepare ? { removeEndpoint($0) } : nil,
                  onDropSources: { handleDrop($0, asSource: true) },
                  onDropDestinations: { handleDrop($0, asSource: false) })
    }

    private func displayName(_ path: String) -> String {
        #if DEBUG
        if let root = ProcessInfo.processInfo.environment["CGC_OFFLOAD_DEMO"], path.hasPrefix(root) {
            let n = (path as NSString).lastPathComponent
            return n.firstIndex(of: "_").map { String(n[n.index(after: $0)...]) } ?? n
        }
        #endif
        return FileManager.default.displayName(atPath: path)
    }

    private var sourceEndpoints: [RouteEndpoint] {
        sourcePaths.enumerated().map { i, path in
            var e = RouteEndpoint(path: path, name: displayName(path), media: mediaByPath[path], role: .source(i + 1))
            let info = cardInfoBySource[path]
            e.warning = !(info?.warnings.isEmpty ?? true)
            e.detail = info?.summary ?? ""
            switch stage {
            case .prepare:
                if let b = bytesBySource[path] { e.figure = formatBytes(b); e.figureCaption = L.t("fig.toCopy") }
                else { e.figureCaption = L.t("fig.measuring") }
                if let cap = capacities[path] { e.secondary = String(format: L.t("fig.ofVolume"), formatBytes(cap.total)) }
            case .transfer:
                e.activity = .reading
                e.figure = formatBytes(runner.bytesDone / Int64(max(runner.destinationCount, 1))); e.figureCaption = L.t("fig.read")
                e.progress = runner.progressPercent / 100
                e.secondary = runner.currentFile
            case .result:
                e.activity = .done
                e.figure = formatBytes(runner.bytesDone / Int64(max(runner.destinationCount, 1))); e.figureCaption = L.t("fig.read")
                e.secondary = String(format: L.t("fig.duration"), duration(runner.elapsedSeconds))
            }
            return e
        }
    }

    private var destinationEndpoints: [RouteEndpoint] {
        destinationPaths.enumerated().map { i, path in
            var e = RouteEndpoint(path: path, name: displayName(path), media: mediaByPath[path], role: .destination(i + 1))
            switch stage {
            case .prepare:
                guard let cap = capacities[path] else { e.figureCaption = L.t("fig.unknownSpace"); return e }
                let incoming = sourceBytes ?? 0
                let after = cap.free - incoming
                e.capacity = (cap.total, cap.total - cap.free, incoming)
                e.figure = formatBytes(abs(after))
                e.figureCaption = L.t(after >= 0 ? "fig.freeAfter" : "fig.missing")
                e.warning = after < 0
                e.secondary = String(format: L.t("fig.usedOf"), formatBytes(cap.total - cap.free), formatBytes(cap.total))
            case .transfer:
                let st = runner.destinationStates.first { $0.destRoot == path }
                let expected = max(runner.totalBytes / Int64(max(runner.destinationCount, 1)), 1)
                let written = st?.bytesWritten ?? 0
                e.online = st?.available ?? true
                e.warning = (st?.filesFailed ?? 0) > 0
                e.activity = .writing
                e.progress = min(1, Double(written) / Double(expected))
                e.figure = "\(Int((e.progress ?? 0) * 100))%"
                e.figureCaption = L.t("fig.written")
                e.secondary = String(format: L.t("monitor.confirmed"), st?.filesConfirmed ?? 0, formatBytes(written))
            case .result:
                guard let r = runner.lastResults.first(where: { $0.destRoot == path }) else { return e }
                e.outcome = r.outcome
                e.activity = .done
                e.figure = "\(r.okCount + r.skipCount)"
                e.figureCaption = L.t("fig.confirmed")
                var parts: [String] = []
                if r.failCount > 0 { parts.append(String(format: L.t("monitor.failedFiles"), r.failCount)) }
                if r.recoveredCount > 0 { parts.append("\(r.recoveredCount) \(L.t("result.recovered"))") }
                e.secondary = parts.joined(separator: " · ")
                var reports: [(label: String, path: String)] = []
                reports.append((L.t("result.openFolder"), r.targetRoot))
                if let x = r.htmlPath { reports.append(("HTML", x)) }
                if let x = r.csvPath { reports.append(("CSV", x)) }
                if let x = r.mhlPath { reports.append(("MHL", x)) }
                e.reports = reports
            }
            return e
        }
    }

    /// Viteza efectivă măsurată, pe feluri; nu se afișează o valoare pentru un fel de activitate care nu are eșantioane.
    private var speedFooterText: String {
        var parts: [String] = []
        if runner.writeBytesPerSecond > 0 { parts.append(L.t("speed.write") + " " + formatBytes(Int64(runner.writeBytesPerSecond)) + "/s") }
        if runner.verifyReadBytesPerSecond > 0 { parts.append(L.t("speed.verifyRead") + " " + formatBytes(Int64(runner.verifyReadBytesPerSecond)) + "/s") }
        return parts.joined(separator: " · ")
    }

    private var routeNode: RouteNodeModel {
        var n = RouteNodeModel(stage: stage, method: "\(verificationModel.shortLabel) · \(L.t("depth.short.\(depth.rawValue)"))")
        switch stage {
        case .prepare:
            n.phaseText = L.t("node.prepare")
        case .transfer:
            n.phaseText = runner.isPaused ? L.t("footer.pause") : L.t(runner.phase.labelKey)
            n.percent = Int(runner.progressPercent)
            n.status = .active
            if runner.phase == .verifying, runner.verifyReadBytesPerSecond > 0 {
                n.rateText = L.t("speed.verifyRead") + " " + formatBytes(Int64(runner.verifyReadBytesPerSecond)) + "/s"
            } else if runner.writeBytesPerSecond > 0 {
                n.rateText = L.t("speed.write") + " " + formatBytes(Int64(runner.writeBytesPerSecond)) + "/s"
            }
            n.etaText = runner.etaSeconds.map { String(format: L.t("node.eta"), duration($0)) }
        case .result:
            if let o = runner.lastOutcome { n.verdict = o; n.status = DMStatus(o); n.phaseText = L.t(o.labelKey) }
        }
        return n
    }

    // MARK: Incidente

    private var prepareIncidents: [Incident] {
        var input = IncidentBuilder.PrepareInput()
        input.issues = preflightIssues + collisionIssues
        input.cardWarnings = sourcePaths.flatMap { p in (cardInfoBySource[p]?.warnings ?? []).map { (p, $0) } }
        if let bytes = sourceBytes {
            input.spaceShort = destinationPaths.compactMap { d in
                guard let cap = capacities[d], bytes > cap.free else { return nil }
                return (d, bytes - cap.free)
            }
        }
        input.depth = depth
        input.unknownDevices = (sourcePaths + destinationPaths).filter { mediaByPath[$0]?.confidence == .fallback }
        return IncidentBuilder.prepare(input)
    }

    private var preparePassed: [String] {
        guard !sourcePaths.isEmpty, !destinationPaths.isEmpty else { return [] }
        var list: [String] = []
        let overlap: Set<PreflightIssue.Code> = [.sameAsSource, .destinationInsideSource, .sourceInsideDestination, .duplicateDestination, .nestedDestinations]
        if !preflightIssues.contains(where: { overlap.contains($0.code) }) { list.append(L.t("prep.check.noOverlap")) }
        if let bytes = sourceBytes, destinationPaths.allSatisfy({ d in capacities[d].map { bytes <= $0.free } ?? false }) { list.append(L.t("prep.check.spaceOk")) }
        if depth != .sizeOnly { list.append(L.t("prep.check.checksum")) }
        return list
    }

    @ViewBuilder private var incidentColumn: some View {
        switch stage {
        case .prepare:
            let list = prepareIncidents
            let blocking = list.filter { $0.blocksStart }.count
            let warnings = list.filter { $0.severity == .warning }.count
            if sourcePaths.isEmpty || destinationPaths.isEmpty {
                IncidentPanel(headline: L.t("incidents.incomplete"), headlineStatus: .neutral, incidents: list, passed: [])
            } else if blocking > 0 {
                IncidentPanel(headline: String(format: L.t("incidents.blocked"), blocking), headlineStatus: .failure, incidents: list, passed: preparePassed)
            } else if warnings > 0 {
                IncidentPanel(headline: String(format: L.t("incidents.readyWarnings"), warnings), headlineStatus: .warning, incidents: list,
                              passed: preparePassed, footnote: L.t("incidents.warningsDontBlock"))
            } else {
                IncidentPanel(headline: L.t("prep.state.ready"), headlineStatus: .verified, incidents: list, passed: preparePassed)
            }
        case .transfer:
            let list = IncidentBuilder.transfer(runner.destinationStates)
            IncidentPanel(headline: list.isEmpty ? L.t("incidents.none") : String(format: L.t("incidents.count"), list.count),
                          headlineStatus: list.isEmpty ? .active : .failure, incidents: list, footnote: L.t("incidents.transferNote"))
        case .result:
            let list = IncidentBuilder.sorted(IncidentBuilder.result(runner.lastResults))
            let o = runner.lastOutcome ?? .failure
            IncidentPanel(headline: L.t(o.labelKey), headlineStatus: DMStatus(o), incidents: list, passed: resultFigures,
                          footnote: L.t("outcomeHelp.\(o.rawValue)"))
        }
    }

    private var resultFigures: [String] {
        let r = runner.lastResults
        guard !r.isEmpty else { return [] }
        let confirmed = r.reduce(0) { $0 + $1.okCount }
        var list = [String(format: L.t("result.fig.files"), confirmed, r.count),
                    String(format: L.t("result.fig.read"), formatBytes(runner.bytesDone / Int64(max(runner.destinationCount, 1)))),
                    String(format: L.t("fig.duration"), duration(runner.elapsedSeconds))]
        if r.allSatisfy({ $0.mhlPath != nil }) { list.append(L.t("result.fig.mhl")) }
        if runner.metadataRunning { list.append(String(format: L.t("meta.fig.running"), runner.metadataProgress)) }
        if let md = runner.metadataSummary {
            if md.coreUnavailable { list.append(L.t("meta.fig.unavailable")) }
            else {
                list.append(String(format: L.t("meta.fig.done"), md.written, md.found))
                if md.failed + md.notVerified > 0 { list.append(String(format: L.t("meta.fig.problems"), md.failed + md.notVerified)) }
                if md.refusedForeign > 0 { list.append(String(format: L.t("meta.fig.foreign"), md.refusedForeign)) }
            }
        }
        if verificationModel == .sizeOnly { list.append(L.t("result.fig.sizeOnly")) }
        else if !verifiedMedia.isEmpty { list.append(String(format: L.t("result.fig.verifiedMedia"), verifiedMedia.count)) }
        return list
    }

    // MARK: Raftul de dispozitive

    private var deviceShelf: some View {
        VStack(alignment: .leading, spacing: DM.Space.s) {
            HStack(spacing: DM.Space.m) {
                DMSectionHeader(title: L.t("shelf.title")).fixedSize()
                Text(L.t("shelf.hint")).font(DM.Font.detail).foregroundStyle(DM.textTertiary).lineLimit(1)
                Spacer(minLength: 0)
                Button { shelfOpen = !shelfExpanded } label: {
                    Image(systemName: shelfExpanded ? "chevron.down" : "chevron.up")
                }
                .buttonStyle(.borderless).controlSize(.small)
                .help(shelfExpanded ? L.t("shelf.collapse") : L.t("shelf.expand"))
                Button { chooseFolder(asSource: true) } label: { Label(L.t("shelf.addSource"), systemImage: "plus") }.controlSize(.small)
                Button { chooseFolder(asSource: false) } label: { Label(L.t("shelf.addDestination"), systemImage: "plus") }.controlSize(.small)
            }
            if shelfExpanded { ScrollView(.horizontal) {
                HStack(spacing: DM.Space.l) {
                    ForEach(volumes) { volume in
                        let used = sourcePaths.contains(volume.path) || destinationPaths.contains(volume.path)
                        DeviceShelfItem(name: volume.name, media: mediaByPath[volume.path], freeBytes: volume.freeBytes)
                            .opacity(used ? 0.45 : 1)
                            .gesture(
                                DragGesture(minimumDistance: 4, coordinateSpace: .named("root"))
                                    .onChanged { value in draggingDiskPath = volume.path; dragPoint = value.location }
                                    .onEnded { value in
                                        if sourcesFrame.contains(value.location) { addSource(volume.path) }
                                        else if destFrame.contains(value.location) { addDestination(volume.path) }
                                        draggingDiskPath = nil
                                    }
                            )
                            .contextMenu {
                                Button(L.t("shelf.useAsSource")) { addSource(volume.path) }
                                Button(L.t("shelf.useAsDestination")) { addDestination(volume.path) }
                            }
                            .accessibilityAction(named: L.t("shelf.useAsSource")) { addSource(volume.path) }
                            .accessibilityAction(named: L.t("shelf.useAsDestination")) { addDestination(volume.path) }
                    }
                }
                .padding(.vertical, DM.Space.xs)
            } }
        }
        .padding(.horizontal, DM.Space.xl).padding(.vertical, shelfExpanded ? DM.Space.m : DM.Space.s)
        .background(DM.surfaceSunken.opacity(DM.Opacity.shelf))
    }

    // MARK: Subsol

    private var footer: some View {
        VStack(spacing: DM.Space.s) {
            DisclosureGroup(isExpanded: $logExpanded) {
                ScrollView {
                    Text(runner.activityLog.suffix(60).joined(separator: "\n"))
                        .font(DM.Font.mono).foregroundStyle(DM.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled)
                }
                .frame(height: DM.Layout.logHeight).padding(DM.Space.s)
                .background(DM.consoleBackground, in: RoundedRectangle(cornerRadius: DM.Radius.m))
            } label: {
                Text(L.t("log.title")).font(DM.Font.sectionTitle).foregroundStyle(DM.textSecondary)
            }
            HStack(spacing: DM.Space.m) {
                VStack(alignment: .leading, spacing: DM.Space.xxs) {
                    Text(footerStatusText).font(DM.Font.label).foregroundStyle(footerStatusColor).lineLimit(2)
                    if runner.isRunning && !runner.speedText.isEmpty { Text(speedFooterText).font(DM.Font.detail).foregroundStyle(DM.textSecondary) }
                }
                Spacer()
                Toggle(L.t("meta.extract"), isOn: $extractMetadata)
                    .toggleStyle(.checkbox).disabled(runner.isRunning).help(L.t("meta.extract.help"))
                profilesMenu
                Button { showHistory = true } label: { Label(L.t("history.title"), systemImage: "clock.arrow.circlepath") }
                Button { showOptions = true } label: { Label(L.t("offload.options"), systemImage: "gearshape") }
            }
            .labelStyle(.titleAndIcon)
        }
        .padding(.horizontal, DM.Space.l).padding(.vertical, DM.Space.m)
    }

    private var footerStatusText: String {
        if runner.isRunning || runner.lastOutcome != nil && showResult, !runner.statusText.isEmpty { return runner.statusText }
        if sourcePaths.isEmpty || destinationPaths.isEmpty { return L.t("footer.addToStart") }
        return String(format: L.t("footer.summary"), sourcePaths.count, destinationPaths.count)
    }

    private var footerStatusColor: Color {
        if runner.isRunning { return DM.textPrimary }
        if showResult, let o = runner.lastOutcome { return DMStatus(o).color }
        return DM.textSecondary
    }

    private var profilesMenu: some View {
        Menu {
            ForEach(profileStore.profiles) { p in
                Button(p.name) { loadProfile(p) }
            }
            if !profileStore.profiles.isEmpty { Divider() }
            Button(L.t("offload.profiles.save")) { showSaveProfile = true }
            ForEach(profileStore.profiles) { p in
                Button(role: .destructive) { profileStore.delete(p) } label: { Text("\(L.t("offload.profiles.delete")) “\(p.name)”") }
            }
        } label: { Label(L.t("offload.profiles.title"), systemImage: "tray.full") }
        .fixedSize()
    }

    // MARK: Acțiuni

    private func attemptStart() {
        guard !sourcePaths.isEmpty, !destinationPaths.isEmpty else { return }
        startTransfer(ignoreSpace: false)
    }

    private func startTransfer(ignoreSpace: Bool) {
        showResult = false
        Self.log.info("start sources=\(sourcePaths.count) destinations=\(destinationPaths.count) model=\(verificationModel.rawValue)")
        runner.start(sources: sourcePaths, destinations: destinationPaths, model: verificationModel,
                     meta: meta, namingTemplate: namingTemplate, ignoreSpaceWarning: ignoreSpace,
                     extractMetadata: extractMetadata)
    }

    // MARK: Coadă

    private func addCurrentToQueue() {
        var j = OffloadQueueJob(title: previewFolderName, sources: sourcePaths, destinations: destinationPaths, model: verificationModel)
        j.project = meta.project; j.card = meta.card; j.camera = meta.camera
        j.operatorName = meta.operatorName; j.client = meta.client; j.notes = meta.notes
        j.namingTemplate = namingTemplate; j.extractMetadata = extractMetadata
        queue.add(j)
    }

    private func startQueue() {
        guard !runner.isRunning else { queue.isActive = true; return }
        queue.isActive = true
        runNextQueued()
    }

    private func runNextQueued() {
        guard queue.isActive, !runner.isRunning, let job = queue.nextWaiting else { queue.isActive = false; return }
        showQueue = showQueue
        sourcePaths = job.sources; destinationPaths = job.destinations
        verificationModel = job.model
        meta = job.meta; namingTemplate = job.namingTemplate
        extractMetadata = job.extractMetadata
        showResult = false
        queue.markRunning(job.id)
        Self.log.info("queue start job=\(job.title) sources=\(job.sources.count) destinations=\(job.destinations.count)")
        runner.start(sources: job.sources, destinations: job.destinations, model: job.model, meta: job.meta,
                     namingTemplate: job.namingTemplate, extractMetadata: job.extractMetadata)
        if !runner.isRunning {   // refuzat înainte de primul octet (spațiu, surse lipsă)
            queue.finish(job.id, state: .failed, detail: runner.insufficientSpaceWarning ?? runner.statusText)
            runNextQueued()
        }
    }

    private func queueJobFinished() {
        guard let job = queue.running, let outcome = runner.lastOutcome else { return }
        let state: OffloadQueueJob.State
        switch outcome {
        case .success: state = .done
        case .successWithWarnings, .partialFailure: state = .doneWithIssues
        case .failure: state = .failed
        case .cancelled: state = .cancelled
        }
        queue.finish(job.id, state: state, detail: L.t(outcome.labelKey))
        Self.log.info("queue finish job=\(job.title) outcome=\(outcome.rawValue)")
        if outcome == .cancelled { queue.isActive = false }   // o anulare oprește coada
        else { runNextQueued() }
    }

    // MARK: Raport PDF

    private func exportPDF() {
        guard let o = runner.lastOutcome else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = "Raport_Offload_\(runner.lastFolderName).pdf"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let input = OffloadPDFInput(folderName: runner.lastFolderName, meta: meta, sources: sourcePaths,
                                    outcomeLabel: L.t(o.labelKey), results: runner.lastResults,
                                    metadata: runner.metadataSummary, duration: runner.elapsedSeconds)
        let ok = OffloadPDFReport.write(input, to: url)
        Self.log.info("pdf report \(ok ? "saved" : "failed") path=\(url.path)")
        pdfNote = ok ? L.t("report.pdf.saved") : "PDF"
        if ok { NSWorkspace.shared.activateFileViewerSelecting([url]) }
    }

    private func newTransfer() {
        showResult = false
        refreshPreparation()
    }

    private func addSource(_ path: String) {
        guard !sourcePaths.contains(path) else { return }
        showResult = false
        sourcePaths.append(path)
        cardInfoBySource[path] = CameraCardDetector.detect(root: path)
        refreshPreparation()
    }

    private func addDestination(_ path: String) {
        guard !destinationPaths.contains(path), destinationPaths.count < 4 else { return }
        showResult = false
        destinationPaths.append(path)
        refreshPreparation()
    }

    private func removeEndpoint(_ path: String) {
        if sourcePaths.contains(path) { sourcePaths.removeAll { $0 == path }; cardInfoBySource[path] = nil }
        else { destinationPaths.removeAll { $0 == path } }
        refreshPreparation()
    }

    private func chooseFolder(asSource: Bool) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let p = panel.url?.path { asSource ? addSource(p) : addDestination(p) }
    }

    private func handleDrop(_ providers: [NSItemProvider], asSource: Bool) -> Bool {
        var handled = false
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            handled = true
            provider.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
                guard let data, let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                var isDir: ObjCBool = false
                guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else { return }
                DispatchQueue.main.async {
                    if asSource { addSource(url.path) } else if isDir.boolValue { addDestination(url.path) }
                }
            }
        }
        return handled
    }

    private func refreshVolumes() {
        let detected = VolumeInfo.detectAll()
        let gone = Set(volumes.map(\.path)).subtracting(detected.map(\.path))
        for p in gone { MediaProbe.forget(p); mediaByPath[p] = nil }
        if detected != volumes { volumes = detected }
    }

    private func classifyNewPaths() async {
        let paths = Set(volumes.map(\.path) + sourcePaths + destinationPaths)
        for p in paths where mediaByPath[p] == nil { mediaByPath[p] = await MediaProbe.classify(path: p) }
    }

    private func refreshPreparation(scanSources: Bool = true) {
        preflightIssues = Preflight.check(sources: sourcePaths, destinations: destinationPaths)
        var caps: [String: VolumeCapacity] = [:]
        for d in destinationPaths + sourcePaths { caps[d] = VolumeCapacity.of(d) }
        capacities = caps
        let sources = sourcePaths
        guard !sources.isEmpty else { sourceBytes = nil; bytesBySource = [:]; collisionIssues = []; return }
        guard scanSources else { return }
        BackgroundWork.run {
            var per: [String: Int64] = [:]
            var all: [FileEntry] = []
            for src in sources {
                var isDir: ObjCBool = false
                guard FileManager.default.fileExists(atPath: src, isDirectory: &isDir) else { continue }
                if isDir.boolValue {
                    let files = offloadListAllFiles(root: src)
                    per[src] = files.reduce(0) { $0 + Int64($1.size) }
                    all += files
                } else {
                    let size = ((try? FileManager.default.attributesOfItem(atPath: src)[.size] as? Int64) ?? nil) ?? 0
                    per[src] = size
                    all.append(FileEntry(fullPath: src, relPath: (src as NSString).lastPathComponent, size: UInt64(size)))
                }
            }
            let measured = per
            let collisions = sources.count > 1 ? Preflight.nameCollisions(all) : []
            Task { @MainActor in
                if sources == sourcePaths {
                    bytesBySource = measured
                    sourceBytes = measured.values.reduce(0, +)
                    collisionIssues = collisions
                }
            }
        }
    }

    private func saveProfile() {
        let name = newProfileName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        profileStore.upsert(TransferProfile(
            name: name, sourcePaths: sourcePaths, destinationPaths: destinationPaths,
            verificationModel: verificationModel, chunkSizeMB: chunkSizeMB, ramLimitMB: ramLimitMB,
            namingTemplate: namingTemplate, project: meta.project, client: meta.client,
            camera: meta.camera, operatorName: meta.operatorName))
        newProfileName = ""
    }

    private func loadProfile(_ p: TransferProfile) {
        sourcePaths = p.sourcePaths; destinationPaths = p.destinationPaths
        verificationModel = p.verificationModel; chunkSizeMB = p.chunkSizeMB; ramLimitMB = p.ramLimitMB
        namingTemplate = p.namingTemplate
        meta.project = p.project; meta.client = p.client; meta.camera = p.camera; meta.operatorName = p.operatorName
        IOSettings.chunkSizeMB = p.chunkSizeMB; IOSettings.ramLimitMB = p.ramLimitMB
        for s in sourcePaths { cardInfoBySource[s] = CameraCardDetector.detect(root: s) }
        refreshPreparation()
    }

    private func duration(_ s: Double) -> String { formatDurata(s) ?? "—" }

    #if DEBUG
    /// Doar DEBUG: `CGC_OFFLOAD_DEMO=<folder>` precompletează sursa `<folder>/CF_A001` și destinațiile
    /// `SSD_SHUTTLE-01`, `RAID_BACKUP-RAID-02`; `CGC_OFFLOAD_DEMO_START=1` pornește transferul (capturi de verificare).
    private func applyDemoIfRequested() {
        let env = ProcessInfo.processInfo.environment
        guard let root = env["CGC_OFFLOAD_DEMO"] else { return }
        meta.project = env["CGC_OFFLOAD_DEMO_PROJECT"] ?? "SOARE DE IARNĂ"
        meta.card = env["CGC_OFFLOAD_DEMO_CARD"] ?? "A001"
        let list = { (key: String, fallback: String) in
            (env[key] ?? fallback).split(separator: ",").map { (root as NSString).appendingPathComponent(String($0)) }
        }
        if env["CGC_OFFLOAD_DEMO_EMPTY"] == "1" { return }
        for s in list("CGC_OFFLOAD_DEMO_SOURCES", "CF_A001") { addSource(s) }
        for d in list("CGC_OFFLOAD_DEMO_DESTS", "SSD_SHUTTLE-01,RAID_BACKUP-RAID-02") { addDestination(d) }
        if env["CGC_OFFLOAD_DEMO_START"] == "1" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { attemptStart() }
        }
    }
    #endif
}

/// Etichetă de antet: în modul îngust doar pictograma (textul rămâne în `help`/accesibilitate).
struct HeaderLabelStyle: LabelStyle {
    let iconOnly: Bool
    func makeBody(configuration: Configuration) -> some View {
        if iconOnly { configuration.icon } else { HStack(spacing: 6) { configuration.icon; configuration.title } }
    }
}
