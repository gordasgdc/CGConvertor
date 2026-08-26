# Genereaza Instructiuni_Utilizare.pdf pentru CG Convertor, RO/EN/ES, cu
# reportlab. Foloseste Arial (nu Helvetica standard-14) pentru ca
# diacriticele romanesti (s-comma, t-comma) nu exista in WinAnsiEncoding-ul
# fonturilor PDF standard - fara asta, ș/ț ies ca patratele goale. Vezi
# istoricul din GDCVault/installer/generate_pdf.py pentru precedent.
#
# STANDARD (CLAUDE.md, "Directiva permanenta: Standardul ghidurilor PDF",
# 2026-08-26): redactare ultra-detaliata, zero presupuneri, ca pentru un
# utilizator complet incepator. 4 sectiuni obligatorii: Panoul de Dependinte
# (rosu/verde), Homebrew pas-cu-pas (doar Mac), Flux conversie + butoane
# post-proces, Licenta & Donatie 23 EUR.
#
# Ruleaza cu: python3 installer/generate_pdf.py
# (necesita `pip install reportlab` intr-un venv)
import os
from reportlab.lib.pagesizes import A4
from reportlab.lib.units import cm
from reportlab.lib import colors
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, ListFlowable, ListItem, PageBreak, Spacer
)

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "Instructiuni_Utilizare.pdf")

pdfmetrics.registerFont(TTFont("Arial", "/System/Library/Fonts/Supplemental/Arial.ttf"))
pdfmetrics.registerFont(TTFont("Arial-Bold", "/System/Library/Fonts/Supplemental/Arial Bold.ttf"))
styles = getSampleStyleSheet()
ACCENT = colors.HexColor("#B96A1E")  # accentul Shift (cupru/amber), inchis pentru lizibilitate pe fundal alb
MUTED = colors.HexColor("#6a6a6a")
FAINT = colors.HexColor("#8a8a8a")
GREEN = colors.HexColor("#2E7D4F")
RED = colors.HexColor("#C0392B")
NOTE_BG = colors.HexColor("#FBF1E6")
NOTE_BORDER = colors.HexColor("#E8963C")

title_style = ParagraphStyle("TitleGDC", parent=styles["Title"], fontName="Arial-Bold",
                              fontSize=19, leading=22, spaceAfter=2, textColor=colors.HexColor("#1a1a1a"))
subtitle_style = ParagraphStyle("Subtitle", parent=styles["Normal"], fontName="Arial",
                                 fontSize=11, textColor=MUTED, spaceAfter=20)
h2_style = ParagraphStyle("H2", parent=styles["Heading2"], fontName="Arial-Bold",
                           fontSize=13, textColor=ACCENT, spaceBefore=16, spaceAfter=6)
h3_style = ParagraphStyle("H3", parent=styles["Heading3"], fontName="Arial-Bold",
                           fontSize=10.8, textColor=colors.HexColor("#1a1a1a"), spaceBefore=8, spaceAfter=3)
body_style = ParagraphStyle("Body", parent=styles["Normal"], fontName="Arial",
                             fontSize=10.5, leading=15, textColor=colors.HexColor("#1a1a1a"), spaceAfter=6)
li_style = ParagraphStyle("Li", parent=body_style, spaceAfter=4)
step_style = ParagraphStyle("Step", parent=body_style, leftIndent=4, spaceAfter=5)
note_style = ParagraphStyle("Note", parent=body_style, backColor=NOTE_BG,
                             borderColor=NOTE_BORDER, borderWidth=0, leftIndent=10, fontSize=10)
footer_style = ParagraphStyle("Footer", parent=styles["Normal"], fontName="Arial",
                               fontSize=8.5, textColor=FAINT, spaceBefore=20)


def bullets(items):
    return ListFlowable(
        [ListItem(Paragraph(it, li_style), leftIndent=14) for it in items],
        bulletType="bullet", start="•", leftIndent=14, spaceBefore=2, spaceAfter=8,
    )


def numbered(items):
    return ListFlowable(
        [ListItem(Paragraph(it, step_style), leftIndent=16) for it in items],
        bulletType="1", start="1", leftIndent=16, spaceBefore=2, spaceAfter=8,
    )


def note(text):
    return Paragraph(text, note_style)


def h3(text):
    return Paragraph(text, h3_style)


