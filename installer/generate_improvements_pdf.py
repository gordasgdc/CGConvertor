# Genereaza "CGConvertor-Imbunatatiri-3.17.0.pdf" (doar RO) — rezumat uman al noutatilor din v3.17.0.
# Ruleaza: python3 installer/generate_improvements_pdf.py [calea_iesire]
import os, sys
from reportlab.lib.pagesizes import A4
from reportlab.lib.units import cm
from reportlab.lib import colors
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import SimpleDocTemplate, Paragraph, ListFlowable, ListItem, Spacer, Table, TableStyle, KeepTogether

VERSION = "3.17.0"
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), f"CGConvertor-Imbunatatiri-{VERSION}.pdf")
TITLE = f"CGConvertor — Îmbunătățiri în versiunea {VERSION}"

pdfmetrics.registerFont(TTFont("Arial", "/System/Library/Fonts/Supplemental/Arial.ttf"))
pdfmetrics.registerFont(TTFont("Arial-Bold", "/System/Library/Fonts/Supplemental/Arial Bold.ttf"))
from reportlab.pdfbase.pdfmetrics import registerFontFamily
registerFontFamily("Arial", normal="Arial", bold="Arial-Bold", italic="Arial", boldItalic="Arial-Bold")
st = getSampleStyleSheet()
ACCENT = colors.HexColor("#B96A1E"); MUTED = colors.HexColor("#6a6a6a"); INK = colors.HexColor("#1a1a1a")
NOTE_BG = colors.HexColor("#FBF1E6"); LINE = colors.HexColor("#D9C9B5")
title = ParagraphStyle("T", parent=st["Title"], fontName="Arial-Bold", fontSize=20, leading=24, textColor=INK, alignment=0, spaceAfter=4)
sub = ParagraphStyle("S", parent=st["Normal"], fontName="Arial", fontSize=11, textColor=MUTED, spaceAfter=16)
h2 = ParagraphStyle("H2", parent=st["Heading2"], fontName="Arial-Bold", fontSize=13.5, textColor=ACCENT, spaceBefore=16, spaceAfter=6)
body = ParagraphStyle("B", parent=st["Normal"], fontName="Arial", fontSize=10.5, leading=15, textColor=INK, spaceAfter=6)
li = ParagraphStyle("L", parent=body, spaceAfter=3)
cell = ParagraphStyle("C", parent=body, fontSize=9.4, leading=12.5, spaceAfter=0)
cellh = ParagraphStyle("CH", parent=cell, fontName="Arial-Bold")
note = ParagraphStyle("N", parent=body, backColor=NOTE_BG, borderPadding=7, leftIndent=8, rightIndent=8, fontSize=10, spaceBefore=6, spaceAfter=10)
foot = ParagraphStyle("F", parent=st["Normal"], fontName="Arial", fontSize=8.5, textColor=MUTED, spaceBefore=14)

def P(t, s=body): return Paragraph(t, s)
def bl(items): return ListFlowable([ListItem(P(i, li), leftIndent=14) for i in items], bulletType="bullet", start="•", leftIndent=14, spaceAfter=6)
def tbl(rows, widths):
    data = [[Paragraph(c, cellh if r == 0 else cell) for c in row] for r, row in enumerate(rows)]
    t = Table(data, colWidths=widths, repeatRows=1)
    t.setStyle(TableStyle([("BACKGROUND", (0,0), (-1,0), NOTE_BG), ("GRID", (0,0), (-1,-1), 0.5, LINE),
                           ("VALIGN", (0,0), (-1,-1), "TOP"), ("LEFTPADDING", (0,0), (-1,-1), 5), ("RIGHTPADDING", (0,0), (-1,-1), 5),
                           ("TOPPADDING", (0,0), (-1,-1), 4), ("BOTTOMPADDING", (0,0), (-1,-1), 4)]))
    return t

S = []
S += [P(TITLE, title), P("Ce aduce noua versiune, cum te ajută și ce limite are, spus direct.", sub)]

S += [P("1. Pe scurt", h2), bl([
    "Timecode-ul clipului (inclusiv drop-frame la Sony) trece în rezultat și este recitit din fișier ca să fie verificat.",
    "La clipurile Canon, pista de metadate a camerei rămâne în ProRes, iar DaVinci Resolve o citește singur.",
    "Poți extrage doar un interval dintr-un clip, cu imaginea, sunetul și timecode-ul rămase la locul lor.",
    "Fiecare clip are un raport: ce s-a păstrat, ce nu și de ce. Un clip cu metadate incomplete nu apare ca succes complet.",
    "Poți exporta un diagnostic local, fără chei, fără media și fără căi personale în clar.",
    "Proba nouă durează 5 zile; licențele sunt de 3, 6, 12 luni sau perpetue.",
])]

