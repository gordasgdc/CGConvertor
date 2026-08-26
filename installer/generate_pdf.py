# Genereaza Instructiuni_Utilizare.pdf pentru CG Convertor, RO/EN/ES, cu
# reportlab. Foloseste Arial (nu Helvetica standard-14) pentru ca
# diacriticele romanesti (s-comma, t-comma) nu exista in WinAnsiEncoding-ul
# fonturilor PDF standard - fara asta, ș/ț ies ca patratele goale. Vezi
# istoricul din GDCVault/installer/generate_pdf.py pentru precedent.
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
    SimpleDocTemplate, Paragraph, ListFlowable, ListItem, PageBreak
)

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "Instructiuni_Utilizare.pdf")

pdfmetrics.registerFont(TTFont("Arial", "/System/Library/Fonts/Supplemental/Arial.ttf"))
pdfmetrics.registerFont(TTFont("Arial-Bold", "/System/Library/Fonts/Supplemental/Arial Bold.ttf"))
styles = getSampleStyleSheet()
ACCENT = colors.HexColor("#B96A1E")  # accentul Shift (cupru/amber), inchis pentru lizibilitate pe fundal alb
MUTED = colors.HexColor("#6a6a6a")
FAINT = colors.HexColor("#8a8a8a")
NOTE_BG = colors.HexColor("#FBF1E6")
NOTE_BORDER = colors.HexColor("#E8963C")

title_style = ParagraphStyle("TitleGDC", parent=styles["Title"], fontName="Arial-Bold",
                              fontSize=19, leading=22, spaceAfter=2, textColor=colors.HexColor("#1a1a1a"))
subtitle_style = ParagraphStyle("Subtitle", parent=styles["Normal"], fontName="Arial",
                                 fontSize=11, textColor=MUTED, spaceAfter=20)
h2_style = ParagraphStyle("H2", parent=styles["Heading2"], fontName="Arial-Bold",
                           fontSize=13, textColor=ACCENT, spaceBefore=16, spaceAfter=6)
body_style = ParagraphStyle("Body", parent=styles["Normal"], fontName="Arial",
                             fontSize=10.5, leading=15, textColor=colors.HexColor("#1a1a1a"), spaceAfter=6)
li_style = ParagraphStyle("Li", parent=body_style, spaceAfter=4)
note_style = ParagraphStyle("Note", parent=body_style, backColor=NOTE_BG,
                             borderColor=NOTE_BORDER, borderWidth=0, leftIndent=10, fontSize=10)
footer_style = ParagraphStyle("Footer", parent=styles["Normal"], fontName="Arial",
                               fontSize=8.5, textColor=FAINT, spaceBefore=20)


def bullets(items):
    return ListFlowable(
        [ListItem(Paragraph(it, li_style), leftIndent=14) for it in items],
        bulletType="bullet", start="•", leftIndent=14, spaceBefore=2, spaceAfter=8,
    )


def note(text):
    return Paragraph(text, note_style)


def page(d):
    flow = [Paragraph("CG Convertor", title_style), Paragraph(d["subtitle"], subtitle_style)]

    flow.append(Paragraph(d["h_install"], h2_style))
    flow.append(bullets(d["install"]))

    flow.append(Paragraph(d["h_usage"], h2_style))
    flow.append(Paragraph(d["usage_intro"], body_style))
    flow.append(bullets(d["usage"]))

    flow.append(Paragraph(d["h_modes"], h2_style))
    flow.append(bullets(d["modes"]))

    flow.append(Paragraph(d["h_trial"], h2_style))
    flow.append(Paragraph(d["trial_intro"], body_style))
    flow.append(bullets(d["trial"]))
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
    ],
    h_usage="2. Folosire rapidă",
    usage_intro="Trage fișiere video în fereastra aplicației (sau Alege fișiere…), alege modul de conversie și codecul, apoi Pornește conversia.",
    usage=[
        "<b>⌘O</b> — adaugă fișiere · <b>⌘⏎</b> — pornește conversia · <b>⌘K</b> — golește lista.",
        "<b>Folder destinație</b> — implicit, fișierele convertite apar lângă cele originale; poți alege alt folder.",
        "<b>Oprește</b> — anulează conversia în curs; fișierele neprocesate rămân în listă, poți reporni ulterior.",
    ],
    h_modes="3. Moduri de conversie",
    modes=[
        "<b>Rewrap</b> — rapid, fără re-encode, doar schimbă containerul. Păstrează exact calitatea și timecode-ul original.",
        "<b>Transcode</b> — re-encode complet în ProRes 422/422 HQ/422 LT/4444 sau DNxHD/DNxHR HQ, cu păstrarea timecode-ului și a bit depth-ului audio original.",
    ],
    h_trial="4. Trial și activare",
    trial_intro="Aplicația oferă acces complet timp de <b>15 zile</b> de la prima pornire. După expirare, conversiile noi se opresc până activezi o licență.",
    trial=[
        "Apasă „Activează licența” — se deschide un mesaj WhatsApp cu ID-ul unic al calculatorului tău.",
        "După ce primești codul de licență, lipește-l în fereastra de activare.",
    ],
    donation_note="<b>Donație, nu preț de listă:</b> 23 € — susține continuarea dezvoltării aplicației și a platformei. Nu e o vânzare — activarea se face manual, prin WhatsApp.",
    trial_note="<b>Important:</b> dacă schimbi calculatorul, scrie din nou pe WhatsApp — codul se regenerează pentru noul ID.",
    h_uninstall="5. Dezinstalare",
    uninstall="Rulează <b>Dezinstalare_CGConvertor.command</b> din arhiva descărcată — șterge aplicația și toate fișierele de date.",
    h_support="6. Suport",
    support="Pentru orice întrebare, scrie pe WhatsApp (buton în fereastra de activare) sau deschide un Issue pe GitHub.",
)

