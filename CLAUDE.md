# CG Convertor — reguli de arhitectură

> **[SYSTEM DIRECTIVE FOR CLAUDE: DO NOT DELETE OR OVERWRITE EXISTING RULES. ONLY APPEND NEW RULES.]**
> Jurnal viu, nu document care se rescrie. La orice actualizare, adaugă la finalul secțiunii potrivite — nu șterge/înlocui reguli vechi decât dacă sunt explicit invalidate de o schimbare reală (și atunci marchează-le **[ÎNVECHIT]** cu motivul, nu le șterge din istoric).

Citit automat de Claude Code la fiecare sesiune în acest repo.

## [PARTEA 1: REGULI GLOBALE ECOSISTEM GDC — identică în toate proiectele GDC]

> Acest bloc e sincronizat manual în `CLAUDE.md`-ul TUTUROR proiectelor din
> `~/Developer/` (CGConvertor, CursorPro, DataMover, GDCPluginManager,
> GDCPluginManagerWin, GDCVault, GDCVaultWin, gdc-plugin-manager-catalog-vendor,
> gdc-plugin-manager-files, gdc-production-manager, gdc-resolve-encoder, și
> orice proiect GDC nou). Dacă modifici o regulă aici, propag-o manual și în
> celelalte 10 fișiere — nu există un fișier partajat/include, fiecare
> `CLAUDE.md` e citit independent per-repo. Vezi jurnalul "Sincronizare
> CLAUDE.md" din secțiunea Partea 2 a fiecărui repo pentru data ultimei
> unificări.

**1. Directoare & structură.** Toate proiectele GDC trăiesc exclusiv în
`~/Developer/<NumeProiect>/`, niciodată în `~/Downloads` sau `~/Desktop`
(curățate automat de CleanMyMac/Hazel pe acest Mac — au șters repo-uri de
sursă în trecut). Niciun repo nou nu se creează/clonează în afara
`~/Developer/`. Certificatele Apple (`.p12`/`.cer`) și orice cheie privată
(`.p8`/`.key`/`.pem`/`.mobileprovision`) stau EXCLUSIV în
`~/Developer/Certificates/` (folder în afara oricărui repo git) — niciodată
comise, indiferent de `.gitignore`.

**2. Securitate — zero secrete în git.** `.git/config` nu conține niciodată
un token în clar în URL-ul remote-ului (`https://user:TOKEN@github.com/...`)
— autentificare exclusiv prin `gh` (credential helper) sau SSH. Orice token
găsit expus se elimină din config imediat; revocarea efectivă din GitHub
Settings e un pas manual al lui Cristi (Claude nu poate revoca un token).
Un secret comis vreodată în istoricul git (verificat cu
`git log --all -p | grep` sau echivalent) trebuie semnalat explicit, nu doar
curățat din starea curentă.

**3. Licențiere & Donație (GDC Plugin Manager / Furnizor).** Toate
aplicațiile standalone GDC folosesc `LicenseCore`/`MachineID` (Ed25519,
aceeași cheie publică hardcodată în tot ecosistemul — copiată byte-for-byte,
NU printr-o dependință de pachet între repo-uri). Probă gratuită implicită:
**15 zile**. Activare manuală prin WhatsApp (ID de mașină pre-completat) →
cod generat din `GenerateSerialView.swift` (Furnizor, `gdcStandaloneProducts`
trebuie să includă `productID`-ul noii aplicații). Valoarea susținerii
aplicației se exprimă EXCLUSIV ca **donație** — sumă implicită de referință
**23 €** dacă nu există alt preț promoțional documentat pentru acea
aplicație — NICIODATĂ cu cuvintele „preț", „cumpără" sau „vânzare" (RO/EN/ES:
niciodată „price"/„buy"/"sale" nici în engleză/spaniolă). Formularea trebuie
să apară clar în: UI-ul aplicației (ecran/pop-up de licență), ghidul PDF, și
orice pagină web dedicată.

