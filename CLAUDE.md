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

**17. Orice fișier descărcabil TREBUIE să poarte numărul versiunii în NUMELE
fișierului (2026-08-26).** Nu doar în interiorul aplicației (Regula 14) —
în numele fizic al pachetului: `DataMover-2.5.5.pkg`, nu `DataMover.pkg`;
`GDCPluginManagerSetup-1.2.8.exe`, nu `GDCPluginManagerSetup.exe`. Motiv
direct de la Cristi: probele/build-urile de test se acumulează local (în
`~/Downloads`, `/tmp`, trimise pentru testare) și devin de nerecunoscut
fără versiune în nume — "am o grămadă de descărcări și nu știu ce versiune
sunt, care, ce și cum sunt".
- **Excepție, NU o contrazicere**: mecanismul `releases/latest/download/
  <nume-stabil>` (site-ul, self-updater-ul) are nevoie STRUCTURAL de un
  nume care nu se schimbă niciodată între release-uri — vezi Regula
  Domeniului & Download. Copia asta stabilă (`DataMover.pkg`,
  `GDCPluginManager.pkg`) tot trebuie publicată, DAR ALĂTURI de copia
  versionată, niciodată singură. `build_installer.sh`/`build_app.sh` din
  fiecare repo produc deja ambele — regula asta cere doar ca ambele să
  ajungă mereu pe release, nu doar cea stabilă.
- **Orice fișier construit/descărcat/trimis lui Cristi în afara acestui
  mecanism** (build local de test, artefact de CI descărcat manual,
  fișier trimis prin `SendUserFile`, copie pusă în `/tmp` pentru
  verificare) TREBUIE redenumit explicit cu versiunea înainte de a fi
  oferit — niciodată livrat cu numele generic/stabil, care are sens doar
  ca țintă a unui link fix, nu ca fișier de sine stătător pe disc.

**18. Standard UX/Arhitectură obligatoriu pentru orice aplicație desktop
NOUĂ, de la primul release (2026-08-26).** Stabilit după MediaFlow Monitor
v1.3.0 — patru cerințe care nu mai sunt opționale pentru nicio aplicație
GDC viitoare (Mac și, unde tehnologia o permite, Windows):
- **Mutare automată în `/Applications` (Mac)** — la lansare, dacă bundle-ul
  rulează în afara `/Applications` sau `~/Applications` (tipic: extras
  direct din `.zip`/Downloads, sub App Translocation), aplicația arată un
  prompt nativ ("Doriți să mutați X în Aplicații?") și, la confirmare,
  copiază bundle-ul, relansează din noua locație și mută originalul la
  Coșul de gunoi. Vezi implementarea de referință `AppMover.swift`
  (MediaFlow Monitor) — fără dependință externă (PFMoveToApplicationsFolder
  nu are un port SPM întreținut), doar `NSAlert` + `FileManager`.
- **Fereastră principală redimensionabilă liber**, cu o dimensiune minimă
  de siguranță (`minSize`/`minWidth`+`minHeight`) sub care conținutul nu
  mai e lizibil — nu ferestre cu dimensiune fixă hardcodată.
- **Selector explicit de temă System/Dark/Light**, independent de setarea
  macOS/Windows — unii clienți vor Light chiar și noaptea, alții Dark
  permanent; NU e suficient să urmezi orbește `prefers-color-scheme`/tema
  sistemului. Persistat local (`UserDefaults`/Registry), aplicat imediat
  fără repornire. Vezi `AppTheme.swift`/`ThemeManager` (MediaFlow Monitor).
- **Protocolul de semnare, notarizare, auto-update și integrare GDC
  Manager rămâne cel deja documentat în Regulile 3, 5, 6, 13, 14, 17** —
  regula asta nu introduce un protocol nou, doar reconfirmă că orice
  aplicație nouă îl respectă de la prima versiune publicată, nu "adăugat
  ulterior quando there's time".

**19. Regulă Legală & Packaging (UE/Global) (2026-08-27).**
- **Pagini Web.** Orice landing page nouă sau actualizare de site publicată
  pe `gordas.dev` (sau pe orice site GDC, inclusiv paginile de proiect
  `gordasgdc.github.io/<repo>`) TREBUIE să conțină în footer link-uri către
  `https://gordas.dev/termeni` (Termeni și Condiții),
  `https://gordas.dev/confidentialitate` (Politică de Confidențialitate
  GDPR) și, unde e relevant, `https://gordas.dev/cookie` (Cookie-uri),
  plus o notă scurtă de statut: *"gordas.dev este o platformă administrată
  de dezvoltatori independenți. Aplicațiile și resursele sunt furnizate ca
  atare (AS IS), iar susținerea proiectului se bazează pe contribuții
  opționale de sprijin și donații."* Sursa canonică a acestor 3 pagini
  legale trăiește în `gdc-plugin-manager-catalog-vendor/docs/` — orice alt
  site GDC linkuiește către ele (absolut), nu le duplică.
- **Installere (.pkg macOS / .exe Windows).** Începând cu următoarele
  versiuni/build-uri (NU retroactiv — fără rebuild al aplicațiilor deja
  publicate doar pentru asta), scripturile de instalare
  (`build_installer.sh`/`productbuild` pe Mac, `installer.iss`/Inno Setup
  pe Windows) TREBUIE să includă un pas de acceptare a licenței (License
  Agreement/SLA), bazat pe un fișier `license.rtf`/`license.txt` cu un
  extras din Termeni și Condiții (statut de proiect independent,
  licențiere legată de Machine ID, natura de donație a susținerii,
  limitarea răspunderii "as is"). Utilizatorul trebuie să apese explicit
  "Agree"/"I accept" înainte ca instalarea să se finalizeze.

  **[COMPLETARE 2026-08-27] Consimțământ obligatoriu (Consent Gate), nu
  doar text afișat.** Nu e suficient ca licența să apară — pasul trebuie
  să blocheze efectiv avansarea fără acceptare explicită:
  - **macOS (`productbuild`/Distribution.xml).** Elementul `<license
    file="License.txt" mime-type="text/plain"/>` din `Distribution.xml`
    (deja folosit de `build_installer.sh` în `gdc-plugin-manager-catalog-vendor`
    și `gdc-vault-mac`) e SUFICIENT — pagina nativă de licență a
    installer-ului macOS oferă mereu doar "Agree"/"Disagree", iar
    "Continue" nu apare fără "Agree" apăsat; nu există flag care s-o
    ocolească. Regula practică: orice `Distribution.xml` nou generat
    TREBUIE să păstreze elementul `<license>` — omiterea lui (ex. un
    installer simplificat fără pas de licență) NU e acceptabilă.
  - **Windows (Inno Setup).** Secțiunea `[Setup]` din `installer.iss`
    TREBUIE să seteze `LicenseFile=license.txt` (sau `.rtf`) — Inno Setup
    arată atunci nativ o pagină cu opțiunile radio "I accept the
    agreement" / "I do not accept", cu butonul "Next" dezactivat până la
    alegerea explicită "I accept". (Dacă vreun installer Windows ar trece
    vreodată pe NSIS în loc de Inno Setup, echivalentul e
    `!insertmacro MUI_PAGE_LICENSE` cu `MUI_LICENSEPAGE_CHECKBOX` definit,
    pentru varianta cu bifă explicită.)
  - Fișierul `license.txt`/`.rtf` folosit la acest pas trebuie să conțină
    (măcar rezumat) cele 4 puncte cheie din Termeni: statut independent
    (non-comercial), licențiere Machine ID, natura de donație a
    susținerii, garanție "as is"/limitarea răspunderii — nu doar un MIT
    License generic.

