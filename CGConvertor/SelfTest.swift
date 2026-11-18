import Foundation
import AppKit

/// Mod de verificare fără interfață, pentru aplicația împachetată:
///   CGConvertor --selftest-convert <sursa> <folder> <preset-id> [--no-meta] [--print-report]
/// Rulează exact conducta reală de conversie și tipărește un raport JSON.
enum SelfTest {
    static func runIfRequested() {
        let a = CommandLine.arguments
        if a.contains("--selftest-trial") { runTrialChecks() }
        if let k = a.firstIndex(of: "--selftest-diag"), a.count > k + 1 {
            runDiagChecks(folder: URL(fileURLWithPath: a[k + 1]))
        }
        if let k = a.firstIndex(of: "--selftest-offload"), a.count > k + 2 {
            // Copiere verificată fără UI: tipărește câte fișiere sunt «verificate» (cu sumă de control) pentru trimiterea la transcodare.
            let src = a[k + 1], dst = a[k + 2]
            for model in [VerificationModel.xxhash64, .sizeOnly] {
                let files = offloadListAllFiles(root: src)
                let job = OffloadDestinationJob(destination: dst, folderName: "selftest_\(model.rawValue)", files: files, sourceRoot: src, model: model,
                                                meta: ProductionMeta(), cancel: CancelToken(), pause: PauseToken(), onFileDone: { _, _, _ in }, onActivity: { _ in })
                let r = job.run()
                print("\(model.rawValue): ok=\(r.okCount) mismatch=\(r.mismatchCount) err=\(r.errorCount) verifiedFiles=\(r.verifiedFiles.count)")
            }
            exit(0)
        }
        if a.contains("--selftest-tc") {
            let f = 30000.0 / 1001.0
            let cases: [(String, Int, Double, String)] = [
                ("00:00:59;29", 1, f, "00:01:00;02"), ("00:09:59;29", 1, f, "00:10:00;00"),
                ("06:37:06;18", 120, 60000.0 / 1001.0, "06:37:08;18"), ("00:01:59;29", 1, f, "00:02:00;02"),
                ("03:18:54:36", 100, 50, "03:18:56:36"), ("00:00:00:00", 24 * 3600 * 25, 25, "00:00:00:00"),
                ("01:00:00;00", -1, f, "00:59:59;29")]
            var bad = 0
            for (tc, d, fps, want) in cases {
                let got = TimecodeMath.offset(tc, frames: d, fps: fps)
                if got != want { bad += 1; print("FAIL \(tc) \(d) -> \(got ?? "nil") want \(want)") } else { print("OK   \(tc) \(d) -> \(want)") }
            }
            exit(bad == 0 ? 0 : 1)
        }
        guard let i = a.firstIndex(of: "--selftest-convert"), a.count >= i + 4 else { return }
        let src = URL(fileURLWithPath: a[i + 1]), folder = URL(fileURLWithPath: a[i + 2])
        let presetID = a[i + 3]
        let preserve = !a.contains("--no-meta")
        guard let preset = PresetsManager.defaultPresets().first(where: { $0.id == presetID }) else {
            print("PRESET? \(PresetsManager.defaultPresets().map { $0.id })"); exit(2)
        }
        let ext = MotorFFmpeg.extensieContainer(pentru: preset)
        let dst = folder.appendingPathComponent(src.deletingPathExtension().lastPathComponent + preset.fileSuffix + "." + ext)
        let started = Date()
        var cancelAfter: Double?
        if let c = a.firstIndex(of: "--cancel-after"), a.count > c + 1 { cancelAfter = Double(a[c + 1]) }
        DispatchQueue.main.async {
            var job = VideoJob(urlSursa: src)
            if let k = a.firstIndex(of: "--interval"), a.count > k + 2 { job.intervalStart = Double(a[k + 1]); job.intervalEnd = Double(a[k + 2]) }
            let h = MotorFFmpeg.ruleazaConversie(job: job, preset: preset, destinatie: dst,
                                         pastreazaMetadate: preserve, progresCallback: { _ in },
                                         finalizareCallback: { r in
                switch r {
                case .success(let rep):
                    let out: [String: Any] = [
                        "ok": true, "output": dst.path, "seconds": Date().timeIntervalSince(started),
                        "metadata": "\(rep.metadata)", "tcSource": rep.timecodeSource ?? "", "tcOutput": rep.timecodeOutput ?? "",
                        "frames": [rep.framesSource ?? -1, rep.framesOutput ?? -1],
                        "audio": [rep.audioStreamsSource, rep.audioStreamsOutput],
                        "duration": [rep.durationSource ?? -1, rep.durationOutput ?? -1],
                        "kept": rep.kept.map { $0.text }, "notKept": rep.notKept.map { $0.text },
                        "problems": rep.metadataProblems.map { $0.text },
                        "interval": rep.interval.map { ["startFrame": $0.startFrame, "frames": $0.frames, "fps": $0.fps] } ?? [:],
                        "grafted": rep.grafted.map { ["fourcc": $0.fourcc, "samples": $0.sampleCount, "sha256": $0.payloadSHA256] },
                    ]
                    if let d = try? JSONSerialization.data(withJSONObject: out, options: [.prettyPrinted, .sortedKeys]) {
                        print(String(decoding: d, as: UTF8.self))
                    }
                    StructuredLog.shared.flush(); exit(0)
                case .failure(let e):
                    print("{\"ok\": false, \"error\": \"\(e.localizedDescription)\"}")
                    StructuredLog.shared.flush(); exit(1)
                }
            })
            if let c = cancelAfter {
                DispatchQueue.main.asyncAfter(deadline: .now() + c) { h.anuleaza() }
            }
        }
    }
}

