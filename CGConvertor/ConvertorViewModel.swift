import Foundation
import SwiftUI
import Combine

@MainActor
final class ConvertorViewModel: ObservableObject {
    @Published var joburi: [VideoJob] = []
    @Published var modConversie: ModConversie = .rewrap
    @Published var codecAles: CodecOutput = .proRes422HQ
    @Published var folderDestinatie: URL?
    @Published var seRuleazaCoada: Bool = false
    @Published var ffmpegInstalat: Bool = MotorFFmpeg.gasesteBinar() != nil

    private var indexCurent: Int = 0

    func verificaFFmpeg() {
        ffmpegInstalat = MotorFFmpeg.gasesteBinar() != nil
    }

    func adaugaFisiere(_ urlURIs: [URL]) {
        for url in urlURIs {
            guard !joburi.contains(where: { $0.urlSursa == url }) else { continue }
            joburi.append(VideoJob(urlSursa: url))
        }
    }

    func stergeJob(_ job: VideoJob) {
        joburi.removeAll { $0.id == job.id }
    }

    func golesteLista() {
        joburi.removeAll()
    }

    func alegeFolderDestinatie() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Alege folder"
        if panel.runModal() == .OK {
            folderDestinatie = panel.url
        }
    }

    /// Construieste URL-ul de iesire pentru un job, in functie de folderul ales si codec
    private func urlDestinatie(pentru job: VideoJob) -> URL {
        let numeBaza = job.urlSursa.deletingPathExtension().lastPathComponent
        let extensie = modConversie == .rewrap ? "mov" : codecAles.extensieContainer
        let folder = folderDestinatie ?? job.urlSursa.deletingLastPathComponent()
        return folder.appendingPathComponent("\(numeBaza)_convertit.\(extensie)")
    }

    func pornesteCoada() {
        guard !seRuleazaCoada, !joburi.isEmpty else { return }
        guard ffmpegInstalat else { return }
        seRuleazaCoada = true
        indexCurent = 0
        proceseazaUrmatorul()
    }

    private func proceseazaUrmatorul() {
        guard indexCurent < joburi.count else {
            seRuleazaCoada = false
            return
        }

        let job = joburi[indexCurent]
        let destinatie = urlDestinatie(pentru: job)
        joburi[indexCurent].urlDestinatie = destinatie
        joburi[indexCurent].stare = .inLucru(progres: 0)

        MotorFFmpeg.ruleazaConversie(
            job: job,
            mod: modConversie,
            codec: codecAles,
            destinatie: destinatie,
            progresCallback: { [weak self] progres in
                guard let self else { return }
                guard let idx = self.joburi.firstIndex(where: { $0.id == job.id }) else { return }
                self.joburi[idx].stare = .inLucru(progres: progres)
            },
            finalizareCallback: { [weak self] rezultat in
                guard let self else { return }
                guard let idx = self.joburi.firstIndex(where: { $0.id == job.id }) else { return }
                switch rezultat {
                case .success:
                    self.joburi[idx].stare = .finalizat
                case .failure(let eroare):
                    self.joburi[idx].stare = .eroare(mesaj: eroare.localizedDescription)
                }
                self.indexCurent += 1
                self.proceseazaUrmatorul()
            }
        )
    }
}

#if canImport(AppKit)
import AppKit
#endif

