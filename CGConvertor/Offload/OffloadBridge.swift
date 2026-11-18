import Foundation

// Punte între modelul de domeniu al traseului (adaptat din DataMover) și motorul de copiere
// verificată al CGConvertor (OffloadEngine.swift).

typealias FileEntry = OffloadFileEntry
typealias DestinationResult = OffloadDestinationResult

extension OffloadDestinationResult {
    var destRoot: String { destination }
    var failCount: Int { mismatchCount + errorCount }
    var skipCount: Int { 0 }
    var targetFolder: String? { targetRoot }
    var pdfPath: String? { nil }
    var outcome: DestinationOutcome {
        DestinationOutcome.evaluate(failCount: failCount, recoveredCount: recoveredCount, cancelled: cancelled)
    }
}
