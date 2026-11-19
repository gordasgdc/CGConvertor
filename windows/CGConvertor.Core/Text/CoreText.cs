using System.Text.RegularExpressions;

namespace CGConvertor.Core;

/// Traducerea textelor produse de nucleu și afișate utilizatorului (stare, erori, descrieri de dispozitiv).
/// Nucleul scrie în română (sursa unică); clientul trece fiecare text afișat prin `Tr`. Șabloanele cu {0}, {1}
/// se potrivesc și textelor interpolate. Un text necunoscut rămâne neschimbat (nu se inventează traduceri).
public static class CoreText
{
    public static string Lang { get; set; } = "ro";

    static readonly (string Ro, string En, string Es)[] Table =
    {
        // dispozitive
        ("intern", "internal", "interno"), ("rețea", "network", "red"), ("virtual", "virtual", "virtual"), ("cititor SD", "SD reader", "lector SD"),
        ("Card foto/video (DCIM)", "Photo/video card (DCIM)", "Tarjeta foto/vídeo (DCIM)"), ("Card video (PRIVATE)", "Video card (PRIVATE)", "Tarjeta de vídeo (PRIVATE)"),
        ("{0} — {1} clip(uri)", "{0} — {1} clips", "{0} — {1} clips"),
        ("Cardul pare gol — nu s-a găsit niciun fișier media.", "The card looks empty — no media file was found.", "La tarjeta parece vacía: no se encontró ningún archivo multimedia."),
        // transcodare
        ("Intervalul cere transcodare (rewrap nu taie exact pe cadru).", "An interval needs transcoding (rewrap cannot cut on an exact frame).", "El intervalo requiere transcodificación (el rewrap no corta en un fotograma exacto)."),
        ("Nu pot citi cadrele/s sau durata sursei pentru interval.", "Cannot read the source frame rate or duration for the interval.", "No se puede leer la velocidad de fotogramas ni la duración del origen para el intervalo."),
        ("Interval invalid.", "Invalid interval.", "Intervalo no válido."),
        ("FFmpeg a esuat (cod {0}): {1}", "FFmpeg failed (code {0}): {1}", "FFmpeg falló (código {0}): {1}"),
        ("Numar de cadre diferit: asteptat {0}, rezultat {1}.", "Frame count differs: expected {0}, got {1}.", "El número de fotogramas difiere: esperado {0}, obtenido {1}."),
        ("Piste audio lipsa: sursa {0}, rezultat {1}.", "Audio tracks missing: source {0}, output {1}.", "Faltan pistas de audio: origen {0}, resultado {1}."),
        ("Originalul pare modificat in timpul conversiei.", "The original seems to have changed during conversion.", "El original parece haberse modificado durante la conversión."),
        // licență
        ("Format de cod serial invalid (lungime gresita).", "Invalid serial code format (wrong length).", "Formato de código de serie no válido (longitud incorrecta)."),
        ("Cod serial invalid — semnatura nu se potriveste.", "Invalid serial code — the signature does not match.", "Código de serie no válido: la firma no coincide."),
        ("Acest cod e pentru alt produs.", "This code is for another product.", "Este código es de otro producto."),
        ("Acest cod e activat pentru alt calculator.", "This code is activated for another computer.", "Este código está activado para otro equipo."),
        ("Codul serial a expirat.", "The serial code has expired.", "El código de serie ha caducado."),
        ("Cod serial invalid sau corupt ({0}).", "Invalid or corrupt serial code ({0}).", "Código de serie no válido o dañado ({0})."),
        // offload
        ("Se copiaza...", "Copying…", "Copiando…"), ("Se anuleaza...", "Cancelling…", "Cancelando…"), ("Anulat.", "Cancelled.", "Cancelado."),
        ("Pauza — apasa Continua pentru a relua", "Paused — press Resume to continue", "En pausa: pulsa Reanudar para continuar"),
        ("Nu am gasit niciun fisier de copiat.", "No file to copy was found.", "No se encontró ningún archivo para copiar."),
        ("Spațiu insuficient la destinație — transferul nu a pornit.", "Not enough space at the destination — the transfer did not start.", "Espacio insuficiente en el destino: la transferencia no se inició."),
        ("Pornire blocata: {0} fisier(e) cu acelasi nume in surse diferite (ex. {1}).", "Start blocked: {0} file(s) with the same name in different sources (e.g. {1}).", "Inicio bloqueado: {0} archivo(s) con el mismo nombre en orígenes distintos (p. ej. {1})."),
        ("Pornire blocată: {0} ({1})", "Start blocked: {0} ({1})", "Inicio bloqueado: {0} ({1})"),
        ("Pornire blocată: {0}", "Start blocked: {0}", "Inicio bloqueado: {0}"),
        ("Nicio sursă", "No source", "Ningún origen"), ("Nicio copie", "No copy", "Ninguna copia"), ("Sursa lipsește", "Source missing", "Origen no disponible"),
        ("Destinația lipsește", "Destination missing", "Destino no disponible"), ("Destinația e un fișier", "Destination is a file", "El destino es un archivo"),
        ("Copia ar ajunge pe card", "The copy would land on the card", "La copia acabaría en la tarjeta"), ("Sursa e în destinație", "Source is inside the destination", "El origen está dentro del destino"),
        ("Sursa = destinația", "Source = destination", "Origen = destino"), ("Destinație dublată", "Duplicate destination", "Destino duplicado"),
        ("Destinații imbricate", "Nested destinations", "Destinos anidados"), ("Același disc cu sursa", "Same disk as the source", "El mismo disco que el origen"),
        ("Nume identice în surse", "Identical names in sources", "Nombres idénticos en los orígenes"),
        ("Extragerea metadatelor nu e disponibilă: componenta GDC Metadata lipsește din aplicație. Copierea continuă fără ea.", "Metadata extraction is unavailable: the GDC Metadata component is missing from the app. The copy continues without it.", "La extracción de metadatos no está disponible: falta el componente GDC Metadata en la aplicación. La copia continúa sin él."),
        // jurnal și stare Offload
        ("Destinatia nu e disponibila: {0} ({1})", "Destination unavailable: {0} ({1})", "Destino no disponible: {0} ({1})"),
        ("MHL: nu se poate genera cu {0} — standardul MHL acceptă doar xxHash64, MD5 sau SHA-1.", "MHL: cannot be generated with {0} — the MHL standard only accepts xxHash64, MD5 or SHA-1.", "MHL: no se puede generar con {0}: el estándar MHL solo admite xxHash64, MD5 o SHA-1."),
        ("Checkpoint ignorat ({0}) — fișierele existente se reverifică.", "Checkpoint ignored ({0}) — existing files are re-verified.", "Punto de control ignorado ({0}): los archivos existentes se vuelven a verificar."),
        ("Checkpoint depășit: {0} lipsește, are altă mărime sau sursa diferă — se reverifică.", "Checkpoint outdated: {0} is missing, has another size or the source differs — re-verifying.", "Punto de control obsoleto: {0} falta, tiene otro tamaño o el origen difiere; se vuelve a verificar."),
        ("Recuperat la reîncercare: {0}", "Recovered on retry: {0}", "Recuperado al reintentar: {0}"),
        ("Eșuat și la reîncercare: {0}", "Failed again on retry: {0}", "Falló también al reintentar: {0}"),
        ("Checkpoint nesalvat ({0}) — nu afectează fișierele confirmate; o reluare le va reverifica.", "Checkpoint not saved ({0}) — confirmed files are unaffected; a resume will re-verify them.", "Punto de control no guardado ({0}): no afecta a los archivos confirmados; al reanudar se volverán a verificar."),
        ("MHL scris: {0} ({1} fișiere certificate)", "MHL written: {0} ({1} certified files)", "MHL escrito: {0} ({1} archivos certificados)"),
        ("Nu s-a putut genera raportul HTML: {0}", "The HTML report could not be generated: {0}", "No se pudo generar el informe HTML: {0}"),
        ("Nu s-a putut genera raportul PDF: {0}", "The PDF report could not be generated: {0}", "No se pudo generar el informe PDF: {0}"),
        ("──────── Transfer nou: {0} ────────", "──────── New transfer: {0} ────────", "──────── Nueva transferencia: {0} ────────"),
        ("Pauza — transferul e oprit temporar de utilizator.", "Paused — the transfer is temporarily stopped by the user.", "En pausa: el usuario ha detenido temporalmente la transferencia."),
        ("Verificare fisier existent: {0}…", "Checking existing file: {0}…", "Comprobando archivo existente: {0}…"),
        ("Se recopiază {0}: {1}.", "Re-copying {0}: {1}.", "Recopiando {0}: {1}."),
        ("Copiere: {0} ({1})", "Copying: {0} ({1})", "Copiando: {0} ({1})"),
        ("Verificare checksum: {0}…", "Verifying checksum: {0}…", "Verificando suma de control: {0}…"),
        ("Reîncercare automată: {0} fișier(e) care au eșuat la prima trecere…", "Automatic retry: {0} file(s) that failed on the first pass…", "Reintento automático: {0} archivo(s) que fallaron en la primera pasada…"),
        ("Metadate: {0} citite complet · {1} parțiale · {2} fără metadate · {3} eșuate · {4} neextrase (copie neverificată)", "Metadata: {0} fully read · {1} partial · {2} without metadata · {3} failed · {4} not extracted (unverified copy)", "Metadatos: {0} leídos por completo · {1} parciales · {2} sin metadatos · {3} fallidos · {4} sin extraer (copia no verificada)"),
        ("Card ejectat automat: {0}", "Card ejected automatically: {0}", "Tarjeta expulsada automáticamente: {0}"),
        ("Cardul {0} nu a putut fi ejectat automat — scoate-l manual (ejectarea cere drepturi de administrator).", "Card {0} could not be ejected automatically — remove it manually (ejecting needs administrator rights).", "La tarjeta {0} no se pudo expulsar automáticamente: sácala manualmente (expulsar requiere permisos de administrador)."),
        ("Cardul {0} nu a putut fi ejectat: {1}", "Card {0} could not be ejected: {1}", "La tarjeta {0} no se pudo expulsar: {1}"),
        ("{0}% ({1}/{2} fisiere)", "{0}% ({1}/{2} files)", "{0}% ({1}/{2} archivos)"),
        ("Finalizat — {0} OK, {1} probleme, {2} recuperate la reîncercare.", "Finished — {0} OK, {1} problems, {2} recovered on retry.", "Finalizado: {0} OK, {1} problemas, {2} recuperados al reintentar."),
        ("Finalizat — {0} OK, {1} probleme.", "Finished — {0} OK, {1} problems.", "Finalizado: {0} OK, {1} problemas."),
        ("Finalizat — {0} OK, {1} recuperate la reîncercare.", "Finished — {0} OK, {1} recovered on retry.", "Finalizado: {0} OK, {1} recuperados al reintentar."),
        ("Finalizat — {0} OK.", "Finished — {0} OK.", "Finalizado: {0} OK."),
        ("Transfer verificat — {0}", "Transfer verified — {0}", "Transferencia verificada — {0}"),
        ("Transfer eșuat — {0}", "Transfer failed — {0}", "Transferencia fallida — {0}"),
        ("Transfer anulat — {0}", "Transfer cancelled — {0}", "Transferencia cancelada — {0}"),
        ("Eșec parțial — nu formata cardul — {0}", "Partial failure — do not format the card — {0}", "Fallo parcial: no formatees la tarjeta — {0}"),
        ("Verificat, cu avertismente — {0}", "Verified, with warnings — {0}", "Verificado, con avisos — {0}"),
        ("Transfer verificat", "Transfer verified", "Transferencia verificada"),
        ("Transfer eșuat", "Transfer failed", "Transferencia fallida"),
        ("Eșec parțial — nu formata cardul", "Partial failure — do not format the card", "Fallo parcial: no formatees la tarjeta"),
        ("Verificat, cu avertismente", "Verified, with warnings", "Verificado, con avisos"),
        ("Transfer anulat", "Transfer cancelled", "Transferencia cancelada"),
        // actualizare
        ("SHA-256 nu se potrivește", "SHA-256 does not match", "El SHA-256 no coincide"),
        ("versiune în fișier {0}, oferită {1}", "version in file {0}, offered {1}", "versión en el archivo {0}, ofrecida {1}"),
    };

