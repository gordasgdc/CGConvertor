# CG Convertor — reguli de arhitectură

> **[SYSTEM DIRECTIVE FOR CLAUDE: DO NOT DELETE OR OVERWRITE EXISTING RULES. ONLY APPEND NEW RULES.]**
> Jurnal viu, nu document care se rescrie. La orice actualizare, adaugă la finalul secțiunii potrivite — nu șterge/înlocui reguli vechi decât dacă sunt explicit invalidate de o schimbare reală (și atunci marchează-le **[ÎNVECHIT]** cu motivul, nu le șterge din istoric).

Citit automat de Claude Code la fiecare sesiune în acest repo.

## REGULĂ PERMANENTĂ: Locația proiectului pe disc (2026-08-26)
Acest repo trăiește în **`~/Developer/CGConvertor`**, NU în `~/Desktop`
sau `~/Downloads` (unde a stat inițial — mutat la auditul din
2026-08-26). Motiv: `~/Downloads` e curățat automat de CleanMyMac/Hazel
pe acest Mac — a șters repo-uri de sursă în timpul unor sesiuni anterioare
(recuperate din Coș la timp, dar risc real de pierdere ireversibilă).
`~/Desktop` nu are aceeași problemă documentată, dar aceeași regulă se
aplică pentru consistență cu restul ecosistemului GDC — vezi
`~/Developer/GDCPluginManager/PROJECT_STRUCTURE.md`.

**Toate proiectele GDC se gestionează exclusiv din `~/Developer/`** —
niciun repo nou nu se creează/clonează în `~/Desktop`/`~/Downloads`,
indiferent de task.

## Audit 2026-08-26 — consolidare surse & securitate

**Găsit și reparat, real, nu presupus:**
- `.git/config` conținea remote-ul cu un **token GitHub în clar**
  (`https://gordasgdc:ghp_...@github.com/...`) — risc de expunere a
  credențialei. Fix: remote resetat la `https://github.com/gordasgdc/CGConvertor.git`
  (fără token în URL), autentificare prin `gh`'s credential helper
  (deja logat, `gh auth status` confirmă token separat `gho_...` în
  keyring). Cristi a fost instruit să revoce tokenul vechi manual din
  GitHub Settings — Claude nu are cum să revoce un token, doar să
  elimine expunerea lui din config.
- **Trei foldere candidate existau** pentru sursa acestui proiect:
  `~/Desktop/CGConvertor` (cu `.git`, istoric complet, conectat la
  `gordasgdc/CGConvertor`), `~/Downloads/CGConvertor-trilingv` și
  `~/Downloads/CGConvertor-update` (ambele fără `.git`, doar `docs/` +
  `README.md`). Verificat prin `diff -rq`: ambele din Downloads sunt
  SUBSETURI vechi, deja depășite de conținutul din Desktop (varianta din
  Desktop are `.github/`, `README.en.md`, `README.es.md`, plus un
  `docs/index.html` mai recent cu switch de limbă RO/EN/ES — celelalte
  două nu au nimic ce lipsește din Desktop). **Nimic de fuzionat** —
  `~/Desktop/CGConvertor` era deja sursa completă și cea mai nouă.
- `__pycache__/` era tracked în git (4 fișiere `.pyc`) — scos din
  tracking, adăugat `.gitignore` (nu exista deloc înainte).
- `venv/` local (nu era tracked, dar ocupa spațiu inutil) — șters
  înainte de mutare, adăugat și el în `.gitignore` preventiv.

## Structura repo-ului (două variante paralele, ambele menținute — 2026-08-04)

1. **Nativă Swift/SwiftUI** (`CGConvertor/`, `CGConvertor.xcodeproj`) —
   `CGConvertorApp.swift`, `ContentView.swift`, `ConvertorViewModel.swift`,
   `MotorFFmpeg.swift` (wrapper peste `ffmpeg`/`ffprobe` bundle-uite),
   `VideoJob.swift`. Aceasta e ținta principală pentru rescrierea UI
   "Shift" (Faza B) — vezi directiva de mai jos.
