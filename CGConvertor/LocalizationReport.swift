import Foundation

/// Texte pentru raportul de conversie și pentru starea metadatelor (RO/EN/ES).
extension L {
    static let reportTable: [String: [AppLanguage: String]] = [
        "report.metadataIncomplete": [.ro: "Videoul e valid, dar metadatele nu au fost păstrate complet.", .en: "The video is valid, but metadata was not fully preserved.", .es: "El vídeo es válido, pero los metadatos no se conservaron por completo."],
        "report.tcFailed": [.ro: "Timecode-ul nu a putut fi scris", .en: "Timecode could not be written", .es: "No se pudo escribir el timecode"],
        "report.tcMismatch": [.ro: "Timecode diferit în rezultat", .en: "Timecode differs in the result", .es: "El timecode del resultado difiere"],
        "report.nativeNeedsMov": [.ro: "Pistele native se păstrează doar în MOV", .en: "Native tracks are kept only in MOV", .es: "Las pistas nativas solo se conservan en MOV"],
        "report.nativeSkipped": [.ro: "Pistele native nu au fost transplantate", .en: "Native tracks were not carried over", .es: "No se trasplantaron las pistas nativas"],
        "report.reasonColorRelabel": [.ro: "ai ales o etichetă de culoare: profilul camerei nu mai descrie imaginea declarată", .en: "a colour label was chosen: the camera profile no longer describes the declared image", .es: "se eligió una etiqueta de color: el perfil de la cámara ya no describe la imagen declarada"],
        "report.reasonFrameRate": [.ro: "cadrele/s au fost schimbate: datele per cadru nu s-ar mai potrivi", .en: "frame rate was changed: per-frame data would no longer match", .es: "se cambió la tasa de fotogramas: los datos por fotograma ya no coincidirían"],
        "report.graftVerify": [.ro: "Verificarea pistei native a eșuat", .en: "Native track verification failed", .es: "Falló la verificación de la pista nativa"],
        "report.graftFailed": [.ro: "Scrierea pistelor native a eșuat", .en: "Writing native tracks failed", .es: "Falló la escritura de las pistas nativas"],
        "report.keptTrack": [.ro: "Pistă nativă păstrată și verificată", .en: "Native track kept and verified", .es: "Pista nativa conservada y verificada"],
        "report.colorTagsNeutral": [.ro: "Etichetele de culoare ale containerului nu afirmă Rec.709 (captura rămâne Log)", .en: "Container colour tags do not claim Rec.709 (capture stays Log)", .es: "Las etiquetas de color del contenedor no afirman Rec.709 (la captura sigue en Log)"],
        "report.keptSidecar": [.ro: "Sidecar .gdc-metadata.json scris lângă rezultat (pentru GDC Metadata / puntea Resolve)", .en: "Sidecar .gdc-metadata.json written next to the result (for GDC Metadata / the Resolve bridge)", .es: "Sidecar .gdc-metadata.json escrito junto al resultado (para GDC Metadata / el puente de Resolve)"],
        "report.sidecarFailed": [.ro: "Sidecar-ul nu a putut fi scris", .en: "The sidecar could not be written", .es: "No se pudo escribir el sidecar"],
        "settings.keepMetadata": [.ro: "Păstrează metadatele", .en: "Keep metadata", .es: "Conservar metadatos"],
        "settings.keepMetadata.help": [.ro: "Timecode și pistele native ale camerei, când imaginea rămâne Log.", .en: "Timecode and the camera's native tracks, when the image stays Log.", .es: "Timecode y pistas nativas de la cámara, cuando la imagen sigue en Log."],
        "settings.exportDiagnostics": [.ro: "Exportă diagnosticul", .en: "Export diagnostics", .es: "Exportar diagnóstico"],
        "settings.openLogs": [.ro: "Deschide folderul de loguri", .en: "Open log folder", .es: "Abrir carpeta de registros"],
        "settings.sessionID": [.ro: "ID sesiune", .en: "Session ID", .es: "ID de sesión"],
        "report.title": [.ro: "Raport conversie", .en: "Conversion report", .es: "Informe de conversión"],
        "report.close": [.ro: "Închide", .en: "Close", .es: "Cerrar"],
        "report.open": [.ro: "Raport", .en: "Report", .es: "Informe"],
        "report.kind.decoded": [.ro: "citit din datele native ale camerei", .en: "read from the camera's native data", .es: "leído de los datos nativos de la cámara"],
        "report.kind.declared": [.ro: "etichetă declarată de producător", .en: "manufacturer-declared label", .es: "etiqueta declarada por el fabricante"],
        "report.kind.computed": [.ro: "dedus dintr-o regulă", .en: "deduced from a rule", .es: "deducido por una regla"],
        "report.kind.user": [.ro: "confirmat manual", .en: "manually confirmed", .es: "confirmado manualmente"],
        "report.field.gamut": [.ro: "Gamut", .en: "Gamut", .es: "Gamut"],
        "report.field.curve": [.ro: "Curbă de transfer", .en: "Transfer curve", .es: "Curva de transferencia"],
        "report.field.camera": [.ro: "Cameră", .en: "Camera", .es: "Cámara"],
        "report.field.lens": [.ro: "Obiectiv", .en: "Lens", .es: "Objetivo"],
        "report.field.focal": [.ro: "Distanță focală", .en: "Focal length", .es: "Distancia focal"],
        "report.field.exposure": [.ro: "Expunere", .en: "Exposure", .es: "Exposición"],
        "report.field.wb": [.ro: "Balans de alb", .en: "White balance", .es: "Balance de blancos"],
        "report.field.profile": [.ro: "Profil sursă", .en: "Source profile", .es: "Perfil de origen"],
        "report.field.timecode": [.ro: "Timecode", .en: "Timecode", .es: "Timecode"],
        "report.field.nativeTrack": [.ro: "Pistă nativă", .en: "Native track", .es: "Pista nativa"],
        "report.field.problem": [.ro: "Problemă metadate", .en: "Metadata problem", .es: "Problema de metadatos"],
        "report.inSidecarOnly": [.ro: "doar în sidecar: se aplică separat (GDC Metadata / punte Resolve)", .en: "sidecar only: applied separately (GDC Metadata / Resolve bridge)", .es: "solo en el sidecar: se aplica por separado (GDC Metadata / puente Resolve)"],
        "report.noProfile": [.ro: "nu s-a putut citi profilul sursei; nu se presupune din model sau nume", .en: "source profile could not be read; nothing is assumed from model or filename", .es: "no se pudo leer el perfil de origen; no se supone por modelo o nombre"],
        "report.tcVerified": [.ro: "scris și recitit din fișierul rezultat", .en: "written and re-read from the output file", .es: "escrito y releído del archivo resultante"],
        "report.state.detected": [.ro: "detectat în sursă", .en: "detected in source", .es: "detectado en el origen"],
        "report.state.embedded": [.ro: "încorporat și verificat", .en: "embedded and verified", .es: "incorporado y verificado"],
        "report.state.separate": [.ro: "necesită aplicare separată", .en: "needs separate application", .es: "requiere aplicación aparte"],
        "report.state.unknown": [.ro: "necunoscut", .en: "unknown", .es: "desconocido"],
        "report.state.notKept": [.ro: "nepăstrat", .en: "not kept", .es: "no conservado"],
        "report.metadataState.off": [.ro: "Păstrarea metadatelor este dezactivată în Setări.", .en: "Metadata preservation is turned off in Settings.", .es: "La conservación de metadatos está desactivada en Ajustes."],
        "report.metadataState.nothingToCarry": [.ro: "Nu exista piste native de păstrat, în afara timecode-ului.", .en: "There were no native tracks to carry besides timecode.", .es: "No había pistas nativas que conservar además del timecode."],
        "report.metadataState.complete": [.ro: "Metadatele cerute au fost scrise și verificate.", .en: "The requested metadata was written and verified.", .es: "Los metadatos solicitados se escribieron y verificaron."],
        "report.metadataState.incomplete": [.ro: "Videoul e valid, dar metadatele nu sunt complete.", .en: "The video is valid, but metadata is incomplete.", .es: "El vídeo es válido, pero los metadatos están incompletos."],
        "report.resolveNote": [.ro: "DaVinci Resolve citește automat doar pistele Canon testate (probe izolate, Resolve 21.2); Sony/Panasonic testate: doar timecode. Aceasta e compatibilitate demonstrată pe probe, nu verificare per clip.", .en: "DaVinci Resolve automatically reads only the tested Canon tracks (isolated probes, Resolve 21.2); tested Sony/Panasonic: timecode only. This is compatibility demonstrated on probes, not per-clip verification.", .es: "DaVinci Resolve lee automáticamente solo las pistas Canon probadas (pruebas aisladas, Resolve 21.2); Sony/Panasonic probadas: solo timecode. Es compatibilidad demostrada en pruebas, no verificación por clip."],
        "interval.title": [.ro: "Interval din clip", .en: "Clip interval", .es: "Intervalo del clip"],
        "interval.start": [.ro: "Început (ex. 00:00:10 sau 10)", .en: "Start (e.g. 00:00:10 or 10)", .es: "Inicio (p. ej. 00:00:10 o 10)"],
        "interval.end": [.ro: "Sfârșit (gol = până la capăt)", .en: "End (empty = to the end)", .es: "Fin (vacío = hasta el final)"],
        "interval.clipLength": [.ro: "Durata clipului", .en: "Clip length", .es: "Duración del clip"],
        "interval.help": [.ro: "Limitele se aliniază la cadre. Imaginea, sunetul și timecode-ul rezultatului pornesc din punctul ales. Disponibil la transcodare, nu la rewrap.", .en: "Limits snap to frames. Picture, audio and timecode of the result start at the chosen point. Available when transcoding, not for rewrap.", .es: "Los límites se ajustan a fotogramas. Imagen, audio y timecode del resultado comienzan en el punto elegido. Disponible al transcodificar, no en rewrap."],
        "interval.invalid": [.ro: "Interval invalid.", .en: "Invalid interval.", .es: "Intervalo no válido."],
        "interval.needsTranscode": [.ro: "Intervalul cere transcodare; rewrap-ul nu taie exact pe cadru.", .en: "An interval needs transcoding; rewrap cannot cut frame-accurately.", .es: "Un intervalo requiere transcodificación; el rewrap no corta con precisión de fotograma."],
        "interval.unreadable": [.ro: "Nu pot citi rata de cadre a sursei pentru interval.", .en: "Cannot read the source frame rate for the interval.", .es: "No se puede leer la tasa de fotogramas del origen."],
        "interval.clear": [.ro: "Clip întreg", .en: "Whole clip", .es: "Clip completo"],
        "interval.cancel": [.ro: "Renunță", .en: "Cancel", .es: "Cancelar"],
        "interval.apply": [.ro: "Aplică", .en: "Apply", .es: "Aplicar"],
        "report.keptTimecode": [.ro: "Timecode păstrat", .en: "Timecode kept", .es: "Timecode conservado"],
    ]
}

extension ConversionReport.Line {
    /// Text localizat; argumentul se traduce dacă e el însuși o cheie.
    var text: String {
        let a = L.reportTable[arg] != nil ? L.t(arg) : arg
        return a.isEmpty ? L.t(key) : "\(L.t(key)): \(a)"
    }
}
