# Generează ghidul PDF Windows al CG Convertor (RO/EN/ES) cu reportlab, local.
# Rulează: python3 windows/guides/generate_guide.py  → Instructiuni_Utilizare_{RO,EN,ES}.pdf lângă script.
import os, sys
from reportlab.lib.pagesizes import A4
from reportlab.lib.units import cm
from reportlab.lib import colors
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import SimpleDocTemplate, Paragraph, ListFlowable, ListItem, Spacer, Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUTDIR = os.environ.get("CGC_GUIDE_OUT", HERE)
pdfmetrics.registerFont(TTFont("Arial", "/System/Library/Fonts/Supplemental/Arial.ttf"))
pdfmetrics.registerFont(TTFont("Arial-Bold", "/System/Library/Fonts/Supplemental/Arial Bold.ttf"))
ss = getSampleStyleSheet()
ACC = colors.HexColor("#B96A1E")
T = ParagraphStyle("T", parent=ss["Title"], fontName="Arial-Bold", fontSize=20, leading=24, textColor=colors.HexColor("#1a1a1a"))
H = ParagraphStyle("H", parent=ss["Heading2"], fontName="Arial-Bold", fontSize=13, leading=16, spaceBefore=12, spaceAfter=4, textColor=ACC)
B = ParagraphStyle("B", parent=ss["BodyText"], fontName="Arial", fontSize=10, leading=14)
N = ParagraphStyle("N", parent=B, fontSize=9, textColor=colors.HexColor("#555555"))