S += [P("2. Păstrarea metadatelor și compatibilitatea verificată", h2),
      P("Ce înseamnă fiecare cuvânt din raportul aplicației:"),
      bl(["<b>Detectat</b> — aplicația a găsit informația în fișierul sursă (de exemplu timecode, modelul camerei, profilul de imagine).",
          "<b>Încorporat</b> — informația a fost scrisă în fișierul ProRes rezultat.",
          "<b>Recuperabil</b> — informația scrisă poate fi citită înapoi din fișier; aplicația o verifică după conversie.",
          "<b>Folosit automat de Resolve</b> — DaVinci Resolve o preia singur la import, fără să faci nimic."]),
      P("Aceste patru lucruri sunt diferite. O informație poate fi încorporată și recuperabilă fără ca Resolve să o folosească automat."),
      P("Ce am verificat concret, în DaVinci Resolve Studio 21.2, într-un proiect Color Managed cu import proaspăt:"),
      tbl([["Cameră testată", "Timecode", "Piste native păstrate", "Resolve folosește automat"],
           ["Canon EOS C50", "da", "da (Canon „cndm”)", "da: informațiile camerei și spațiul de culoare (Canon Cinema Gamut / Canon Log 2)"],
           ["Sony A7 IV", "da, inclusiv drop-frame", "da (Sony „rtmd”)", "doar timecode-ul; profilul Log trebuie ales în Resolve"],
           ["Panasonic DC-S1", "da", "nu există piste native de păstrat", "doar timecode-ul; profilul V-Log trebuie ales în Resolve"]],
          [3.2*cm, 3.0*cm, 4.0*cm, 6.8*cm]),
      P("Rezultatele sunt pentru camerele și clipurile testate. Nu înseamnă că toată marca se comportă la fel, iar celelalte mărci (Nikon, Fujifilm, Blackmagic, ARRI, RED, DJI, GoPro, Apple) nu au fost verificate în aplicație.", note),
      P("Pistele native se păstrează doar când imaginea rămâne Log, rămâne în MOV și nu schimbi cadrele pe secundă. Dacă alegi o etichetă de culoare sau o transformare, aplicația spune în raport că pistele nu au fost păstrate și de ce. Aplicația nu transformă imaginea și nu etichetează drept Rec.709 o imagine rămasă Log.")]

S += [P("3. Extragerea intervalelor", h2),
      P("Cu pictograma foarfecă de pe un clip alegi începutul și sfârșitul pe cadre. Aplicația taie imaginea exact pe cadru, taie sunetul la aceeași durată, recalculează timecode-ul (începutul sursei plus decalajul, corect și pentru drop-frame) și taie pistele native la cadrele păstrate. La final verifică numărul de cadre așteptat."),
      P("Verificat pe clipuri Canon, Sony și Panasonic: numărul de cadre, timecode-ul și sunetul corespund intervalului ales. Intervalul se poate extrage la transcodare; la rewrap (copiere fără recodare) nu, pentru că rewrap-ul nu poate tăia exact pe cadru.")]

S += [P("4. Raportul pe clip, interfața și diagnosticul", h2),
      bl(["<b>Raport per clip</b> (butonul „Raport”): ce s-a detectat, ce s-a încorporat și verificat, ce necesită aplicare separată și ce nu s-a păstrat, fiecare cu motivul.",
          "<b>Interfață</b>: cardurile laterale au aceeași lățime, iar butonul principal rămâne vizibil și pe ferestre mici. Textele sunt în română, engleză și spaniolă.",
          "<b>Diagnostic</b>: Setări → „Exportă diagnosticul” creează un ZIP local. Nu conține chei, tokenuri, fișiere media sau căi în clar. Aplicația ține și un jurnal local cu rotire și scrie un singur rezultat final per conversie, inclusiv la anulare.",
          "<b>Sidecar</b>: lângă rezultat se scrie un fișier „.gdc-metadata.json” cu ce a fost detectat, pentru informațiile pe care Resolve nu le citește din fișier. Este un supliment, nu înlocuiește metadatele din ProRes.",
          "Comutatorul „Păstrează metadatele” din Setări îți permite să oprești păstrarea metadatelor."])]

S += [P("5. Proba de 5 zile și licențiere", h2),
      bl(["Proba nouă durează 5 zile. Probele începute înainte de această versiune își păstrează durata inițială.",
          "Licențele disponibile: 3 luni, 6 luni, 12 luni sau perpetuă.",
          "Din aplicație au dispărut donațiile și sumele.",
          "Activarea rămâne legată de calculatorul tău, ca până acum."])]

S += [P("6. Optimizări măsurate", h2),
      P("Pe un clip Canon 4K la 50 fps (10 secunde, ProRes HQ), scrierea timecode-ului la sfârșit durează sub o secundă din aproximativ nouă, deci nu a fost nevoie să rescriem acel pas. Decodarea hardware a fost încercată: a scurtat cu aproximativ un sfert conversia clipului HEVC testat, dar pe un clip Panasonic H.264 4:2:2 a dat o imagine diferită de decodarea software. Din acest motiv <b>rămâne dezactivată</b>. Nu promitem alte câștiguri de viteză.")]

S += [P("7. Limite cunoscute", h2),
      bl(["Resolve nu atribuie automat profilul Log la Sony A7 IV și Panasonic DC-S1 pe clipurile testate; alegi profilul în Resolve.",
          "Compatibilitatea e verificată doar pe camerele și clipurile menționate; alte camere sunt netestate, nu neapărat nesuportate.",
          "Pistele native nu se păstrează la etichete de culoare, schimbarea cadrelor pe secundă sau alt container decât MOV.",
          "Intervalul nu se poate extrage la rewrap.",
          "ExifTool este opțional și nu este inclus; fără el, unele câmpuri apar ca „necunoscut”.",
          "Versiunea pentru Windows nu a fost modificată în această versiune.",
          "Instalarea automată a actualizării cu parolă de administrator nu a fost verificată pe un Mac curat."])]
S += [P(f"CGConvertor {VERSION} · gordas.dev", foot)]

def numbered(c, d):
    c.saveState(); c.setFont("Arial", 8.5); c.setFillColor(MUTED)
    c.drawRightString(A4[0]-2*cm, 1.2*cm, f"Pagina {d.page}"); c.restoreState()
doc = SimpleDocTemplate(OUT, pagesize=A4, leftMargin=2*cm, rightMargin=2*cm, topMargin=2*cm, bottomMargin=2*cm, title=TITLE, author="Cristi Gordaș / GDC")
doc.build(S, onFirstPage=numbered, onLaterPages=numbered)
print(OUT)
