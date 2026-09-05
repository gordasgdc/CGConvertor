import Foundation

enum StareJob: Equatable {
    case astept
    case inLucru(progres: Double)
    case finalizat
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

    var numeFisier: String {
        urlSursa.lastPathComponent
    }

    static func == (lhs: VideoJob, rhs: VideoJob) -> Bool {
        lhs.id == rhs.id
    }
}