2. **Python standalone** (`main.py`, `converter.py`, `theme.py`,
   `translations.py`, `config.py`, `build-mac.spec`/`build-windows.spec`
   — PyInstaller) — variantă opțională, adăugată 2026-08-04 ca alternativă
   fără Xcode/semnare, pentru distribuție rapidă cross-platform (inclusiv
   Windows, unde varianta Swift nu există deloc — SwiftUI e Mac-only).
   **Pentru Windows, aceasta rămâne singura bază de pornire** (nu există
   niciun proiect Windows nativ separat, spre deosebire de GDCPluginManager/
   GDCVault/DataMover care au repo-uri `.NET`/WPF dedicate).

`docs/index.html` — pagina de prezentare curentă, deja RO/EN/ES cu switch
de limbă (adăugată 2026-08-04) — locuiește ÎN ACEST repo, nu pe
`gordas.dev`; rămâne de decis (Faza C) dacă devine `gordas.dev/cg-convertor`
sau un subdomeniu dedicat.

## DIRECTIVĂ PERMANENTĂ SUPREMĂ: Checklist obligatoriu la FIECARE release
Aceeași regulă aplicată în tot ecosistemul GDC (CursorPro, GDC Plugin
Manager, GDC Vault, DataMover, GDC Production Manager) — vezi
`CLAUDE.md`-urile acelor repo-uri pentru text complet. Pe scurt:
1. Versiune vizibilă în UI.
2. Update checker cu pop-up (nu doar banner discret).
3. Pachet de release standard: executabil/installer semnat+notarizat +
   `Dezinstalare_CGConvertor.command` + ghid PDF (RO/EN/ES).
4. Site sincronizat cu `releases/latest/download/...`, verificat HTTP 200.

## Plan Faze (2026-08-26, cerut explicit de Cristi)
- **Faza A** (relocare + curățare) — **COMPLETĂ**.
- **Faza B** (licențiere + UI "Shift" + versiune/update checker) — **COMPLETĂ pe Mac și Windows**.
- **Faza C** (pachete semnate Mac+Windows + pagină web dedicată) — **COMPLETĂ**, vezi jurnal mai jos.

## Faza C — jurnal de implementare (2026-08-26)

**Cerință critică — instalare 100% automată, fără drag-and-drop manual:**
- **Mac**: `build_installer.sh` (nou, port al tiparului `GDCVault`/`CursorPro`,
  adaptat pentru `xcodebuild` în loc de `swift build`) — `pkgbuild
  --install-location "/"` cu payload-ul la `Applications/CGConvertor.app`
  scrie DIRECT în `/Applications` la instalare, fără niciun pas manual.
  Verificat cu `pkgutil --payload-files` — confirmă `./Applications/CGConvertor.app`.
- **Windows**: `installer.iss` (creat la completarea de iconițe, vezi mai
  sus) — `DefaultDirName={autopf}\GDC\CG Convertor` (Program Files),
  scurtături automate Desktop + Start Menu deja cablate.

**CI curățat — elimină sursele de confuzie găsite:**
Existau ANTERIOR **trei workflow-uri** care produceau, la un singur tag
`v*`, **cinci fișiere Mac diferite** (`release.yml`: `.zip`+`.pkg`
NESEMNATE din varianta Swift; `build-mac.yml`: `.zip`+`.pkg` NESEMNATE
din varianta Python "Standalone") — exact tiparul de "prea multe fișiere
confuze" semnalat explicit de Cristi la alte aplicații din ecosistem.
**Șterse complet** `release.yml` și `build-mac.yml` — Mac-ul se
construiește acum LOCAL (`build_installer.sh`, certificat real din
Keychain), la fel ca toate celelalte aplicații GDC. Rămâne un singur
pachet Mac oficial: `CGConvertor-Mac.zip` (native Swift, semnat+notarizat).

