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

    # --- Selectie si conversie partiala (2026-09-06) ----------------------
    flow.append(Paragraph(d["h_selection"], h2_style))
    flow.append(Paragraph(d["selection_intro"], body_style))
    flow.append(bullets(d["selection_items"]))

    # --- Presetari de iesire ------------------------------------------------
    flow.append(Paragraph(d["h_presets"], h2_style))
    flow.append(Paragraph(d["presets_intro"], body_style))
    flow.append(numbered(d["presets_steps"]))

    # --- Watch Folders --------------------------------------------------
    flow.append(Paragraph(d["h_watchfolders"], h2_style))
    flow.append(Paragraph(d["watchfolders_intro"], body_style))
    flow.append(numbered(d["watchfolders_steps"]))
    flow.append(note(d["watchfolders_note"]))

    # --- Previzualizare LUT/LOG ------------------------------------------
    flow.append(Paragraph(d["h_player"], h2_style))
    flow.append(Paragraph(d["player_intro"], body_style))

    # --- Comparatie de metadate -------------------------------------------
    flow.append(Paragraph(d["h_compare"], h2_style))
    flow.append(Paragraph(d["compare_intro"], body_style))
    flow.append(numbered(d["compare_steps"]))
    flow.append(bullets(d["compare_features"]))

    # --- Genereaza raport ---------------------------------------------------
    flow.append(Paragraph(d["h_report"], h2_style))
    flow.append(Paragraph(d["report_intro"], body_style))

    for kind, val in d.get("extra", []):
        if kind == "h": flow.append(Paragraph(val, h2_style))
        elif kind == "h3": flow.append(h3(val))
        elif kind == "p": flow.append(Paragraph(val, body_style))
        elif kind == "b": flow.append(bullets(val))
        elif kind == "n": flow.append(numbered(val))
        elif kind == "note": flow.append(note(val))

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
        "Descarcă <b>CGConvertor-&lt;versiune&gt;.dmg</b> de pe pagina de descărcare, deschide-l și trage CGConvertor în Applications.",
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
    h_selection="5. Selecție și conversie parțială",
    selection_intro="Nu trebuie mereu să convertești toată coada. Bifează căsuța din stânga fiecărui rând ca să selectezi doar fișierele pe care le vrei:",
    selection_items=[
        "<b>„Selectează tot” / „Deselectează tot”</b> — butoane în bara de jos, lângă „Golește lista”, pentru a bifa/debifa dintr-un click toate fișierele din coadă.",
        "Dacă ai cel puțin un fișier bifat, butonul principal devine <b>„Pornește (N)”</b> și convertește DOAR fișierele selectate, lăsând restul neatinse în coadă.",
        "Dacă nu ai nimic bifat, „Pornește” convertește toată coada, ca înainte.",
    ],
    h_presets="6. Presetări de ieșire",
    presets_intro="O presetare salvează o combinație completă de format/codec, ca să nu o mai alegi manual de fiecare dată. Se editează din fereastra „Presetări”:",
    presets_steps=[
        "Apasă „Editează” lângă selectorul de presetări, din bara laterală.",
        "Adaugă o presetare nouă (nume liber, ales de tine) sau editează una existentă — alege containerul, codecul video, FPS-ul dorit și celelalte opțiuni.",
        "Salvează — presetarea apare imediat în lista din bara laterală, gata de folosit pentru conversiile următoare.",
    ],
    h_watchfolders="7. Watch Folders — conversie automată de folder",
    watchfolders_intro="Un Watch Folder e un folder pe care aplicația îl supraveghează constant — orice fișier video nou apărut acolo (de pe un card de memorie, dintr-un export automat etc.) e adăugat singur la coadă:",
    watchfolders_steps=[
        "Apasă „Adaugă folder” în panoul „Watch Folders” și alege folderul de urmărit.",
        "Dacă folderul are deja fișiere în el, aplicația te întreabă dacă vrei să le adaugi și pe acelea, sau doar pe cele care vor apărea de acum înainte.",
        "Comutatorul de lângă fiecare folder îl activează/dezactivează temporar, fără să-l ștergi din listă.",
    ],
    watchfolders_note="<b>Notă:</b> un Watch Folder rămâne activ doar cât timp aplicația CG Convertor este deschisă.",
    h_player="8. Previzualizare LUT/LOG în timp real",
    player_intro="Din meniul contextual al unui fișier (click-dreapta pe rândul lui), „Deschide previzualizarea” pornește un player video care redă fișierul cu un LUT 3D (.cube) aplicat live, direct pe imaginea originală — util ca să verifici rapid cum arată un clip Log cu un anumit LUT de vizualizare, fără să aștepți conversia efectivă.",
    h_compare="9. Comparație de metadate",
    compare_intro="Selectează 2 sau mai multe fișiere din coadă (Cmd+click sau Shift+click pe rânduri) și apasă butonul „Compară (N)” — se deschide o pagină completă, într-o filă de browser, cu TOATE metadatele tehnice ale fișierelor selectate, puse unele lângă altele:",
    compare_steps=[
        "Fiecare coloană din tabel arată un thumbnail al clipului deasupra numelui fișierului, ca să știi exact la ce fișier te uiți.",
        "Câmpul de căutare din partea de sus filtrează instant rândurile după numele parametrului tehnic căutat.",
    ],
    compare_features=[
        "„Evidențiază diferențele” — colorează rândurile unde fișierele NU au aceeași valoare.",
        "„Ascunde identice” — arată doar parametrii care diferă între fișiere, util când compari zeci de parametri și vrei să vezi rapid doar ce nu se potrivește.",
    ],
    h_report="10. Generează raport",
    report_intro="Butonul „Generează raport” din bara de jos creează o pagină HTML cu un rezumat al întregii cozi curente — thumbnail, nume fișier, metadate de bază și statusul conversiei pentru fiecare fișier — utilă ca dovadă/jurnal al unei sesiuni de conversie, trimisă mai departe pe email sau păstrată ca arhivă.",
    h_modes="11. Moduri de conversie",
    modes=[
        "<b>Rewrap</b> — rapid, fără re-encode, doar schimbă containerul. Păstrează exact calitatea și timecode-ul original.",
        "<b>Transcode</b> — re-encode complet în ProRes 422/422 HQ/422 LT/4444 sau DNxHD/DNxHR HQ, cu păstrarea timecode-ului și a bit depth-ului audio original.",
    ],
    h_trial="12. Licență, Trial și Donație",
    trial_intro="Aplicația oferă acces complet, fără restricții, timp de <b>15 zile</b> de la prima pornire. După expirarea acestei perioade de probă (Trial), conversiile noi se opresc până activezi o licență.",
    trial=[
        "Apasă „Activează licența” — se deschide un mesaj WhatsApp pre-completat, cu ID-ul unic al calculatorului tău deja inclus.",
        "Trimite acel mesaj. După ce primești codul de licență ca răspuns, revino în aplicație și lipește codul în fereastra de activare.",
    ],
    donation_note="<b>Donație:</b> 23 € — susține continuarea dezvoltării aplicației și a platformei, după cele 15 zile de Trial gratuit. Nu este o vânzare — activarea se face manual, prin WhatsApp, pe baza donației.",
    trial_note="<b>Important:</b> dacă schimbi calculatorul, scrie din nou pe WhatsApp — codul se regenerează pentru noul ID.",
    h_uninstall="13. Dezinstalare",
    uninstall="Închide aplicația și mut-o din Applications în Coș. Datele rămân în <b>~/Library/Application Support/CGConvertor</b> și se pot șterge manual.",
    h_support="14. Suport",
    support="Pentru orice întrebare, scrie pe WhatsApp (buton în fereastra de activare) sau deschide un Issue pe GitHub.",
)

