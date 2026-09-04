import SwiftUI

/// Setări (Faza 1 v3.0.0) — temă System/Dark/Light (Regula 18), mărime
/// text (Regula 24), joburi simultane, și profilul afișat în sidebar
/// (Nume/Email — Regula 12). Spre deosebire de varianta Windows
/// (Tkinter, necesită teardown+rebuild manual), aici temă/mărime text se
/// aplică INSTANT — `Shift`/`.dynamicTypeSize` citesc direct din
/// `AppSettings.shared`, orice `@ObservedObject` pe el redesenează live.
struct SettingsSheet: View {
    @Binding var isPresented: Bool
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L.t("sidebar.settings")).font(.title2).bold()

            Picker(L.t("settings.theme"), selection: $settings.themePreference) {
                ForEach(ThemePreference.allCases) { pref in
                    Text(pref.label).tag(pref)
                }
            }
            Picker(L.t("settings.fontSize"), selection: $settings.textScale) {
                ForEach(TextScale.allCases) { scale in
                    Text(scale.label).tag(scale)
                }
            }

            Stepper(value: $settings.maxParallelJobs, in: 1...4) {
                Text("\(L.t("settings.parallelJobs")): \(settings.maxParallelJobs)")
            }

            Divider().overlay(Shift.border)

            TextField(L.t("settings.userName"), text: $settings.userName)
                .textFieldStyle(.roundedBorder)
            TextField(L.t("settings.userEmail"), text: $settings.userEmail)
                .textFieldStyle(.roundedBorder)

            HStack {
                Spacer()
                Button(L.t("settings.save")) { isPresented = false }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 380)
        .background(Shift.bg)
        .foregroundStyle(Shift.text)
    }
}