**Pachet Mac (`CGConvertor-Mac.zip`)** — exact 3 fișiere la rădăcină:
`CGConvertor.pkg` (semnat Developer ID Application+Installer, notarizat,
stapled — verificat `pkgutil --check-signature`), `Dezinstalare_CGConvertor.command`
(nou), `Instructiuni_Utilizare.pdf` (nou, RO/EN/ES, 6 pagini,
`installer/generate_pdf.py`, același tipar ca GDCVault). `codesigning/`
copiat din GDCVault. `installer/scripts/preinstall` (pkill + rm -rf pe
instalarea veche, fără hack-uri) + `installer/License.txt` (nou).

**Pagina web dedicată** — `docs/index.html` din ACEST repo (NU
gordas.dev) e deja servită live la `https://gordas.dev/CGConvertor/`
**și** `https://gordasgdc.github.io/CGConvertor/` (GitHub Pages cu
`build_type: legacy`, `path: /docs` — confirmat via `gh api
repos/.../pages`; Cloudflare-ul din fața `gordas.dev` rutează
`/CGConvertor/*` acolo, mecanism preexistent, nu creat acum). Pagina
veche descria DOUĂ variante paralele (Swift nesemnat + Python
"Standalone") cu link-uri către pagina generică de Releases și un
avertisment explicit "aplicația nu e semnată" — TOATE FALSE acum.
Rescrisă complet: o singură poveste (pachet Mac semnat+notarizat +
installer Windows), butoane cu link DIRECT către
`releases/latest/download/CGConvertor-Mac.zip` /
`.../CGConvertor-Windows-Setup.exe`, temă "Shift" (aceeași paletă ca
aplicația), RO/EN/ES cu switch (tipar `data-i18n` identic cu
`gdc-vault`/situl principal). **Bug prins la testare locală** (server
Python + Browser, înainte de commit — regulă din incidentul JS-crash al
sitului principal GDCPluginManager, 2026-08-25): 3 blocuri de instrucțiuni
conțineau tag-uri HTML (`<code>`, `<b>`) dar erau marcate `data-i18n`
(text simplu) în loc de `data-i18n-html` — tag-urile apăreau literal pe
pagină. Reparat, verificat vizual + `read_console_messages` (fără erori)
înainte de push.

## Completare 2026-08-26 — terminologie financiară obligatorie: DONAȚIE, nu preț
Cerință explicită: niciodată „Preț"/„Cumpără"/„Vânzare" — valoarea (23 €)
se exprimă EXCLUSIV ca donație pentru continuarea dezvoltării, pe toate
canalele, RO/EN/ES:
- **UI Mac** (`Localization.swift`, cheia `license.note`, afișată în
  `ActivationSheet.swift`) — actualizată cu suma explicită și formularea
  de donație.
- **UI Windows** (`python/activation.py`) — nu avea NICIUN text de preț/
  donație în dialog înainte; adăugat `donation_note` (cheie nouă în
  `TEXTS`) + label vizibil în `ActivationDialog._build_ui`, înaintea
  butonului WhatsApp. Fereastra crescută 480→560px ca să încapă textul.
- **PDF** (`installer/generate_pdf.py`) — cheie nouă `donation_note`,
  afișată ca `note()` separată de `trial_note` (schimbare de calculator),
  în toate 3 limbi. Regenerat, verificat cu `pypdf` că textul „23 €"/
  „€23" apare efectiv în conținutul extras.
- **Site** (`docs/index.html`) — secțiunea de licențiere redenumită
  „Susține dezvoltarea" / „Support development" / „Apoya el desarrollo",
  badge „Donație Lifetime", preț afișat explicit (`23 €` + „donație
  unică"), nota RO veche ("Prețul se stabilește...") conținea EXACT
  cuvântul interzis — înlocuită complet. Testat local (server + Browser,
  `read_console_messages` fără erori) înainte de commit.