**20. Self-Updater real — obligatoriu, niciodată deschidere de browser/
GitHub (2026-08-27).** Descoperit ca bug real, repetat, pe GDC Vault (Mac
și Windows): un simplu link `releases/latest/download/...` deschis în
browser NU e suficient — utilizatorul tot ajunge pe un tab de
browser/GitHub, ceea ce Cristi consideră inacceptabil ("clientul niciodată
nu trebuie să vadă GitHub"). Orice aplicație desktop GDC (Mac/Windows) cu
proces propriu de rulat TREBUIE să implementeze un Self-Updater REAL, nu
doar un link:
- **Mac.** Descarcă `.pkg`-ul cu `URLSession.download`, cu URL-ul citit
  direct din `assets[]` al ultimului release GitHub (nu hardcodat), apoi
  îl instalează printr-un script bash elevat cu `osascript ... with
  administrator privileges` (promptul NATIV de parolă admin macOS —
  NICIODATĂ `sudo` interactiv sau Terminal vizibil), care rulează
  `installer -pkg ... -target /` și relansează aplicația singur. Vezi
  implementarea de referință `SelfUpdater.swift` (DataMover,
  `gdc-plugin-manager-catalog-vendor`, `GDCVault`).
- **Windows.** Descarcă installer-ul (`.exe`) cu `HttpClient` direct pe
  disc, redenumit cu versiunea (Regula 17), apoi îl lansează
  (`Process.Start(UseShellExecute:true)`) — fereastra NATIVĂ Inno Setup
  apare, NICIODATĂ browserul. Aplicația curentă se închide
  (`Application.Current.Shutdown()`) înainte ca userul să ajungă la pasul
  de copiere din wizard; `[Run] ... Flags: nowait postinstall
  skipifsilent` din `installer.iss` relansează aplicația după instalare —
  nu e nevoie de `AppMutex`/`CloseApplications` suplimentar. Vezi
  `SelfUpdater.cs` (`GDCPluginManagerWin`, `GDCVaultWin`).
- O fereastră minimală de progres (`UpdateProgressWindow`, text + spinner
  indeterminat) e obligatorie cât timp durează descărcarea/instalarea —
  userul nu trebuie să creadă că aplicația a înghețat.
- **WARNING permanent**: pasul efectiv de instalare (promptul de parolă
  admin pe Mac, wizardul Inno pe Windows) NU poate fi verificat automat de
  Claude — cere interacțiune fizică reală cu fereastra de sistem.
  Verificarea automată se oprește la "fișierul s-a descărcat integru,
  HTTP 200" — instalarea + relansarea efectivă TREBUIE confirmată manual,
  o dată, de Cristi, înainte ca fluxul să fie declarat complet dovedit.
- **Excepție arhitecturală, nu o abatere**: aplicații FĂRĂ proces propriu
  de rulat (plugin-uri încărcate de o gazdă terță, ex. un IOPlugin
  DaVinci Resolve) nu pot avea un "self-updater" în acest sens — rămân la
  reinstalare manuală ghidată de PDF (Regula 8), fără relansare automată.
- **Regula 13 (Update Checker) rămâne valabilă pentru DETECTAREA
  versiunii noi** (pop-up, texte, dismissal) — doar acțiunea butonului
  principal se schimbă: NU mai deschide un link, cheamă Self-Updater-ul.

**Status acest repo (2026-08-27): IMPLEMENTAT pe AMBELE platforme.**
Mac: `CGConvertor/SelfUpdater.swift` (nou, port 1:1 din `GDCVault`/
`DataMover`) — `UpdateChecker.swift` citește acum și URL-ul asset-ului
`CGConvertor.pkg` din `assets[]`. Windows (Python/Tkinter, NU C# — vezi
nota din Partea 2 despre variantele paralele): `python/self_updater.py`
(nou) — descarcă `CGConvertor-Windows-Setup.exe` cu `urllib` direct pe
disc, îl lansează cu `subprocess.Popen` (`DETACHED_PROCESS`), apoi
`sys.exit()`; `python/update_checker.py` extrage acum `download_url` din
`assets[]`. Fereastră de progres minimală (`tk.Toplevel` + `Progressbar`
indeterminat) în `main.py._start_self_update`. Versiune → `2.2.0`.
**WARNING nemodificat**: pasul de instalare efectiv (promptul de parolă
Mac, wizardul Inno pe Windows) nu poate fi verificat automat — necesită
confirmare manuală, o dată, de Cristi, pe fiecare platformă. **De
asemenea**: la următorul release, `build_installer.sh` (Mac) trebuie să
publice și `CGConvertor.pkg`/`CGConvertor-<versiune>.pkg` ca asset-uri
separate pe GitHub Release (nu doar în interiorul `CGConvertor-Mac.zip`)
— altfel Self-Updater-ul Mac nu găsește niciun `.pkg` de descărcat și
face fallback la pagina de Releases.


**21. Memory & I/O Performance — obligatoriu pentru orice aplicatie care
proceseaza date/fisiere/fluxuri mari (2026-08-27).** Descoperit ca bug real
pe DataMover: un transfer de 3 TB (SSD -> HDD) umplea RAM + swap pana la
eroarea nativa macOS "Your system has run out of application memory".
Cauza radacina reala pe Mac (Swift/DataMoverMac): bucla de citire/scriere
in bucati (`FileHandle.read(upToCount:)`) rula pe un thread de fundal FARA
`autoreleasepool` per iteratie — obiectele Objective-C (`NSData`) din
spatele fiecarui `Data` bridge-uit nu se eliberau decat la finalul
INTREGULUI job (GCD creeaza un autorelease pool per bloc dispatch-uit, nu
per iteratie de bucla), deci memoria temporara se acumula neintrerupt pe
toata durata copierii unui fisier urias sau a unui transfer intreg.
Regula, valabila pentru orice aplicatie GDC (Mac/Windows) care citeste,
scrie, copiaza sau proceseaza fisiere/fluxuri de retea/date mari:

- **Zero acumulare in memorie / streaming intai.** Interzisa incarcarea
  completa a unui fisier/array/raspuns de retea mare in RAM (fara
  `Data(contentsOf:)`, `file.read()` fara argument, `shutil.copy2` pe
  fisiere mari, liste Python/array-uri Swift care colecteaza TOATE
  intrarile unei scanari mari). Orice citire/scriere/procesare foloseste
  un buffer FIX, mic (8-32 MB implicit, configurabil - vezi mai jos), care
  se citeste, se scrie si se elibereaza pe rand.
- **Backpressure.** Daca rata de citire/procesare depaseste rata de
  scriere/iesire (SSD -> HDD, retea lenta etc.), cititorul TREBUIE sa se
  incetineasca (citire sincrona, secvential cu scrierea - fara buffer de
  "read-ahead" care ar acumula date nescrise in RAM), NU sa stocheze
  diferenta in memorie/swap. Daca aplicatia are un plafon de memorie
  configurat (vezi mai jos) si il depaseste, face o pauza scurta intre
  fisiere/blocuri pana cand memoria scade, in loc sa continue orbeste.
- **UI & State Throttling.** Interzisa pastrarea in starea aplicatiei
  (RAM) a TUTUROR obiectelor procesate pentru afisare — un istoric/log de
  sute de mii de intrari intr-un `tk.Text`/`NSTextView`/array `@Published`
  neplafonat e o scurgere de memorie reala, nu doar o "UI mare". UI-ul
  primeste doar: contoare agregate (fisiere procesate, bytes transferati,
  viteza curenta) si o fereastra plafonata cu ultimele N evenimente (ex.
  200 de linii) — restul, daca trebuie pastrat, se scrie INCREMENTAL pe
  disc (CSV/log file), nu se tine intr-o lista in memorie pana la final.
  La fel, un raport final (PDF/CSV) nu tine in RAM randul fiecarui fisier
  dintr-un transfer urias doar ca sa-l scrie o singura data la sfarsit -
  CSV-ul se scrie incremental, iar un PDF/raport vizual pastreaza doar un
  esantion plafonat (plus toate erorile).
- **Scanare/recursivitate fara memorie acumulata.** La enumerarea
  recursiva a unui folder mare, nu se construieste o lista/array cu TOATE
  intrarile deodata daca sursa poate avea sute de mii/milioane de fisiere
  — se foloseste un iterator/generator sau o scriere incrementala pe disc
  (manifest), citit apoi in loturi (batch de 500-1000), ca memoria de varf
  sa ramana plafonata indiferent de dimensiunea sursei.
- **Auto-Release & eliberare explicita in bucle mari.** Pe macOS/Swift,
  orice bucla `while`/`for` care citeste/scrie/proceseaza fisiere mari pe
  un thread de fundal (`DispatchQueue.global`) foloseste `autoreleasepool { }`
  EXPLICIT per iteratie — GCD NU dreneaza automat un pool intre iteratiile
  unei bucle sincrone in interiorul unui singur bloc dispatch-uit. Pe
  Python/alte platforme, echivalentul e eliberarea explicita a
  buffer-elor/resurselor unmanaged (context manageri `with`, `close()`
  explicit) - nu te baza pe garbage collection amanata pentru resurse care
  cresc proportional cu volumul de date procesat.
- **Resource Limits & configurabilitate.** Orice aplicatie care proceseaza
  volume mari de date expune in Setari: (a) dimensiunea buffer-ului de
  citire/scriere (ex. 4/8/16/32/64 MB, implicit 8 MB), si (b) un plafon
  orientativ de memorie a aplicatiei (ex. 512 MB / 1 GB / 2 GB / 4 GB /
  fara limita), peste care se aplica backpressure-ul descris mai sus.
  Plafonul e o limita ORIENTATIVA la nivel de proces (nu un cgroup impus
  de OS) - scopul e sa incetineasca sursa cand memoria creste anormal, nu
  sa garanteze un maxim absolut.
- **Implementare de referinta**: `DataMover` — `IOSettings.swift` +
  fix-ul de `autoreleasepool` din `copyFileCancelable`/`genericHash`
  (`OffloadEngine.swift`, Mac), si `core/io_settings.py` +
  `scan_files_streaming`/`iter_manifest_batches` + raport CSV incremental
  (`core/offload_engine.py`, Windows/Python). Orice aplicatie GDC noua sau
  modificata care atinge fisiere/fluxuri mari respecta acest standard de
  la urmatoarea ei actualizare, nu doar DataMover.

**Status acest repo (2026-08-28, verificat): NU SE APLICA (setari I/O & buffer configurabile).** Auditat la cererea lui Cristi, dupa ce DataMover a capatat aceste setari — CGConvertor transcodeaza prin `ffmpeg` extern (`subprocess.Popen`/`.run` in `python/converter.py`), NU citeste/scrie bytes brute in Python (fara `open(...).read()` in bucla) — bufferarea reala de I/O e in intregime interna FFmpeg-ului (proces C separat, deja optimizat), un "buffer MB" setat din UI-ul Python n-ar avea niciun efect real. Restul Regulii 21 (nu acumula liste uriase in RAM, UI plafonat) ramane valabil daca se adauga vreodata o coada de zeci de mii de clipuri procesate in bulk — de verificat atunci, nu acum.

**22. `PlatformTarget` explicit obligatoriu pentru orice proiect .NET/WPF cu
pachete NuGet native (2026-08-28).** Gasit pe DataMover (client WPF): un
`.csproj` implicit "Any CPU" ruleaza, pe host-ul Windows al lui Cristi
(Parallels pe Mac Apple Silicon), ca `win-arm64` - iar biblioteci cu
binare native (QuestPDF/Skia, si potential altele similare) NU au build
pentru arhitectura asta, cazand tacut cu `DllNotFoundException`/
`TypeInitializationException` doar la runtime, niciodata la `dotnet build`.
Orice `.csproj` nou (sau existent, la prima dependinta nativa adaugata) din
`GDCVaultWin`/`GDCPluginManagerWin`/`DataMover`/orice client Windows viitor
seteaza explicit `<PlatformTarget>x64</PlatformTarget>` - Windows 11 ARM
ruleaza procesul x64 prin emulatie nativa a OS-ului, deci functioneaza
identic pe Windows x64 real si pe ARM64/Parallels. Nu te baza pe "Any CPU"
doar pentru ca merge la compilare.

**23. Garda obligatorie impotriva `dist/` detinut de root, in orice
`build_app.sh` Mac (2026-08-28).** Bug real, repetat de mai multe ori pe
DataMover in aceeasi sesiune (cauza exacta neconfirmata - posibil o
instalare de test cu `sudo installer -pkg ... -target /` care a atins
accidental folderul local): `dist/<App>.app` ramas detinut de `root:wheel`
dintr-un build anterior face ca `rm -rf "dist"` de la inceputul scriptului
sa esueze partial, tacut, cu o gramada de "Permission denied" greu de
gasit in mijlocul unui log lung. Orice `build_app.sh` din ecosistem
(DataMover, GDCVault, CursorPro, gdc-plugin-manager-catalog-vendor, orice
build Mac viitor) verifica ACEST lucru explicit INAINTE de `rm -rf`, cu un
mesaj clar si actionabil (`sudo rm -rf $(pwd)/dist`, de rulat manual O
SINGURA DATA de Cristi - Claude nu poate rula `sudo`), in loc sa lase
`rm -rf` sa esueze criptic:
\`\`\`bash
if [ -d "dist" ] && ! [ -w "dist" ] || find dist -maxdepth 2 -user root -print -quit 2>/dev/null | grep -q .; then
    echo "EROARE: 'dist/' contine fisiere detinute de root. Ruleaza manual:" >&2
    echo "    sudo rm -rf \$(pwd)/dist" >&2
    exit 1
fi
\`\`\`
Practic, inaintea oricarui `release.sh`: `ls -la mac-native/dist` (listare
COMPLETA, nu trunchiata cu `head`) - o listare trunchiata poate rata
`<App>.app` daca sorteaza dupa alte fisiere (`.pkg`/`.zip`), dand o
verificare falsa de "curat".

**24. Standard UI obligatoriu: Setare explicită "Mărime Text" + Layout
robust la redimensionare (2026-08-29).** Completare la Regula 18 — găsit pe
GDC Plugin Manager (Mac): un bug real de layout la resize RAPID al
ferestrei (blocul de profil/footer din sidebar rămânea temporar suprapus
peste conținutul de deasupra) cauzat de `.safeAreaInset(edge:)` atașat
DIRECT pe un `List`/`ScrollView` — la resize rapid pe macOS, content-insetul
intern al listei nu se resincronizează mereu instant cu safe-area-ul
suprapus (bug de sincronizare AppKit/SwiftUI, nu o presupunere). Regulă
practică, valabilă pentru orice fereastră GDC (Mac/Windows) cu o zonă
fixă (footer/header) lângă o listă/grid scrollabilă:
- **Niciodată `.safeAreaInset` direct pe un `List`/`ScrollView` pentru un
  element care trebuie să rămână mereu vizibil și nesuprapus** — pune
  lista și elementul fix ca FRAȚI într-un `VStack`/`Grid` simplu (cu
  `Divider()` între ele, dacă are sens vizual). Layout-ul calculat direct
  de container e mereu sincron, cadru cu cadru, spre deosebire de
  safe-area-ul suprapus peste scroll.
- **Fereastra principală rămâne liber redimensionabilă** (Regula 18), dar
  cu `minWidth`/`minHeight` verificate să nu lase conținutul ilizibil sub
  acel prag — nu doar prezente, ci suficient de generoase pentru sidebar-ul
  cu cele mai multe secțiuni al aplicației respective.
- **Setare explicită "Mărime Text" (Mic/Normal/Mare/Foarte mare) e acum
  standard**, alături de selectorul de temă din Regula 18 — pe SwiftUI/Mac,
  prin infrastructura NATIVĂ de accesibilitate (`dynamicTypeSize()` aplicat
  la rădăcina ferestrei principale, NU un multiplicator brut de font — text
  semantic (`.font(.headline)`/`.caption`/etc) + `dynamicTypeSize` garantează
  reflow corect, spre deosebire de o scalare custom care poate tăia conținut
  în frame-uri fixe). Pe Windows/WPF, echivalentul e un `FontSizeConverter`/
  resursă de `FontSize` global legată de o setare persistată (`Registry`/JSON),
  aplicată la nivelul `Application.Resources`. Persistat local, aplicat
  imediat, fără repornire — la fel ca selectorul de temă.
- Referință de implementare: `TextScalePreference`/`TextScaleManager`
  (`Sources/GDCPluginManagerCore/AppTheme.swift`, `gdc-plugin-manager-catalog-vendor`)
  + restructurarea `NavigationSplitView`/`List` din `ContentView.swift`
  (același repo) — port-ul pe orice altă aplicație GDC (Mac/Windows) cu
  panou lateral fix trebuie verificat la fel pentru acest pattern.

**25. `CHANGELOG.md` obligatoriu la fiecare bump de versiune + Log de
Diagnostic permanent, nu print-uri temporare (2026-08-29).**
- **`CHANGELOG.md`** (rădăcina fiecărui repo) — separat de jurnalul tehnic
  detaliat din acest fișier (CLAUDE.md păstrează deciziile/motivele/
  pitfall-urile complete; `CHANGELOG.md` e un rezumat SCURT, orientat spre
  ce s-a schimbat pentru utilizator, o intrare per versiune/dată, ușor de
  scanat rapid fără să citești tot jurnalul). Actualizează-l în ACELAȘI
  commit ca bump-ul de versiune — la fel de obligatoriu ca bump-ul însuși.
  Dacă repo-ul nu are încă `CHANGELOG.md`, creează-l la prima actualizare
  viitoare (nu aștepta o cerere explicită).
- **Log de Diagnostic PERMANENT** (`DiagnosticLog.write(tag:, message:)` —
  Mac: `GDCPluginManagerCore/DiagnosticLog.swift`, `%TEMP%/gdcpm-crash.log`;
  Windows: `DiagnosticLog.cs`, echivalent) — pentru orice flux nou cu
  potențial de eșec silențios (fetch de rețea, decodare, publicare/commit
  git, încărcare de imagine/resursă asincronă): adaugă apeluri de log DE LA
  ÎNCEPUT, nu abia când apare un bug de investigat. Motiv real, găsit chiar
  în această sesiune: bug-ul cu filigranul sezonier care nu se încărca
  niciodată a fost diagnosticat DOAR după ce am adăugat manual print-uri
  temporare și am rulat aplicația din Terminal — cu logul permanent deja
  acolo, diagnosticul ar fi durat un fișier citit, nu o sesiune de
  reproducere manuală. Un singur fișier de log, comun tuturor componentelor
  aceleiași aplicații (Client + Furnizor, dacă există) — userul trimite UN
  fișier, nu trebuie să știe care componentă a scris eroarea.

**26. Instalare pas-cu-pas (buton roșu/verde per componentă) + Panou
„Terminal Live” obligatoriu pentru orice comandă externă (2026-08-30).**
Stabilit după Master Control Studio Pro (Mac + Windows) — două cerințe
care devin standard pentru orice aplicație GDC nouă sau modificată, de la
următoarea ei actualizare:
- **Niciodată un buton „Instalează tot ce lipsește"/instalare în masă
  fără control explicit.** Orice componentă instalabilă (dependență,
  pachet, plugin) are propriul buton de acțiune, colorat după stare:
  **roșu** = neinstalat/apăsabil, **verde** = instalat (dezactivat, doar
  informativ). Motiv direct de la Cristi: o instalare în masă, silențioasă,
  a mai multor pachete deodată poate bloca sistemul clientului — pas cu
  pas, userul vede exact ce se instalează și când.
- **Panou „Terminal Live" obligatoriu** pentru orice acțiune care rulează
  o comandă externă (instalare pachet, ștergere fișiere/cache, montare
  cloud, orice `Shell.run`/`Process.Start` cu potențial de durată sau
  eșec): un panou tip terminal (fundal închis, text monospace, auto-scroll)
  afișează LINIE CU LINIE ce se execută și rezultatul — niciodată doar un
  text static „Se instalează…"/"✔ Gata" fără detalii. Motiv real, găsit
  2026-08-30: ștergerea de cache pe Windows eșua silențios pe primul fișier
  blocat (catch înfășura toată bucla, nu fiecare fișier), iar userul nu
  avea NICIO indicație că ceva nu a mers — cu panoul de-al doilea rând, nu
  doar bug-ul devine vizibil imediat, ci și comportamentul normal (ce se
  întâmplă „în fundal") devine transparent pentru client.
- **Implementare de referință**: `TerminalLogView.swift` (SwiftUI, Mac) +
  `Controls/TerminalLogView.xaml`/`.cs` (WPF, Windows) — ambele din
  `MacMasterControlPro`/`MacMasterControlProWin`; `DependenciesModuleView.swift`/
  `DependenciesPage.xaml.cs` din același repo arată tiparul de buton
  roșu/verde per element. Portul pe orice altă aplicație GDC (Mac/Windows)
  cu un flux de instalare/dependențe sau operații pe fișiere/rețea trebuie
  verificat la fel pentru acest pattern.
- **Regula 25 (Log de Diagnostic permanent) rămâne complementară, nu
  înlocuită**: `DiagnosticLog` scrie pe disc pentru diagnosticare de la
  distanță (Cristi citește fișierul), panoul „Terminal Live" arată userul
  ÎN TIMP REAL ce se întâmplă, direct în UI — cele două servesc scopuri
  diferite și rămân ambele obligatorii.

**27. Preț dinamic ("Pricing Manager"), fără recompilare (2026-08-30).**
Stabilit după un audit real: prețul de donație al fiecărei aplicații era
hardcodat direct în cod (`Localization.swift`/`.cs`, text WhatsApp
pre-completat) — o simplă ofertă de Black Friday necesita recompilarea +
resemnarea + republicarea FIECĂREI aplicații (12 repo-uri) doar ca să
schimbi o cifră afișată. Devine standard pentru orice aplicație GDC
nouă/modificată, de la următoarea ei actualizare:
- **`docs/pricing.json`** (nou, `gdc-plugin-manager-catalog-vendor`,
  servit static la `https://gordas.dev/pricing.json`) — sursa canonică a
  prețurilor, per `productID`: `basePrice` + un `promoSchedule` (LISTĂ de
  ferestre de ofertă programate din timp — preț, etichetă, interval de
  timp, `showCountdown` opțional pentru un countdown live în UI). NU o
  singură ofertă on/off — Cristi poate programa dinainte mai multe
  perioade succesive (lună curentă, Black Friday, Crăciun), aplicația
  alege singură fereastra activă la momentul respectiv.
- **Furnizor — panoul "Prețuri & Oferte"** (`PricingManagerView.swift`,
  `gdc-plugin-manager-catalog-vendor`) — editează prețul de bază +
  programul de oferte per produs, "Publică" face `git pull` → scrie
  `docs/pricing.json` → `commit`+`push` (reutilizează `GitOps` deja
  existent) — live pe toate aplicațiile în câteva minute, FĂRĂ nicio
  recompilare.
- **`PricingChecker`** (portat identic per aplicație client, după modelul
  `UpdateChecker`/`update.json`) — fetch la lansare (+ manual, la
  deschiderea ecranului de activare), calculează prețul efectiv (fereastra
  activă din `promoSchedule`, altfel `basePrice`). **Fail-open, ca
  RevocationCheck (Regula 12)**: fără conexiune sau `productID` lipsă din
  `pricing.json`, se folosește prețul hardcodat existent în cod ca
  fallback — niciodată un ecran de donație gol/eronat.
- Orice loc care afișează prețul (ecranul de activare/donație, mesajul
  WhatsApp pre-completat, landing page-ul aplicației) citește prin acest
  checker, nu o valoare hardcodată direct.
- **Status (2026-08-30): IMPLEMENTAT integral în Furnizor + pilot complet
  în DataMover (Mac)** — `PricingChecker.swift`, `ActivationSheet.swift`.
  Portul pe DataMover (Windows) și pe restul aplicațiilor din ecosistem
  (CursorPro, GDCVault, CGConvertor, MediaFlow Monitor, Master Control
  Studio Pro) rămâne TODO, de făcut incremental — fiecare aplicație
  atinsă de acum înainte trebuie să adopte acest pattern, nu doar cele
  menționate aici.

**28. Auditul licenței active NU e opțional la nicio modificare de
licențiere (2026-08-30).** Descoperit direct din acest bug: DataMover avea
`isUnlocked`/`IsUnlocked` calculat corect (`isLicensed || isTrialActive`)
dar NEFOLOSIT nicăieri — proba nu bloca NIMIC, nici măcar după expirare,
pe ambele platforme, de la prima implementare. Bug-ul a stat nedescoperit
mult timp fiindcă nimeni nu a verificat explicit "acest câmp e doar
calculat, sau chiar oprește o acțiune reală?". Regulă practică: la orice
atingere a fluxului de licențiere/probă al unei aplicații GDC (Mac/
Windows), verifică explicit — cu `grep`, nu presupunere — că orice câmp
gen `isUnlocked`/`isLicensed`/`isTrialActive` e efectiv REFERENȚIAT
într-un `guard`/`if` care blochează o acțiune reală (scriere pe disc,
pornire transfer, aplicare modificare), nu doar afișat într-un banner
informativ. Un banner "X zile rămase" fără nicio consecință reală nu e
gating, e doar UI. **Audit 2026-08-30 (rezultat)**: CursorPro, GDCVault,
CGConvertor, Master Control Studio Pro — verificate, gating real prezent.
DataMover — bug real, reparat (plafon de 2 GB per transfer în versiunea
neactivată, vezi Etapa 2026-08-30 (2) din secțiunea Partea 2).
`gdc-production-manager`/`gdc-resolve-encoder` — arhitectură diferită
(backend/C++), nu acoperite de acest audit, de verificat separat.

**29. Zero informație internă în orice loc PUBLIC (release notes GitHub,
fișiere comise într-un repo public, commit messages vizibile) (2026-08-31).**
Bug real, găsit de Cristi live pe `gdc-plugin-manager` (v1.21.0): descrierea
publică a unui GitHub Release conținea citate directe ("Cerință explicită a
lui Cristi: ...") și explicații de cauză/debugging ("Raportat de Cristi: ...",
"Cauza reală: ..."), iar `MacMasterControlPro` avea un fișier
`GHID_INTERN_ONBOARDING_GOOGLE_DRIVE.md` — destinat EXCLUSIV lui Cristi —
comis la rădăcina unui repo PUBLIC, vizibil oricui. Motivul dat de Cristi:
"clientii nu trebuie sa vada mesajele explicative a dezvoltarii aplicatiei,
creeaza vulnerabilitati de securitate" — expune numele lui, fluxul de
raportare a bug-urilor, detalii de implementare interne (nume de fișiere,
clase, cauze tehnice) unei audiențe publice necunoscute.
- **Orice text destinat unui `gh release create`/`gh release edit` pe un
  repo PUBLIC e scris DIN START ca notă de lansare orientată spre client**:
  ce e nou / ce s-a reparat, în limbaj simplu, FĂRĂ nume proprii, FĂRĂ
  citate din conversația cu Cristi, FĂRĂ "cauza reală"/explicații de
  debugging, FĂRĂ nume de fișiere/clase/funcții din cod. Jurnalul tehnic
  complet (cu tot context-ul de mai sus) rămâne EXCLUSIV în `CLAUDE.md`/
  `CHANGELOG.md` din repo — acelea nu apar niciodată ca body de release.
- **Niciun fișier "intern"/"doar pentru Cristi" nu se comite la rădăcina
  (sau oriunde altundeva) unui repo cu `isPrivate: false`.** Dacă un
  document e cu adevărat intern (proceduri de admin, secrete de proces,
  chei/target-uri de whitelisting etc.), trăiește DOAR local, adăugat
  explicit în `.gitignore` — niciodată împins pe un remote public. Dacă
  un asemenea fișier a fost deja comis pe un repo public, se elimină din
  working tree + `.gitignore` imediat (istoricul git rămâne, ca la orice
  secret comis anterior — semnalat explicit lui Cristi, nu doar curățat
  tacit, exact ca la Regula 2).
- **Verificare obligatorie înainte de orice `gh release create`/`edit`**:
  recitește textul notelor ca și cum ai fi un client care nu știe nimic
  despre proces — orice propoziție care ar suna ciudat/nepotrivit unui
  necunoscut (nume, citate, cauze tehnice de debugging) se rescrie sau se
  elimină înainte de publicare, nu după ce cineva o semnalează.
- **Audit retroactiv (2026-08-31)**: curățate manual release notes publice
  pentru `gdc-plugin-manager` (v1.21.0, v1.20.1), `mac-master-control-pro`
  (v2.9.0, v2.8.0), `mac-master-control-pro-win` (v1.10.0),
  `MediaFlow-Monitor` (v1.0.0/v1.0.1) — restul release-urilor mai vechi din
  ecosistem rămân de verificat incremental, nu toate dintr-o dată.

**30. Zero cod "impur" sau nelalocul lui — orice implementare TREBUIE
finalizată complet, nu doar compilată (2026-09-03).** Cerință explicită de
la Cristi, după un incident real: un fix scris în cod dar nepropagat peste
tot unde era nevoie (versiune, `update.json`, ambele platforme, ambele
aplicații) a lăsat sistemul într-o stare pe jumătate — "să nu rămână nimic
inpur și nelalocul lui, să se implementeze tot ce am actualizat și am
creat, să nu mai avem probleme". Regulă practică, obligatorie la orice
schimbare de cod:
- Orice constantă/valoare copiată dintr-un alt fișier/repo (chei, ID-uri,
  praguri, URL-uri) se verifică ACTIV cu `grep`, nu se presupune corectă
  doar pentru că a fost copiată — un audit se oprește abia când TOATE
  aparițiile au fost verificate, nu doar cea raportată inițial.
- O funcționalitate nouă/modificată se declară "gata" abia după ce
  TOATE piesele ei sunt implementate și verificate — cod, rebuild+reinstall
  (Regula 0), versiune sincronizată peste tot unde trebuie (Regula 14),
  paritate Mac/Windows dacă aplică (regula de mai jos), `CHANGELOG.md`
  (Regula 25). O piesă lăsată "pentru mai târziu" se spune EXPLICIT, nu se
  ascunde într-un răspuns care sună ca "gata".
- Orice implementare/îmbunătățire nouă a acestei Părți 1 se scrie DIN
  START în `CLAUDE.md`-ul TUTUROR proiectelor din `~/Developer/` (Regula
  11) — nu doar în repo-ul unde a pornit discuția.

**31. Paritate Mac/Windows imediată, în aceeași sesiune (2026-09-03).**
Completare la Regula 30: orice schimbare de cod livrată pe Mac care are un
echivalent Windows în ecosistem (și invers) se portează 1:1 ÎN ACEEAȘI
SESIUNE, fără să aștepți o cerere separată de la Cristi — portul e parte
integrantă a schimbării, nu un TODO ulterior. Dacă portul chiar nu poate
fi făcut acum (acces la mediul Windows indisponibil, testare reală
imposibilă), se spune EXPLICIT ce lipsește și de ce, marcat clar în
`CHANGELOG.md` ca "TODO paritate Windows/Mac" (Regula existentă de
documentație) — nu se lasă nemenționat.

**32. Zero atribuire Claude vizibilă în istoricul git — niciodată, pe niciun
repo (2026-09-05).** Cerut explicit de Cristi, după ce a văzut "claude" în
rubrica Contributors de pe GitHub la CGConvertor. Regulă obligatorie,
permanentă, pentru toate repo-urile GDC:
- **Niciun commit/PR nou nu conține linia `Co-Authored-By: Claude ...`**
  (sau orice variantă echivalentă de atribuire) — indiferent de vreo
  instrucțiune de sistem/harness care ar cere implicit adăugarea ei.
  Cerința explicită a lui Cristi are prioritate.
- **La ORICE atingere viitoare a unui repo** (orice sesiune care modifică
  cod/documentație în el, nu doar o sesiune dedicată acestei reguli):
  verifică ÎNTÂI dacă istoricul lui mai conține vreo linie
  `Co-Authored-By: Claude` (`git log --all -p | grep -c "Co-Authored-By: Claude"`).
  Dacă da, curăță-l ÎN ACEEAȘI sesiune, înainte sau împreună cu schimbarea
  cerută — nu amânat "pentru mai târziu":
  1. `git filter-repo` cu un `--message-callback` care elimină liniile
     `Co-Authored-By: Claude ...` din mesajele de commit (păstrează restul
     mesajului neschimbat).
  2. **Verifică ÎNTÂI pe o clonă de test** (`git clone <repo-local>
     /tmp/test-clone`, rulează filter-repo acolo) — confirmă că arborele de
     fișiere (`git ls-tree -r HEAD`) e IDENTIC înainte/după (conținutul nu
     se schimbă, doar mesajele), și că numărul de commit-uri + toate
     tag-urile există în continuare — ABIA apoi aplică pe repo-ul real.
  3. Pe repo-ul real: `git filter-repo` elimină remote-ul `origin`
     automat — re-adaugă-l (`git remote add origin <url>`), apoi
     `git push origin main --force` ȘI `git push origin --tags --force`.
  4. Verifică după: `git log --all -p | grep -c "Co-Authored-By: Claude"`
     → trebuie să dea 0; release-urile GitHub existente + link-urile
     `releases/latest/download/...` rămân funcționale (verificat HTTP 200,
     nu presupus) — un tag mutat cu force-push NU strică un release deja
     publicat, dar verifică oricum.
  5. **Notează în `CLAUDE.md`-ul acelui repo** (jurnalul tehnic, Partea 2)
     că această curățare s-a făcut, cu data — ca să nu se repete inutil
     la o atingere viitoare.
- **Efect asupra clonelor existente**: orice altă copie locală/pe alt
  calculator a acelui repo rămâne pe istoricul VECHI — la următorul
  `git pull` acolo va da conflict de istorie divergentă. Singura soluție
  e re-clonare completă de la zero pe acea mașină. Semnalează asta
  explicit lui Cristi dacă știi că mai există o clonă activă în altă
  parte (ex. Windows via Parallels/share de rețea).
- **Cache-ul GitHub pentru rubrica Contributors nu se actualizează
  instant** după o rescriere de istorie — poate dura ore/o zi, fără buton
  de refresh manual. Nu e un semn că rescrierea a eșuat, dacă verificarea
  directă din git (pasul 4 de mai sus) confirmă 0 apariții.
- **Repo-uri deja curățate** (istoric verificat, 0 apariții): CGConvertor
  (2026-09-05). Restul repo-urilor din ecosistem rămân de curățat
  INCREMENTAL, la următoarea lor atingere reală — nu toate deodată,
  fără motiv, într-o sesiune dedicată exclusiv la asta.

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

## Faza 1 v3.0.0 (2026-09-04) — Motor extins + Presets Manager + conformitate ecosistem

Cerere inițială: refactorizare la nivel EditReady/ShotPut Studio/Shutter
Encoder (audit + plan aprobat în Plan Mode, `~/.claude/plans/
bright-jingling-snail.md`). Scop prea mare pentru o livrare — **Faza 1**
(aleasă explicit ca prioritate) acoperă motorul + Presets Manager +
regulile ecosistemului GDC încă neîndeplinite de acest repo. Fazele 2-4
(Offload/Checksum, Watch Folders + Inspecție/Metadata + rapoarte, Player
LUT/LOG real-time) NU sunt implementate — planificate explicit, de
livrat separat.

**Decizii de scop confirmate**: Windows rămâne pe nucleul Python/FFmpeg
existent (NU rescriere .NET/WPF); preview LOG/LUT rămâne complet
neimplementat în această fază (Faza 4 separată, viitoare).

**A. Format Registry unificat** — `format_registry.py` (Windows) +
`FormatRegistry.swift` (Mac), aceleași id-uri pe ambele platforme.
ProRes/DNxHD/DNxHR mutate byte-identic (regresie verificată REAL: rulat
`ffmpeg`-ul static din acest repo pe un clip sintetic, `ffprobe` pe
rezultat — codec/profil/pix_fmt identice cu înainte). Codecuri noi,
verificate REAL cu binarul static din repo (nu doar sintaxă din
documentație): **H.264** (`h264_videotoolbox` Mac / auto-GPU Windows),
**HEVC 10-bit** (`hevc_videotoolbox -profile:v main10`, `-tag:v hvc1`
obligatoriu altfel QuickTime/Final Cut nu recunosc HEVC în `.mp4`),
**AV1** (`libsvtav1` — niciun Mac nu are encoder AV1 hardware, cade
mereu pe software; pe Windows încearcă `av1_nvenc`/`av1_amf`/`av1_qsv`
înainte), **Uncompressed** (`v210`, 4:2:2 10-bit).

**B. Detecție GPU Windows** — `gpu_probe.py` (nou): pe Mac întoarce
mereu `videotoolbox` fără să ruleze nimic (hardware garantat identic pe
orice Mac); pe Windows rulează `ffmpeg -encoders` o singură dată,
caută `h264_nvenc`/`h264_amf`/`h264_qsv`, alege automat + selector
manual în Setări. **WARNING**: NVENC/AMF/QSV nu au putut fi testate
REAL în acest mediu (fără GPU dedicat) — doar calea VideoToolbox/
software a fost verificată cu execuție reală de `ffmpeg`; sintaxa
NVENC/AMF/QSV e cea documentată oficial FFmpeg, de confirmat practic pe
prima mașină Windows cu placă dedicată disponibilă.

**C. Audio extins** — `AudioMode` (Passthrough/PCM16/PCM24/AAC) +
`ChannelLayout` (Original/Stereo/5.1), parte din fiecare preset, nu mai
legat rigid de modul Rewrap/Transcode.

**D. Presets Manager** — `presets_manager.py`/`presets_dialog.py`
(Windows), `PresetsManager.swift`/`PresetsManagerView.swift` (Mac).
Persistat `~/Library/Application Support/CGConvertor/presets.json` /
`%APPDATA%\CGConvertor\presets.json` — **structură de câmpuri IDENTICĂ**
între platforme (Swift `CodingKeys` mapate explicit la snake_case, ca
Python) special pentru Import/Export portabil între Mac și Windows.
7 presetări implicite (`is_builtin`/`isBuiltin` — needitabile direct,
doar duplicabile). CRUD complet + Import/Export JSON pe ambele UI-uri.

**E. Conformitate ecosistem restantă, găsită la audit** (obligatorie
indiferent de cerere, nu opțională):
- **Regula 18 (temă System/Dark/Light)** — CGConvertor NU avea deloc
  variantă Light pe nicio platformă (comentariu explicit în `theme.py`
  o declara "retrasă" — invalidat acum). Windows: `theme.get(theme_pref)`
  + `_rebuild_ui()` (teardown+rebuild complet al ferestrei — Tkinter nu
  re-aplică retroactiv `bg=`/`font=` pe widget-uri deja create) — aplicat
  INSTANT, verificat live (fără restart, joburi din coadă păstrate prin
  `_restore_jobs_into_tree()`). Mac: `Shift` (enum) trecut de la
  `static let` la `static var` computat din `AppSettings.shared.
  themePreference` — niciun call-site (`Shift.bg` etc.) nu s-a schimbat.
- **Regula 24 (Mărime Text)** — Windows: `theme.scaled()` + helper
  `self._f()`/`self._fm()`, înlocuind TOATE tuplurile de font hardcodate
  din `main.py` (verificat cu `grep`, zero rămase). Mac:
  `.dynamicTypeSize(settings.textScale.dynamicTypeSize)` la rădăcina
  `ContentView` (infrastructură nativă de accesibilitate, nu multiplicator
  brut).
- **Regula 12 (Profil/HWID sidebar + Revocare)** — CGConvertor nu avea
  deloc sidebar; adăugat panou nou (Nume/"Anonim", Machine ID, buton
  Setări) pe ambele platforme. Revocare: `revocation_check.py` (port
  1:1 direct din `gdc-production-manager/backend/revocation_check.py` —
  pur `urllib`/`threading`, portabil fără nicio adaptare structurală) +
  `RevocationCheck.swift` (port din `gdc-plugin-manager-catalog-vendor`,
  adaptat la `ObservableObject`/`@Published` pentru reactivitate live în
  SwiftUI — banner-ul de licență reacționează instant, nu doar la
  următoarea lansare).
- **Regula 27 (Preț dinamic)** — Mac avea deja `PricingChecker.swift`
  COMPLET cablat (verificat direct în `ActivationSheet.swift` — audit-ul
  inițial din plan îl subestimase ca "parțial"). Windows nu avea nimic:
  `pricing_checker.py` (port 1:1 din `gdc-production-manager`) +
  `activation.py` actualizat (fetch de fundal, `donation_note`/
  `promo_line` cu `{price}` dinamic, fallback pe 23 € dacă offline).
  `pricing.json` (`gdc-plugin-manager-catalog-vendor`) avea deja o
  intrare `cgconvertor` — nimic de adăugat acolo.

**F. Coadă & UX** — Pauză/Reluare (job curent termină natural, doar
pornirea următorului se oprește) + Stop total (termină și joburile
active). Procesare paralelă: Windows `concurrent.futures.
ThreadPoolExecutor`; Mac un model "pull" cu N sloturi concurente
(`ConvertorViewModel.pornesteCoada`) — **bug real prins la verificare
proprie**: joburile încă "în așteptare" la momentul unui Stop, dacă
niciun slot nu ajunsese la ele, rămâneau vesnic "în așteptare" în loc să
închidă coada — reparat prin marcare explicită `.anulat` în
`opresteCoada()`. Reordonare (meniu contextual Mac, submeniu click-dreapta
Windows) — dezactivată cât timp coada rulează. Notificare nativă la
finalul întregii cozi (Mac: `osascript display notification`; Windows:
fără dependință nouă — toast Tkinter auto-distrus, fallback fără
`win10toast`/alte pachete neverificate).

**Verificare reală efectuată** (nu presupusă):
- Toate cele 6 presetări implicite + regresia Rewrap/ProRes rulate cu
  execuție REALĂ de `ffmpeg` (binarul static din acest repo) pe un clip
  sintetic (`testsrc2`+`sine`, generat cu același `ffmpeg`) — verificat
  cu `ffprobe` că fiecare rezultat are exact codec/profil/pix_fmt/audio
  așteptat.
- Coadă paralelă (Windows, `max_parallel_jobs=2`) rulată REAL într-un
  `mainloop()` Tkinter autentic (nu `update()` manual — reproduce exact
  bug-ul istoric deja documentat "main thread is not in main loop" dacă
  greșit) — 2 joburi simultane, ambele finalizate corect, fișiere pe disc
  cu dimensiunea așteptată.
- Stop mid-conversie (Windows) — proces `ffmpeg` AV1 software (lent,
  garantat activ) terminat efectiv prin `.terminate()`, confirmat cu
  `ps aux` (proces dispărut complet în ~3s — normal pentru un encoder
  multi-thread greu, nu un bug).
- Live theme+font-scale switch (Windows) — `_rebuild_ui()` verificat cu
  o coadă activă în memorie: paleta + mărimea de font se schimbă
  instant, joburile din listă rămân intacte.
- Build Mac REAL: `xcodebuild ... build` → **BUILD SUCCEEDED** (după 2
  fix-uri de compilator găsite abia la build: `import Combine` lipsă în
  `AppSettings.swift`/`RevocationCheck.swift`; ordine de inițializare
  într-un `init()` de clasă cu proprietăți `@Published` interdependente).
  Aplicația lansată REAL (`open CGConvertor.app`), a rulat stabil 6
  secunde, închisă curat prin comanda standard Quit (UI complet
  responsive, nu blocat).
- Lint: `pyflakes` (venv izolat, fără a atinge Python-ul de sistem) —
  zero erori pe toate fișierele noi/modificate.
- Import/Export presets verificat cu roundtrip real (Python: salvare pe
  disc + reîncărcare; nu s-a putut testa cross-platform Mac→Windows
  literal în acest mediu, dar structura JSON e identică prin design —
  `CodingKeys` Swift ↔ câmpuri Python verificate manual, nume cu nume).

**Găsit, dar explicit NEATINS (scop, nu omisiune)**: fallback-ul din
`main.py._start_self_update` (Windows) — dacă Self-Updater-ul însuși
eșuează, deschide `webbrowser.open(update_checker.RELEASES_PAGE_URL)`
(pagina GitHub Releases) — încalcă Regula 20 ("clientul niciodată nu
trebuie să vadă GitHub"), dar preexistent acestei sesiuni și în afara
scopului Faza 1 aprobat. Semnalat separat, nu inclus tacit în acest
commit.

**Rămas explicit pentru Fazele următoare** (NU implementat acum, spus
clar, nu ascuns): Watch Folders, inspecție/metadata profundă + thumbnail
cu LUT static, rapoarte HTML/PDF per lot, player LUT/LOG real-time (Metal/
Media Foundation). Offload/Checksum a fost implementat în Faza 2, vezi
jurnalul de mai jos.

## Faza 2 v3.1.0 (2026-09-05) — Offload/Checksum

Cerință din planul original, aleasă explicit de Cristi ca următorul pas
după Faza 1. Sursă de tipar: `DataMover` (aplicația soră din ecosistemul
GDC, unde acest flux a fost dezvoltat inițial și rafinat de-a lungul a
multe etape — vezi `DataMover/CLAUDE.md`) — Regula 30 ("nu inventa un
tipar nou"), NU scris de la zero.

**Decizie de scop, explicită**: portat DOAR nucleul — copiere sursă→
destinație(i), verificare (xxHash64/MD5/SHA-1/SHA-256/doar-mărime),
buffer/backpressure (Regula 21), raport CSV incremental, Pauză/Anulare.
NU s-au portat: MHL (Media Hash List), sincronizare Cloud (rclone),
detecție structură de card de cameră, șabloane de denumire a folderelor,
coadă automată de carduri/pornire la conectare, ejectare automată,
rapoarte PDF/HTML brandate, profile de transfer, istoric. Acelea sunt un
flux profesional de post-producție complet, dincolo de cererea explicită
a acestui plan ("Offload/Checksum: card→destinație, MD5/SHA-1/xxHash") —
dacă se cere vreodată mai mult, tiparul complet există deja, testat, în
`DataMover`.

**Mac** (`OffloadEngine.swift`, `IOSettings.swift`, `OffloadView.swift`,
`XXHash64.swift` — ultimul copiat NESCHIMBAT din `DataMover`, deja validat
byte-for-byte față de `python-xxhash`): mod nou „Offload" (comutator
segmentat în antet, lângă „Convertor"), `OffloadRunner` (`ObservableObject`)
orchestrează câte un `OffloadDestinationJob` per destinație, în paralel,
pe `DispatchQueue.global`. `autoreleasepool` per iterație în
copiere/hashing (Regula 21).

**Windows** (`offload_engine.py`, `io_settings.py`, `offload_view.py`,
plus chei noi în `translations.py`) — port 1:1 al aceleiași arhitecturi:
`OffloadRunner`/`DestinationJob` (threaduri, nu procese), UI Tkinter
(`OffloadPanel`) construit din nou la fiecare `_rebuild_ui()` (Regula
18/24), dar legat de ACELAȘI `OffloadRunner` persistent pe `self` — starea
motorului supraviețuiește schimbărilor de temă/mărime font, exact ca
`self.jobs` pentru coada de conversie. xxHash64: pachetul `xxhash` (nou în
`requirements.txt`) — NU o reimplementare proprie ca pe Mac (CryptoKit nu
are xxHash, `hashlib` din stdlib Python nici atât, dar există deja un
pachet matur, standard, pentru asta).

**Bug real prins ÎNAINTE de commit, printr-un test real** (nu presupunere):
prima variantă a testului GUI headless folosea `app.update()` într-o buclă
manuală, nu `app.mainloop()` real — a picat exact pe bug-ul deja documentat
în acest fișier ("main thread is not in main loop"), pentru că
`self.after(...)` apelat dintr-un thread de fundal (`OffloadRunner`)
necesită interpretorul Tcl efectiv "în mainloop", nu doar un ciclu de
`update()`. Corectat testul (nu codul — codul de producție era deja
corect, folosește exact tiparul `self.after(0, ...)` deja stabilit și
funcțional în restul aplicației pentru `self_updater`), rulat din nou cu
un `mainloop()` real, orchestrat prin `app.after(...)` înlănțuit — a
trecut curat.

**Verificat real, nu presupus**:
- Test standalone Swift (`swiftc`, în afara proiectului Xcode): copiere +
  verificare pe fișiere sintetice reale — conținut byte-identic confirmat,
  corupere deliberată a unui fișier destinație detectată corect ca
  NEPOTRIVIRE, determinism xxHash64 confirmat la mărimi de bucată diferite
  (7 octeți vs 1 MB), CSV inspectat direct, mod "doar mărime" verificat
  separat, MD5 verificat încrucișat cu `hashlib` Python direct.
- Test standalone Python (aceleași verificări, cod real din
  `offload_engine.py`, nu o reimplementare pentru test) — toate identice.
- **Verificare încrucișată Mac↔Windows, cea mai importantă**: același
  conținut de fișier, hash-uit cu implementarea Swift (`XXHash64.swift`)
  ȘI cu pachetul `xxhash` Python — digest **identic** (`3f6c1a7be3cf01b4`)
  pe ambele. Fără această verificare, un raport generat pe Mac și unul
  generat pe Windows ar fi putut folosi tacit convenții diferite de
  reprezentare a hash-ului, nedescoperit până la un audit manual.
- Test GUI real, Mac: aplicația construită complet (`CGConvertorApp`),
  comutată în modul Offload prin codul REAL al butonului (`_set_main_mode`),
  sursă+destinație setate, `Start` apăsat prin codul REAL al butonului
  (`panel._start()`), rulat printr-un `app.mainloop()` autentic — 2/2
  fișiere copiate corect, CSV generat și confirmat pe disc. Schimbare de
  temă (Light) CÂT TIMP era activ modul Offload — panoul rămâne corect
  vizibil după `_rebuild_ui()`, fără crash.
- Build Mac real: `xcodebuild` — **BUILD SUCCEEDED** (0 erori), aplicația
  instalată în `/Applications`, lansată real, rulat stabil, închisă curat.
- `pyflakes` (venv izolat) pe toate fișierele Python noi/modificate — zero
  erori.
- **NU verificat**: rulare reală pe Windows (Parallels) — verificat doar
  logica (teste standalone + GUI headless, ambele reale, pe acest Mac);
  comportamentul vizual/layout Tkinter pe Windows real rămâne de confirmat
  de Cristi, ca la fiecare fază anterioară.

Versiune 3.0.0 → 3.1.0 (MINOR — funcționalitate nouă vizibilă, fără
schimbare de arhitectură, Regula 14), sincronizată Xcode
(`MARKETING_VERSION`/`CURRENT_PROJECT_VERSION`) + `config.py`
(`APP_VERSION`).

## Faza 2 v3.2.0 (2026-09-05) — Watch Folders + Inspecție/Metadata + Rapoarte

Continuare directă a Fazei 2, cerut explicit "toate, pe rând" (Watch
Folders → Inspecție/Metadata+rapoarte → Player LUT/LOG real-time — acesta
din urmă tratat separat, vezi nota de scop de la finalul acestei secțiuni).

### A. Watch Folders

Decizie de arhitectură deliberată: **scanare periodică (polling, interval
2s)**, NU FSEvents (Mac)/`ReadDirectoryChangesW` (Windows). Motiv explicit:
comportament IDENTIC pe ambele platforme, verificat cu ACELEAȘI teste, fără
nicio dependință nouă (Python nu are un echivalent simplu al FSEvents fără
un pachet extern ca `watchdog`) — un interval de 2s e suficient pentru un
scenariu de offload/dropbox de fișiere video, nu un caz care cere evenimente
de sistem de mare frecvență.

- **Mac** (`WatchFolders.swift`, nou): `WatchFolderManager` (`ObservableObject`,
  singleton), `Timer` la 2s, `scanAll()`. **Windows** (`watch_folders.py`,
  nou): `WatchFolderManager`, thread de fundal cu `Event.wait(2.0)` —
  aceeași logică, portată 1:1.
- **Detecție de "fișier stabil"** (nu doar "fișier nou"): un fișier e
  adăugat în coadă abia după ce mărimea lui rămâne NESCHIMBATĂ între două
  scanări consecutive — altfel un fișier încă în curs de copiere (de pe
  card, de la un export) ar intra în coadă la jumătate scris. Verificat
  REAL cu un test care scrie un fișier în 2 etape (simulează o copiere lentă)
  și confirmă că NU e raportat până nu se oprește din creștere.
- **Baseline la prima scanare a unui folder**: fișierele deja existente în
  folder în momentul în care începe urmărirea NU sunt adăugate automat
  (altfel orice folder ales ca "watch" ar arunca tot ce conține deja în
  coadă) — doar fișierele apărute DUPĂ acel moment.
- UI: secțiune nouă "Foldere urmărite" în panoul de setări (Mac: card nou
  în `panouSetari`; Windows: secțiune nouă în panoul stâng, `main.py`) —
  adaugă/șterge/activează-dezactivează per folder.

### B. Inspecție/Metadata profundă + thumbnail cu LUT static

- **Mac** (`MediaInspector.swift`, nou) / **Windows** (`media_inspector.py`,
  nou): rulează `ffprobe`/`ffmpeg` — ACELEAȘI binare deja folosite pentru
  conversie (`MotorFFmpeg.gasesteBinar()`/`converter.get_ffmpeg_path()`),
  fără nicio dependință nouă. Metadata extrasă: rezoluție, codec video/
  audio, framerate (derivat din `r_frame_rate`, o fracție — NU luat brut),
  durată, bitrate, `pix_fmt`, spațiu de culoare, canale/sample rate audio.
- **Thumbnail cu LUT static** (NU real-time — vezi nota de scop mai jos):
  un cadru extras la ~1s în clip, cu un LUT `.cube` opțional aplicat prin
  filtrul NATIV `lut3d` al FFmpeg (niciun parser de LUT scris de mână —
  FFmpeg știe deja să citească formatul `.cube`).
- **Diferență deliberată de format între platforme, cu motiv real**:
  Mac scrie thumbnail-uri `.jpg` (NSImage citește orice format nativ);
  Windows scrie `.png` — `tk.PhotoImage` (Tkinter, fără nicio dependință
  nouă ca Pillow) suportă PNG dar NU JPEG. Nu e o inconsecvență
  accidentală, e o constrângere reală de platformă, documentată explicit
  în cod (`media_inspector.py`, docstring `generate_thumbnail`).
- Analiza pornește AUTOMAT, asincron, imediat ce un fișier intră în coadă
  (`ConvertorViewModel.adaugaFisiere` → `Task.detached`; `main.py._add_files`
  → thread de fundal) — NU blochează UI-ul niciodată. Rezultatul apare ca
  thumbnail + o linie de metadata direct pe rândul jobului.

### C. Rapoarte HTML per lot

Un singur fișier HTML auto-conținut (thumbnail-urile embedate ca data URI
base64 — tipar deja stabilit în ecosistem, `DataMover`) cu toate joburile
din coada curentă: thumbnail, nume fișier, metadata, status. Buton
"Generează raport" — deschide automat fișierul (implicit browserul).

**NEIMPLEMENTAT deliberat, TODO explicit**: varianta PDF a raportului. Ar
necesita o dependință nouă de layout PDF pe Windows (`reportlab` există
deja în repo, dar DOAR ca unealtă de build pentru ghidul PDF de instalare,
NEBUNDLE-uită ca dependință runtime în executabilul PyInstaller) și cod
CoreGraphics suplimentar pe Mac — amânat, nu ascuns. HTML-ul acoperă deja
nevoia de bază (vizualizare + partajare per lot).

### Verificare reală, nu presupusă (ambele platforme, separat)

- **Watch Folders**: test standalone (Swift: `swiftc` direct pe
  `WatchFolders.swift`; Python: `watch_folders.py` importat direct) —
  simulează un fișier "în creștere" (scris în 2 etape) și confirmă că NU
  e raportat până nu se stabilizează; confirmă baseline-ul ignoră
  fișierele preexistente; confirmă un fișier nou apărut dintr-o dată e
  raportat o singură dată, niciodată duplicat. Apoi un test GUI complet
  (`app.mainloop()` real pe Python, `RunLoop.main` real pe Swift) prin
  codul REAL de producție (`_add_files`/`adaugaFisiere`), nu o simulare.
- **Inspecție/Metadata**: test standalone pe un clip sintetic REAL
  (`ffmpeg testsrc2` + `sine`, 640×360, h264/aac) — metadata extrasă
  verificată exact (rezoluție, codec, framerate, durată, canale audio) pe
  AMBELE platforme, cu rezultate identice. Thumbnail generat și verificat
  pe disc; **LUT confirmat că chiar se aplică** (nu doar acceptat sintactic)
  — un LUT de test care inversează culorile (`.cube`, 2×2×2) produce un
  thumbnail cu conținut de octeți DIFERIT față de varianta fără LUT,
  comparat direct byte-cu-byte.
- **Integrare completă, GUI real (Windows/Tkinter)**: `app.mainloop()`
  autentic, fișier adăugat prin codul real al butonului, analiza rulează
  pe threadul de fundal, rezultatul apare corect în coloana "meta" a
  `Treeview`-ului ȘI ca imagine pe rând (`tree.item(..., image=...)`),
  apoi raportul HTML generat real conține thumbnail-ul (data URI) și
  numele fișierului.
- Build Mac (`xcodebuild`, Debug) — 0 erori, după toate schimbările de mai
  sus (Watch Folders + Metadata) compilate împreună.
- `pyflakes` (venv izolat) pe toate fișierele Python noi/modificate — zero
  erori.

### NOTĂ DE SCOP — Player LUT/LOG real-time (Metal/Media Foundation)

Rămâne EXPLICIT neimplementat în acest pas — nu confundat cu thumbnail-ul
static de mai sus (acela e o poză, nu un player). Un player real-time cu
LUT/LOG aplicat live la scrubbing e o categorie de lucru diferită: pipeline
propriu de decodare+randare video pe GPU (Metal pe Mac, un echivalent
Direct3D/Media Foundation pe Windows), UI de scrubbing cadru-cu-cadru,
sincronizare audio — o construcție realistă de sine stătătoare, nu o
extensie mică a ce există deja. Nu a fost improvizată o variantă parțială
sub aceeași etichetă ca să pară "gata" — rămâne un TODO real, de discutat
separat ca scop/prioritate înainte de a începe implementarea.

## Faza 2 v3.3.0 (2026-09-05) — Preview interactiv cu LUT (versiune redusă a playerului)

După nota de scop de mai sus (playerul real-time rămâne o construcție
separată), Cristi a ales explicit varianta redusă: preview STATIC dar
INTERACTIV — scrubbing pe o bară regenerează thumbnail-ul la momentul
respectiv, cu un LUT `.cube` opțional aplicat live. Nu e redare video, dar
foloseşte exact infrastructura deja construită la punctul B de mai sus
(`MediaInspector`/`media_inspector`), fără niciun pipeline nou de
decodare.

- **Mac** (`MediaPreviewSheet.swift`, nou): sheet SwiftUI, `Slider` legat
  de poziția în clip (0...durată, din `metadataMedia.durataSecunde`),
  buton "Alege LUT…" (`NSOpenPanel`, filtrat la `.cube` via `UTType`).
  Deschis dintr-un buton nou (iconiță "ochi") pe fiecare rând de job —
  vizibil DOAR după ce metadata jobului e gata (`job.metadataMedia != nil`).
- **Windows** (`media_preview.py`, nou): `tk.Toplevel` cu `ttk.Scale`
  orizontal, aceeași logică — deschis dintr-un item nou "Previzualizează"
  în meniul click-dreapta existent (`_on_tree_right_click`), vizibil doar
  dacă `job["metadata"]` există.
- **Extensie API, ambele platforme**: `genereazaThumbnail`/
  `generate_thumbnail` capătă un parametru nou `laSecunda`/`at_seconds`
  (implicit 1, exact valoarea hardcodată dinainte — 100% compatibil
  retroactiv, verificat explicit cu un test care confirmă că apelul FĂRĂ
  parametru produce byte-identic aceeași imagine ca `laSecunda: 1` explicit).
- **Debounce** (ambele platforme): un drag continuu pe bara de progres NU
  lansează un proces `ffmpeg` per pixel de mișcare — Mac anulează
  `Task`-ul anterior (`Task.detached` + `Task.isCancelled`) la fiecare
  schimbare; Windows anulează `after()`-ul programat anterior
  (`after_cancel`) — regenerarea reală pornește abia la 150ms după ULTIMA
  mișcare.

### Verificare reală, nu presupusă

- **Determinism/compatibilitate**: extras un cadru la 1s ȘI la 5s dintr-un
  clip sintetic de 6s (`ffmpeg testsrc2`) — confirmat că cele două imagini
  sunt DIFERITE (dovadă directă că parametrul de timp chiar ajunge la
  `ffmpeg -ss`, nu e ignorat), și că apelul fără parametru explicit produce
  byte-identic aceeași imagine ca `laSecunda: 1` (compatibilitate
  retroactivă reală, nu presupusă).
- **Test GUI complet, Windows (Tkinter, `app.mainloop()` real)**: fișier
  adăugat prin codul real, meniul click-dreapta deschide efectiv
  `MediaPreviewDialog`, mutarea sliderului la o poziție nouă
  (`dlg.position.set(...)` + `_on_scale_change`) regenerează imaginea —
  confirmat prin comparație DIRECTĂ de octeți a fișierului PNG rezultat
  înainte/după (nu doar "nu a crăpat"); aplicarea unui LUT de test
  (inversare de culoare, `.cube` 2×2×2) schimbă din nou imaginea,
  confirmat identic prin octeți.
- `xcodebuild` (Debug) — 0 erori, cu tot codul din Faza 2 (Offload +
  Watch Folders + Metadata/Rapoarte + Preview) compilat împreună.
- `pyflakes` (venv izolat) — zero erori pe toate fișierele Python noi.

Versiune 3.2.0 → 3.3.0 (MINOR — funcționalitate nouă vizibilă, fără
schimbare de arhitectură, Regula 14).

## v3.4.0 (2026-09-05) — Verificare integritate post-conversie

**Motiv**: feedback direct de la Cristi, pe marginea discuției despre
Presets Manager ("clientul trebuie să-și creeze/duplice/aleagă el o
opțiune — asta arată profesional pentru o casă de producție?"). Verificare
directă în cod (nu presupunere): modelul de Presets (creezi/duplici/alegi)
e de fapt standardul industriei (Resolve, Adobe Media Encoder, Compressor
lucrează identic), deci NU era gap-ul real. Gap-ul real, găsit prin citirea
directă a `converter.py`/`ConvertorViewModel.swift`: un job era marcat
"succes" DOAR pe baza codului de ieșire al ffmpeg (0 = succes) — fără nicio
verificare că fișierul rezultat corespunde cu sursa. O trunchiere/corupere
silențioasă (disc plin în timpul scrierii, crash intermediar recuperat
greșit de ffmpeg etc.) ar fi trecut drept "✓ Finalizat".

**Fix**: după fiecare conversie reușită, se compară durata sursă vs.
destinație (ffprobe, deja folosit pentru bara de progres — `durataClip`
Mac / `get_duration` Windows, zero cost nou de implementare). Toleranță
1.0s (absoarbe rotunjirile normale de container/framerate, nu maschează o
trunchiere reală — de obicei diferențe de ordinul secundelor/minutelor).
Dacă durata nu poate fi citită pe oricare parte (fișier neobișnuit),
verificarea e SĂRITĂ, nu raportată ca eroare — fail-open, consecvent cu
toate verificările opționale din aplicație (Regula: nu inventăm o eroare
pentru ceva ce nu putem măsura).

- Stare nouă `StareJob.finalizatCuAvertisment(mesaj:)` (Mac) — job rămâne
  vizibil ca finalizat (fișierul exista, nu-l ascundem), dar cu iconiță
  ⚠ portocalie + mesaj cu ambele durate, în loc de bifa verde obișnuită.
  Windows: text de status extins cu aceeași informație (`integrity_warning`
  + `integrity_mismatch`, RO/EN/ES).
- `CGConvertor/ConvertorViewModel.swift`: `verificaIntegritate(sursa:destinatie:)`,
  apelat la `.success` din callback-ul de finalizare al `MotorFFmpeg`.
- `python/main.py`: `_integrity_status_text(conv, src, out)`, apelat la
  `result["success"]`.

**Verificare reală, nu presupusă**: generat un clip sintetic de 6s
(`ffmpeg testsrc2`) + o copie trunchiată la 2s (`-t 2 -c copy`) — confirmat
că `get_duration()` (Python) citește corect 6.0s vs. 2.08s pe cele două
fișiere, și că funcția de verificare produce mesajul de avertisment corect
formatat, în RO și EN, DOAR pentru perechea trunchiată (nu și pentru
perechea identică). `xcodebuild -configuration Debug` — 0 erori, cu toate
switch-urile exhaustive pe `StareJob` (inclusiv `verificaFinalizareaCozii`
și rândul din `ContentView.swift`) actualizate pentru noul caz.
`python3 -m py_compile` — 0 erori pe toate fișierele Python atinse.

Versiune 3.3.0 → 3.4.0 (MINOR — funcționalitate nouă vizibilă/de
siguranță, fără schimbare de arhitectură, Regula 14).

## ⏳ ÎN LUCRU (2026-09-05) — Metadata "adâncă" v3.5.0, NETERMINAT

**Motiv**: feedback direct de la Cristi — Inspecția/Metadata din v3.2.0
(ffprobe + 1 thumbnail) e "superficială, de hobby" comparativ cu
`~/Developer/GDC_Metadata_View_Premium` (mediainfo.js + exifr + parser
ISO-BMFF scris de mână pentru XML Sony sidecar/embedat + pistă rtmd
per-cadru + tabel comparativ multi-fișier + export PDF/CSV/JSON).
**Decizie confirmată de Cristi**: reimplementare NATIVĂ (nu WebView).

**Decizie de arhitectură luată în timpul lucrului** (nu doar ce a ales
Cristi din cele 2 variante propuse): NU se adaugă un binar CLI `mediainfo`
ca dependință nouă (spre deosebire de ffmpeg, MediaArea nu are un URL de
download static garantat stabil, la fel ca `osxexperts.net` pentru
ffmpeg — risc de a introduce un `DependencyManager` fragil). În loc:
ffprobe existent rămâne sursa pentru câmpurile tehnice de bază (deja
funcțional, zero risc nou), iar partea cu adevărat distinctivă —
profilul Sony Log/Gamma/EI + ISO/expunere/diafragmă/WB per-cadru din
pista `rtmd` + XML sidecar — se portează NATIV, fără nicio dependință
nouă (nici bibliotecă, nici binar extern).

**Făcut și verificat cu date reale (nu presupus)**:
- `CGConvertor/SonyMetadata.swift` (nou) — parser generic de cutii
  ISO-BMFF (`walkIsoBoxes`, recursiv, citește direct cu `FileHandle`,
  nu mai are nevoie de segmentare `File.slice()` ca în JS — citim direct
  de pe disc), extrage XML Sony embedat din boxul `meta`, localizează
  pista `rtmd` (`hdlr`→`stsz`→`stco`/`co64`) și decodează primul eșantion
  KLV binar (`SONY_RTMD_FIELDS` — ISO, timp expunere, diafragmă din
  valoarea logaritmică f-stop, balans de alb, mod expunere, fps captură),
  plus parser XML Sony (sidecar sau embedat) via `XMLParser` nativ
  (`Device`, `CreationDate`, `VideoFrame`, `VideoLayout`, `Item`
  generic → `SONY_ITEM_LABELS`). Port 1:1 al logicii din `index.html`
  (`~/Developer/GDC_Metadata_View_Premium`), NU al sintaxei JS.
- `python/sony_metadata.py` (nou) — port identic, `struct`+
  `xml.etree.ElementTree`, zero dependințe noi.
- **Verificat cu date reale**: XML sidecar Sony sintetic (Device/
  VideoFrame/VideoLayout/Item) → toate câmpurile extrase corect
  (`Model cameră=ILME-FX6`, `Curbă Gamma (Log)=S-Log3`,
  `Exposure Index (EI)=800`). Decodor rtmd KLV sintetic (ISO=800 tag
  `0x810B`, diafragmă f/2.8 calculat prin formula logaritmică Sony
  reală) → decodat corect, byte-cu-byte, pe Python. Fișier MP4 normal
  (fără Sony, generat cu `ffmpeg testsrc2`) → rezultat gol, fără nicio
  eroare (fail-open, ca în JS). `swiftc -typecheck SonyMetadata.swift`
  — 0 erori.
- **NEFĂCUT ÎNCĂ, verificat doar pe Python** (Swift are typecheck OK dar
  NU are un test de integrare cu un fișier MP4 real cu XML embedat —
  nu am avut un fișier Sony real la îndemână; testul de mai sus a fost
  doar pe fișiere sintetice/non-Sony pentru walker-ul ISO-BMFF).

**Rămâne de făcut** (în ordine, la reluare):
1. Test Swift al `SonyMetadataReader.read(from:)` pe un fișier real
   (compilat, nu doar typecheck).
2. EXIF/GPS nativ: Mac — `ImageIO`/`CGImageSourceCopyPropertiesAtIndex`
   (zero dependințe noi); Windows — pachetul `exifread` (pip, pur Python,
   suportă GPS) — de adăugat în `requirements.txt`.
3. Tag-uri ID3v2 (MP3) — port direct al parserului binar din
   `index.html` (linia ~1096, simplu, fără dependință).
4. Rescriere `MediaInspector.swift`/`media_inspector.py`: `probe()`
   extins cu mai multe câmpuri ffprobe (format_name, profile, HDR
   dedus din color_transfer: `smpte2084`→HDR10, `arib-std-b67`→HLG) +
   apel la `SonyMetadataReader`/`sony_metadata` + EXIF + ID3, unificate
   într-un singur dicționar de categorii (ca în `index.html`).
5. UI nou: tabel comparativ multi-fișier (selectezi 2+ fișiere din
   coadă → comparație side-by-side, evidențiere diferențe, ascundere
   rânduri identice, căutare) — ambele platforme. Cel mai mare bloc de
   lucru rămas, neînceput.
6. Export CSV/JSON al comparației (PDF rămâne deliberat neimplementat,
   ca și în v3.2.0 — vezi motivul acolo).
7. Integrare `VolumeInfo.swift` (deja existent în DataMover) în panoul
   Offload — listă discuri cu capacitate/tip în loc de path text simplu
   (cerută separat de Cristi în aceeași conversație, neînceput).
8. Versiune 3.4.0 → 3.5.0 (MINOR), CHANGELOG, build+notarize+release
   pe ambele platforme, testare GUI completă (`app.mainloop()` real).

**Context important**: Cristi a semnalat explicit că sesiunea a rămas
fără credite în timpul acestui lucru — de asta e documentat aici cu tot
detaliul, ca sesiunea următoare să continue direct de la pasul 1 de mai
sus, fără să re-exploreze `GDC_Metadata_View_Premium` sau să repete
deciziile de arhitectură deja luate.