EN = dict(
    subtitle="Installation and usage instructions — English",
    h_install="1. Installation",
    install=[
        "Download and unzip <b>CGConvertor-Mac.zip</b> from the download page or the GitHub Releases section.",
        "Double-click <b>CGConvertor.pkg</b> — a package officially signed and notarized by Apple, installs directly into /Applications, no Gatekeeper warnings and nothing to drag manually.",
        "Follow the installer steps. You'll need to accept the Terms and Conditions to continue.",
    ],
    h_usage="2. Quick usage",
    usage_intro="Drag video files into the app window (or Choose files…), pick the conversion mode and codec, then Start conversion.",
    usage=[
        "<b>⌘O</b> — add files · <b>⌘⏎</b> — start conversion · <b>⌘K</b> — clear the list.",
        "<b>Destination folder</b> — by default, converted files appear next to the originals; you can choose another folder.",
        "<b>Stop</b> — cancels the running conversion; unprocessed files stay in the list, you can restart later.",
    ],
    h_modes="3. Conversion modes",
    modes=[
        "<b>Rewrap</b> — fast, no re-encode, just swaps the container. Keeps the exact original quality and timecode.",
        "<b>Transcode</b> — full re-encode into ProRes 422/422 HQ/422 LT/4444 or DNxHD/DNxHR HQ, preserving timecode and the original audio bit depth.",
    ],
    h_trial="4. Trial and activation",
    trial_intro="The app offers full access for <b>15 days</b> from the first launch. After that, new conversions stop until you activate a license.",
    trial=[
        "Tap “Activate license” — opens a WhatsApp message with your computer's unique ID.",
        "Once you receive the license code, paste it into the activation window.",
    ],
    donation_note="<b>A donation, not a list price:</b> €23 — supports ongoing development of the app and the platform. Not a sale — activation happens manually, over WhatsApp.",
    trial_note="<b>Important:</b> if you switch computers, message WhatsApp again — the code is regenerated for the new ID.",
    h_uninstall="5. Uninstalling",
    uninstall="Run <b>Dezinstalare_CGConvertor.command</b> from the downloaded archive — it removes the app and all data files.",
    h_support="6. Support",
    support="For any question, message WhatsApp (button in the activation window) or open an Issue on GitHub.",
)

ES = dict(
    subtitle="Instrucciones de instalación y uso — Español",
    h_install="1. Instalación",
    install=[
        "Descarga y descomprime <b>CGConvertor-Mac.zip</b> desde la página de descarga o la sección Releases de GitHub.",
        "Doble clic en <b>CGConvertor.pkg</b> — paquete firmado y notarizado oficialmente por Apple, se instala directamente en /Applications, sin avisos de Gatekeeper y sin arrastrar nada manualmente.",
        "Sigue los pasos del instalador. Deberás aceptar los Términos y Condiciones para continuar.",
    ],
    h_usage="2. Uso rápido",
    usage_intro="Arrastra archivos de vídeo a la ventana de la app (o Elegir archivos…), elige el modo de conversión y el códec, luego Iniciar conversión.",
    usage=[
        "<b>⌘O</b> — añadir archivos · <b>⌘⏎</b> — iniciar conversión · <b>⌘K</b> — vaciar la lista.",
        "<b>Carpeta de destino</b> — por defecto, los archivos convertidos aparecen junto a los originales; puedes elegir otra carpeta.",
        "<b>Detener</b> — cancela la conversión en curso; los archivos sin procesar quedan en la lista, puedes reiniciar después.",
    ],
    h_modes="3. Modos de conversión",
    modes=[
        "<b>Rewrap</b> — rápido, sin re-codificación, solo cambia el contenedor. Conserva exactamente la calidad y el timecode original.",
        "<b>Transcodificar</b> — re-codificación completa a ProRes 422/422 HQ/422 LT/4444 o DNxHD/DNxHR HQ, conservando el timecode y la profundidad de bits del audio original.",
    ],
    h_trial="4. Prueba y activación",
    trial_intro="La app ofrece acceso completo durante <b>15 días</b> desde el primer inicio. Después, las conversiones nuevas se detienen hasta que actives una licencia.",
    trial=[
        "Pulsa “Activar licencia” — se abre un mensaje de WhatsApp con el ID único de tu ordenador.",
        "Cuando recibas el código de licencia, pégalo en la ventana de activación.",
    ],
    donation_note="<b>Una donación, no un precio de lista:</b> 23 € — apoya el desarrollo continuo de la app y la plataforma. No es una venta — la activación se hace manualmente, por WhatsApp.",
    trial_note="<b>Importante:</b> si cambias de ordenador, escribe de nuevo por WhatsApp — el código se regenera para el nuevo ID.",
    h_uninstall="5. Desinstalación",
    uninstall="Ejecuta <b>Dezinstalare_CGConvertor.command</b> desde el archivo descargado — elimina la app y todos los archivos de datos.",
    h_support="6. Soporte",
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