extension SelfTest {
    /// Scenarii de proba pe domeniu de preferinte + serviciu Keychain IZOLATE
    /// (nu atinge licenta sau preferintele reale ale utilizatorului).
    static func runTrialChecks() -> Never {
        func suite(_ n: String) -> UserDefaults { let d = UserDefaults(suiteName: n)!; d.removePersistentDomain(forName: n); return d }
        let id = UUID().uuidString.prefix(8)
        var results: [String] = []
        func check(_ name: String, _ ok: Bool, _ extra: String = "") { results.append("\(ok ? "OK " : "FAIL") \(name) \(extra)") }
        let day: TimeInterval = 86400
        let t0 = Date(timeIntervalSince1970: 1_800_000_000)
        var clock = t0

        // 1. utilizator nou: 5 zile
        let svcNew = "cgc.test.new.\(id)"
        let dNew = suite("cgc.test.new.\(id)")
        let m1 = LicenseManager(defaults: dNew, markerService: svcNew, now: { clock })
        check("nou: 5 zile acordate", m1.trialGrantedDays == 5)
        check("nou: ziua 0 activa, 5 ramase", m1.isTrialActive && m1.trialDaysRemaining == 5, "\(m1.trialDaysRemaining)")
        clock = t0.addingTimeInterval(4.5 * day)
        check("nou: ziua 4.5 inca activa", m1.isTrialActive, "\(m1.trialDaysRemaining)")
        clock = t0.addingTimeInterval(5.01 * day)
        check("nou: dupa 5 zile expirata", !m1.isTrialActive)
        // 2. stergerea preferintelor nu reporneste proba (Keychain)
        let dNew2 = suite("cgc.test.new2.\(id)")
        let m2 = LicenseManager(defaults: dNew2, markerService: svcNew, now: { clock })
        check("preferinte sterse: proba NU reporneste", !m2.isTrialActive && m2.trialGrantedDays == 5)
        // 3. proba veche (15 zile) pastrata, fara marker
        let svcOld = "cgc.test.old.\(id)"
        let dOld = suite("cgc.test.old.\(id)")
        dOld.set(t0.addingTimeInterval(-3 * day).timeIntervalSince1970, forKey: "cgconvertor_trial_start")
        clock = t0
        let m3 = LicenseManager(defaults: dOld, markerService: svcOld, now: { clock })
        check("veche: 15 zile pastrate", m3.trialGrantedDays == 15, "\(m3.trialGrantedDays)")
        check("veche: 12 zile ramase dupa 3 consumate", m3.trialDaysRemaining == 12, "\(m3.trialDaysRemaining)")
        clock = t0.addingTimeInterval(11.9 * day)
        check("veche: inca activa dupa 14.9 zile totale", m3.isTrialActive)
        TrialMarker.delete(service: svcNew); TrialMarker.delete(service: svcOld)
        print(results.joined(separator: "\n"))
        exit(results.contains { $0.hasPrefix("FAIL") } ? 1 : 0)
    }
}


