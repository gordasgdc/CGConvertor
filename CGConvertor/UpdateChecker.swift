import AppKit

/// "Check for Updates" — compară versiunea rulată cu ultimul tag de pe
/// GitHub Releases și descarcă+instalează automat noua versiune, FĂRĂ să
/// mai treacă prin browser/pagina de GitHub — vezi SelfUpdater.swift și
/// CLAUDE.md Partea 1, Regula 20.
enum UpdateChecker {
    private static let latestReleaseAPIURL = URL(string: "https://api.github.com/repos/gordasgdc/CGConvertor/releases/latest")!
    private static let releasesPageURL = URL(string: "https://github.com/gordasgdc/CGConvertor/releases/latest")!

    static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }

    /// Verificare automată, o singură dată per lansare, tăcută dacă nu e
    /// nimic nou. Dismissal per-versiune, ca update-ul deja văzut să nu
    /// reapară la fiecare pornire.
    static func checkSilentlyOnLaunch(onNewVersion: @escaping (String, URL) -> Void) {
        Task {
            if case .newVersion(let version, let pkgURL) = await fetchLatestTag() {
                let dismissedKey = "cgconvertor_dismissed_update_version"
                if UserDefaults.standard.string(forKey: dismissedKey) == version { return }
                await MainActor.run { onNewVersion(version, pkgURL) }
            }
        }
    }

    static func markDismissed(_ version: String) {
        UserDefaults.standard.set(version, forKey: "cgconvertor_dismissed_update_version")
    }

    static func checkAndShowAlert() {
        Task {
            let result = await fetchLatestTag()
            await MainActor.run { presentResult(result) }
        }
    }

    private enum Result {
        case upToDate
        case newVersion(String, URL)
        case error
    }

    private static func fetchLatestTag() async -> Result {
        var request = URLRequest(url: latestReleaseAPIURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tag = json["tag_name"] as? String else {
                return .error
            }
            let latest = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
            guard isVersion(latest, newerThan: currentVersion) else { return .upToDate }

            // Asset-ul .pkg cu nume STABIL ("CGConvertor.pkg") publicat de
            // build_installer.sh la fiecare release.
            let assets = json["assets"] as? [[String: Any]] ?? []
            let pkgAsset = assets.first { ($0["name"] as? String) == "CGConvertor.pkg" }
            guard let urlString = pkgAsset?["browser_download_url"] as? String, let pkgURL = URL(string: urlString) else {
                return .newVersion(latest, releasesPageURL)
            }
            return .newVersion(latest, pkgURL)
        } catch {
            return .error
        }
    }

    private static func isVersion(_ a: String, newerThan b: String) -> Bool {
        let partsA = a.split(separator: ".").compactMap { Int($0) }
        let partsB = b.split(separator: ".").compactMap { Int($0) }
        for i in 0..<max(partsA.count, partsB.count) {
            let x = i < partsA.count ? partsA[i] : 0
            let y = i < partsB.count ? partsB[i] : 0
            if x != y { return x > y }
        }
        return false
    }

    private static func presentResult(_ result: Result) {
        let alert = NSAlert()
        switch result {
        case .upToDate:
            alert.messageText = L.t("update.upToDate.title")
            alert.informativeText = String(format: L.t("update.upToDate.body"), currentVersion)
            alert.addButton(withTitle: "OK")
            alert.runModal()
        case .newVersion(let version, let pkgURL):
            alert.messageText = L.t("update.available.title")
            alert.informativeText = String(format: L.t("update.available.body"), version, currentVersion)
            alert.addButton(withTitle: L.t("update.download"))
            alert.addButton(withTitle: L.t("update.later"))
            let response = alert.runModal()
            markDismissed(version)
            if response == .alertFirstButtonReturn {
                Task { await SelfUpdater.downloadAndInstall(pkgURL: pkgURL, version: version) }
            }
        case .error:
            alert.messageText = L.t("update.error.title")
            alert.informativeText = L.t("update.error.body")
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
}