def page(d):
    flow = [Paragraph("CG Convertor", title_style), Paragraph(d["subtitle"], subtitle_style)]

    flow.append(Paragraph(d["h_install"], h2_style))
    flow.append(numbered(d["install"]))

    # --- 1. Panoul de Dependinte (rosu/verde) ---------------------------
    flow.append(Paragraph(d["h_deps"], h2_style))
    flow.append(Paragraph(d["deps_intro"], body_style))
    flow.append(h3(d["deps_red_label"]))
    flow.append(Paragraph(d["deps_red_text"], body_style))
    flow.append(h3(d["deps_green_label"]))
    flow.append(Paragraph(d["deps_green_text"], body_style))
    flow.append(h3(d["deps_howto_label"]))
    flow.append(numbered(d["deps_howto"]))

    # --- 2. Homebrew (doar Mac) ------------------------------------------
    flow.append(Paragraph(d["h_homebrew"], h2_style))
    flow.append(Paragraph(d["homebrew_intro"], body_style))
    flow.append(numbered(d["homebrew_steps"]))
    flow.append(note(d["homebrew_note"]))

    # --- Flux de conversie + actiuni post-proces --------------------------
    flow.append(Paragraph(d["h_usage"], h2_style))
    flow.append(Paragraph(d["usage_intro"], body_style))
    flow.append(numbered(d["usage_add"]))
    flow.append(bullets(d["usage"]))
    flow.append(h3(d["postconv_label"]))
    flow.append(bullets(d["postconv"]))

    flow.append(Paragraph(d["h_modes"], h2_style))
    flow.append(bullets(d["modes"]))

    # --- 4. Licenta & Donatie ---------------------------------------------
    flow.append(Paragraph(d["h_trial"], h2_style))
    flow.append(Paragraph(d["trial_intro"], body_style))
    flow.append(numbered(d["trial"]))
    flow.append(note(d["donation_note"]))
    flow.append(note(d["trial_note"]))

    flow.append(Paragraph(d["h_uninstall"], h2_style))
    flow.append(Paragraph(d["uninstall"], body_style))

    flow.append(Paragraph(d["h_support"], h2_style))
    flow.append(Paragraph(d["support"], body_style))

    flow.append(Paragraph("CG Convertor — github.com/gordasgdc/CGConvertor", footer_style))
    return flow


