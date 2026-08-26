import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case ro, en, es
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .ro: return "Română"
        case .en: return "English"
        case .es: return "Español"
        }
    }
}

/// Tabel mic de traduceri, independent de locale-ul sistemului — același
/// tipar RO-implicit / EN / ES folosit în restul ecosistemului GDC.
/// Persistat via UserDefaults, ca alegerea să rămână între lansări.
enum L {
    static var current: AppLanguage {
        get {
            if let raw = UserDefaults.standard.string(forKey: "cgconvertor_lang"),
               let lang = AppLanguage(rawValue: raw) {
                return lang
            }
            return .ro
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "cgconvertor_lang") }
    }

    static func t(_ key: String) -> String {
        table[key]?[current] ?? table[key]?[.ro] ?? key
    }

    private static let table: [String: [AppLanguage: String]] = [
        "app.title": [.ro: "CG Convertor", .en: "CG Convertor", .es: "CG Convertor"],
        "app.subtitle": [.ro: "Transcode & Rewrap pentru DaVinci Resolve", .en: "Transcode & Rewrap for DaVinci Resolve", .es: "Transcode y Rewrap para DaVinci Resolve"],

        "mode.title": [.ro: "Mod conversie", .en: "Conversion mode", .es: "Modo de conversión"],
        "mode.rewrap": [.ro: "Rewrap", .en: "Rewrap", .es: "Rewrap"],
        "mode.rewrap.hint": [.ro: "Rapid, fără re-encode", .en: "Fast, no re-encode", .es: "Rápido, sin re-codificación"],
        "mode.transcode": [.ro: "Transcode", .en: "Transcode", .es: "Transcodificar"],
        "mode.transcode.hint": [.ro: "Re-encode complet", .en: "Full re-encode", .es: "Re-codificación completa"],

        "codec.title": [.ro: "Codec output", .en: "Output codec", .es: "Codec de salida"],
        "codec.hint.proRes422": [.ro: "Recomandat pentru surse 4:2:0 (HEVC, H.264, majoritatea camerelor consumer/mirrorless). Păstrează tot detaliul sursei fără să umfle fișierul inutil.",
                                  .en: "Recommended for 4:2:0 sources (HEVC, H.264, most consumer/mirrorless cameras). Keeps all the source detail without bloating the file.",
                                  .es: "Recomendado para fuentes 4:2:0 (HEVC, H.264, la mayoría de cámaras consumer/mirrorless). Conserva todo el detalle de la fuente sin inflar el archivo."],
        "codec.hint.proRes422HQ": [.ro: "Recomandat pentru surse deja 4:2:2 (ProRes, DNxHD, camere broadcast/cinema). Pe surse 4:2:0 nu aduce calitate suplimentară.",
                                    .en: "Recommended for sources already 4:2:2 (ProRes, DNxHD, broadcast/cinema cameras). Adds no extra quality on 4:2:0 sources.",
                                    .es: "Recomendado para fuentes ya 4:2:2 (ProRes, DNxHD, cámaras broadcast/cine). No añade calidad extra en fuentes 4:2:0."],
        "codec.hint.proRes422LT": [.ro: "Bitrate redus, pentru proxy-uri sau preview rapid. Nerecomandat pentru grading final.",
                                    .en: "Lower bitrate, for proxies or quick preview. Not recommended for final grading.",
                                    .es: "Bitrate reducido, para proxies o vista previa rápida. No recomendado para el grading final."],
        "codec.hint.proRes4444": [.ro: "Doar pentru surse 4:4:4 native sau cu canal alpha. Pe o sursă 4:2:0 nu adaugă informație reală.",
                                   .en: "Only for native 4:4:4 sources or with an alpha channel. On a 4:2:0 source it adds no real information.",
                                   .es: "Solo para fuentes 4:4:4 nativas o con canal alfa. En una fuente 4:2:0 no añade información real."],
        "codec.hint.dnx": [.ro: "Alternativa Avid la ProRes. Folosește dacă lucrezi și în Media Composer.",
                            .en: "Avid's alternative to ProRes. Use if you also work in Media Composer.",
                            .es: "La alternativa de Avid a ProRes. Úsalo si también trabajas en Media Composer."],

        "destination.title": [.ro: "Folder destinație", .en: "Destination folder", .es: "Carpeta de destino"],
        "destination.sameAsSource": [.ro: "La fel ca sursa", .en: "Same as source", .es: "Igual que la fuente"],
        "destination.choose": [.ro: "Alege folder…", .en: "Choose folder…", .es: "Elegir carpeta…"],

        "queue.empty.title": [.ro: "Trage fișiere video aici", .en: "Drag video files here", .es: "Arrastra archivos de vídeo aquí"],
        "queue.empty.or": [.ro: "sau", .en: "or", .es: "o"],
        "queue.chooseFiles": [.ro: "Alege fișiere…", .en: "Choose files…", .es: "Elegir archivos…"],
        "queue.clear": [.ro: "Golește lista", .en: "Clear list", .es: "Vaciar lista"],
        "queue.addFiles": [.ro: "Adaugă fișiere…", .en: "Add files…", .es: "Añadir archivos…"],
        "queue.status.waiting": [.ro: "În așteptare", .en: "Waiting", .es: "En espera"],
        "queue.status.done": [.ro: "Finalizat", .en: "Done", .es: "Completado"],
        "queue.status.canceled": [.ro: "Anulat", .en: "Canceled", .es: "Cancelado"],

        "action.start": [.ro: "Pornește conversia", .en: "Start conversion", .es: "Iniciar conversión"],
        "action.stop": [.ro: "Oprește", .en: "Stop", .es: "Detener"],
        "action.processing": [.ro: "Se procesează…", .en: "Processing…", .es: "Procesando…"],

        "ffmpeg.missing": [.ro: "FFmpeg nu este instalat. Deschide Terminal și rulează:", .en: "FFmpeg isn't installed. Open Terminal and run:", .es: "FFmpeg no está instalado. Abre Terminal y ejecuta:"],
        "ffmpeg.recheck": [.ro: "Reverifică", .en: "Recheck", .es: "Volver a comprobar"],

        "shortcuts.hint": [.ro: "⌘O Adaugă · ⏎ Pornește · ⌘⌫ Șterge · ⌘K Golește", .en: "⌘O Add · ⏎ Start · ⌘⌫ Delete · ⌘K Clear", .es: "⌘O Añadir · ⏎ Iniciar · ⌘⌫ Eliminar · ⌘K Vaciar"],

        // MARK: - License / Trial

        "trial.daysLeft": [.ro: "Probă gratuită — %d zile rămase", .en: "Free trial — %d days left", .es: "Prueba gratuita — %d días restantes"],
        "trial.expired": [.ro: "Proba a expirat — activează licența ca să continui conversiile", .en: "Trial expired — activate your license to keep converting", .es: "La prueba ha caducado — activa tu licencia para seguir convirtiendo"],
        "trial.activate": [.ro: "Activează licența", .en: "Activate license", .es: "Activar licencia"],

        "license.title": [.ro: "Activează CG Convertor", .en: "Activate CG Convertor", .es: "Activar CG Convertor"],
        "license.machineID": [.ro: "ID calculator", .en: "Computer ID", .es: "ID del ordenador"],
        "license.copy": [.ro: "Copiază", .en: "Copy", .es: "Copiar"],
        "license.copied": [.ro: "Copiat", .en: "Copied", .es: "Copiado"],
        "license.codePlaceholder": [.ro: "Cod de activare", .en: "Activation code", .es: "Código de activación"],
        "license.note": [.ro: "Donație de 23 € pentru continuarea dezvoltării aplicației și a platformei — nu un preț de listă, nu o vânzare. Se activează după cele 15 zile de probă gratuită.",
                          .en: "A €23 donation to support ongoing development of the app and the platform — not a list price, not a sale. Applies after the 15-day free trial.",
                          .es: "Una donación de 23 € para apoyar el desarrollo continuo de la app y la plataforma — no un precio de lista, no una venta. Se activa tras los 15 días de prueba gratuita."],
        "license.whatsapp": [.ro: "Scrie-mi pe WhatsApp", .en: "Message me on WhatsApp", .es: "Escríbeme por WhatsApp"],
        "license.cancel": [.ro: "Anulează", .en: "Cancel", .es: "Cancelar"],
        "license.activate": [.ro: "Activează", .en: "Activate", .es: "Activar"],
        "license.error.malformed": [.ro: "Cod invalid — verifică să nu lipsească vreun caracter.", .en: "Invalid code — check that nothing's missing.", .es: "Código no válido — comprueba que no falte nada."],
        "license.error.badSignature": [.ro: "Semnătura codului nu se potrivește.", .en: "The code's signature doesn't match.", .es: "La firma del código no coincide."],
        "license.error.wrongProduct": [.ro: "Codul e valid, dar pentru alt produs GDC.", .en: "The code is valid, but for a different GDC product.", .es: "El código es válido, pero para otro producto GDC."],
        "license.error.wrongMachine": [.ro: "Codul e blocat pe alt calculator.", .en: "The code is locked to a different computer.", .es: "El código está bloqueado en otro ordenador."],
        "license.error.expired": [.ro: "Codul a expirat.", .en: "The code has expired.", .es: "El código ha caducado."],

        // MARK: - Menu / About / Updates

        "menu.about": [.ro: "Despre CG Convertor", .en: "About CG Convertor", .es: "Acerca de CG Convertor"],
        "menu.checkForUpdates": [.ro: "Caută actualizări…", .en: "Check for Updates…", .es: "Buscar actualizaciones…"],
        "update.upToDate.title": [.ro: "Ești la zi", .en: "You're up to date", .es: "Estás al día"],
        "update.upToDate.body": [.ro: "Rulezi deja ultima versiune (%@).", .en: "You're already running the latest version (%@).", .es: "Ya tienes la última versión (%@)."],
        "update.available.title": [.ro: "Este disponibilă o versiune nouă", .en: "A new version is available", .es: "Hay una nueva versión disponible"],
        "update.available.body": [.ro: "CG Convertor %@ este disponibil (tu ai %@). Te rugăm să descarci ultimul installer și să îl instalezi peste versiunea actuală.",
                                   .en: "CG Convertor %@ is available (you have %@). Please download the latest installer and install it over your current version.",
                                   .es: "CG Convertor %@ está disponible (tienes %@). Descarga el último instalador e instálalo sobre tu versión actual."],
        "update.download": [.ro: "Descarcă", .en: "Download", .es: "Descargar"],
        "update.later": [.ro: "Mai târziu", .en: "Later", .es: "Más tarde"],
        "update.error.title": [.ro: "Verificarea a eșuat", .en: "Check failed", .es: "La comprobación falló"],
        "update.error.body": [.ro: "Nu am putut verifica actualizările — verifică conexiunea la internet.", .en: "Couldn't check for updates — check your internet connection.", .es: "No se pudieron buscar actualizaciones — comprueba tu conexión a internet."],
    ]
}
