import Foundation
import Combine

/// Biblioteca de LUT-uri memorate + LUT-ul asociat fiecărui clip (2026-09-11).
///
/// Cerință directă de la Cristi: *„să selectez clipurile și să selectez de
/// dinainte un anumit tip de LUT sau eventual să pot să-mi memorez LUT-uri, ca
/// să nu stau pe fiecare să tot dau aplică LUT"*.
///
/// Două lucruri distincte, ambele aici:
///   1. **Biblioteca** — LUT-urile folosite frecvent, memorate între sesiuni,
///      alese dintr-un meniu în loc de un dialog de fișiere de fiecare dată.
///   2. **Asocierea per clip** — fiecare fișier din coadă își reține LUT-ul
///      ales, iar playerul/previzualizarea pornesc direct cu el.
///
/// Persistăm **căi**, nu conținutul LUT-urilor: un `.cube` poate avea zeci de
/// MB, iar userul își ține fișierele acolo unde vrea. Un LUT mutat/șters e
/// semnalat, nu ascuns — vezi `lipsesteFisierul`.
@MainActor
final class LUTLibrary: ObservableObject {
    static let shared = LUTLibrary()

    struct LUTMemorat: Identifiable, Codable, Hashable {
        var id: String { cale }
        let cale: String
        var nume: String
        var numeAfisat: String { nume.isEmpty ? (cale as NSString).lastPathComponent : nume }
        var url: URL { URL(fileURLWithPath: cale) }
        var lipsesteFisierul: Bool { !FileManager.default.fileExists(atPath: cale) }
    }

    @Published private(set) var memorate: [LUTMemorat] = []
    /// jobID -> calea LUT-ului ales pentru acel clip.
    @Published private(set) var lutPerJob: [UUID: String] = [:]

    private let cheieMemorate = "cgc.lut.library"

    private init() { incarca() }

    // MARK: - Bibliotecă

    func adauga(url: URL) {
        let cale = url.path
        guard !memorate.contains(where: { $0.cale == cale }) else { return }
        memorate.append(LUTMemorat(cale: cale, nume: url.deletingPathExtension().lastPathComponent))
        salveaza()
    }

    func elimina(_ lut: LUTMemorat) {
        memorate.removeAll { $0.cale == lut.cale }
        // Clipurile care foloseau acest LUT rămân fără el — altfel ar arăta
        // în continuare un LUT care nu mai e în bibliotecă.
        for (jobID, cale) in lutPerJob where cale == lut.cale {
            lutPerJob.removeValue(forKey: jobID)
        }
        salveaza()
    }

    func redenumeste(_ lut: LUTMemorat, nume: String) {
        guard let index = memorate.firstIndex(where: { $0.cale == lut.cale }) else { return }
        memorate[index].nume = nume
        salveaza()
    }

    // MARK: - Asociere per clip

    func lut(pentru jobID: UUID) -> URL? {
        guard let cale = lutPerJob[jobID] else { return nil }
        return URL(fileURLWithPath: cale)
    }

    func numeLUT(pentru jobID: UUID) -> String? {
        guard let cale = lutPerJob[jobID] else { return nil }
        if let memorat = memorate.first(where: { $0.cale == cale }) { return memorat.numeAfisat }
        return (cale as NSString).lastPathComponent
    }

    /// Aplică un LUT pe MAI MULTE clipuri deodată — exact pasul care lipsea.
    /// Adaugă automat LUT-ul în bibliotecă, ca data viitoare să fie la un click.
    func aplica(url: URL, pe jobIDs: some Sequence<UUID>) {
        adauga(url: url)
        for id in jobIDs { lutPerJob[id] = url.path }
        salveaza()
    }

    func elimina(dePe jobIDs: some Sequence<UUID>) {
        for id in jobIDs { lutPerJob.removeValue(forKey: id) }
        salveaza()
    }

    // MARK: - Persistență

    private struct Stare: Codable {
        var memorate: [LUTMemorat]
        var lutPerJob: [String: String]
    }

    private func salveaza() {
        // Asocierile per clip NU se persistă: un `jobID` e valabil doar cât
        // trăiește coada curentă, iar la repornire fișierele primesc alte
        // identificatoare. Biblioteca, în schimb, are sens între sesiuni.
        let stare = Stare(memorate: memorate, lutPerJob: [:])
        if let data = try? JSONEncoder().encode(stare) {
            UserDefaults.standard.set(data, forKey: cheieMemorate)
        }
    }

    private func incarca() {
        guard let data = UserDefaults.standard.data(forKey: cheieMemorate),
              let stare = try? JSONDecoder().decode(Stare.self, from: data) else { return }
        memorate = stare.memorate
    }
}