RO = dict(
    subtitle="Instrucțiuni de instalare și utilizare — Română",
    h_install="1. Instalare",
    install=[
        "Descarcă și dezarhivează <b>CGConvertor-Mac.zip</b> de pe pagina de descărcare sau din secțiunea Releases de pe GitHub.",
        "Dublu-click pe <b>CGConvertor.pkg</b> — pachet semnat și notarizat oficial de Apple, se instalează direct în /Applications, fără avertismente Gatekeeper și fără să tragi manual nimic.",
        "Urmează pașii instalatorului. Va trebui să accepți Termenii și Condițiile pentru a continua.",
        "La prima pornire, deschide aplicația din Launchpad sau din folderul Applications.",
    ],
    h_deps="2. Panoul de Dependințe (indicatorul roșu/verde)",
    deps_intro="În partea de sus a ferestrei aplicației vezi un mic punct colorat, urmat de un text scurt. Acesta îți spune dacă aplicația este gata de lucru sau mai are nevoie de o componentă tehnică (FFmpeg) ca să poată converti fișiere video.",
    deps_red_label="🔴 Punct roșu — „Dependențe lipsă”",
    deps_red_text="Înseamnă că FFmpeg (motorul intern folosit pentru conversie) nu a fost găsit sau nu funcționează pe acest calculator. Butonul „Pornește conversia” rămâne dezactivat până rezolvi acest lucru — nu e nimic stricat, aplicația doar așteaptă instalarea automată descrisă mai jos.",
    deps_green_label="🟢 Punct verde — „Sistem pregătit”",
    deps_green_text="Înseamnă că FFmpeg este instalat corect și funcțional. Poți adăuga fișiere și porni conversia normal, fără niciun pas suplimentar.",
    deps_howto_label="Ce faci exact când vezi punctul roșu:",
    deps_howto=[
        "Dă click pe indicatorul roșu din partea de sus a ferestrei (lângă selectorul de limbă). Se deschide o fereastră nouă, numită „Verificare & Dependențe Sistem”.",
        "În această fereastră vezi o listă cu componente, fiecare cu propriul punct colorat. Componenta „FFmpeg” va avea punctul roșu și, lângă ea, un buton cu textul „Descarcă & Instalează Automat”.",
        "Apasă acel buton. Aplicația descarcă automat, pe internet, o versiune independentă a FFmpeg (nu trebuie să cauți tu nimic, nu trebuie să instalezi altceva) și o salvează într-un folder intern al aplicației.",
        "Așteaptă câteva secunde până la un minut, în funcție de viteza conexiunii tale la internet — vei vedea un text de progres cât timp se descarcă.",
        "Când descărcarea s-a terminat, punctul de lângă „FFmpeg” devine automat verde. Poți închide fereastra (butonul „Închide”) și reveni la conversia fișierelor — indicatorul principal din partea de sus a aplicației devine și el verde.",
    ],
    h_homebrew="3. Homebrew — ghid pas-cu-pas (opțional, doar pe Mac)",
    homebrew_intro="Homebrew este un instrument opțional, recomandat doar dacă vrei un mediu complet de dezvoltare pe Mac (nu este obligatoriu pentru conversia de fișiere — pentru asta e suficient FFmpeg, instalat automat mai sus). Dacă în panoul de dependințe vezi „Homebrew” cu punct portocaliu/roșu și eticheta „Opțional — Neinstalat”, poți urma acești pași dacă vrei totuși să-l instalezi:",
    homebrew_steps=[
        "În panoul „Verificare & Dependențe Sistem”, lângă rândul „Homebrew”, apasă butonul „Copiază Comanda”. O comandă de instalare este acum copiată automat (invizibil) în memoria temporară a calculatorului tău.",
        "Deschide aplicația Terminal de pe Mac. Cel mai simplu mod: apasă simultan tastele <b>Cmd + Space</b> (bara de spațiu), scrie cuvântul „Terminal” și apasă Enter când apare în listă.",
        "În fereastra neagră care s-a deschis (Terminal), lipește comanda copiată apăsând simultan tastele <b>Cmd + V</b>.",
        "Apasă tasta <b>Enter</b> ca să pornești instalarea.",
        "Terminalul îți va cere parola contului tău de Mac. Este normal ca, în timp ce scrii parola, să nu vezi nicio literă sau steluță pe ecran — Terminal ascunde parola complet din motive de securitate, dar ea se scrie în fundal. Scrie parola și apasă din nou tasta <b>Enter</b>.",
        "Așteaptă câteva minute cât se instalează Homebrew. La final, poți reveni în CG Convertor și redeschide panoul de dependințe — rândul „Homebrew” ar trebui să devină verde cu textul „Detectat”.",
    ],
    homebrew_note="<b>Notă:</b> dacă nu vrei să instalezi Homebrew, poți ignora complet acest pas — aplicația funcționează perfect pentru conversia de fișiere doar cu FFmpeg (instalat automat din panoul de dependințe, punctul 2 de mai sus).",
    h_usage="4. Fluxul de conversie și acțiuni după conversie",
    usage_intro="Iată exact cum aduci fișiere în aplicație și cum le convertești:",
    usage_add=[
        "Trage fișierele video direct din Finder și lasă-le să „cadă” peste fereastra aplicației (Drag & Drop) — SAU apasă butonul „Alege fișiere…” din interfață și selectează-le din fereastra care se deschide.",
        "Alege modul de conversie (Rewrap sau Transcode) și, dacă ai ales Transcode, codecul dorit din listă.",
        "Apasă butonul „Pornește conversia” (activ doar când indicatorul de dependințe este verde).",
    ],
    usage=[
        "<b>⌘O</b> — adaugă fișiere · <b>⌘⏎</b> — pornește conversia · <b>⌘K</b> — golește lista.",
        "<b>Folder destinație</b> — implicit, fișierele convertite apar lângă cele originale; poți alege alt folder.",
        "<b>Oprește</b> — anulează conversia în curs; fișierele neprocesate rămân în listă, poți reporni ulterior.",
    ],
    postconv_label="Ce înseamnă butoanele care apar lângă un fișier terminat cu succes:",
    postconv=[
        "<b>„Deschide fișierul”</b> — deschide fișierul convertit direct în aplicația implicită de pe calculatorul tău pentru redare video (de exemplu QuickTime Player sau DaVinci Resolve, dacă e setat implicit).",
        "<b>„Arată în Finder”</b> — deschide o fereastră Finder cu folderul de destinație, având fișierul convertit deja selectat (evidențiat), ca să-l găsești instant fără să cauți manual prin foldere.",
    ],
    h_modes="5. Moduri de conversie",
    modes=[
        "<b>Rewrap</b> — rapid, fără re-encode, doar schimbă containerul. Păstrează exact calitatea și timecode-ul original.",
        "<b>Transcode</b> — re-encode complet în ProRes 422/422 HQ/422 LT/4444 sau DNxHD/DNxHR HQ, cu păstrarea timecode-ului și a bit depth-ului audio original.",
    ],
    h_trial="6. Licență, Trial și Donație",
    trial_intro="Aplicația oferă acces complet, fără restricții, timp de <b>15 zile</b> de la prima pornire. După expirarea acestei perioade de probă (Trial), conversiile noi se opresc până activezi o licență.",
    trial=[
        "Apasă „Activează licența” — se deschide un mesaj WhatsApp pre-completat, cu ID-ul unic al calculatorului tău deja inclus.",
        "Trimite acel mesaj. După ce primești codul de licență ca răspuns, revino în aplicație și lipește codul în fereastra de activare.",
    ],
    donation_note="<b>Donație, nu preț de listă:</b> 23 € — susține continuarea dezvoltării aplicației și a platformei, după cele 15 zile de Trial gratuit. Nu este o vânzare — activarea se face manual, prin WhatsApp, pe baza donației.",
    trial_note="<b>Important:</b> dacă schimbi calculatorul, scrie din nou pe WhatsApp — codul se regenerează pentru noul ID.",
    h_uninstall="7. Dezinstalare",
    uninstall="Rulează <b>Dezinstalare_CGConvertor.command</b> din arhiva descărcată — șterge aplicația și toate fișierele de date.",
    h_support="8. Suport",
    support="Pentru orice întrebare, scrie pe WhatsApp (buton în fereastra de activare) sau deschide un Issue pe GitHub.",
)