EN = dict(
    subtitle="Installation and usage instructions — English",
    h_install="1. Installation",
    install=[
        "Download <b>CGConvertor-&lt;version&gt;.dmg</b> from the download page, open it and drag CGConvertor into Applications.",
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
    h_selection="5. Selection and partial conversion",
    selection_intro="You don't always have to convert the whole queue. Check the box on the left of each row to select only the files you want:",
    selection_items=[
        "<b>“Select All” / “Deselect All”</b> — buttons in the bottom bar, next to “Clear list”, to check/uncheck every file in the queue with one click.",
        "With at least one file checked, the main button becomes <b>“Start (N)”</b> and converts ONLY the selected files, leaving the rest untouched in the queue.",
        "With nothing checked, “Start” converts the whole queue, as before.",
    ],
    h_presets="6. Output presets",
    presets_intro="A preset saves a complete format/codec combination so you don't have to pick it manually every time. Edit them from the “Presets” window:",
    presets_steps=[
        "Press “Edit” next to the preset picker in the sidebar.",
        "Add a new preset (any name you like) or edit an existing one — pick the container, video codec, desired FPS, and the other options.",
        "Save — the preset appears immediately in the sidebar list, ready to use for the next conversions.",
    ],
    h_watchfolders="7. Watch Folders — automatic folder conversion",
    watchfolders_intro="A Watch Folder is a folder the app constantly monitors — any new video file that appears there (from a memory card, an automatic export, etc.) is added to the queue on its own:",
    watchfolders_steps=[
        "Press “Add folder” in the “Watch Folders” panel and pick the folder to watch.",
        "If the folder already has files in it, the app asks whether you want to add those too, or only the ones that will appear from now on.",
        "The toggle next to each folder temporarily enables/disables it without removing it from the list.",
    ],
    watchfolders_note="<b>Note:</b> a Watch Folder stays active only while the CG Convertor app is open.",
    h_player="8. Real-time LUT/LOG preview",
    player_intro="From a file's context menu (right-click on its row), “Open preview” launches a video player that plays the file with a 3D LUT (.cube) applied live, right on top of the original footage — useful to quickly check how a Log clip looks with a given viewing LUT, without waiting for the actual conversion.",
    h_compare="9. Metadata comparison",
    compare_intro="Select 2 or more files in the queue (Cmd+click or Shift+click on rows) and press the “Compare (N)” button — a full page opens in a browser tab, with ALL the technical metadata of the selected files laid out side by side:",
    compare_steps=[
        "Each column in the table shows a thumbnail of the clip above the filename, so you always know which file you're looking at.",
        "The search field at the top instantly filters rows by the technical parameter name you're searching for.",
    ],
    compare_features=[
        "“Highlight differences” — colors the rows where the files don't share the same value.",
        "“Hide identical” — shows only the parameters that differ between files, useful when comparing dozens of parameters and you want to see just what doesn't match.",
    ],
    h_report="10. Generate report",
    report_intro="The “Generate report” button in the bottom bar creates an HTML page summarizing the entire current queue — thumbnail, filename, basic metadata, and conversion status for each file — useful as proof/log of a conversion session, to send by email or keep as an archive.",
    h_modes="11. Conversion modes",
    modes=[
        "<b>Rewrap</b> — fast, no re-encode, just swaps the container. Keeps the exact original quality and timecode.",
        "<b>Transcode</b> — full re-encode into ProRes 422/422 HQ/422 LT/4444 or DNxHD/DNxHR HQ, preserving timecode and the original audio bit depth.",
    ],
    h_trial="12. License, Trial and Donation",
    trial_intro="The app offers full, unrestricted access for <b>15 days</b> from the first launch. After this Trial period expires, new conversions stop until you activate a license.",
    trial=[
        "Tap “Activate license” — opens a pre-filled WhatsApp message with your computer's unique ID already included.",
        "Send that message. Once you receive the license code as a reply, go back to the app and paste the code into the activation window.",
    ],
    donation_note="<b>A donation, not a list price:</b> €23 — supports ongoing development of the app and the platform, after the 15-day free Trial. Not a sale — activation happens manually, over WhatsApp, based on the donation.",
    trial_note="<b>Important:</b> if you switch computers, message WhatsApp again — the code is regenerated for the new ID.",
    h_uninstall="13. Uninstalling",
    uninstall="Quit the app and move it from Applications to the Trash. Data stays in <b>~/Library/Application Support/CGConvertor</b> and can be deleted manually.",
    h_support="14. Support",
    support="For any question, message WhatsApp (button in the activation window) or open an Issue on GitHub.",
)

ES = dict(
    subtitle="Instrucciones de instalación y uso — Español",
    h_install="1. Instalación",
    install=[
        "Descarga <b>CGConvertor-&lt;versión&gt;.dmg</b> desde la página de descarga, ábrelo y arrastra CGConvertor a Applications.",
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
    h_selection="5. Selección y conversión parcial",
    selection_intro="No siempre tienes que convertir toda la cola. Marca la casilla a la izquierda de cada fila para seleccionar solo los archivos que quieres:",
    selection_items=[
        "<b>“Seleccionar todo” / “Deseleccionar todo”</b> — botones en la barra inferior, junto a “Vaciar lista”, para marcar/desmarcar con un clic todos los archivos de la cola.",
        "Con al menos un archivo marcado, el botón principal se convierte en <b>“Iniciar (N)”</b> y convierte SOLO los archivos seleccionados, dejando el resto intacto en la cola.",
        "Sin nada marcado, “Iniciar” convierte toda la cola, como antes.",
    ],
    h_presets="6. Preajustes de salida",
    presets_intro="Un preajuste guarda una combinación completa de formato/códec, para no tener que elegirla manualmente cada vez. Se edita desde la ventana “Preajustes”:",
    presets_steps=[
        "Pulsa “Editar” junto al selector de preajustes, en la barra lateral.",
        "Añade un preajuste nuevo (nombre libre, el que quieras) o edita uno existente — elige el contenedor, el códec de vídeo, los FPS deseados y las demás opciones.",
        "Guarda — el preajuste aparece de inmediato en la lista de la barra lateral, listo para usar en las próximas conversiones.",
    ],
    h_watchfolders="7. Watch Folders — conversión automática de carpeta",
    watchfolders_intro="Un Watch Folder es una carpeta que la app vigila constantemente — cualquier archivo de vídeo nuevo que aparezca allí (de una tarjeta de memoria, una exportación automática, etc.) se añade solo a la cola:",
    watchfolders_steps=[
        "Pulsa “Añadir carpeta” en el panel “Watch Folders” y elige la carpeta a vigilar.",
        "Si la carpeta ya tiene archivos, la app te pregunta si quieres añadir también esos, o solo los que aparezcan a partir de ahora.",
        "El interruptor junto a cada carpeta la activa/desactiva temporalmente, sin eliminarla de la lista.",
    ],
    watchfolders_note="<b>Nota:</b> un Watch Folder permanece activo solo mientras la app CG Convertor esté abierta.",
    h_player="8. Previsualización LUT/LOG en tiempo real",
    player_intro="Desde el menú contextual de un archivo (clic derecho sobre su fila), “Abrir previsualización” inicia un reproductor de vídeo que reproduce el archivo con un LUT 3D (.cube) aplicado en directo, sobre la imagen original — útil para comprobar rápidamente cómo se ve un clip Log con un LUT de visualización concreto, sin esperar a la conversión real.",
    h_compare="9. Comparación de metadatos",
    compare_intro="Selecciona 2 o más archivos en la cola (Cmd+clic o Mayús+clic sobre las filas) y pulsa el botón “Comparar (N)” — se abre una página completa, en una pestaña del navegador, con TODOS los metadatos técnicos de los archivos seleccionados, uno junto a otro:",
    compare_steps=[
        "Cada columna de la tabla muestra una miniatura del clip encima del nombre del archivo, para que siempre sepas qué archivo estás viendo.",
        "El campo de búsqueda de arriba filtra al instante las filas según el nombre del parámetro técnico buscado.",
    ],
    compare_features=[
        "“Resaltar diferencias” — colorea las filas donde los archivos no comparten el mismo valor.",
        "“Ocultar idénticos” — muestra solo los parámetros que difieren entre archivos, útil al comparar decenas de parámetros y querer ver rápido solo lo que no coincide.",
    ],
    h_report="10. Generar informe",
    report_intro="El botón “Generar informe” de la barra inferior crea una página HTML con un resumen de toda la cola actual — miniatura, nombre de archivo, metadatos básicos y estado de conversión de cada archivo — útil como prueba/registro de una sesión de conversión, para enviar por correo o guardar como archivo.",
    h_modes="11. Modos de conversión",
    modes=[
        "<b>Rewrap</b> — rápido, sin re-codificación, solo cambia el contenedor. Conserva exactamente la calidad y el timecode original.",
        "<b>Transcodificar</b> — re-codificación completa a ProRes 422/422 HQ/422 LT/4444 o DNxHD/DNxHR HQ, conservando el timecode y la profundidad de bits del audio original.",
    ],
    h_trial="12. Licencia, Prueba y Donación",
    trial_intro="La app ofrece acceso completo y sin restricciones durante <b>15 días</b> desde el primer inicio. Al finalizar este período de prueba (Trial), las conversiones nuevas se detienen hasta que actives una licencia.",
    trial=[
        "Pulsa “Activar licencia” — se abre un mensaje de WhatsApp ya redactado, con el ID único de tu ordenador incluido.",
        "Envía ese mensaje. Cuando recibas el código de licencia como respuesta, vuelve a la app y pega el código en la ventana de activación.",
    ],
    donation_note="<b>Una donación, no un precio de lista:</b> 23 € — apoya el desarrollo continuo de la app y la plataforma, tras los 15 días de prueba gratuita. No es una venta — la activación se hace manualmente, por WhatsApp, en base a la donación.",
    trial_note="<b>Importante:</b> si cambias de ordenador, escribe de nuevo por WhatsApp — el código se regenera para el nuevo ID.",
    h_uninstall="13. Desinstalación",
    uninstall="Cierra la app y muévela de Applications a la Papelera. Los datos quedan en <b>~/Library/Application Support/CGConvertor</b> y se pueden borrar a mano.",
    h_support="14. Soporte",
    support="Para cualquier pregunta, escribe por WhatsApp (botón en la ventana de activación) o abre un Issue en GitHub.",
)


# ---- v3.17.0: metadate, interval, diagnostic, licențiere fără donații ----
RO.update(
    install=[
        "Descarcă <b>CGConvertor-&lt;versiune&gt;.dmg</b> de pe pagina oficială, deschide-l și trage CGConvertor în folderul Applications. Pachetul este semnat Developer ID și notarizat de Apple.",
        "La prima pornire, deschide aplicația din Launchpad sau din Applications.",
        "Actualizările apar în aplicație (fereastră cu „Actualizează acum” / „Mai târziu”); instalarea o face aplicația, nu un browser.",
    ],
    extra=[
        ("h", "10. Păstrarea metadatelor sursei"),
        ("p", "Când convertești, CG Convertor încearcă să păstreze în fișierul rezultat ce poate fi recuperat din sursă, și îți spune exact ce s-a păstrat și ce nu. Comutatorul „Păstrează metadatele” este în Setări (implicit pornit)."),
        ("h3", "Ce se păstrează"),
        ("b", [
            "<b>Timecode-ul</b>, inclusiv drop-frame (Sony), scris și apoi recitit din fișierul rezultat.",
            "<b>Pistele native ale camerei</b> (Canon: date per cadru „cndm”; Sony: „rtmd”), copiate fără modificare în MOV-ul rezultat, tăiate exact la cadrele convertite și verificate prin sumă de control. Se păstrează DOAR când imaginea rămâne în Log.",
            "<b>Etichetele de culoare ale containerului</b> nu afirmă Rec.709 când imaginea e Log: profilul real al capturii (gamut + curbă) se vede în raport și în sidecar, nu într-o etichetă falsă.",
            "<b>Fișier sidecar</b> „.gdc-metadata.json” lângă rezultat, cu fișa sursei, pentru GDC Metadata sau puntea Resolve.",
        ]),
        ("h3", "Când NU se păstrează pistele native"),
        ("b", [
            "Ai ales o etichetă de culoare (Rec.709/Rec.2020): profilul camerei nu mai descrie imaginea declarată.",
            "Ai schimbat cadrele/s: datele per cadru nu s-ar mai potrivi.",
            "Containerul rezultat nu este MOV.",
            "Raportul afișează motivul fiecărei omisiuni. Dacă scrierea sau verificarea eșuează, videoul rămâne valid, dar clipul apare cu avertisment, nu ca succes complet.",
        ]),
        ("h3", "Raportul per clip (butonul „Raport”)"),
        ("b", [
            "<b>Detectat în sursă</b> — citit din date native, etichetă a producătorului sau dedus dintr-o regulă (se spune care).",
            "<b>Încorporat și verificat</b> — scris în fișier și recitit independent.",
            "<b>Necesită aplicare separată</b> — există doar în sidecar (ex. obiectiv, expunere).",
            "<b>Necunoscut</b> — nu s-a putut citi; nimic nu se presupune din model sau din numele fișierului.",
            "<b>Nepăstrat</b> — cu motiv.",
        ]),
        ("h3", "Ce citește DaVinci Resolve (demonstrat pe probe)"),
        ("b", [
            "Testat în proiecte Resolve izolate (Resolve 21.2): pistele Canon (EOS C50) din ProRes sunt citite automat — metadate informative și, în proiecte Color Managed v2, Input Color Space.",
            "Testat pe Sony A7 IV și Panasonic DC-S1: Resolve citește doar timecode-ul; pistele native păstrate nu sunt folosite de Resolve, deci profilul se aplică prin sidecar sau punte.",
            "Aceste rezultate sunt pentru camerele testate, nu pentru toată marca și nu sunt o verificare a fiecărui clip.",
        ]),
        ("note", "<b>Opțional:</b> ExifTool (instalat prin Homebrew) poate completa mai multe câmpuri. Aplicația funcționează și fără el; ce nu poate fi citit apare ca „necunoscut” în raport."),
        ("h", "11. Extragerea unui interval dintr-un clip"),
        ("n", [
            "Apasă pictograma foarfecă de pe rândul clipului (înainte de pornire).",
            "Scrie începutul și sfârșitul: secunde („90”), „mm:ss” sau „hh:mm:ss.zecimale”. Sfârșit gol = până la capăt.",
            "Apasă „Aplică”. Foarfeca devine colorată. „Clip întreg” anulează intervalul.",
        ]),
        ("b", [
            "Limitele se aliniază la cadre. Intervalul funcționează la transcodare; rewrap-ul (fără re-encode) nu taie exact pe cadru și îl refuză cu mesaj.",
            "Imaginea și sunetul rezultatului pornesc din punctul ales; timecode-ul = timecode-ul sursei + decalajul (calculat și pentru drop-frame); pistele native sunt tăiate la același interval.",
            "Verificat pe Canon, Sony și Panasonic: numărul exact de cadre, timecode, primul și ultimul cadru față de sursă, iar la Canon sunetul PCM e identic bit cu bit cu sursa. Containerul poate avea sunetul cu până la o fracțiune de cadru (aprox. 8 ms) mai lung, din granularitatea audio.",
        ]),
        ("h", "12. Diagnostic și jurnal"),
        ("b", [
            "Jurnalul local e în <b>~/Library/Logs/CGConvertor/</b>, cu rotire la 5 MB; fiecare conversie are un ID și un singur rezultat final (terminat, eșuat sau anulat).",
            "<b>Setări → „Exportă diagnosticul”</b> creează un ZIP local, fără chei de licență, tokenuri, fișiere media sau căi în clar (căile sunt anonimizate). Nu se trimite nimic automat; tu decizi dacă îl trimiți.",
            "„Deschide folderul de loguri” și ID-ul sesiunii sunt în aceeași fereastră.",
        ]),
        ("note", "<b>Decodare hardware:</b> CG Convertor nu folosește decodarea hardware pentru surse. Într-un test, pe un clip Panasonic H.264 4:2:2 rezultatul diferă de decodarea software, deci rămâne dezactivată."),
    ],
    h_modes="13. Moduri de conversie",
    h_trial="14. Licență și probă",
    trial_intro="Aplicația oferă acces complet timp de <b>5 zile</b> de la prima pornire (probele deja începute își păstrează durata inițială, de exemplu 15 zile). După aceea, pornirea conversiilor cere o licență. Licențele sunt de 3, 6 sau 12 luni sau perpetue, legate de calculatorul tău, și rămân valide la actualizări.",
    donation_note="<b>Licență:</b> aplicația nu folosește donații. Condițiile de obținere a licenței ți se comunică pe canalul de contact; nu sunt afișate sume în aplicație.",
    trial_note="<b>Important:</b> dacă schimbi calculatorul, scrie din nou — licența se regenerează pentru noul calculator.",
    h_uninstall="15. Dezinstalare",
    h_support="16. Suport",
)
EN.update(
    install=[
        "Download <b>CGConvertor-&lt;version&gt;.dmg</b> from the official page, open it and drag CGConvertor to the Applications folder. The package is Developer ID signed and notarized by Apple.",
        "On first launch, open the app from Launchpad or Applications.",
        "Updates appear inside the app (“Update now” / “Later” dialog); the app installs them, not a browser.",
    ],
    extra=[
        ("h", "10. Keeping the source metadata"),
        ("p", "When you convert, CG Convertor tries to keep in the result whatever can be recovered from the source, and tells you exactly what was kept and what was not. The “Keep metadata” switch is in Settings (on by default)."),
        ("h3", "What is kept"),
        ("b", [
            "<b>Timecode</b>, including drop-frame (Sony), written and then re-read from the result file.",
            "<b>The camera's native tracks</b> (Canon: per-frame data “cndm”; Sony: “rtmd”), copied unchanged into the resulting MOV, cut to exactly the converted frames and verified by checksum. Kept ONLY while the image stays Log.",
            "<b>Container colour tags</b> do not claim Rec.709 when the image is Log: the real capture profile (gamut + curve) is shown in the report and the sidecar, not in a false label.",
            "<b>A “.gdc-metadata.json” sidecar</b> next to the result, with the source sheet, for GDC Metadata or the Resolve bridge.",
        ]),
        ("h3", "When native tracks are NOT kept"),
        ("b", [
            "You chose a colour label (Rec.709/Rec.2020): the camera profile no longer describes the declared image.",
            "You changed the frame rate: per-frame data would no longer match.",
            "The output container is not MOV.",
            "The report states the reason for each omission. If writing or verification fails, the video is still valid but the clip shows a warning, not full success.",
        ]),
        ("h3", "The per-clip report (“Report” button)"),
        ("b", [
            "<b>Detected in source</b> — read from native data, a manufacturer label, or deduced from a rule (it says which).",
            "<b>Embedded and verified</b> — written to the file and independently re-read.",
            "<b>Needs separate application</b> — exists only in the sidecar (e.g. lens, exposure).",
            "<b>Unknown</b> — could not be read; nothing is assumed from model or file name.",
            "<b>Not kept</b> — with the reason.",
        ]),
        ("h3", "What DaVinci Resolve reads (demonstrated on probes)"),
        ("b", [
            "Tested in isolated Resolve projects (Resolve 21.2): Canon (EOS C50) tracks inside ProRes are read automatically — informative metadata and, in Color Managed v2 projects, Input Color Space.",
            "Tested on Sony A7 IV and Panasonic DC-S1: Resolve reads only the timecode; the preserved native tracks are not used by Resolve, so the profile is applied through the sidecar or the bridge.",
            "These results are for the cameras tested, not for a whole brand, and are not a per-clip verification.",
        ]),
        ("note", "<b>Optional:</b> ExifTool (installed via Homebrew) can fill in more fields. The app also works without it; whatever cannot be read shows as “unknown” in the report."),
        ("h", "11. Extracting an interval from a clip"),
        ("n", [
            "Click the scissors icon on the clip's row (before starting).",
            "Enter start and end: seconds (“90”), “mm:ss” or “hh:mm:ss.fraction”. Empty end = to the end.",
            "Click “Apply”. The scissors turn coloured. “Whole clip” clears the interval.",
        ]),
        ("b", [
            "Limits snap to frames. Intervals work when transcoding; rewrap (no re-encode) cannot cut frame-accurately and refuses with a message.",
            "Picture and audio of the result start at the chosen point; timecode = source timecode + offset (also computed for drop-frame); native tracks are cut to the same interval.",
            "Checked on Canon, Sony and Panasonic: exact frame count, timecode, first and last frame against the source, and on Canon the PCM audio is bit-identical to the source. The container's audio may be up to a fraction of a frame (about 8 ms) longer, from audio granularity.",
        ]),
        ("h", "12. Diagnostics and log"),
        ("b", [
            "The local log is in <b>~/Library/Logs/CGConvertor/</b>, rotating at 5 MB; every conversion has an ID and a single final outcome (finished, failed or cancelled).",
            "<b>Settings → “Export diagnostics”</b> creates a local ZIP with no licence keys, tokens, media files or plain paths (paths are anonymised). Nothing is sent automatically; you decide whether to send it.",
            "“Open log folder” and the session ID are in the same window.",
        ]),
        ("note", "<b>Hardware decoding:</b> CG Convertor does not use hardware decoding for sources. In one test, on a Panasonic H.264 4:2:2 clip the result differed from software decoding, so it stays disabled."),
    ],
    h_modes="13. Conversion modes",
    h_trial="14. Licence and trial",
    trial_intro="The app gives full access for <b>5 days</b> from first launch (trials already started keep their original length, e.g. 15 days). After that, starting conversions needs a licence. Licences are 3, 6 or 12 months or perpetual, tied to your computer, and stay valid across updates.",
    donation_note="<b>Licence:</b> the app does not use donations. The terms for obtaining a licence are given on the contact channel; no amounts are shown in the app.",
    trial_note="<b>Important:</b> if you change computer, write again — the licence is regenerated for the new computer.",
    h_uninstall="15. Uninstall",
    h_support="16. Support",
)
ES.update(
    install=[
        "Descarga <b>CGConvertor-&lt;versión&gt;.dmg</b> de la página oficial, ábrelo y arrastra CGConvertor a la carpeta Applications. El paquete está firmado con Developer ID y notarizado por Apple.",
        "En el primer arranque, abre la app desde Launchpad o Applications.",
        "Las actualizaciones aparecen dentro de la app (diálogo «Actualizar ahora» / «Más tarde»); las instala la app, no un navegador.",
    ],
    extra=[
        ("h", "10. Conservación de los metadatos de origen"),
        ("p", "Al convertir, CG Convertor intenta conservar en el resultado lo que se pueda recuperar del origen y te dice exactamente qué se conservó y qué no. El interruptor «Conservar metadatos» está en Ajustes (activado por defecto)."),
        ("h3", "Qué se conserva"),
        ("b", [
            "<b>El timecode</b>, incluido drop-frame (Sony), escrito y vuelto a leer del archivo resultante.",
            "<b>Las pistas nativas de la cámara</b> (Canon: datos por fotograma «cndm»; Sony: «rtmd»), copiadas sin cambios al MOV resultante, recortadas exactamente a los fotogramas convertidos y verificadas con suma de control. Solo se conservan MIENTRAS la imagen sigue en Log.",
            "<b>Las etiquetas de color del contenedor</b> no afirman Rec.709 cuando la imagen es Log: el perfil real de captura (gamut + curva) aparece en el informe y el sidecar, no en una etiqueta falsa.",
            "<b>Un sidecar «.gdc-metadata.json»</b> junto al resultado, con la ficha del origen, para GDC Metadata o el puente de Resolve.",
        ]),
        ("h3", "Cuándo NO se conservan las pistas nativas"),
        ("b", [
            "Elegiste una etiqueta de color (Rec.709/Rec.2020): el perfil de la cámara ya no describe la imagen declarada.",
            "Cambiaste los fotogramas/s: los datos por fotograma ya no coincidirían.",
            "El contenedor de salida no es MOV.",
            "El informe indica el motivo de cada omisión. Si la escritura o la verificación fallan, el vídeo sigue siendo válido, pero el clip muestra una advertencia, no un éxito completo.",
        ]),
        ("h3", "El informe por clip (botón «Informe»)"),
        ("b", [
            "<b>Detectado en el origen</b> — leído de datos nativos, de una etiqueta del fabricante o deducido por una regla (se indica cuál).",
            "<b>Incorporado y verificado</b> — escrito en el archivo y releído de forma independiente.",
            "<b>Requiere aplicación aparte</b> — solo existe en el sidecar (p. ej. objetivo, exposición).",
            "<b>Desconocido</b> — no se pudo leer; no se supone nada por el modelo ni por el nombre.",
            "<b>No conservado</b> — con el motivo.",
        ]),
        ("h3", "Qué lee DaVinci Resolve (demostrado en pruebas)"),
        ("b", [
            "Probado en proyectos Resolve aislados (Resolve 21.2): las pistas Canon (EOS C50) dentro de ProRes se leen automáticamente — metadatos informativos y, en proyectos Color Managed v2, Input Color Space.",
            "Probado en Sony A7 IV y Panasonic DC-S1: Resolve solo lee el timecode; las pistas nativas conservadas no las usa Resolve, así que el perfil se aplica mediante el sidecar o el puente.",
            "Estos resultados son para las cámaras probadas, no para toda la marca, y no son una verificación clip a clip.",
        ]),
        ("note", "<b>Opcional:</b> ExifTool (instalado con Homebrew) puede completar más campos. La app también funciona sin él; lo que no se pueda leer aparece como «desconocido» en el informe."),
        ("h", "11. Extraer un intervalo de un clip"),
        ("n", [
            "Pulsa el icono de tijeras en la fila del clip (antes de iniciar).",
            "Escribe inicio y fin: segundos («90»), «mm:ss» o «hh:mm:ss.fracción». Fin vacío = hasta el final.",
            "Pulsa «Aplicar». Las tijeras se colorean. «Clip completo» borra el intervalo.",
        ]),
        ("b", [
            "Los límites se ajustan a fotogramas. Los intervalos funcionan al transcodificar; el rewrap (sin recodificar) no corta con precisión de fotograma y lo rechaza con un mensaje.",
            "Imagen y audio del resultado empiezan en el punto elegido; timecode = timecode del origen + desfase (calculado también para drop-frame); las pistas nativas se recortan al mismo intervalo.",
            "Verificado en Canon, Sony y Panasonic: número exacto de fotogramas, timecode, primer y último fotograma frente al origen y, en Canon, el audio PCM es idéntico bit a bit al origen. El audio del contenedor puede ser hasta una fracción de fotograma (unos 8 ms) más largo, por la granularidad del audio.",
        ]),
        ("h", "12. Diagnóstico y registro"),
        ("b", [
            "El registro local está en <b>~/Library/Logs/CGConvertor/</b>, con rotación a 5 MB; cada conversión tiene un ID y un único resultado final (terminada, fallida o cancelada).",
            "<b>Ajustes → «Exportar diagnóstico»</b> crea un ZIP local sin claves de licencia, tokens, archivos multimedia ni rutas en claro (las rutas se anonimizan). No se envía nada automáticamente; tú decides si lo envías.",
            "«Abrir carpeta de registros» y el ID de sesión están en la misma ventana.",
        ]),
        ("note", "<b>Decodificación por hardware:</b> CG Convertor no usa decodificación por hardware para los orígenes. En una prueba, con un clip Panasonic H.264 4:2:2 el resultado difería de la decodificación por software, por lo que permanece desactivada."),
    ],
    h_modes="13. Modos de conversión",
    h_trial="14. Licencia y prueba",
    trial_intro="La app ofrece acceso completo durante <b>5 días</b> desde el primer arranque (las pruebas ya iniciadas conservan su duración original, p. ej. 15 días). Después, iniciar conversiones requiere una licencia. Las licencias son de 3, 6 o 12 meses o perpetuas, ligadas a tu ordenador y siguen válidas tras las actualizaciones.",
    donation_note="<b>Licencia:</b> la app no usa donaciones. Las condiciones para obtener una licencia se comunican por el canal de contacto; la app no muestra importes.",
    trial_note="<b>Importante:</b> si cambias de ordenador, escribe de nuevo — la licencia se regenera para el nuevo ordenador.",
    h_uninstall="15. Desinstalar",
    h_support="16. Soporte",
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
