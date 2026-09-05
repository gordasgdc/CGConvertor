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
        "codec.hint.h264": [.ro: "Livrare compatibilă universal (YouTube, Vimeo, web, telefoane). Cu accelerare VideoToolbox.",
                             .en: "Universally compatible delivery (YouTube, Vimeo, web, phones). Uses VideoToolbox acceleration.",
                             .es: "Entrega compatible universalmente (YouTube, Vimeo, web, teléfonos). Usa aceleración VideoToolbox."],
        "codec.hint.hevc10": [.ro: "Master de livrare 10-bit, fișier mult mai mic decât ProRes la calitate similară. Necesită playere/aplicații compatibile HEVC.",
                               .en: "10-bit delivery master, much smaller than ProRes at similar quality. Needs HEVC-compatible players/apps.",
                               .es: "Master de entrega de 10 bits, mucho más pequeño que ProRes con calidad similar. Necesita reproductores/apps compatibles con HEVC."],
        "codec.hint.av1": [.ro: "Cea mai bună compresie pentru web modern, dar cea mai lentă la encodare — software, fără accelerare VideoToolbox pe niciun Mac.",
                            .en: "Best compression for modern web, but slowest to encode — software only, no VideoToolbox acceleration on any Mac.",
                            .es: "La mejor compresión para la web moderna, pero la más lenta de codificar — software, sin aceleración VideoToolbox en ningún Mac."],
        "codec.hint.uncompressed": [.ro: "Fără nicio compresie — fișiere foarte mari, doar pentru arhivare sau schimb cu sisteme care nu acceptă altceva.",
                                     .en: "No compression at all — very large files, only for archiving or exchange with systems that accept nothing else.",
                                     .es: "Sin ninguna compresión — archivos muy grandes, solo para archivado o intercambio con sistemas que no aceptan otra cosa."],

        // MARK: - Faza 1 v3.0.0 — Presets Manager, sidebar, pauză, Setări

        "preset.title": [.ro: "Preset de ieșire", .en: "Output preset", .es: "Preset de salida"],
        "preset.edit": [.ro: "Editează presets…", .en: "Edit presets…", .es: "Editar presets…"],
        "gpu.accel.prefix": [.ro: "Accelerare:", .en: "Acceleration:", .es: "Aceleración:"],
        "pause.action": [.ro: "Pauză", .en: "Pause", .es: "Pausar"],
        "resume.action": [.ro: "Reluare", .en: "Resume", .es: "Reanudar"],
        "queue.moveUp": [.ro: "Mută sus", .en: "Move up", .es: "Subir"],
        "queue.moveDown": [.ro: "Mută jos", .en: "Move down", .es: "Bajar"],
        "sidebar.anonymous": [.ro: "Anonim", .en: "Anonymous", .es: "Anónimo"],
        "sidebar.machineID": [.ro: "ID mașină", .en: "Machine ID", .es: "ID de máquina"],
        "sidebar.settings": [.ro: "Setări", .en: "Settings", .es: "Ajustes"],
        "license.revoked": [.ro: "Licența a fost revocată — contactează suportul prin WhatsApp.",
                             .en: "Your license has been revoked — contact support via WhatsApp.",
                             .es: "Tu licencia ha sido revocada — contacta con soporte por WhatsApp."],

        "presets.new": [.ro: "Preset nou", .en: "New preset", .es: "Preset nuevo"],
        "presets.duplicate": [.ro: "Duplică", .en: "Duplicate", .es: "Duplicar"],
        "presets.delete": [.ro: "Șterge", .en: "Delete", .es: "Eliminar"],
        "presets.import": [.ro: "Importă…", .en: "Import…", .es: "Importar…"],
        "presets.export": [.ro: "Exportă…", .en: "Export…", .es: "Exportar…"],
        "presets.targetApp": [.ro: "Aplicație țintă", .en: "Target app", .es: "Aplicación de destino"],
        "presets.profile": [.ro: "Codec / profil", .en: "Codec / profile", .es: "Códec / perfil"],
        "presets.audioMode": [.ro: "Mod audio", .en: "Audio mode", .es: "Modo de audio"],
        "presets.channels": [.ro: "Canale", .en: "Channels", .es: "Canales"],
        "presets.suffix": [.ro: "Sufix nume fișier", .en: "Filename suffix", .es: "Sufijo del nombre de archivo"],
        "presets.label": [.ro: "Nume preset", .en: "Preset name", .es: "Nombre del preset"],
        "presets.close": [.ro: "Închide", .en: "Close", .es: "Cerrar"],
        "presets.builtinHint": [.ro: "Presetările implicite nu se pot edita direct — duplică-le mai întâi.",
                                 .en: "Built-in presets can't be edited directly — duplicate one first.",
                                 .es: "Los presets integrados no se pueden editar directamente — duplícalos primero."],

        "audio.passthrough": [.ro: "Passthrough (păstrează originalul)", .en: "Passthrough (keep original)", .es: "Passthrough (mantener original)"],
        "audio.pcm16": [.ro: "Re-encode PCM 16-bit", .en: "Re-encode PCM 16-bit", .es: "Recodificar PCM 16-bit"],
        "audio.pcm24": [.ro: "Re-encode PCM 24-bit", .en: "Re-encode PCM 24-bit", .es: "Recodificar PCM 24-bit"],
        "audio.aac": [.ro: "Re-encode AAC", .en: "Re-encode AAC", .es: "Recodificar AAC"],
        "channel.original": [.ro: "Păstrează originalul", .en: "Keep original", .es: "Mantener original"],
        "channel.stereo": [.ro: "Stereo", .en: "Stereo", .es: "Estéreo"],
        "channel.51": [.ro: "5.1", .en: "5.1", .es: "5.1"],
        "targetApp.davinci": [.ro: "DaVinci Resolve", .en: "DaVinci Resolve", .es: "DaVinci Resolve"],
        "targetApp.premiere": [.ro: "Premiere Pro", .en: "Premiere Pro", .es: "Premiere Pro"],
        "targetApp.fcp": [.ro: "Final Cut Pro", .en: "Final Cut Pro", .es: "Final Cut Pro"],
        "targetApp.avid": [.ro: "Avid Media Composer", .en: "Avid Media Composer", .es: "Avid Media Composer"],
        "targetApp.web": [.ro: "Web / Social", .en: "Web / Social", .es: "Web / Redes sociales"],
        "targetApp.custom": [.ro: "Personalizat", .en: "Custom", .es: "Personalizado"],

        "settings.theme": [.ro: "Temă", .en: "Theme", .es: "Tema"],
        "settings.theme.system": [.ro: "Sistem", .en: "System", .es: "Sistema"],
        "settings.theme.dark": [.ro: "Dark", .en: "Dark", .es: "Oscuro"],
        "settings.theme.light": [.ro: "Light", .en: "Light", .es: "Claro"],
        "settings.fontSize": [.ro: "Mărime text", .en: "Text size", .es: "Tamaño de texto"],
        "settings.font.small": [.ro: "Mic", .en: "Small", .es: "Pequeño"],
        "settings.font.normal": [.ro: "Normal", .en: "Normal", .es: "Normal"],
        "settings.font.large": [.ro: "Mare", .en: "Large", .es: "Grande"],
        "settings.font.xlarge": [.ro: "Foarte mare", .en: "Extra large", .es: "Muy grande"],
        "settings.parallelJobs": [.ro: "Joburi simultane", .en: "Simultaneous jobs", .es: "Trabajos simultáneos"],
        "settings.userName": [.ro: "Nume", .en: "Name", .es: "Nombre"],
        "settings.userEmail": [.ro: "Email", .en: "Email", .es: "Email"],
        "settings.save": [.ro: "Salvează", .en: "Save", .es: "Guardar"],

        "destination.title": [.ro: "Folder destinație", .en: "Destination folder", .es: "Carpeta de destino"],
        "destination.sameAsSource": [.ro: "La fel ca sursa", .en: "Same as source", .es: "Igual que la fuente"],
        "destination.choose": [.ro: "Alege folder…", .en: "Choose folder…", .es: "Elegir carpeta…"],

        "queue.empty.title": [.ro: "Trage fișiere video aici", .en: "Drag video files here", .es: "Arrastra archivos de vídeo aquí"],
        "queue.empty.or": [.ro: "sau", .en: "or", .es: "o"],
        "queue.chooseFiles": [.ro: "Alege fișiere…", .en: "Choose files…", .es: "Elegir archivos…"],
        "queue.clear": [.ro: "Golește lista", .en: "Clear list", .es: "Vaciar lista"],
        "queue.addFiles": [.ro: "Adaugă fișiere…", .en: "Add files…", .es: "Añadir archivos…"],
        "queue.report": [.ro: "Generează raport", .en: "Generate report", .es: "Generar informe"],
        "queue.status.waiting": [.ro: "În așteptare", .en: "Waiting", .es: "En espera"],
        "queue.status.done": [.ro: "Finalizat", .en: "Done", .es: "Completado"],
        "queue.status.canceled": [.ro: "Anulat", .en: "Canceled", .es: "Cancelado"],
        "queue.status.integrityWarning": [.ro: "Finalizat — verificare durată eșuată", .en: "Done — duration check failed", .es: "Completado — verificación de duración fallida"],
        "queue.integrityMismatch": [.ro: "durata sursă %.1fs vs. rezultat %.1fs — posibilă trunchiere", .en: "source duration %.1fs vs. output %.1fs — possible truncation", .es: "duración origen %.1fs vs. salida %.1fs — posible truncamiento"],

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

        // MARK: - Dependency Manager

        "deps.badge.ok": [.ro: "Sistem pregătit", .en: "System ready", .es: "Sistema listo"],
        "deps.badge.missing": [.ro: "Dependențe lipsă", .en: "Missing dependencies", .es: "Dependencias faltantes"],
        "deps.panel.title": [.ro: "Verificare & Dependențe Sistem", .en: "System Check & Dependencies", .es: "Verificación y dependencias del sistema"],
        "deps.panel.subtitle": [.ro: "Fiecare componentă se testează independent — instalezi doar ce ai nevoie, când ai nevoie.",
                                 .en: "Each component is tested independently — install only what you need, when you need it.",
                                 .es: "Cada componente se comprueba de forma independiente — instala solo lo que necesites, cuando lo necesites."],
        "deps.refresh": [.ro: "Reverifică", .en: "Recheck", .es: "Volver a comprobar"],
        "deps.close": [.ro: "Închide", .en: "Close", .es: "Cerrar"],
        "deps.state.ok": [.ro: "Activ (static)", .en: "Active (static)", .es: "Activo (estático)"],
        "deps.state.missing": [.ro: "Inactiv / lipsă", .en: "Inactive / missing", .es: "Inactivo / faltante"],
        "deps.state.optionalMissing": [.ro: "Opțional — neinstalat", .en: "Optional — not installed", .es: "Opcional — no instalado"],
        "deps.state.checking": [.ro: "Se verifică…", .en: "Checking…", .es: "Comprobando…"],
        "deps.ffmpeg.hint": [.ro: "Motorul de conversie video (transcode + rewrap). Obligatoriu pentru a folosi aplicația.",
                              .en: "The video conversion engine (transcode + rewrap). Required to use the app.",
                              .es: "El motor de conversión de vídeo (transcode y rewrap). Obligatorio para usar la app."],
        "deps.ffmpeg.install": [.ro: "Descarcă & Instalează Automat", .en: "Download & Install Automatically", .es: "Descargar e instalar automáticamente"],
        "deps.ffmpeg.downloading": [.ro: "Se descarcă…", .en: "Downloading…", .es: "Descargando…"],
        "deps.homebrew.hint": [.ro: "Recomandat pentru un mediu de dezvoltare Mac complet — nu e necesar pentru conversii.",
                                .en: "Recommended for a full Mac development environment — not required for conversions.",
                                .es: "Recomendado para un entorno de desarrollo Mac completo — no es necesario para las conversiones."],
        "deps.homebrew.copy": [.ro: "Copiază comanda de instalare", .en: "Copy install command", .es: "Copiar comando de instalación"],
        "deps.homebrew.copied": [.ro: "Comanda copiată! Lipește-o în Terminal.", .en: "Command copied! Paste it into Terminal.", .es: "¡Comando copiado! Pégalo en Terminal."],
        "deps.homebrew.openSite": [.ro: "Deschide brew.sh", .en: "Open brew.sh", .es: "Abrir brew.sh"],
        "deps.error.title": [.ro: "Instalarea a eșuat", .en: "Install failed", .es: "La instalación falló"],

        // MARK: - Post-conversie

        "job.openFile": [.ro: "Deschide fișierul", .en: "Open file", .es: "Abrir archivo"],
        "job.showInFinder": [.ro: "Arată în Finder", .en: "Show in Finder", .es: "Mostrar en Finder"],
        "update.upToDate.title": [.ro: "Ești la zi", .en: "You're up to date", .es: "Estás al día"],
        "update.upToDate.body": [.ro: "Rulezi deja ultima versiune (%@).", .en: "You're already running the latest version (%@).", .es: "Ya tienes la última versión (%@)."],
        "update.available.title": [.ro: "Este disponibilă o versiune nouă", .en: "A new version is available", .es: "Hay una nueva versión disponible"],
        "update.available.body": [.ro: "CG Convertor %@ este disponibil (tu ai %@). Apasă „Actualizează acum” pentru a descărca și instala automat.",
                                   .en: "CG Convertor %@ is available (you have %@). Tap “Update now” to download and install automatically.",
                                   .es: "CG Convertor %@ está disponible (tienes %@). Pulsa «Actualizar ahora» para descargar e instalar automáticamente."],
        "update.download": [.ro: "Actualizează acum", .en: "Update now", .es: "Actualizar ahora"],
        "update.later": [.ro: "Mai târziu", .en: "Later", .es: "Más tarde"],
        "update.error.title": [.ro: "Verificarea a eșuat", .en: "Check failed", .es: "La comprobación falló"],
        "update.error.body": [.ro: "Nu am putut verifica actualizările — verifică conexiunea la internet.", .en: "Couldn't check for updates — check your internet connection.", .es: "No se pudieron buscar actualizaciones — comprueba tu conexión a internet."],

        // MARK: - Offload/Checksum (Faza 2)

        "mainMode.convert": [.ro: "Convertor", .en: "Converter", .es: "Convertidor"],
        "mainMode.offload": [.ro: "Offload", .en: "Offload", .es: "Offload"],
        "offload.source": [.ro: "Sursă (card)", .en: "Source (card)", .es: "Origen (tarjeta)"],
        "offload.source.choose": [.ro: "Alege sursa…", .en: "Choose source…", .es: "Elegir origen…"],
        "offload.destinations": [.ro: "Destinații", .en: "Destinations", .es: "Destinos"],
        "offload.destinations.add": [.ro: "Adaugă destinație…", .en: "Add destination…", .es: "Añadir destino…"],
        "offload.destinations.empty": [.ro: "Nicio destinație adăugată încă", .en: "No destination added yet", .es: "Aún no se ha añadido ningún destino"],
        "offload.verify.title": [.ro: "Verificare", .en: "Verification", .es: "Verificación"],
        "offload.verify.recommended": [.ro: "recomandat", .en: "recommended", .es: "recomendado"],
        "offload.verify.sizeOnly": [.ro: "Doar mărime (fără hash)", .en: "Size only (no hash)", .es: "Solo tamaño (sin hash)"],
        "offload.io.title": [.ro: "Buffer & Memorie", .en: "Buffer & Memory", .es: "Búfer y memoria"],
        "offload.io.buffer": [.ro: "Buffer citire/scriere", .en: "Read/write buffer", .es: "Búfer de lectura/escritura"],
        "offload.io.ramLimit": [.ro: "Plafon memorie", .en: "Memory ceiling", .es: "Límite de memoria"],
        "offload.start": [.ro: "Pornește Offload", .en: "Start Offload", .es: "Iniciar Offload"],
        "offload.pause": [.ro: "Pauză", .en: "Pause", .es: "Pausar"],
        "offload.resume": [.ro: "Continuă", .en: "Resume", .es: "Reanudar"],
        "offload.cancel": [.ro: "Anulează", .en: "Cancel", .es: "Cancelar"],
        "offload.activity.title": [.ro: "Activitate", .en: "Activity", .es: "Actividad"],
        "offload.results.title": [.ro: "Rezultat", .en: "Result", .es: "Resultado"],
        "offload.results.row": [.ro: "%@ — OK: %d · Nepotriviri: %d · Erori: %d", .en: "%@ — OK: %d · Mismatches: %d · Errors: %d", .es: "%@ — OK: %d · Discrepancias: %d · Errores: %d"],
        "offload.results.openReport": [.ro: "Arată raportul CSV", .en: "Show CSV report", .es: "Mostrar informe CSV"],
        "offload.status.noFiles": [.ro: "Sursa nu conține fișiere de copiat.", .en: "Source contains no files to copy.", .es: "El origen no contiene archivos para copiar."],
        "offload.status.running": [.ro: "Copiez %d fișiere către %d destinații…", .en: "Copying %d files to %d destinations…", .es: "Copiando %d archivos a %d destinos…"],
        "offload.status.cancelling": [.ro: "Se anulează…", .en: "Cancelling…", .es: "Cancelando…"],
        "offload.status.cancelled": [.ro: "Anulat.", .en: "Cancelled.", .es: "Cancelado."],
        "offload.status.done": [.ro: "Gata — OK: %d · Nepotriviri: %d · Erori: %d", .en: "Done — OK: %d · Mismatches: %d · Errors: %d", .es: "Listo — OK: %d · Discrepancias: %d · Errores: %d"],
        "offload.log.mismatch": [.ro: "NEPOTRIVIRE la verificare: %@", .en: "Verification MISMATCH: %@", .es: "DISCREPANCIA de verificación: %@"],
        "offload.log.error": [.ro: "Eroare la %@: %@", .en: "Error on %@: %@", .es: "Error en %@: %@"],
        "offload.log.permError": [.ro: "Permisiune refuzată la %@: %@ — verifică Full Disk Access în Preferințe Sistem.", .en: "Permission denied on %@: %@ — check Full Disk Access in System Settings.", .es: "Permiso denegado en %@: %@ — revisa Acceso completo al disco en Preferencias del Sistema."],
        "offload.log.ramWait": [.ro: "Memoria a depășit plafonul — aștept să scadă…", .en: "Memory exceeded the ceiling — waiting for it to drop…", .es: "La memoria superó el límite — esperando a que baje…"],

        // MARK: - Watch Folders (Faza 2)

        "watchFolders.title": [.ro: "Foldere urmărite", .en: "Watch Folders", .es: "Carpetas vigiladas"],
        "watchFolders.empty": [.ro: "Niciun folder urmărit", .en: "No folder watched", .es: "Ninguna carpeta vigilada"],
        "watchFolders.add": [.ro: "Adaugă folder…", .en: "Add folder…", .es: "Añadir carpeta…"],

        // MARK: - Preview interactiv (Faza 2, versiune redusă a playerului LUT/LOG)

        "preview.noLut": [.ro: "Fără LUT", .en: "No LUT", .es: "Sin LUT"],
        "preview.chooseLut": [.ro: "Alege LUT…", .en: "Choose LUT…", .es: "Elegir LUT…"],
        "preview.clearLut": [.ro: "Elimină", .en: "Clear", .es: "Quitar"],
    ]
}
