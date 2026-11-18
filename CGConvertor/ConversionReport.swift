import Foundation

/// Rezultatul complet al unei conversii, separat pentru imagine/audio/timecode
/// și pentru metadate. Alimentează interfața (ce s-a păstrat, ce nu) fără ca
/// aceasta să deducă nimic din textul erorilor.
struct ConversionReport: Equatable {
    /// O linie de raport: cheie de localizare + argument liber (nume pistă, motiv tehnic).
    struct Line: Equatable { let key: String; let arg: String }

    enum MetadataState: Equatable {
        /// Utilizatorul a dezactivat păstrarea metadatelor.
        case off
        /// Nu era nimic de păstrat peste timecode (ex. sursă fără piste native).
        case nothingToCarry
        /// Toate piesele cerute au fost scrise ȘI verificate.
        case complete
        /// Scrierea/verificarea a eșuat sau a fost omisă; fișierul video e valid.
        case incomplete
    }

    var sourceProfile: SourceProfile?
    var timecodeSource: String?
    var timecodeOutput: String?
    var grafted: [GraftedTrack] = []
    /// Ce s-a păstrat (cheie localizabilă + argument).
    var kept: [Line] = []
    /// Ce NU s-a păstrat, cu motiv.
    var notKept: [Line] = []
    /// Probleme de metadate (distincte de erorile de transcodare).
    var metadataProblems: [Line] = []
    var metadata: MetadataState = .off
    /// Rezumat măsurat al verificării imaginii/audio.
    var framesSource: Int?
    var framesOutput: Int?
    var audioStreamsSource = 0
    var audioStreamsOutput = 0
    var durationSource: Double?
    var durationOutput: Double?
    /// Interval extras (cadre sursă), când nu s-a convertit clipul întreg.
    struct Interval: Equatable { let startFrame: Int; let frames: Int; let fps: Double }
    var interval: Interval?
}

enum EroareConversie: LocalizedError {
    case verificareEsuata(String)

    var errorDescription: String? {
        switch self {
        case .verificareEsuata(let m): return m
        }
    }
}