EN = dict(
    subtitle="Installation and usage instructions — English",
    h_install="1. Installation",
    install=[
        "Download and unzip <b>CGConvertor-Mac.zip</b> from the download page or the GitHub Releases section.",
        "Double-click <b>CGConvertor.pkg</b> — a package officially signed and notarized by Apple, installs directly into /Applications, no Gatekeeper warnings and nothing to drag manually.",
        "Follow the installer steps. You'll need to accept the Terms and Conditions to continue.",
        "On first launch, open the app from Launchpad or the Applications folder.",
    ],
    h_deps="2. Dependency Panel (the red/green indicator)",
    deps_intro="At the top of the app window you'll see a small colored dot followed by a short label. It tells you whether the app is ready to work, or still needs one technical component (FFmpeg) before it can convert video files.",
    deps_red_label="🔴 Red dot — “Missing dependencies”",
    deps_red_text="Means FFmpeg (the internal engine used for conversion) was not found or isn't working on this computer. The “Start conversion” button stays disabled until this is resolved — nothing is broken, the app is just waiting for the automatic install described below.",
    deps_green_label="🟢 Green dot — “System ready”",
    deps_green_text="Means FFmpeg is installed correctly and working. You can add files and start converting normally, no extra steps needed.",
    deps_howto_label="Exactly what to do when you see the red dot:",
    deps_howto=[
        "Click the red indicator at the top of the window (next to the language switcher). A new window opens, called “System Check & Dependencies”.",
        "In this window you'll see a list of components, each with its own colored dot. The “FFmpeg” item will show a red dot and, next to it, a button labeled “Download & Install Automatically”.",
        "Press that button. The app automatically downloads a self-contained, independent build of FFmpeg over the internet (you don't need to search for or install anything yourself) and saves it inside the app's own data folder.",
        "Wait a few seconds up to about a minute, depending on your internet speed — you'll see a progress message while it downloads.",
        "Once the download finishes, the dot next to “FFmpeg” turns green automatically. You can close the window (“Close” button) and go back to converting files — the main indicator at the top of the app also turns green.",
    ],
    h_homebrew="3. Homebrew — step-by-step guide (optional, Mac only)",
    homebrew_intro="Homebrew is an optional tool, recommended only if you want a full development environment on your Mac (it is not required for converting files — FFmpeg, auto-installed above, is enough for that). If the dependency panel shows “Homebrew” with an orange/red dot labeled “Optional — Not installed”, follow these steps if you'd still like to install it:",
    homebrew_steps=[
        "In the “System Check & Dependencies” panel, next to the “Homebrew” row, press the “Copy Command” button. An install command is now copied automatically (invisibly) to your computer's clipboard.",
        "Open the Terminal app on your Mac. The easiest way: press <b>Cmd + Space</b> at the same time, type the word “Terminal”, and press Enter when it appears in the list.",
        "In the black window that opened (Terminal), paste the copied command by pressing <b>Cmd + V</b> at the same time.",
        "Press the <b>Enter</b> key to start the installation.",
        "Terminal will ask for your Mac account password. It's normal that while typing the password, you won't see any letters or dots appear on screen — Terminal fully hides the password for security, but it's still being typed in the background. Type the password and press <b>Enter</b> again.",
        "Wait a few minutes while Homebrew installs. Afterwards, you can go back to CG Convertor and reopen the dependency panel — the “Homebrew” row should now be green, labeled “Detected”.",
    ],
    homebrew_note="<b>Note:</b> if you don't want to install Homebrew, you can safely skip this step entirely — the app works perfectly for converting files with just FFmpeg (auto-installed from the dependency panel, step 2 above).",
    h_usage="4. Conversion flow and post-conversion actions",
    usage_intro="Here's exactly how you bring files into the app and convert them:",
    usage_add=[
        "Drag video files directly from Finder and drop them onto the app window (Drag & Drop) — OR press the “Choose files…” button in the interface and select them from the window that opens.",
        "Pick the conversion mode (Rewrap or Transcode) and, if you chose Transcode, the desired codec from the list.",
        "Press the “Start conversion” button (only active when the dependency indicator is green).",
    ],
    usage=[
        "<b>⌘O</b> — add files · <b>⌘⏎</b> — start conversion · <b>⌘K</b> — clear the list.",
        "<b>Destination folder</b> — by default, converted files appear next to the originals; you can choose another folder.",
        "<b>Stop</b> — cancels the running conversion; unprocessed files stay in the list, you can restart later.",
    ],
    postconv_label="What the buttons next to a successfully finished file mean:",
    postconv=[
        "<b>“Open File”</b> — opens the converted file directly in your computer's default video player app (for example QuickTime Player, or DaVinci Resolve if that's set as default).",
        "<b>“Show in Finder”</b> — opens a Finder window at the destination folder, with the converted file already selected (highlighted), so you find it instantly without browsing folders manually.",
    ],
    h_modes="5. Conversion modes",
    modes=[
        "<b>Rewrap</b> — fast, no re-encode, just swaps the container. Keeps the exact original quality and timecode.",
        "<b>Transcode</b> — full re-encode into ProRes 422/422 HQ/422 LT/4444 or DNxHD/DNxHR HQ, preserving timecode and the original audio bit depth.",
    ],
    h_trial="6. License, Trial and Donation",
    trial_intro="The app offers full, unrestricted access for <b>15 days</b> from the first launch. After this Trial period expires, new conversions stop until you activate a license.",
    trial=[
        "Tap “Activate license” — opens a pre-filled WhatsApp message with your computer's unique ID already included.",
        "Send that message. Once you receive the license code as a reply, go back to the app and paste the code into the activation window.",
    ],
    donation_note="<b>A donation, not a list price:</b> €23 — supports ongoing development of the app and the platform, after the 15-day free Trial. Not a sale — activation happens manually, over WhatsApp, based on the donation.",
    trial_note="<b>Important:</b> if you switch computers, message WhatsApp again — the code is regenerated for the new ID.",
    h_uninstall="7. Uninstalling",
    uninstall="Run <b>Dezinstalare_CGConvertor.command</b> from the downloaded archive — it removes the app and all data files.",
    h_support="8. Support",
    support="For any question, message WhatsApp (button in the activation window) or open an Issue on GitHub.",
)