## Faza B — jurnal de implementare (2026-08-26)

**Analiză comparativă (cerută explicit) — ce avea Python și lipsea din Swift:**
verificat linie cu linie `converter.py`/`main.py`/`config.py` vs
`MotorFFmpeg.swift`/`ConvertorViewModel.swift`/`ContentView.swift`.
Concluzie: Swift-ul era de fapt tehnic SUPERIOR pe motorul de conversie
(păstrare timecode prin re-wrap în 2 pași, `-c:a copy` care păstrează bit
depth-ul original — Python folosea `pcm_s16le` forțat, o regresie reală,
reparată acum și în Python). Ce lipsea REAL din Swift, portat acum:
- **Setări persistate** (ultimul mod/codec/folder destinație) — Python
  le avea (`config.py`), Swift reseta la fiecare lansare. Fix:
  `ConvertorViewModel.swift`, `UserDefaults`.
- **Stop/Anulare coadă în curs** — Python avea infrastructura
  (`Converter.stop()`/`_stop_requested`) dar main.py nu o apela NICIODATĂ
  din UI; Swift nu avea deloc conceptul. Fix pe ambele: `ConversieHandle`
  (Swift, nou, `MotorFFmpeg.swift`) + wiring real în `main.py` (Python).
- **Gardă la "Golește lista" în timpul rulării** — exista în Python
  (`if self.is_running: return`), lipsea din Swift (bug real — ar fi
  lăsat FFmpeg să scrie într-un fișier dispărut din UI). Adăugată acum
  și în `ConvertorViewModel.swift`.
- **Limbă RO/EN/ES** — exista doar în Python; Swift nu avea deloc
  localizare. Adăugat `Localization.swift` (`L.t()`, tipar identic cu
  CursorPro/DataMover) + switch de limbă vizibil în header.

**UI "Shift" (rescriere completă vizuală, ambele platforme):**
paletă dark, accent cupru/amber (`#E8963C` — distinct de teal-ul folosit
de restul ecosistemului GDC, intenționat, ton "Color page" DaVinci
Resolve). Mac: `Theme.swift` (`enum Shift`) + `ContentView.swift`
rescris complet — carduri elevate, mod/codec/destinație în panouri
separate, coadă de fișiere ca listă de carduri cu progress bar, taste
rapide (⌘O adaugă, ⌘⏎ pornește, ⌘K golește). Windows: `theme.py`
rescris pe aceeași paletă hex, `main.py` restilizat (stiluri `ttk`
noi: `Stop.TButton`, `LangActive.TButton`), aceleași taste rapide
(Ctrl+O/Ctrl+Enter/Ctrl+K).

**Licențiere unificată (GDC Plugin Manager / Furnizor), Trial 15 zile:**
- Mac: `LicenseCore.swift`/`MachineID.swift`/`LicenseManager.swift`/
  `ActivationSheet.swift`/`WhatsAppLink.swift` — copiate byte-for-byte
  din `GDCVault` (aceeași cheie publică Ed25519, tot ecosistemul GDC),
  `productID = "cgconvertor"`, `trialDurationDays = 15`. Blochează
  butonul "Pornește conversia" la expirare (nu accesul la UI, ca la
  DataMover — un convertor nu are "date vechi" de protejat).
- Windows: `license_core.py`/`license_validator.py`/`machine_id.py`
  copiate din `DataMover/core/` (Python, aceeași cheie publică),
  `PRODUCT_ID = "cgconvertor"`. `activation.py` nou (dialog Tkinter,
  port 1:1 al `DataMover/core/activation.py`, TRIAL_DAYS=15, stilizat
  Shift). **IMPORTANT — pas manual rămas**: `cgconvertor` trebuie adăugat
  în `gdcStandaloneProducts` din `GenerateSerialView.swift`
  (`gdc-plugin-manager`, Furnizor) ca să poată fi generate coduri reale —
  nefăcut încă în acest commit (fișier din alt repo).
