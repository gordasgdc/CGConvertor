import Foundation

enum StareJob: Equatable {
    case astept
    case inLucru(progres: Double)
    case finalizat
    /// FFmpeg a raportat succes (cod ieșire 0), dar durata fișierului
    /// rezultat NU corespunde cu durata sursei (peste toleranța admisă) —
    /// semn posibil de trunchiere/corupere silențioasă. Vezi
    /// `ConvertorViewModel.verificaIntegritate(...)`.
    case finalizatCuAvertisment(mesaj: String)
    case anulat
    case eroare(mesaj: String)
}

// [ISTORIC, Faza 1 v3.0.0] `ModConversie`/`CodecOutput` (Mod fix
// Rewrap/Transcode + 6 codecuri hardcodate) au fost înlocuite complet de
// `OutputPreset`/`FormatRegistry.swift` (Presets Manager) — vezi
// PresetsManager.swift. Modul "Rewrap" trăiește acum ca
// `FormatRegistry.rewrapProfileID`, un sentinel verificat direct în
// `MotorFFmpeg.construiesteArgumente`.

struct VideoJob: Identifiable, Equatable {
    let id = UUID()
    let urlSursa: URL
    var urlDestinatie: URL?
    var stare: StareJob = .astept

    // Inspecție/Metadata (Faza 2) — completate asincron, în fundal, imediat
    // după adăugarea fișierului în coadă (vezi ConvertorViewModel.adaugaFisiere
    // și MediaInspector.swift). `nil` până se termină analiza (sau dacă a eșuat).
    var metadataMedia: MediaMetadata?
    var caleThumbnail: String?
    /// Raport complet al ultimei conversii (imagine/audio/timecode/metadate).
    var raport: ConversionReport?
    /// Interval ales din sursă (secunde, linia de timp a clipului); nil = clipul întreg.
    var intervalStart: Double?
    var intervalEnd: Double?
    var areInterval: Bool { intervalStart != nil || intervalEnd != nil }

    // Configurare per clip (spațiul Transcodare). nil = se folosește valoarea implicită din inspector.
    /// Preset ales explicit pentru acest clip.
    var presetOverrideID: String?
    /// Folder de destinație ales explicit pentru acest clip.
    var destinatieOverride: URL?
    /// Sufix de denumire ales explicit pentru acest clip.
    var sufixOverride: String?
    /// Marcat pentru procesare (butonul principal convertește clipurile marcate).
    var marcat = true
    /// Profil citit prin nucleul GDC Metadata (spațiul Metadate), pe cerere.
    var profilSursa: SourceProfile?
    var scanTerminat = false

    var numeFisier: String {
        urlSursa.lastPathComponent
    }

    static func == (lhs: VideoJob, rhs: VideoJob) -> Bool {
        // Compară și starea vizibilă: altfel SwiftUI nu redesenează rândurile când se schimbă progresul, profilul etc.
        lhs.id == rhs.id && lhs.stare == rhs.stare && lhs.caleThumbnail == rhs.caleThumbnail
            && lhs.metadataMedia == rhs.metadataMedia && lhs.profilSursa == rhs.profilSursa && lhs.scanTerminat == rhs.scanTerminat
            && lhs.raport == rhs.raport && lhs.urlDestinatie == rhs.urlDestinatie
            && lhs.intervalStart == rhs.intervalStart && lhs.intervalEnd == rhs.intervalEnd
            && lhs.presetOverrideID == rhs.presetOverrideID && lhs.destinatieOverride == rhs.destinatieOverride
            && lhs.sufixOverride == rhs.sufixOverride && lhs.marcat == rhs.marcat
    }
}