VERSION = "3.18.0"
DOCS = {
"RO": ("Instrucțiuni de utilizare — CG Convertor pentru Windows", [
 ("Ce este", ["CG Convertor are trei spații de lucru: <b>Transcodare</b> (conversie video), <b>Offload</b> (copiere verificată de pe carduri și discuri) și <b>Metadate</b> (informațiile clipurilor). Versiunea Windows este aceeași aplicație ca pe Mac, adaptată pentru Windows 10/11 pe 64 de biți (rulează și pe Windows ARM prin emulare x64).",
   "Nu trebuie să instalezi nimic în plus: FFmpeg, FFprobe, ExifTool și nucleul de metadate sunt incluse în aplicație (licențele lor sunt în folderul tools al instalării). Poți deschide fișiere sau foldere și din Explorer, cu „Deschide cu”, sau trăgându-le pe CGConvertor.exe."]),
 ("Instalare, actualizare, dezinstalare", ["<b>Instalare:</b> rulează <i>CGConvertor-Windows-3.18.0.exe</i>, acceptă licența și apasă Următorul. Windows poate afișa un avertisment SmartScreen deoarece instalatorul nu are încă reputație: alege „Mai multe informații” → „Rulează oricum”.",
   "<b>Actualizare:</b> instalatorul nou înlocuiește versiunea veche pe loc; licența și proba rămân. Din aplicație: Setări → „Caută actualizări”; apare butonul „Actualizează acum” doar dacă există un instalator Windows pentru versiunea nouă.",
   "<b>Dezinstalare:</b> Setări Windows → Aplicații → CG Convertor → Dezinstalează. Se șterg setările, temele și logurile; proba gratuită nu se resetează prin reinstalare."]),
 ("Transcodare", ["1. Apasă „Adaugă fișiere” sau „Adaugă folder”, ori trage fișiere în listă. Comută între Listă și Grilă.",
   "2. Alege o presetare (ProRes, DNxHR, H.264, HEVC, necomprimat sau Rewrap rapid). Opțional: cadre/s la ieșire și eticheta spațiului de culoare (doar etichetă, nu transformare de pixeli).",
   "3. Interval: introdu începutul și sfârșitul în secunde (sau mm:ss) ori apasă „Previzualizare”, mută cursorul și folosește „de la” / „până la”. Intervalul se aplică la transcodare, nu la Rewrap.",
   "4. Alege folderul de ieșire (implicit lângă sursă; niciodată nu se suprascrie un fișier existent) și apasă „Pornește”. „Anulează” oprește conversia curentă și șterge fișierele temporare.",
   "5. După fiecare clip, „Raport” arată cadrele sursă/rezultat, pistele audio, timecode-ul și ce s-a păstrat. Destinația apare doar după verificare."]),
 ("Offload", ["Adaugă una sau mai multe surse (card, folder) și una sau mai multe destinații; dublu-clic pe o unitate detectată o adaugă ca sursă. Alege verificarea (xxHash64 implicit), completează proiectul/cardul și apasă „Pornește”. Fiecare fișier se copiază și se verifică prin sumă de control pe fiecare destinație; la final se scriu raport PDF, MHL și (opțional) metadatele clipurilor. „Trimite fișierele verificate la Transcodare” adaugă în Transcodare numai fișierele cu verdict verificat."]),
 ("Metadate", ["Adaugă clipuri și apasă „Citește metadatele”. Pentru fiecare valoare apare proveniența (citită din date native, declarată de producător sau dedusă). „Exportă fișier însoțitor” scrie <i>clip.gdc-metadata.json</i> lângă clip."]),
 ("Setări, licență, probă", ["Temă: Sistem, Deschisă sau Închisă. Limbă: română, engleză sau spaniolă. Proba nouă durează 5 zile; probele începute înainte nu sunt scurtate. Pentru activare, copiază ID-ul calculatorului, trimite-l emitentului și lipește codul serial primit.",
   "Pentru suport: Setări → „Exportă diagnostic (ZIP)” creează un arhivă cu loguri fără parole sau conținut de fișiere."]),
 ("Limite reale pe Windows", ["• Codarea este software (prores_ks, libx264, libx265); accelerarea hardware nu este activată automat. Presetările AV1 nu apar, pentru că FFmpeg-ul inclus nu are encoderul AV1. La DNxHD/DNxHR în MXF, audio este convertit automat în PCM 24-bit 48 kHz (MXF nu acceptă altceva), iar aplicația îți spune asta înainte de pornire.",
   "• Pistele native de cameră (cndm Canon, rtmd Sony) se copiază doar în fișiere MOV, fără schimbare de cadre/s sau de etichetă de culoare; în rest, timecode-ul, audio și metadatele din container se păstrează, iar fișierul însoțitor <i>.gdc-metadata.json</i> poartă valorile originale. DaVinci Resolve citește singur din fișier doar unele camere (de exemplu Canon C50).",
   "• Instalatorul poate fi nesemnat și va declanșa SmartScreen."]),
]),
"EN": ("User guide — CG Convertor for Windows", [
 ("What it is", ["CG Convertor has three workspaces: <b>Transcode</b> (video conversion), <b>Offload</b> (verified copy from cards and drives) and <b>Metadata</b> (clip information). The Windows version is the same app as on Mac, adapted for 64-bit Windows 10/11 (it also runs on Windows on ARM through x64 emulation).",
   "You do not have to install anything else: FFmpeg, FFprobe, ExifTool and the metadata core are included (their licenses are in the tools folder of the installation). You can also open files or folders from Explorer with “Open with”, or by dragging them onto CGConvertor.exe."]),
 ("Install, update, uninstall", ["<b>Install:</b> run <i>CGConvertor-Windows-3.18.0.exe</i>, accept the license and press Next. Windows may show a SmartScreen warning because the installer has no reputation yet: choose “More info” → “Run anyway”.",
   "<b>Update:</b> the new installer replaces the old version in place; your license and trial are kept. In the app: Settings → “Check for updates”; the “Update now” button appears only when a Windows installer exists for the new version.",
   "<b>Uninstall:</b> Windows Settings → Apps → CG Convertor → Uninstall. Settings, themes and logs are deleted; the free trial is not reset by reinstalling."]),
 ("Transcode", ["1. Press “Add files” or “Add folder”, or drag files into the list. Switch between List and Grid.",
   "2. Pick a preset (ProRes, DNxHR, H.264, HEVC, uncompressed or fast Rewrap). Optional: output frame rate and colour-space tag (a tag only, not a pixel transform).",
   "3. Range: type start and end in seconds (or mm:ss) or press “Preview”, move the slider and use “from” / “to”. A range applies to transcoding, not to Rewrap.",
   "4. Choose the output folder (next to the source by default; an existing file is never overwritten) and press “Start”. “Cancel” stops the current conversion and removes temporary files.",
   "5. After each clip, “Report” shows source/result frames, audio tracks, timecode and what was kept. The destination only appears after verification."]),
 ("Offload", ["Add one or more sources (card, folder) and one or more destinations; double-click a detected drive to add it as a source. Choose the verification (xxHash64 by default), fill in project/card and press “Start”. Every file is copied and checksum-verified on each destination; at the end a PDF report, an MHL and (optionally) the clips’ metadata are written. “Send verified files to Transcode” adds only files with a verified verdict to Transcode."]),
 ("Metadata", ["Add clips and press “Read metadata”. Each value shows its provenance (decoded from native data, declared by the manufacturer or derived). “Export sidecar” writes <i>clip.gdc-metadata.json</i> next to the clip."]),
 ("Settings, license, trial", ["Theme: System, Light or Dark. Language: Romanian, English or Spanish. A new trial lasts 5 days; trials started earlier are not shortened. To activate, copy the Machine ID, send it to the issuer and paste the serial code you receive.",
   "For support: Settings → “Export diagnostics (ZIP)” creates an archive with logs and no passwords or file contents."]),
 ("Real limits on Windows", ["• Encoding is software (prores_ks, libx264, libx265); hardware acceleration is not enabled automatically. AV1 presets do not appear because the bundled FFmpeg has no AV1 encoder. For DNxHD/DNxHR in MXF, audio is converted automatically to 24-bit 48 kHz PCM (MXF accepts nothing else), and the app tells you before you start.",
   "• Native camera tracks (Canon cndm, Sony rtmd) are copied only into MOV files, without a frame-rate or colour-tag change; otherwise timecode, audio and container metadata are kept, and the <i>.gdc-metadata.json</i> sidecar carries the original values. DaVinci Resolve reads only some cameras (for example Canon C50) from the file itself.",
   "• The installer may be unsigned and will trigger SmartScreen."]),
]),
"ES": ("Guía de uso — CG Convertor para Windows", [
 ("Qué es", ["CG Convertor tiene tres espacios de trabajo: <b>Transcodificar</b> (conversión de vídeo), <b>Offload</b> (copia verificada desde tarjetas y discos) y <b>Metadatos</b> (información de los clips). La versión de Windows es la misma aplicación que en Mac, adaptada a Windows 10/11 de 64 bits (también funciona en Windows ARM mediante emulación x64).",
   "No necesitas instalar nada más: FFmpeg, FFprobe, ExifTool y el núcleo de metadatos están incluidos (sus licencias están en la carpeta tools de la instalación). También puedes abrir archivos o carpetas desde el Explorador con «Abrir con» o arrastrándolos sobre CGConvertor.exe."]),
 ("Instalar, actualizar, desinstalar", ["<b>Instalar:</b> ejecuta <i>CGConvertor-Windows-3.18.0.exe</i>, acepta la licencia y pulsa Siguiente. Windows puede mostrar un aviso de SmartScreen porque el instalador aún no tiene reputación: elige «Más información» → «Ejecutar de todas formas».",
   "<b>Actualizar:</b> el instalador nuevo sustituye a la versión anterior; la licencia y la prueba se conservan. En la aplicación: Ajustes → «Buscar actualizaciones»; el botón «Actualizar ahora» solo aparece si existe un instalador de Windows para la versión nueva.",
   "<b>Desinstalar:</b> Configuración de Windows → Aplicaciones → CG Convertor → Desinstalar. Se borran ajustes, temas y registros; la prueba gratuita no se reinicia al reinstalar."]),
 ("Transcodificar", ["1. Pulsa «Añadir archivos» o «Añadir carpeta», o arrastra archivos a la lista. Alterna entre Lista y Cuadrícula.",
   "2. Elige un preajuste (ProRes, DNxHR, H.264, HEVC, sin comprimir o Rewrap rápido). Opcional: fotogramas/s de salida y etiqueta de espacio de color (solo etiqueta, no transformación de píxeles).",
   "3. Intervalo: escribe inicio y fin en segundos (o mm:ss) o pulsa «Vista previa», mueve el control y usa «desde» / «hasta». El intervalo se aplica al transcodificar, no al Rewrap.",
   "4. Elige la carpeta de salida (junto al origen por defecto; nunca se sobrescribe un archivo existente) y pulsa «Iniciar». «Cancelar» detiene la conversión actual y borra los temporales.",
   "5. Tras cada clip, «Informe» muestra fotogramas origen/resultado, pistas de audio, timecode y lo que se conservó. El destino solo aparece tras la verificación."]),
 ("Offload", ["Añade uno o varios orígenes (tarjeta, carpeta) y uno o varios destinos; doble clic en una unidad detectada la añade como origen. Elige la verificación (xxHash64 por defecto), rellena proyecto/tarjeta y pulsa «Iniciar». Cada archivo se copia y se verifica por suma de comprobación en cada destino; al final se escriben informe PDF, MHL y (opcionalmente) los metadatos de los clips. «Enviar archivos verificados a Transcodificar» añade solo los archivos con veredicto verificado."]),
 ("Metadatos", ["Añade clips y pulsa «Leer metadatos». Cada valor muestra su procedencia (leída de datos nativos, declarada por el fabricante o deducida). «Exportar archivo acompañante» escribe <i>clip.gdc-metadata.json</i> junto al clip."]),
 ("Ajustes, licencia, prueba", ["Tema: Sistema, Clara u Oscura. Idioma: rumano, inglés o español. Una prueba nueva dura 5 días; las pruebas iniciadas antes no se acortan. Para activar, copia el ID del equipo, envíalo al emisor y pega el código de serie recibido.",
   "Para soporte: Ajustes → «Exportar diagnóstico (ZIP)» crea un archivo con registros sin contraseñas ni contenido de archivos."]),
 ("Límites reales en Windows", ["• La codificación es por software (prores_ks, libx264, libx265); la aceleración por hardware no se activa automáticamente. Los preajustes AV1 no aparecen porque el FFmpeg incluido no tiene codificador AV1. En DNxHD/DNxHR en MXF, el audio se convierte automáticamente a PCM de 24 bits y 48 kHz (MXF no admite otra cosa) y la app te lo indica antes de empezar.",
   "• Las pistas nativas de cámara (cndm de Canon, rtmd de Sony) solo se copian en archivos MOV, sin cambio de fotogramas/s ni de etiqueta de color; además se conservan timecode, audio y metadatos del contenedor, y el archivo <i>.gdc-metadata.json</i> lleva los valores originales. DaVinci Resolve solo lee de forma automática algunas cámaras (por ejemplo Canon C50).",
   "• El instalador puede no estar firmado y activará SmartScreen."]),
]),
}

def build(lang):
    title, sections = DOCS[lang]
    out = os.path.join(OUTDIR, f"Instructiuni_Utilizare_{lang}.pdf")
    doc = SimpleDocTemplate(out, pagesize=A4, leftMargin=2*cm, rightMargin=2*cm, topMargin=2*cm, bottomMargin=2*cm, title=title, author="CG Convertor")
    st = [Paragraph(title, T), Paragraph(f"CG Convertor {VERSION}", N), Spacer(1, 8)]
    for h, items in sections:
        st.append(Paragraph(h, H))
        for it in items:
            st.append(Paragraph(it, B)); st.append(Spacer(1, 4))
    doc.build(st)
    return out

if __name__ == "__main__":
    for l in ("RO", "EN", "ES"):
        print(build(l))