- `requirements.txt`: adăugat `cryptography>=42.0.0` (necesar de
  `license_core.py`, lipsea complet).

**Versiune vizibilă + Update Checker cu pop-up (ambele platforme):**
Mac: `UpdateChecker.swift` (GitHub Releases API, port 1:1 GDCVault),
`v{versiune}` în header + `.alert` SwiftUI la lansare (o dată per
versiune, dismissal persistat) + buton manual (⟳ în header, și din
meniu). Windows: `update_checker.py` nou (aceeași logică, `urllib`, fără
dependințe noi), `v{versiune}` în header + `messagebox` pop-up la
lansare + buton manual (⟳ în header).

**Iconiță (completare cerută separat, 2026-08-26):**
- Executabil: deja seta iconița corect (`build-windows.spec`,
  `icon='CGConvertor.ico'`, `build-mac.spec`, `icon='CGConvertor.icns'`)
  — verificat, nicio schimbare necesară acolo.
- **Fereastră (title bar/taskbar)**: lipsea complet pe Windows — Tk
  arăta iconița implicită (o frunză), indiferent de iconița exe-ului.
  Fix: `main.py._set_window_icon()` (`self.iconbitmap()`), plus
  `CGConvertor.ico` acum bundle-uit explicit ca `datas` în
  `build-windows.spec` (înainte NU era inclus ca fișier accesibil la
  runtime din `sys._MEIPASS` — doar folosit static de PyInstaller la
  compilare, `_resource_path()` nu l-ar fi găsit deloc).
- **Installer + scurtături Desktop/Start Menu**: NU EXISTA NICIUN
  INSTALLER înainte de acest commit — CI publica direct un `.exe` brut
  (`CGConvertor-standalone-windows.exe`), fără scurtături, fără intrare
  în "Apps & Features", fără dezinstalare curată. Creat `installer.iss`
  (Inno Setup, port 1:1 al tiparului `GDCVaultWin`/`GDCPluginManagerWin`,
  adaptat pentru build PyInstaller onefile în loc de `dotnet publish`) —
  `SetupIconFile=CGConvertor.ico`, scurtăturile mostenesc iconița direct
  din `.exe` (deja setată). `.github/workflows/build-windows.yml`
  rescris să compileze installer-ul (ISCC, preinstalat pe
  `windows-latest`) și să publice `CGConvertor-Windows-Setup.exe`, NU
  mai exe-ul brut — aliniat cu restul ecosistemului GDC (Directiva
  Permanentă Supremă, punctul 3).

**Curățare structurală găsită pe parcurs**: fișierele Python existau
DUBLU în repo — la rădăcină (vechi, stil `tk.Button` fără `ttk`, ignoră
culorile pe macOS) ȘI în `python/` (mai nou, `ttk.Style` corect, folosit
de CI real). Rădăcina ștearsă complet (`main.py`, `converter.py`,
`theme.py`, `translations.py`, `config.py`, `build-*.spec`,
`requirements.txt`) — `python/` e acum singura sursă de adevăr.
`ffmpeg`/`ffprobe` de la rădăcină NU au fost atinse — alea sunt resurse
bundle-uite de varianta Swift (referite direct în `.xcodeproj`).

**Alte fix-uri reale găsite la verificare, nu presupuse:**
- `CGConvertor.xcodeproj`: `MACOSX_DEPLOYMENT_TARGET` era `26.5` (!) —
  ar fi blocat instalarea pe orice Mac fără ultima versiune de macOS,
  fără niciun motiv de cod real. Coborât la `14.0`, aliniat cu restul
  ecosistemului GDC.
- Versiune: `MARKETING_VERSION` (Xcode) și `config.APP_VERSION` (Python)
  sincronizate la `2.0.0` (rescriere majoră UI+funcționalitate).
