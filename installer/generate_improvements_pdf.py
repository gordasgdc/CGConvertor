# Genereaza "CGConvertor-Imbunatatiri-3.17.0.pdf" (doar RO) — rezumat uman al noutatilor din v3.18.0.
# Ruleaza: python3 installer/generate_improvements_pdf.py [calea_iesire]
import os, sys
from reportlab.lib.pagesizes import A4
from reportlab.lib.units import cm
from reportlab.lib import colors
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import SimpleDocTemplate, Paragraph, ListFlowable, ListItem, Spacer, Table, TableStyle, KeepTogether

VERSION = "3.18.0"
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
S += [P(TITLE, title), P("Ce se schimbă în aplicație, cum te ajută și ce limite are, spus direct.", sub)]

S += [P("1. Pe scurt", h2), bl([
    "Aplicația are acum un cadru unic cu trei spații de lucru: <b>Transcodare</b>, <b>Offload</b> (copiere verificată) și <b>Metadate</b>.",
    "Un inspector în dreapta arată și modifică setările clipurilor selectate, cu o previzualizare cu redare.",
    "Poți marca clipurile care se procesează, le selectezi separat și vezi clar când setările diferă între ele.",
    "Înainte de pornire vezi un rezumat și avertismente; nimic nu se suprascrie niciodată.",
    "Copierea verificată trimite la transcodare doar fișierele verificate prin sumă de control.",
    "Spațiul Metadate arată profilul de culoare (gamut și curbă separat), timecode-ul și de unde provine fiecare valoare.",
    "Temă Sistem / Deschisă / Închisă, în română, engleză și spaniolă.",
])]

S += [P("2. Transcodare", h2),
      bl(["<b>Import:</b> tragi fișierele peste fereastră sau folosești „Adaugă fișiere…”. Lista se vede ca grilă cu miniaturi sau ca listă.",
          "<b>Marcat și selectat:</b> căsuța de pe clip hotărăște ce se convertește; selecția hotărăște ce editezi în inspector. Bannerul din inspector spune mereu cărui grup i se aplică modificarea.",
          "<b>Valori diferite:</b> dacă selecția are presetări sau setări diferite, vezi „Valori diferite” în loc de o valoare înșelătoare. O setare individuală nu se schimbă decât dacă alegi tu o valoare nouă.",
          "<b>Cadre pe secundă și viteză:</b> aplicația explică diferența. Conversia ratei de cadre păstrează durata și sunetul. Schimbarea vitezei nu există în această versiune și de aceea nu este afișată.",
          "<b>Rezumat și avertismente:</b> bara de jos arată câte clipuri se produc și cu ce presetare; te avertizează când un rezultat există deja (cel nou primește _2, _3…), când spațiul pare insuficient sau când o combinație nu poate păstra anumite informații.",
          "<b>Progres:</b> progres pe clip și total; viteza și timpul rămas apar doar când pot fi estimate credibil. Oprirea anulează conversia în curs."]),
      ]

S += [P("3. Offload — copiere verificată", h2),
      bl(["O copiere verificată din card către una sau mai multe destinații, cu raport (inclusiv MHL).",
          "Originalele nu sunt modificate și aplicația nu șterge nimic automat din card sau sursă.",
          "„Copiat” și „verificat” sunt tratate separat: un fișier copiat dar neverificat nu este prezentat ca verificat. Eșecurile sunt arătate pe fiecare destinație.",
          "„Trimite la transcodare” pune în coadă doar fișierele verificate prin sumă de control. Nu pornește conversia singur, iar fișierele eșuate sau verificate doar prin mărime nu se trimit.",
          "Coadă de operații (una câte una, păstrată între lansări) și opțiunea „Extrage metadatele”: fișe .gdc-metadata.json scrise lângă copiile verificate, separat de verdictul copierii.",
          "„Raport PDF” cu fișierele sursă și copiile verificate pe fiecare destinație; la anulare, fișierele terminate dar neverificate sunt numite separat.",
          "Viteze afișate separat (scriere și citire la verificare), doar când sunt măsurate; la 1000×652 interfața se adaptează fără tăieturi.",
          "Transcodarea funcționează independent, fără offload."])]

S += [P("4. Metadate", h2),
      bl(["Spațiu dedicat, cu căutare, plus fila „Metadate” din inspectorul de transcodare.",
          "Secțiuni: fișier, video, audio, producător și model, profil de culoare (gamut și curbă separat), timecode și tipul lui, obiectiv și captură, proveniență, conflicte, câmpuri brute (avansat).",
          "Fiecare valoare arată dacă a fost detectată, declarată de producător, dedusă sau introdusă manual. Valorile necunoscute rămân „necunoscute”.",
          "Valorile introduse manual se păstrează doar în CGConvertor și în fișa exportată; fișierul original nu este modificat.",
          "Poți compara metadatele a două sau mai multe clipuri."]),
      P("<b>Limită importantă:</b> faptul că aplicația afișează un profil nu înseamnă că DaVinci Resolve îl atribuie automat. Verificat: Canon C50. La Sony A7 IV și Panasonic DC-S1 Resolve citește doar timecode-ul. Alte mărci nu au fost testate.", note)]

S += [P("5. Ce s-a păstrat neschimbat", h2),
      bl(["Motorul de conversie și metodele de păstrare a metadatelor din versiunea anterioară.",
          "Licențierea: probă de 5 zile pentru utilizatorii noi, probele începute își păstrează durata, licențe de 3, 6, 12 luni sau perpetue, fără donații.",
          "Fișierele nu se suprascriu și nu se șterg automat."])]

S += [P("6. Limite cunoscute", h2),
      bl(["Schimbarea vitezei clipului și redimensionarea imaginii nu sunt disponibile.",
          "Previzualizarea redă direct doar formatele pe care macOS le poate reda; pentru restul rămâne previzualizarea pe cadre.",
          "Presetarea „H.264 1080p” nu redimensionează imaginea.",
          "Versiunea pentru Windows nu a fost modificată în această versiune (rămâne 3.15.0).",
          "Instalarea automată a actualizării cu parolă de administrator nu a fost verificată pe un Mac curat."])]
S += [P(f"CGConvertor {VERSION} · gordas.dev", foot)]

def numbered(c, d):
    c.saveState(); c.setFont("Arial", 8.5); c.setFillColor(MUTED)
    c.drawRightString(A4[0]-2*cm, 1.2*cm, f"Pagina {d.page}"); c.restoreState()
doc = SimpleDocTemplate(OUT, pagesize=A4, leftMargin=2*cm, rightMargin=2*cm, topMargin=2*cm, bottomMargin=2*cm, title=TITLE, author="Cristi Gordaș / GDC")
doc.build(S, onFirstPage=numbered, onLaterPages=numbered)
print(OUT)