    static readonly Dictionary<string, (string En, string Es)> Exact = new();
    static readonly List<(Regex Rx, string En, string Es)> Patterns = new();

    static CoreText()
    {
        foreach (var (ro, en, es) in Table)
        {
            if (!ro.Contains("{0}")) { Exact[ro] = (en, es); continue; }
            var rx = "^" + Regex.Replace(Regex.Escape(ro), @"\\\{(\d)\}", "(?<g$1>.+?)") + "$";
            Patterns.Add((new Regex(rx, RegexOptions.Singleline), en, es));
        }
    }

    public static string Tr(string? ro)
    {
        if (string.IsNullOrEmpty(ro) || Lang == "ro") return ro ?? "";
        if (Exact.TryGetValue(ro, out var t)) return Lang == "es" ? t.Es : t.En;
        foreach (var (rx, en, es) in Patterns)
        {
            var m = rx.Match(ro); if (!m.Success) continue;
            var tpl = Lang == "es" ? es : en;
            return Regex.Replace(tpl, @"\{(\d)\}", g => m.Groups["g" + g.Groups[1].Value] is { Success: true } gr ? Tr(gr.Value) : g.Value);
        }
        return ro;
    }

    /// Șiruri compuse de tipul „A · B”: se traduce fiecare parte separat.
    public static string TrParts(string? s, string sep = " · ") => string.Join(sep, (s ?? "").Split(sep).Select(Tr));
}