extension SelfTest {
    /// Redactare, rotație cu limite, export fără secrete/media, logger care eșuează nu blochează.
    static func runDiagChecks(folder: URL) {
        let fm = FileManager.default
        try? fm.removeItem(at: folder)
        try? fm.createDirectory(at: folder, withIntermediateDirectories: true)
        var res: [String] = []
        func check(_ name: String, _ ok: Bool) { res.append((ok ? "OK   " : "FAIL ") + name) }

        let secrets = ["GDC1-ABCDEF0123456789ABCDEF0123456789XYZ", ("sk_" + "live_" + "0123456789abcdefghijklmn"), "hunter2secretpw"]
        var cfg = StructuredLog.Config(directory: folder.appendingPathComponent("logs"))
        cfg.maxBytes = 20_000; cfg.maxFiles = 3
        let log = StructuredLog(config: cfg)
        log.log(.info, "diag", "t.secret", "licenseCode=\(secrets[0]) token=\(secrets[1]) password=\(secrets[2])", job: "j1",
                fields: ["licenseCode": secrets[0], "path": "/Users/someone/Movies/clip.mov"])
        log.log(.error, "diag", "t.err", "Eroare la /Volumes/CristiGordas/clipuri/secret.mov", job: "j1")
        for i in 0..<400 { log.log(.info, "diag", "t.fill", "linie de umplere numarul \(i) cu text suficient de lung ca sa rotim fisierul", job: "j\(i)") }
        log.flush()
        let files = log.logFiles()
        check("rotation keeps <= maxFiles", files.count <= cfg.maxFiles && files.count > 1)
        check("each file within limit (+1 record)", files.allSatisfy { (try? fm.attributesOfItem(atPath: $0.path)[.size] as? Int64 ?? 0) ?? 0 <= cfg.maxBytes + 2000 })
        let all = files.compactMap { try? String(contentsOf: $0, encoding: .utf8) }.joined()
        check("no secret in log files", !secrets.contains { all.contains($0) })

        // Primul fisier (cu secretele) poate fi rotit; scriem din nou intr-un log mic pentru export.
        var cfg2 = StructuredLog.Config(directory: folder.appendingPathComponent("logs2"))
        let log2 = StructuredLog(config: cfg2)
        log2.log(.info, "diag", "t.secret", "licenseCode=\(secrets[0]) token=\(secrets[1]) password=\(secrets[2]) /Users/someone/Movies/clip.mov", job: "j1")
        cfg2.maxFiles = 1
        var ex = DiagnosticExporter(log: log2, accessSummary: ["mode": "trial", "licenseCode": secrets[0]])
        ex.lastJob = ["outcome": "ok", "token": secrets[1]]
        do {
            let zip = try ex.export(to: folder.appendingPathComponent("exports"))
            let dir = folder.appendingPathComponent("unz"); try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/bin/ditto"); p.arguments = ["-x", "-k", zip.path, dir.path]
            try p.run(); p.waitUntilExit()
            var text = ""; var media = false
            if let en = fm.enumerator(at: dir, includingPropertiesForKeys: nil) {
                for case let u as URL in en where !u.hasDirectoryPath {
                    if ["mov", "mp4", "mxf", "wav"].contains(u.pathExtension.lowercased()) { media = true }
                    text += (try? String(contentsOf: u, encoding: .utf8)) ?? ""
                }
            }
            check("export has no secrets", !secrets.contains { text.contains($0) })
            check("export has no home path", !text.contains("/Users/someone"))
            check("export has no media files", !media)
            check("export has manifest", text.contains("cgconvertor-diagnostic/1"))
        } catch { check("export succeeds (\(error))", false) }

        // Logger care nu poate scrie nu blocheaza si nu arunca.
        let bad = StructuredLog(config: StructuredLog.Config(directory: URL(fileURLWithPath: "/nonexistent-root/x/y")))
        let t0 = Date(); bad.log(.info, "diag", "t.bad", "msg"); bad.flush()
        check("failing logger does not block", Date().timeIntervalSince(t0) < 2)

        res.forEach { print($0) }
        exit(res.contains { $0.hasPrefix("FAIL") } ? 1 : 0)
    }
}
