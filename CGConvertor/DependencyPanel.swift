import SwiftUI
import AppKit

/// Badge global din header — bulina + text, click deschide panoul
/// complet. Verde DOAR pe baza componentelor obligatorii (FFmpeg);
/// Homebrew fiind opțional nu-l face roșu.
struct DependencyBadge: View {
    @ObservedObject var deps: DependencyManager
    @Binding var showPanel: Bool

    var body: some View {
        Button { showPanel = true } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(deps.isReady ? Shift.success : Shift.error)
                    .frame(width: 7, height: 7)
                Text(deps.isReady ? L.t("deps.badge.ok") : L.t("deps.badge.missing"))
                    .font(.system(size: 10.5, weight: .medium))
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Shift.elevated)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .foregroundStyle(Shift.text)
    }
}

/// Panoul modular "Verificare & Dependențe Sistem" — o listă generică de
/// componente (`DependencyManager.items`), fiecare cu propria stare și
/// buton de acțiune. Extensibil: o componentă nouă înseamnă un rând nou
/// în `DependencyManager.items`, nu o schimbare de UI aici.
struct DependencyPanel: View {
    @ObservedObject var deps: DependencyManager
    @Binding var isPresented: Bool
    @State private var justCopiedHomebrew = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L.t("deps.panel.title")).font(.title3.bold())
                    Text(L.t("deps.panel.subtitle"))
                        .font(.system(size: 11.5))
                        .foregroundStyle(Shift.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }

            VStack(spacing: 10) {
                ForEach(deps.items) { item in
                    row(for: item)
                }
            }

            if let error = deps.downloadError {
                Text(error).font(.system(size: 11.5)).foregroundStyle(Shift.error)
            }

            HStack {
                Button(L.t("deps.refresh")) { deps.refreshAll() }
                    .buttonStyle(ShiftGhostButtonStyle())
                Spacer()
                Button(L.t("deps.close")) { isPresented = false }
                    .buttonStyle(ShiftGhostButtonStyle())
            }
        }
        .padding(20)
        .frame(width: 460)
        .background(Shift.bg)
        .onAppear { deps.refreshAll() }
    }

    @ViewBuilder
    private func row(for item: DependencyItem) -> some View {
        ShiftCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    stateDot(item.state)
                    Text(item.name).font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Text(stateLabel(item.state))
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(stateColor(item.state))
                }

                Text(item.id == "ffmpeg" ? L.t("deps.ffmpeg.hint") : L.t("deps.homebrew.hint"))
                    .font(.system(size: 11))
                    .foregroundStyle(Shift.muted)

                if item.id == "ffmpeg", item.state == .missing {
                    if deps.isDownloadingFFmpeg {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small).tint(Shift.accent)
                            Text(L.t("deps.ffmpeg.downloading")).font(.system(size: 11)).foregroundStyle(Shift.muted)
                        }
                    } else {
                        Button(item.actionLabel) { item.action?() }
                            .buttonStyle(ShiftGhostButtonStyle())
                    }
                } else if item.id == "homebrew", item.state == .optionalMissing {
                    HStack(spacing: 8) {
                        Button(justCopiedHomebrew ? L.t("deps.homebrew.copied") : L.t("deps.homebrew.copy")) {
                            deps.copyHomebrewInstallCommand()
                            justCopiedHomebrew = true
                        }
                        .buttonStyle(ShiftGhostButtonStyle())
                        Button(L.t("deps.homebrew.openSite")) { deps.openHomebrewSite() }
                            .buttonStyle(ShiftGhostButtonStyle())
                    }
                }
            }
        }
    }

    private func stateDot(_ state: DependencyState) -> some View {
        Circle().fill(stateColor(state)).frame(width: 8, height: 8)
    }

    private func stateColor(_ state: DependencyState) -> Color {
        switch state {
        case .ok: return Shift.success
        case .missing: return Shift.error
        case .optionalMissing: return .orange
        case .checking, .unknown: return Shift.faint
        }
    }

    private func stateLabel(_ state: DependencyState) -> String {
        switch state {
        case .ok: return L.t("deps.state.ok")
        case .missing: return L.t("deps.state.missing")
        case .optionalMissing: return L.t("deps.state.optionalMissing")
        case .checking: return L.t("deps.state.checking")
        case .unknown: return ""
        }
    }
}