**[COMPLETARE 2026-08-26, închide o lacună de scop reală]** Interdicția de
mai sus se aplică ACUM și produselor din catalogul GDC Plugin Manager
(LUT/DCTL/PowerGrade vândute prin marketplace-ul gratuit) — găsit la audit
un card cu buton „Cumpără" și sume afișate brut („378,00 €"). Butonul
devine „Donează" peste tot (RO/EN/ES); suma documentată de furnizor pentru
acel produs (promoția specifică lui, nu neapărat 23 €) rămâne vizibilă, dar
NICIODATĂ lângă cuvântul „preț"/„cumpără"/„vânzare" — decizia anterioară de
scop (marketplace = "relație comercială diferită, nu se aplică") e
INVALIDATĂ explicit. Excepție: tabelele interne ale Furnizorului (ex.
`SalesHistoryView`, coloana „Preț" din registrul de vânzări al lui Cristi)
nu sunt UI orientat spre client — rămân neatinse.

**15. CRM Furnizor — set minim de funcționalități administrative
(2026-08-26).** Panoul de Clienți al Furnizorului (`SalesHistoryView.swift`)
nu rămâne un log rigid — trebuie să ofere: filtrare rapidă pe produs
(dropdown dinamic, nu hardcodat), export 1-click (clipboard sau fișier) al
email-urilor/HWID-urilor din selecția curentă (filtrată), copiere rapidă
per-câmp direct din tabel (fără să deschizi editarea), Licențiere în Masă
(paste o listă de email-uri/machine ID-uri → generează automat câte o
licență per linie, pentru un produs/durată alese o singură dată), și
editare liberă a duratei unei licențe deja generate (Zile/Luni/Ani/
Lifetime). Furnizorul arată versiunea curentă în UI, la fel ca orice
aplicație client — nu e scutit de Regula 7 doar pentru că e un instrument
intern.

**16. Design Web "Shift" — compact, fără spații goale (2026-08-26).**
Completare la Regula 12: paginile de prezentare NU doar adoptă paleta
amber/cupru — trebuie și dense/aerisite corect, nu găunoase. `min-height:
100svh` pe un hero cu conținut scurt lasă spațiu gol enorm pe orice ecran
mai mare — evită-l sau limitează-l (ex. `78svh`); padding-ul secțiunilor
(`section`) rămâne generos dar nu excesiv (60px, nu 90px+). Orice accent
vechi (verde/teal/albastru folosit ca accent PRIMAR, nu ca stare
semantică precum "verificat cu succes") se înlocuiește cu amber/cupru —
o variabilă CSS poate păstra alt NUME istoric (`--scope`, `--accent-copy`)
atât timp cât VALOAREA ei devine amber, ca să nu rescrii zeci de
apariții `var(--x)` din foaia de stil.

**4. Manager de Dependențe (Standard GDC, opt-in).** Aplicația de bază
rămâne lightweight — orice dependință externă opțională/grea (ex. FFmpeg
static) se descarcă LA CERERE, nu bundle-uită implicit dacă poate fi evitat.
Indicator global 🔴/🟢 vizibil în header/meniu: verde doar dacă TOATE
componentele obligatorii (non-opționale) sunt OK; componentele opționale
(ex. Homebrew pe Mac) nu blochează starea verde. Click pe indicator deschide
un panou dedicat ("Verificare & Dependențe Sistem") cu o listă modulară de
componente (model generic `DependencyItem` — id, nume, opțional/obligatoriu,
verificare headless, acțiune, niciodată câmpuri hardcodate per-dependință),
fiecare cu propriul status + buton de acțiune (descărcare automată a unui
binar static, sau copiere comandă de instalare). Verificarea rulează headless
la fiecare deschidere a panoului/meniului, actualizând starea instant.

**5. Instalare Autonomă.** Mac: `.pkg` semnat Developer ID Application +
Installer, notarizat, stapled, cu `pkgbuild --install-location "/"` și
payload la `Applications/<App>.app` — instalare DIRECTĂ în `/Applications`
la dublu-click, fără drag-and-drop manual (verificabil cu
`pkgutil --payload-files`). Windows: installer Inno Setup cu
`DefaultDirName={autopf}\GDC\<App>` (Program Files) sau varianta x86,
scurtături automate Desktop + Start Menu, dezinstalare nativă prin
"Apps & Features" (fără script separat necesar dacă Inno Setup o acoperă).

**6. Packaging Mac — arhivă cu STRICT 3 fișiere.** Orice
`<App>-Mac.zip` livrat clientului conține la rădăcină EXACT: (1)
executabilul/`.pkg`-ul semnat+notarizat+stapled, (2)
`Dezinstalare_<App>.command` (dezinstalare completă: procese, TCC dacă
relevant, `~/Library/Application Support`, `Caches`, `Preferences`,
`Saved Application State`, `Logs`, orice item Keychain scris de aplicație),
(3) `Instructiuni_Utilizare.pdf` (RO/EN/ES). NICIODATĂ hack-uri
`xattr -dr com.apple.quarantine` sau launchere `Instalare_*.command` —
pachetul stapled e acceptat nativ de Gatekeeper. Curățarea unei instalări
vechi se face în `installer/scripts/preinstall` (`pkgbuild --scripts`,
pkill + `rm -rf`), niciodată legat de quarantine.

**7. UI Standard — varianta "Shift".** Temă dark, profesională, inspirată de
paginile de Color din DaVinci Resolve (fundal `#14161A`/`#1A1D22`, accent
cald cupru/amber sau altă culoare distinctă per-aplicație, text `#EDEFF2`).
Număr de versiune vizibil în UI (About/Meniu/Settings/Footer), fără excepție.
Update Checker automat la lansare + verificare manuală, conectat la
`update.json`/GitHub Releases API, cu notificare atât banner discrét CÂT ȘI
pop-up modal (o singură dată per versiune nouă, stare de dismissal comună
între cele două) — un simplu banner nu e suficient. `mandatory: true` în
`update.json` ignoră dismissal-ul anterior.

**8. Documentație PDF — standard ultra-detaliat.** Orice
`Instructiuni_Utilizare.pdf` (RO/EN/ES) se redactează pentru un utilizator
complet începător, zero presupuneri, cu secțiunile relevante aplicației:
(a) Panoul de Dependențe — ce înseamnă 🔴/🟢, pas-cu-pas ce face userul la
roșu (unde dă clic, ce se deschide, ce buton apasă); (b) Homebrew (Mac,
dacă aplicabil) — pași la nivel de acțiune: copiază comanda din aplicație,
deschide Terminal (Spotlight, `⌘+Space`), lipește (`⌘+V`), Enter, apoi
explică parola de Mac cerută (invizibilă la tastare) + Enter din nou;
(c) Fluxul de utilizare + acțiuni post-proces — cum se adaugă
fișiere/date, ce face fiecare buton rezultat; (d) Licență & Donație — trial
gratuit explicit (zile), suma exactă ca donație (niciodată "preț"/"vânzare");
(e) Cum funcționează actualizarea automată — ce înseamnă pop-up-ul de
versiune nouă, ce face butonul „Actualizează acum" vs „Mai târziu", și că
instalarea noii versiuni rămâne un pas asistat (descărcare + reinstalare),
nu un update silențios în fundal.

**9. Checklist obligatoriu la FIECARE release** (păstrat identic cu
"DIRECTIVĂ PERMANENTĂ SUPREMĂ" din jurnalul fiecărui proiect — punctele
1-4 de acolo sunt subsumate integral de punctele 5-8 de mai sus). Site-ul
public al fiecărei aplicații trebuie să pointeze mereu la
`releases/latest/download/...` (HTTP 200 verificat, nu presupus), niciodată
un tag fix.

**10. Comunicare & jurnal.** Fiecare `CLAUDE.md` rămâne un jurnal
append-only (regulile vechi nu se șterg, doar se marchează
**[ÎNVECHIT]** cu motivul dacă sunt explicit invalidate). Răspunsurile
Claude rămân ultra-concise: fără explicații de proces, direct codul/
diff-ul/comenzile și statusul. La orice modificare de cod, comanda exactă
de rebuild local se include la finalul răspunsului.

**11. Sincronizare dinamică a Standardului Master (CONTINUOUS UPDATE,
2026-08-26).** Orice adăugare/modificare/optimizare a unei reguli globale
din ACEASTĂ Partea 1 — indiferent din ce proiect pornește — devine automat
noul Standard Master și TREBUIE propagată manual, în ACELAȘI commit sau
imediat următorul, în `CLAUDE.md`-ul tuturor celorlalte proiecte din
`~/Developer/` (nu doar notată "pentru mai târziu"). Orice aplicație NOUĂ
creată în `~/Developer/` primește Partea 1 (versiunea curentă, completă)
încă din primul `CLAUDE.md` scris pentru ea — nu se pornește niciodată de
la un fișier gol sau parțial. Regula 1 de mai sus ("Dacă modifici o regulă
aici, propag-o manual...") descrie mecanismul; aceasta îl declară
obligatoriu, nu opțional.

**12. Profil Utilizator/HWID în Sidebar, Sistem de Revocare Licențe &
Standard Design Web Mobile/Desktop "Shift" (2026-08-26).**
- **Profil Utilizator opțional, vizibil în sidebar-ul UI** (Mac + Windows,
  pe toate aplicațiile cu licențiere GDC): Nume (sau „Anonim" dacă nu e
  completat), Email, și Machine ID (HWID) — afișate clar, nu ascunse
  într-un submeniu. Portat din modulul Tracker existent (Mac,
  `AnalyticsClient.registerDevice` → Supabase `devices`) — Windows trebuie
  aliniat la aceeași infrastructură, nu una separată.
- **Revocare/blacklist de licențe, prin Supabase** (ACEEAȘI bază de date
  deja folosită de Tracker — niciun backend nou de construit). O licență
  Ed25519 rămâne verificată local (offline-first, nicio schimbare la
  activarea inițială), dar clientul verifică periodic + la lansare (dacă
  există conexiune) un tabel de revocări după `machineID`/serial. **Fail
  OPEN, nu fail closed**: fără conexiune la internet, o licență deja
  activată local CONTINUĂ să funcționeze (nu bricuim un user legitim offline)
  — revocarea se aplică abia la următoarea verificare online reușită.
  Furnizor capătă unelte de revocare instant + editare a perioadei de
  valabilitate a unei licențe existente deja generate.
- **Generare flexibilă de licențe** (Furnizor): selector explicit al
  duratei — Zile / Luni / Ani / Forever (Lifetime) / Valabil până la
  versiunea X — nu doar trial fix + activare permanentă binară.
- **Standard Design Web "Shift"** — orice pagină de prezentare/descărcare
  GDC (`gordas.dev` și paginile dedicate per-aplicație) adoptă design-ul
  dark, minimalist, accent amber/cupru consacrat de CG Convertor
  (`gordas.dev/cg-convertor`) — niciun accent verde vechi sau stil
  nealiniat. Toate paginile trebuie optimizate explicit pentru mobil
  (iOS Safari + Android Chrome), verificat vizual la lățimi de telefon,
  nu doar "responsive by CSS framework".

**13. Update Checker — specificație UX obligatorie (2026-08-26).** La
lansare, aplicația verifică `update.json`/GitHub Releases; dacă versiunea
locală e mai veche, arată un pop-up/modal Shift (nu doar bannerul discret
din Regula 7) cu: numărul noii versiuni, un rezumat scurt al noutăților
(Release Notes, dacă `update.json` le are — câmp opțional, degradează
elegant dacă lipsește), și DOUĂ butoane explicite — **„Actualizează acum"**
(deschide direct link-ul de descărcare a installer-ului/pachetului nou,
`releases/latest/download/...`, și arată userului că trebuie să
instaleze peste versiunea curentă + repornească aplicația — NU e un
self-update silențios, niciun helper nu înlocuiește bundle-ul/exe-ul în
fundal, vezi WARNING-ul deja existent din `UpdateChecker.swift`/`.cs`) și
**„Mai târziu"** (închide fereastra, aceeași stare de dismissal ca
bannerul). Popup-ul apare o singură dată per versiune nouă, cu excepția
`mandatory: true` (reapare la fiecare lansare). Ghidul PDF (Regula 8(e))
trebuie să explice acest flux exact.

**14. Versionare semantică obligatorie la FIECARE schimbare (2026-08-26).**
Orice modificare de cod livrată clientului — oricât de mică — incrementează
numărul de versiune, sincron în TOATE punctele care îl țin (Info.plist Mac,
`.csproj`/`installer.iss` Windows, `docs/update.json`, orice altă constantă
de versiune din acel repo). Format `MAJOR.MINOR.PATCH` (ex. `2.3.1`):
- **PATCH** (ultima cifră, `2.3.0`→`2.3.1`) — orice fix, ajustare, adăugare
  mică sau schimbare care nu rupe compatibilitatea. Cazul implicit, cel mai
  frecvent.
- **MINOR** (cifra din mijloc, `2.3.x`→`2.4.0`) — funcționalitate nouă
  vizibilă (ex. o fază/etapă întreagă ca Panoul de Dependențe sau Profilul
  HWID), fără schimbări radicale de arhitectură.
- **MAJOR** (prima cifră, `2.x.x`→`3.0.0`) — schimbare radicală: rebranding,
  redesign complet de UI, schimbare de arhitectură (ex. sistem nou de
  licențiere), sau orice prag pe care Cristi îl declară explicit "versiune
  majoră".
**De ce**: `UpdateChecker`/`.cs` compară STRICT numărul de versiune din
`update.json` cu cel instalat (`IsNewer`) — înlocuirea unui binar pe un
release existent, PE ACEEAȘI versiune, nu declanșează nicio notificare la
clienții deja instalați (bug real, găsit și reparat 2026-08-26: Windows
Shift UI + Faza 1/3/4 livrate silențios sub `v1.2.22`, fără niciun bump).
Un bump de versiune fără schimbare reală de cod e la fel de greșit ca
schimbarea de cod fără bump — cele două merg mereu împreună, în același
commit.

## [PARTEA 2: SPECIFICAȚII TEHNICE PROIECT]

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

## DIRECTIVĂ PERMANENTĂ: Standardul ghidurilor PDF (2026-08-26)
Aplicabilă la orice `Instructiuni_Utilizare.pdf` generat pentru aplicațiile
GDC de-acum. **Regula de aur: redactare ultra-detaliată, zero presupuneri**
— scris ca pentru un utilizator complet începător, fără cunoștințe tehnice.
Secțiuni obligatorii, când sunt relevante pentru aplicație:
1. **Panoul de Dependențe** — explică EXACT ce înseamnă indicatorul
   Roșu/Verde, și pas cu pas ce face userul când vede roșu (unde dă clic,
   ce se deschide, ce buton apasă).
2. **Homebrew (doar Mac, dacă aplicația îl menționează)** — NU doar
   "instalează Homebrew". Pași concreți, la nivel de acțiune: (1) apasă
   butonul de copiere din aplicație, (2) deschide Terminal (Spotlight,
   `⌘+Space`), (3) lipește (`⌘+V`) și apasă Enter, (4) explică ce urmează
   — parola de Mac cerută (caractere invizibile la tastare) + Enter din
   nou.
3. **Fluxul de conversie/utilizare + acțiuni post-proces** — cum se
   adaugă fișiere (drag&drop sau buton), ce face fiecare buton rezultat
   (ex. "Deschide fișierul"/"Arată în Finder-Explorer").
4. **Licență & Donație** — trial-ul gratuit explicit (zile), suma exactă
   ca DONAȚIE (niciodată "preț"/"vânzare" — vezi directiva de terminologie
   financiară de mai sus).
Vezi `installer/generate_pdf.py` pentru implementarea de referință.

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
## HOTFIX CRITIC 2026-08-26 (v2.1.0) — FFmpeg crash pe Mac + Manager de Dependințe

**Bug real, raportat de Cristi cu screenshot**: `FFmpeg a eșuat (cod 6):
dyld: Library not loaded: /opt/homebrew/Cellar/ffmpeg/8.1.2/lib/libavdevice.62.dylib`.
**Cauza reală, confirmată cu `otool -L`**: binarul `ffmpeg`/`ffprobel`
de la rădăcina repo-ului (bundle-uit în `.app` via
`PBXFileSystemSynchronizedRootGroup`) era o copie brută a build-ului
Homebrew de pe mașina de dezvoltare — legat DINAMIC de căi
`/opt/homebrew/Cellar/ffmpeg/<versiune>/lib/*.dylib`. Funcționează DOAR
pe mașina cu exact acea versiune Homebrew instalată; se sparge pe orice
alt Mac, sau chiar pe aceeași mașină după un `brew upgrade` (exact ce s-a
întâmplat aici — versiunea din Cellar avansase, dylib-urile vechi nu mai
existau).

**Fix real (nu doar patch cosmetic)**: binarele de la rădăcina repo-ului
înlocuite cu un build STATIC nativ arm64 de la `osxexperts.net`
(`ffmpeg9arm.zip`/`ffprobe9arm.zip`) — verificat cu `otool -L`: ZERO
dependințe externe (doar framework-uri de sistem), include
`prores_videotoolbox`/`dnxhd` (verificat cu `-encoders`). Testat rulând
direct binarul din `.app`-ul compilat local — pornește curat, fără
`dyld` errors.

**Plus, cerut explicit — Manager Modular de Dependințe (standard nou
pentru tot ecosistemul GDC de-acum, "Managerul Modular de Dependințe la
Cerere")**: `DependencyManager.swift`/`python/dependency_manager.py` —
listă generică de componente (`DependencyItem`), fiecare cu propriul
`check()` headless + acțiune. Nu doar FFmpeg — arhitectura e explicit
extensibilă pentru orice dependință viitoare, fără schimbare de UI.
- **Badge global** (bulină + text) în header — verde DOAR pe baza
  componentelor OBLIGATORII (FFmpeg); Homebrew fiind opțional nu-l
  face roșu — click deschide panoul.
- **Panou "Verificare & Dependențe Sistem"** (sheet/Toplevel modal) —
  câte un rând per componentă, stare + descriere + buton de acțiune:
  FFmpeg lipsă → "Descarcă & Instalează Automat" (descarcă build-ul
  static potrivit arhitecturii curente în `~/Library/Application
  Support/CGConvertor/bin/`, chmod +x + elimină quarantine, reverifică);
  Homebrew lipsă → "Copiază comanda de instalare" (`brew.sh`) + "Deschide
  brew.sh" — informativ, NU blochează nimic.
- `MotorFFmpeg.gasesteBinar()`/`dependency_manager.find_ffmpeg()`
  actualizate: ordinea de căutare e acum (1) copie descărcată prin
  Manager, (2) bundle-uit în aplicație, (3) Homebrew/PATH — un download
  reușit are mereu prioritate față de un bundle posibil stricat.

**BUG REAL PRINS LA TESTARE (Windows/Python), înainte de commit**:
apelarea `self.after(0, ...)` dintr-un thread de fundal pornit SINCRON,
direct din `__init__` (înainte ca `mainloop()` să fi pornit efectiv)
arunca `RuntimeError: main thread is not in main loop` — reprodus
consistent cu un test headless (`app.mainloop()` real, nu doar
`app.update()` în buclă — acesta din urmă NU declanșează bug-ul, deci un
test superficial l-ar fi ratat). Fix: verificarea inițială de dependințe
amânată cu `self.after(100, self._refresh_dependencies)`, exact tiparul
deja folosit (și deja corect) de verificarea de actualizări
(`self.after(800, self._check_updates_silently)`). Verificat din nou cu
`mainloop()` real după fix — funcționează curat.

**Opțiuni post-conversie (cerute explicit)**: pe rândul unui job
finalizat — Mac: butoane "Deschide fișierul" (`NSWorkspace.shared.open`)
+ "Arată în Finder" (`activateFileViewerSelecting`); Windows: dublu-click
sau click-dreapta pe rând → meniu contextual cu aceleași două acțiuni
(`os.startfile`/`explorer /select,`). Active DOAR dacă fișierul de
destinație chiar există pe disc la momentul click-ului (nu doar dacă
statusul spune "finalizat" — fișierul putea fi mutat/șters între timp).

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