ES = dict(
    subtitle="Instrucciones de instalación y uso — Español",
    h_install="1. Instalación",
    install=[
        "Descarga y descomprime <b>CGConvertor-Mac.zip</b> desde la página de descarga o la sección Releases de GitHub.",
        "Doble clic en <b>CGConvertor.pkg</b> — paquete firmado y notarizado oficialmente por Apple, se instala directamente en /Applications, sin avisos de Gatekeeper y sin arrastrar nada manualmente.",
        "Sigue los pasos del instalador. Deberás aceptar los Términos y Condiciones para continuar.",
        "En el primer inicio, abre la app desde Launchpad o la carpeta Aplicaciones.",
    ],
    h_deps="2. Panel de Dependencias (el indicador rojo/verde)",
    deps_intro="En la parte superior de la ventana de la app verás un pequeño punto de color seguido de un texto breve. Te indica si la app está lista para funcionar o si todavía necesita un componente técnico (FFmpeg) para poder convertir archivos de vídeo.",
    deps_red_label="🔴 Punto rojo — “Dependencias faltantes”",
    deps_red_text="Significa que FFmpeg (el motor interno usado para la conversión) no se encontró o no funciona en este ordenador. El botón “Iniciar conversión” permanece desactivado hasta resolver esto — no hay ningún fallo, la app solo espera la instalación automática descrita a continuación.",
    deps_green_label="🟢 Punto verde — “Sistema listo”",
    deps_green_text="Significa que FFmpeg está instalado correctamente y funciona. Puedes añadir archivos e iniciar la conversión con normalidad, sin pasos adicionales.",
    deps_howto_label="Qué hacer exactamente cuando ves el punto rojo:",
    deps_howto=[
        "Haz clic en el indicador rojo en la parte superior de la ventana (junto al selector de idioma). Se abre una ventana nueva llamada “Comprobación y Dependencias del Sistema”.",
        "En esta ventana verás una lista de componentes, cada uno con su propio punto de color. El elemento “FFmpeg” mostrará un punto rojo y, junto a él, un botón con el texto “Descargar e Instalar Automáticamente”.",
        "Pulsa ese botón. La app descarga automáticamente, por internet, una versión independiente y autónoma de FFmpeg (no necesitas buscar ni instalar nada por tu cuenta) y la guarda dentro de la carpeta de datos propia de la app.",
        "Espera unos segundos, hasta un minuto aproximadamente, según la velocidad de tu conexión a internet — verás un mensaje de progreso mientras se descarga.",
        "Cuando termine la descarga, el punto junto a “FFmpeg” se vuelve verde automáticamente. Puedes cerrar la ventana (botón “Cerrar”) y volver a convertir archivos — el indicador principal en la parte superior de la app también se vuelve verde.",
    ],
    h_homebrew="3. Homebrew — guía paso a paso (opcional, solo Mac)",
    homebrew_intro="Homebrew es una herramienta opcional, recomendada solo si quieres un entorno de desarrollo completo en tu Mac (no es necesaria para convertir archivos — para eso basta con FFmpeg, instalado automáticamente arriba). Si en el panel de dependencias ves “Homebrew” con un punto naranja/rojo y la etiqueta “Opcional — No instalado”, sigue estos pasos si aun así quieres instalarlo:",
    homebrew_steps=[
        "En el panel “Comprobación y Dependencias del Sistema”, junto a la fila “Homebrew”, pulsa el botón “Copiar Comando”. Un comando de instalación se copia ahora automáticamente (de forma invisible) al portapapeles de tu ordenador.",
        "Abre la aplicación Terminal en tu Mac. La forma más fácil: pulsa a la vez las teclas <b>Cmd + Espacio</b>, escribe la palabra “Terminal” y pulsa Enter cuando aparezca en la lista.",
        "En la ventana negra que se abrió (Terminal), pega el comando copiado pulsando a la vez <b>Cmd + V</b>.",
        "Pulsa la tecla <b>Enter</b> para iniciar la instalación.",
        "Terminal te pedirá la contraseña de tu cuenta de Mac. Es normal que, mientras escribes la contraseña, no veas ninguna letra ni punto en la pantalla — Terminal oculta la contraseña por completo por seguridad, pero se está escribiendo en segundo plano. Escribe la contraseña y pulsa <b>Enter</b> de nuevo.",
        "Espera unos minutos mientras se instala Homebrew. Al terminar, puedes volver a CG Convertor y reabrir el panel de dependencias — la fila “Homebrew” debería aparecer ahora en verde, con la etiqueta “Detectado”.",
    ],
    homebrew_note="<b>Nota:</b> si no quieres instalar Homebrew, puedes omitir este paso por completo — la app funciona perfectamente para convertir archivos solo con FFmpeg (instalado automáticamente desde el panel de dependencias, paso 2 anterior).",
    h_usage="4. Flujo de conversión y acciones posteriores",
    usage_intro="Así es exactamente cómo se añaden archivos a la app y se convierten:",
    usage_add=[
        "Arrastra archivos de vídeo directamente desde Finder y suéltalos sobre la ventana de la app (Drag & Drop) — O pulsa el botón “Elegir archivos…” en la interfaz y selecciónalos en la ventana que se abre.",
        "Elige el modo de conversión (Rewrap o Transcodificar) y, si elegiste Transcodificar, el códec deseado de la lista.",
        "Pulsa el botón “Iniciar conversión” (solo activo cuando el indicador de dependencias está en verde).",
    ],
    usage=[
        "<b>⌘O</b> — añadir archivos · <b>⌘⏎</b> — iniciar conversión · <b>⌘K</b> — vaciar la lista.",
        "<b>Carpeta de destino</b> — por defecto, los archivos convertidos aparecen junto a los originales; puedes elegir otra carpeta.",
        "<b>Detener</b> — cancela la conversión en curso; los archivos sin procesar quedan en la lista, puedes reiniciar después.",
    ],
    postconv_label="Qué significan los botones junto a un archivo terminado con éxito:",
    postconv=[
        "<b>“Abrir archivo”</b> — abre el archivo convertido directamente en la app de reproducción de vídeo predeterminada de tu ordenador (por ejemplo QuickTime Player, o DaVinci Resolve si está configurado como predeterminado).",
        "<b>“Mostrar en Finder”</b> — abre una ventana de Finder en la carpeta de destino, con el archivo convertido ya seleccionado (resaltado), para que lo encuentres al instante sin buscar manualmente en carpetas.",
    ],
    h_modes="5. Modos de conversión",
    modes=[
        "<b>Rewrap</b> — rápido, sin re-codificación, solo cambia el contenedor. Conserva exactamente la calidad y el timecode original.",
        "<b>Transcodificar</b> — re-codificación completa a ProRes 422/422 HQ/422 LT/4444 o DNxHD/DNxHR HQ, conservando el timecode y la profundidad de bits del audio original.",
    ],
    h_trial="6. Licencia, Prueba y Donación",
    trial_intro="La app ofrece acceso completo y sin restricciones durante <b>15 días</b> desde el primer inicio. Al finalizar este período de prueba (Trial), las conversiones nuevas se detienen hasta que actives una licencia.",
    trial=[
        "Pulsa “Activar licencia” — se abre un mensaje de WhatsApp ya redactado, con el ID único de tu ordenador incluido.",
        "Envía ese mensaje. Cuando recibas el código de licencia como respuesta, vuelve a la app y pega el código en la ventana de activación.",
    ],
    donation_note="<b>Una donación, no un precio de lista:</b> 23 € — apoya el desarrollo continuo de la app y la plataforma, tras los 15 días de prueba gratuita. No es una venta — la activación se hace manualmente, por WhatsApp, en base a la donación.",
    trial_note="<b>Importante:</b> si cambias de ordenador, escribe de nuevo por WhatsApp — el código se regenera para el nuevo ID.",
    h_uninstall="7. Desinstalación",
    uninstall="Ejecuta <b>Dezinstalare_CGConvertor.command</b> desde el archivo descargado — elimina la app y todos los archivos de datos.",
    h_support="8. Soporte",
    support="Para cualquier pregunta, escribe por WhatsApp (botón en la ventana de activación) o abre un Issue en GitHub.",
)

doc = SimpleDocTemplate(
    OUT, pagesize=A4,
    leftMargin=2 * cm, rightMargin=2 * cm, topMargin=2.2 * cm, bottomMargin=2.2 * cm,
)

story = []
for i, lang in enumerate([RO, EN, ES]):
    story.extend(page(lang))
    if i < 2:
        story.append(PageBreak())

doc.build(story)
print("wrote", OUT)
