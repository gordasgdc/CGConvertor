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

**[RECIDIVĂ GĂSITĂ ȘI REZOLVATĂ 2026-09-06]** O nouă atribuire reală
apăruse pe commit-ul `v3.14.2` (după curățarea din 2026-09-05) — o
sesiune ulterioară a scăpat regula. `git filter-repo` blocat de
clasificatorul mediului — Cristi a rulat manual
`~/Developer/clean-claude-attribution.sh CGConvertor`. **Verificat după
rulare: 0 apariții** (`git log --all --format=%B | grep -c
"Co-Authored-By: Claude"`), remote `origin` corect re-adăugat, push
confirmat.

**33. Iconițe SVG monocrome, tip contur — niciodată emoji, pe nicio pagină
web GDC (2026-09-05).** Cerut explicit de Cristi, după ce a comparat
`gordas.dev/DisplayCAL-CG/` (emoji colorate ca iconițe de feature) cu
`gordas.dev/mac-master-control-pro/` (sprite SVG monocrom, `currentColor`,
stil contur) — a doua variantă e standardul, prima nu mai e acceptabilă.
Regulă obligatorie pentru orice pagină de prezentare/descărcare GDC nouă
sau atinsă de-acum înainte:
- Un singur `<svg style="display:none">` cu `<symbol>`-uri, inserat o
  singură dată în `<body>`, referit prin `<svg><use href="#icon-x"/></svg>`
  oriunde e nevoie (brand mark din header, badge mare din hero, iconițe de
  feature, iconițe din butoane) — niciodată emoji Unicode (⬇ 🎯 🖥️ 📊 etc.)
  ca iconiță funcțională sau decorativă principală.
- Stil vizual: `fill="none" stroke="currentColor" stroke-width="1.6-1.8"
  stroke-linecap="round"` (contur simplu, 24×24 viewBox) — culoarea vine
  din CSS (`color:var(--accent)` pe containerul părinte), nu hardcodată în
  SVG. Vezi sprite-ul complet de referință din `mac-master-control-pro/`
  (`gear`, `zap`, `piechart`, `globe`, `cloud`, `trash`, `wrench`, `shield`,
  `cpu`, `box`, `harddrive`, `download`, etc.) — reutilizează un icon
  existent din acel sprite dacă se potrivește semantic, înainte de a
  desena unul nou.
- **Atenție la `data-i18n`/`textContent` pe elemente care conțin și un
  `<svg>`** (ex. un buton cu iconiță + text) — `el.textContent = ...` la
  schimbarea de limbă ȘTERGE orice copil SVG din acel element. Textul
  tradus trebuie să stea într-un `<span data-i18n="...">` COPIL, separat
  de `<svg>`, niciodată direct pe elementul care conține iconița.
- **Nu retroactiv, la fiecare pagină deodată** — orice aplicație/pagină
  care încă folosește emoji ca iconițe de feature se aliniază la acest
  model DOAR la următoarea ei atingere/actualizare reală, nu într-o
  sesiune dedicată exclusiv migrării tuturor paginilor existente.
- **Bonus, găsit în aceeași sesiune**: bulina de status colorată
  (`.dot`/`.signed-note .dot`, un `<span>` cu `background` CSS) NU intră
  sub această regulă — e un indicator de stare semantic (verde =
  verificat), nu o iconiță de conținut, poate rămâne CSS pur.

**34. Semnare Windows (Code Signing) obligatorie la build — Self-Signed
ca implicit pentru testare internă, real (comercial) la lansare publică
(2026-09-06).** Cerut explicit de Cristi, după clarificarea (verificată
tehnic, nu presupusă) că un certificat self-signed NU elimină avertismentul
SmartScreen/"Unknown Publisher" pentru publicul larg — doar un certificat
real de la o CA publică (cu reputație acumulată) sau un certificat EV fac
asta; din iunie 2023, CA/Browser Forum obligă orice certificat OV/EV nou
să fie stocat pe token hardware/HSM cloud (Azure Trusted Signing, DigiCert
KeyLocker, SSL.com eSigner), NU ca `.pfx` exportabil. Decizie explicită
Cristi: self-signed ACUM (testare internă + cerc restrâns, cu `.cer`
importat manual de colaboratori în Trusted Root), evaluare Azure Trusted
Signing/EV la lansarea comercială publică — regula de mai jos NU
presupune că self-signed rezolvă SmartScreen pentru clienți finali, e
DOAR pentru etapa de testare.
- **Certificatul (privat, cu cheie) NU trece NICIODATĂ prin conversația cu
  Claude** — generarea (`New-SelfSignedCertificate`, doar posibilă pe
  Windows real, Claude nu poate rula asta de pe Mac) și încărcarea ca
  secret CI (`gh secret set`, valoare base64 a `.pfx` + parola) se fac
  DIRECT de Cristi, pe mașina lui Windows — identic cu regula deja
  existentă pentru parole/chei (Claude nu vede/manipulează credențiale).
- **CI-ul de build Windows verifică ÎNTÂI existența secretelor** (ex.
  `WIN_SELFSIGN_PFX_BASE64`/`WIN_SELFSIGN_PFX_PASSWORD`) — dacă lipsesc,
  build-ul continuă NESEMNAT (exact ca varianta Mac, `APPLE_SIGN_IDENTITY_APP`
  nesetat → semnare ad-hoc, niciodată o eroare de build). Dacă sunt
  prezente: decodează `.pfx`-ul temporar, semnează cu `signtool.exe`
  (localizat dinamic din Windows Kits, NU hardcodat o versiune) atât
  executabilul PyInstaller cât și installer-ul final Inno Setup, cu
  timestamp (`/tr .../td sha256`) ca semnătura să rămână validă și după
  expirarea certificatului, apoi ȘTERGE fișierul `.pfx` temporar de pe
  disc imediat după folosire.
- **Verificare post-semnare obligatorie în CI**: `Get-AuthenticodeSignature`
  (confirmă DOAR că fișierul are efectiv o semnătură atașată — nu
  `signtool verify /pa`, care validează lanțul de încredere complet și
  eșuează mereu pe un runner CI proaspăt, unde certificatul self-signed
  nu e importat în Trusted Root; asta e normal pentru testare internă,
  nu un eșec real) pe fiecare executabil semnat, ÎNAINTE ca pasul de
  build să fie considerat trecut — o semnare care "reușește" silențios
  dar produce un binar nesemnat/corupt nu trebuie să treacă drept succes.
  **[CORECȚIE 2026-09-06]**: prima implementare folosea `signtool verify
  /pa`, care a picat CI-ul chiar și după o semnare reușită — descoperit
  la primul test real, corectat imediat.
- **Exportul `.cer` (public, fără cheie privată)** se publică alături de
  installer (asset de release sau folder `dist/`) — colaboratorii îl
  importă o SINGURĂ dată în Trusted Root, apoi orice build viitor semnat
  cu ACELAȘI certificat (persistent via secret CI, NU regenerat la
  fiecare build — un cert nou la fiecare release ar rupe încrederea deja
  acordată) e automat de încredere pe mașinile lor.
- **Aplicare**: la fiecare build de release/actualizare Windows, pe orice
  aplicație din `~/Developer/` care produce un `.exe`/installer Windows —
  aplicată incremental, la următoarea atingere reală a fiecărui repo
  (Regula 11), nu retroactiv peste tot dintr-o sesiune dedicată.
- **Implementare de referință**: CGConvertor (`build-windows.spec` +
  `.github/workflows/build-windows.yml`, 2026-09-06) — vezi
  `codesigning/README-windows.md` din acel repo pentru pașii exacți pe
  care Cristi trebuie să-i ruleze o singură dată (generare cert + upload
  secret CI).

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

## v3.5.0 (2026-09-05) — Preview LUT: fullscreen + rezoluție mare

**Motiv**: cerere directă a lui Cristi — previzualizarea LUT era o
fereastră fixă mică (480×270), afișând mereu thumbnail-ul de 320px lățime
generat pentru coadă. La mărire nu ar fi avut cum să arate bine (aceeași
imagine mică, doar întinsă).

- Mac (`MediaPreviewSheet.swift`): buton nou de mărire/micșorare în
  header (iconițe `arrow.up.left.and.arrow.down.right`/inversă) — panoul
  de imagine se extinde la 90% din ecranul curent (`NSScreen.main`),
  păstrând 16:9. `MediaInspector.genereazaThumbnail(...)` capătă parametru
  nou `laLatime: Int = 320` (implicit neschimbat, 100% compatibil
  retroactiv) — fullscreen cere explicit 1920px, nu doar mărește CSS
  aceeași imagine mică.
- Windows (`media_preview.py`): fereastra devine liber redimensionabilă
  (`resizable(True, True)`, elimină restricția fixă anterioară) + buton
  de fullscreen real (`attributes('-fullscreen', ...)`, cu degradare
  fără crash pe platforme care nu-l suportă) + tasta Escape iese din
  fullscreen. `media_inspector.generate_thumbnail(...)` capătă parametru
  `width=320` (identic ca rol cu `laLatime` din Swift).

**Verificare reală, nu presupusă**: `ffprobe` pe cadre extrase manual la
`scale=320:-2` vs. `scale=1920:-2` din același clip sintetic — confirmat
320×180 vs. 1920×1080 (nu doar citit codul, măsurat efectiv). Test GUI
complet pe Windows (`app.mainloop()` real, `CGConvertorApp` +
`MediaPreviewDialog` din codul de producție, nu o simulare): deschis
dialogul, verificat thumbnail compact generat, apelat
`_toggle_fullscreen()`, verificat cu `ffprobe` pe fișierul PNG rezultat
că lățimea reală a devenit 1920 — confirmat. `xcodebuild -configuration
Debug` — 0 erori.

Versiune 3.4.0 → 3.5.0 (MINOR — funcționalitate nouă vizibilă, fără
schimbare de arhitectură, Regula 14).

## v3.7.0 (2026-09-05) — Offload: drag&drop discuri + tabel comparativ metadate + flux profesional complet (port masiv DataMover)

**Motiv**: Cristi, în aceeași conversație, cerând explicit să nu se
fragmenteze munca ("nu ma duce pe bucati... vreau sa fie integrata
complexitatea lucrurilor odata"): (1) drag&drop real pentru discurile
detectate în Offload (butonul "Sursă" era confuz, ținte mici/apropiate),
(2) tabel comparativ multi-fișier pentru metadate, (3) auditul complet
DataMover → CGConvertor pentru tot ce lipsea ca să fie "profesională,
folosită în industrie".

### A. Drag&drop pentru discurile din Offload
`OffloadView.swift`: chip-urile de disc au acum `.onDrag` (dragul unui
disc peste Sursă/Destinații le setează, la fel ca un folder tras din
Finder — ambele folosesc UTType `.fileURL`, aceeași convenție ca drop-ul
de fișiere din coada Convertorului). Butoanele "Sursă"/"Destinație" au
fost mărite și separate pe rânduri (nu mai lipite, sursa confuziei
raportate). Windows: fără echivalent nativ direct (drag-ul de discuri
Tkinter nu are un pattern la fel de simplu) — rămâne pe butoanele clare
existente, deja funcționale.

### B. Tabel comparativ metadate (`MetadataCompare.swift`, nou, Mac)
Motorul din sesiunea anterioară (Sony XML/rtmd, EXIF, ID3 — vezi secțiunea
mai sus) e acum UNIFICAT într-un singur set de categorii ordonate +
integrat într-un tabel comparativ multi-fișier real:
`MetadataCompareSheet.swift` — selectezi 2+ fișiere din coadă (checkmark
nou per rând, `RandJob`), buton "Compară (N)" deschide un tabel (rânduri =
parametru, coloane = fișiere), cu evidențiere diferențe, ascundere rânduri
identice, căutare, export CSV. Rulează la cerere (nu la fiecare adăugare
de fișier). **Doar Mac** — echivalentul Windows (Sony/EXIF/ID3 engine +
tabel Tkinter) rămâne TODO explicit, nemenționat ca gata.

### C. Flux profesional complet Offload (port DataMover, Etapa 2026-09-03)
Port masiv, AMBELE platforme, verificat cu date reale la fiecare piesă:

1. **MHL (Media Hash List) v1.1** — `MHLWriter.swift`/`mhl_writer.py`.
   Scris lângă datele copiate, căi relative, doar pentru fișiere
   OK/verificate. Doar md5/sha1/xxhash64 sunt în schema MHL — la SHA-256
   transferul rămâne complet, doar MHL-ul nu se scrie.
2. **Reîncercare automată** a fișierelor eșuate/nepotrivite — O SINGURĂ
   dată, la finalul transferului. Refactorizat `processOne`/`process_one`
   (Outcome enum, fără mutare directă de contoare) — verificat explicit că
   NU dublează numărătoarea la un fișier care eșuează definitiv.
3. **Verificare spațiu liber** înainte de primul octet copiat —
   `offloadHasEnoughSpace`/`has_enough_space` (marjă 1%, minim 100MB);
   sub prag, transferul NU pornește, cu opțiune explicită de a forța.
4. **Șablon de nume folder** — `NamingTemplate.swift`/`naming_template.py`,
   tokeni `{data} {ora} {proiect} {card} {camera} {operator}`, previzualizare
   live în UI. Implicit reproduce exact numele vechi.
5. **Recunoaștere structură card** — `CameraCardDetector.swift`/
   `camera_card_detector.py` (RED/ARRI/Sony XDCAM+XAVC/Panasonic
   AVCHD+P2/Blackmagic/Canon/DCIM generic), avertisment fișiere de 0
   octeți, și avertisment separat dacă sursa aleasă e un SUBFOLDER al unui
   card (pierdere de metadate).
6. **Producție/branding** — `ProductionMeta.swift`/`production_meta.py`
   (Proiect/Client/Card/Cameră/Operator/Note/Logo) → alimentează ȘI
   numele folderului, ȘI raportul HTML brandat (logo ca data URI, plafonat
   3MB) care înlocuiește/completează CSV-ul.
7. **Profile de transfer** — `TransferProfile.swift`/`transfer_profile.py`
   (căi + verificare + buffer/RAM + șablon + producție, numite, salvate în
   Application Support).
8. **Istoric persistat** — `HistoryStore.swift`/`history_store.py` +
   `HistoryView.swift`/`history_view.py` (dialog cu deschidere directă
   Finder/Explorer per sursă/destinație).

**Explicit NEPORTAT, deliberat, documentat (nu ascuns)**:
- **CloudSyncService (rclone)** — `CloudSyncService.swift` copiat în repo
  (Mac), dar NECONECTAT la OffloadEngine/OffloadView. Motiv: cere un cont
  rclone real pentru testare end-to-end, imposibil de verificat automat
  aici — rămâne pentru o cerere separată, cu un cont de test disponibil.
- **Ejectare automată + notificare sistem, coadă de carduri, pornire
  automată la introducere card** — flux DataMover complet (auto-start
  neasistat), nepotrivit ca implicit pentru CGConvertor (un convertor, nu
  un ofloader dedicat) fără o decizie explicită de scop.
- **Windows: tabelul comparativ de metadate** (partea B de mai sus) —
  motorul Sony/EXIF/ID3 din sesiunea anterioară + UI Tkinter rămân TODO.

**Verificare reală, nu presupusă** — Mac: test standalone (`swiftc`,
stub minim `MotorFFmpeg`) rulat pe fișiere sintetice reale — copiere
completă + MHL valid (`<hashlist version="1.1">`, element `<xxhash64be>`)
+ raport HTML conținând corect Proiect/Client; test separat de
recunoaștere card (structură Sony XAVC reală creată pe disc, fișier de 0
octeți detectat, subfolder recunoscut ca fiind în interiorul cardului);
test separat de verificare spațiu (1 PB respins, 1 KB acceptat, pe
discul real); test separat de reîncercare (fișier lipsă → 1 eroare
finală, NU 2, fără dublă numărare). Python — aceleași teste, rulate
identic (venv izolat, `xxhash`+`exifread`), plus un test GUI COMPLET cu
`app.mainloop()` real (`CGConvertorApp`+`OffloadPanel` din codul de
producție): previzualizare nume folder reflectă câmpurile de producție
introduse, profil salvat+reîncărcat prin UI, transfer real pornit prin
`_start()` produce MHL+HTML pe disc; `HistoryDialog` (tot cu
`app.mainloop()`) randează corect intrarea înregistrată. Fișierele de
test scrise din greșeală în Application Support real (istoric/profile)
au fost șterse după verificare, nu lăsate ca date false pentru Cristi.
`xcodebuild -configuration Debug` — 0 erori. `python3 -m py_compile` pe
toate fișierele noi — 0 erori.

Versiune 3.6.0 → 3.7.0 (MINOR — funcționalitate profesională nouă,
masivă, dar fără schimbare de arhitectură a aplicației de bază, Regula
14).

## v3.6.0 (2026-09-05) — Discuri detectate în Offload (port din DataMover)

**Motiv**: cerută explicit de Cristi, de două ori, ca să nu se piardă —
panoul Offload arăta sursa/destinațiile doar ca un câmp de path text
simplu, în loc de o listă reală de discuri/carduri montate, cu spațiu
liber, ca în DataMover.

- Mac: `CGConvertor/VolumeInfo.swift` (nou) — copiat verbatim din
  `~/Developer/DataMover/mac-native/Sources/DataMoverMac/VolumeInfo.swift`
  (`/Volumes`, iconiță nativă Finder per volum, spațiu liber via
  `FileManager.attributesOfFileSystem`). `OffloadView.swift` capătă o
  secțiune nouă "Discuri detectate" (chips orizontale, cu buton
  "Reîmprospătează" — montările se pot schimba cât timp panoul e
  deschis) — click pe "Sursă" setează `sourcePath`, "+" adaugă la
  `destinations`. Dialogurile `NSOpenPanel` existente rămân neschimbate,
  pentru orice folder care nu e rădăcina unui volum montat.
- Windows: `python/volume_info.py` (nou) — port al
  `list_mounted_volumes()` din `~/Developer/DataMover/core/offload_engine.py`
  (litere de drive, exclus `C:\` — de obicei discul de sistem), extins cu
  etichetă reală de volum (`GetVolumeInformationW`, fallback pe litera de
  drive dacă lipsește) și spațiu liber (`shutil.disk_usage`, zero
  dependință nouă). `offload_view.py` capătă aceeași secțiune de chips
  (Tkinter).

**Verificare reală, nu presupusă**: `python3 volume_info.list_volumes()`
rulat direct pe Mac-ul lui Cristi (ramura `Darwin` a codului, care e cea
comună cu portul viitor pe alte funcții) — a detectat corect toate cele
7 volume montate real (`BackUp`, `DavinciResolve`, `GDC`, `SonyFX5`,
etc.) cu spațiu liber corect formatat. Test GUI complet Windows
(`app.mainloop()` real, `OffloadPanel` din codul de producție): construit
panoul, verificat că au apărut 7 chips reale, simulat click pe butonul
"Sursă" al primului chip (`.invoke()`, nu doar apel direct de funcție) —
confirmat că `panel.source_path` ȘI `app.offload_source_path` au fost
setate corect la path-ul volumului. `xcodebuild -configuration Debug` —
0 erori. `python3 -m py_compile` — 0 erori.

Versiune 3.5.0 → 3.6.0 (MINOR — funcționalitate nouă vizibilă, fără
schimbare de arhitectură, Regula 14).

## v3.7.1 (2026-09-05) — Fix: buton de golire Sursă în Offload

Câmpul de Sursă din panoul Offload capătă un buton "✕" identic vizual cu
cel deja existent la Destinații — vizibil doar când `sourcePath`/
`self.source_path` nu e gol, resetează sursa (Mac: `sourcePath = nil`;
Windows: `_clear_source()` → `source_path = None` + `app.offload_source_path
= None` + refacere `source_label`/`card_info_var`). Regula 32 verificată
la această atingere: cele 4 apariții de "Co-Authored-By: Claude" rămase în
istoric sunt exclusiv text citat în acest CLAUDE.md (documentând regula
însăși), nu atribuiri reale de commit — nimic de curățat.

Versiune 3.7.0 → 3.7.1 (PATCH — fix izolat, Regula 14).

## v3.8.0 (2026-09-05) — Tabel comparativ de metadate pe Windows (paritate Mac v3.7.0)

Port 1:1 al `MetadataCompare.swift`/`MetadataCompareSheet.swift` (Mac):
`python/metadata_compare.py` (nou) — `categories_for(path)`, unifică
`media_inspector.probe()` + `sony_metadata.read()` + `image_metadata.
read_exif()`/`read_id3()` într-un singur set ordonat de categorii (Fișier/
General/Video/Audio/Imagine EXIF/Audio ID3/Setări captură rtmd/Profil
Cameră Sony XML) — identic ca ordine cu Mac. `sony_metadata.py`/
`image_metadata.py` existau deja din sesiunea anterioară de metadata
(neterminată atunci) — nu s-a scris cod nou pentru Sony/EXIF/ID3 în sine,
doar motorul de unificare + UI-ul, care lipseau efectiv.

`python/metadata_compare_view.py` (nou) — `MetadataCompareDialog`
(`tk.Toplevel`), spre deosebire de Mac (grid SwiftUI construit manual):
aici un `ttk.Treeview` cu coloane dinamice (o coloană per fișier selectat)
— tiparul nativ Tkinter pentru tabele, mai simplu decât un grid manual pe
acest toolkit, dar echivalent funcțional complet (evidențiere rânduri
diferite cu tag portocaliu, ascundere rânduri identice, căutare live,
export CSV). Analiza rulează pe un thread de fundal (`threading.Thread`),
UI-ul se construiește abia după ce se termină (`self.after(0, ...)`,
tiparul deja stabilit în restul aplicației).

`main.py._on_tree_right_click`: `ttk.Treeview` are deja `selectmode`
implicit "extended" (multi-select cu Ctrl/Shift+click) — bug de UX
evitat explicit: varianta veche apela necondiționat `selection_set
(item_id)`, care ar fi distrus orice selecție multiplă anterioară la
primul click-dreapta. Fix: `selection_set` se aplică DOAR dacă rândul
apăsat nu era deja parte din selecția curentă — restul meniului (deschide
fișier/preview/reordonare) rămâne condiționat la o selecție de UN singur
rând, noua intrare „Compară metadatele (N)” apare doar la 2+.

**Verificare reală, nu presupusă** (venv izolat, `pip install -r
requirements.txt`, fără să atingă Python-ul de sistem):
- `metadata_compare.categories_for()` rulat direct pe un clip sintetic
  real (`ffmpeg testsrc2`+`sine`, H.264/AAC) — categorii Fișier/General/
  Video/Audio extrase corect; pe un MP3 sintetic cu tag-uri ID3 reale
  (`-metadata title=...`) — categoria „Audio (tag ID3)” extrasă corect.
- **Test GUI complet, `app.mainloop()` real** (`CGConvertorApp` din codul
  de producție, nu o simulare): `_open_metadata_compare` apelat cu cele 2
  fișiere sintetice de mai sus — dialogul se deschide, tabelul are toate
  rândurile așteptate (20), export CSV verificat cu conținutul CSV citit
  înapoi de pe disc (rânduri diferite între video/audio prezente corect,
  câmpuri comune — ex. „Canale”, identice — prezente o singură dată).
- Filtrele testate separat, tot cu `mainloop()` real: „Ascunde identice”
  reduce corect numărul de rânduri (20→18, cele 2 rânduri identice —
  „Canale”/„Frecvență eșantionare” — dispar); căutarea „codec” lasă vizibile
  DOAR categoriile Video/Audio + rândul „Codec”, exclude „Titlu”.
- `pyflakes` (venv izolat) pe toate fișierele noi/modificate — zero erori.

Versiune 3.7.1 → 3.8.0 (MINOR — funcționalitate nouă vizibilă, paritate cu
Mac, fără schimbare de arhitectură, Regula 14).

## v3.9.0 (2026-09-05) — Player real-time LUT/LOG, doar Mac

Cerut explicit de Cristi, scopat chiar de el în aceeași propoziție:
"playerul real time dar pe Mac, pe Windows altă dată". Confirmat înainte
de start (AskUserQuestion): (1) player VIDEO COMPLET cu LUT live — nu doar
un scrubbing mai rapid al preview-ului static existent — și (2) fereastră
SEPARATĂ, nouă, pe lângă `MediaPreviewSheet` (care rămâne neschimbat,
neînlocuit).

**Arhitectură**: `AVMutableVideoComposition(asset:applyingCIFiltersWithHandler:)`
— API-ul standard AVFoundation pentru randare CoreImage per-cadru în timpul
redării reale — NU un pipeline Metal scris de la zero (ar fi însemnat
reimplementarea decodării video + sincronizării audio, cost nejustificat
față de o unealtă deja matură din SDK). `VideoPlayer` (AVKit/SwiftUI)
oferă transportul nativ complet (play/pause, scrub, volum, fullscreen)
gratuit — construit doar ce lipsea efectiv:

- **`CGConvertor/LUTPlayerEngine.swift`** (nou) — `CubeLUT.load(from:)`,
  primul parser `.cube` din acest repo (până acum LUT-ul era doar o cale
  de fișier pasată direct către `ffmpeg -vf lut3d=file=...`, niciodată
  parsat efectiv în Swift). Respinge explicit LUT-uri 1D
  (`LUT_1D_SIZE`) — doar 3D. `LUTPlayerCoordinator` (`ObservableObject`)
  — ține filtrul `CIColorCube` construit din datele LUT-ului, referit (nu
  copiat) din closure-ul AVFoundation, ca schimbarea LUT-ului în timpul
  redării să se reflecte pe cadrul următor fără reconstrucția compoziției.
- **`CGConvertor/LUTPlayerSheet.swift`** (nou) — sheet SwiftUI cu
  `VideoPlayer(player:)`, buton "Alege LUT…"/"Elimină" (reutilizează
  cheile `preview.chooseLut`/`preview.clearLut`/`preview.noLut` — semantică
  identică cu preview-ul static, fără duplicare de traduceri).
- **`ContentView.swift`** — buton nou "▶" (`play.circle`) pe fiecare rând
  de job cu metadata gata, lângă butonul "ochi" existent — deschide
  `LUTPlayerSheet` într-un `.sheet` SEPARAT, `MediaPreviewSheet` rămâne
  complet neatins.
- **`Localization.swift`** — chei noi `player.open`/`player.title`.

**Verificare reală, nu presupusă** (fără capturi de ecran, per regula de
economisire — verificare programatică):
- Test standalone (`swiftc`, compilat DIRECT din `LUTPlayerEngine.swift`
  real, nicio reimplementare pentru test): un `.cube` 2×2×2 de inversare
  scris pe disc, încărcat prin `CubeLUT.load` (confirmat: dimensiune=2,
  32 floats RGBA), filtrul `CIColorCube` construit din el aplicat pe o
  imagine roșie (255,0,0) pură — rezultatul citit pixel-cu-pixel prin
  `CGContext` confirmă cyan (0,255,255), exact inversarea așteptată.
  Dovedește că parsarea `.cube` ȘI transformarea de culoare prin
  CoreImage chiar funcționează, pe codul de producție.
- `xcodebuild -configuration Debug` — **BUILD SUCCEEDED**, 0 erori (după
  un fix real găsit la build: `import Combine` lipsă pentru
  `ObservableObject`/`@Published` în `LUTPlayerEngine.swift`).
- Aplicația compilată lansată REAL (`open CGConvertor.app`), confirmată
  rulând (`pgrep`), închisă curat (`quit app` via `osascript`) — fără
  crash la lansare cu noul cod încărcat.
- **NEVERIFICAT interactiv**: click-ul efectiv pe butonul "▶" + redarea
  video propriu-zisă cu LUT vizibil pe ecran — asta cere fie o captură de
  ecran (interzisă implicit de regula de economisire, doar la cerere
  explicită "SCREENSHOT"), fie un fișier video real cu conținut vizual
  variat de testat manual. Cristi confirmă manual, o dată, la prima
  utilizare reală.

**Explicit NEATINS, cerut chiar de Cristi**: portul Windows (Media
Foundation sau echivalent — Python/Tkinter nu are un pipeline de
compoziție video real-time comparabil, ar necesita o dependință nouă
majoră, ex. `python-vlc`/`mpv` cu shader custom) — TODO real, discuție de
scop separată la reluare, nu o omisiune ascunsă.

Versiune 3.8.0 → 3.9.0 (MINOR — funcționalitate nouă vizibilă, doar Mac,
fără schimbare de arhitectură a restului aplicației, Regula 14).

## v3.10.0 (2026-09-05) — Control cadre/s la transcodare (Mac + Windows)

Cerut explicit de Cristi ("control frame rate mac windows"), ambele
platforme în aceeași sesiune (Regula 31). Motorul de conversie
(`MotorFFmpeg.swift`/`converter.py`) nu expunea nicio opțiune de
schimbare a fps-ului la ieșire — conversia păstra mereu fps-ul sursei.

- **`OutputPreset`** (ambele platforme) capătă `frameRate`/`frame_rate:
  String? = nil` — `nil`/`None` (implicit) păstrează comportamentul
  vechi 100%. Retrocompatibil verificat REAL: un preset salvat pe disc
  ÎNAINTE de această schimbare (fără cheia `frame_rate` deloc) decodează
  corect la `nil`/`None`, fără eroare — Swift automat (Optional pe
  Codable sintetizat), Python explicit (`from_dict` filtrează doar
  câmpurile cunoscute, restul rămân pe valoarea implicită a
  dataclass-ului).
- **`FrameRateOption.allValues`/`FRAME_RATE_OPTIONS`** — listă fixă
  ("23.976", "24", "25", "29.97", "30", "50", "59.94", "60"), NU un câmp
  de text liber — evită o valoare invalidă pasată direct la `-r`.
- **`MotorFFmpeg.construiesteArgumente`/`converter.py.convert`**: `-r
  <fps>` adăugat DOAR în ramura de transcodare (Rewrap rămâne `-c copy`
  total, fără re-encode posibil — nu are sens acolo).
- **UI**: `PresetsManagerView.swift` (Picker nou, "Cadre/s la ieșire",
  vizibil doar când profilul nu e Rewrap, alături de Mod audio/Canale) +
  `presets_dialog.py` (Combobox nou, `presets_frame_rate`/
  `presets_frame_rate_source`, aceeași poziție în formular).

**Verificare reală, nu presupusă**:
- Mac: test standalone (`swiftc`, compilat DIRECT din
  `MotorFFmpeg.swift`/`PresetsManager.swift`/`FormatRegistry.swift`/
  `VideoJob.swift` reale) — confirmat `-r 30` apare în argumente cu
  `frameRate="30"`, și LIPSEȘTE complet cu `frameRate=nil` (0 regresie).
  Apoi rulare REALĂ `ffmpeg` cu argumentele exact generate de cod, pe un
  clip sintetic de 25fps (`ffmpeg testsrc2 -rate 25`) — `ffprobe` pe
  rezultat confirmă `30/1` (fps chiar schimbat, nu doar sintaxă acceptată).
- Windows: `presets_manager.OutputPreset.from_dict()` testat cu un dict
  vechi FĂRĂ cheia `frame_rate` → `None` corect; roundtrip
  `to_dict`/`from_dict` cu `frame_rate="30"` → păstrat corect. Apoi
  `converter.Converter.convert()` (codul REAL de producție, nu o
  reimplementare) rulat pe același clip sintetic de 25fps → `ffprobe` pe
  rezultat confirmă `30/1`.
- `xcodebuild -configuration Debug` — BUILD SUCCEEDED, 0 erori.
- `pyflakes` (venv izolat) — 0 erori noi (3 avertismente de importuri
  nefolosite preexistente în `converter.py`, neatinse de această
  schimbare, verificat cu `git diff`).

Versiune 3.9.0 → 3.10.0 (MINOR — funcționalitate nouă vizibilă, Mac +
Windows, fără schimbare de arhitectură, Regula 14).

## v3.11.0 (2026-09-05) — Etichetă spațiu de culoare la transcodare (Mac + Windows)

Item 3 din coadă, cerut din nou explicit de Cristi — scop confirmat
ÎNAINTE de implementare (AskUserQuestion, 2 runde): doar etichetare
corectă (metadata `color_primaries`/`color_trc`/`colorspace` în
container), NU transformare reală a pixelilor (LOG→Rec.709 sau
Rec.709→Rec.2020) — decizie explicită, nu simplificare ascunsă.

- **`OutputPreset.colorSpace`/`color_space`** (ambele platforme) — enum
  `ColorSpaceOption` (Swift)/string sentinel (Python): `.bt709`/`.bt2020`,
  `nil`/`None` implicit = nemodificat, 100% retrocompatibil (ca la
  `frameRate`, v3.10.0).
- **BUG REAL GĂSIT LA TESTARE, ÎNAINTE de a considera implementarea
  gata**: prima variantă folosea `-color_primaries`/`-color_trc`/
  `-colorspace` ca opțiuni BRUTE de ieșire FFmpeg — verificat cu
  `ffprobe` pe rezultat: DOAR `color_space` (matricea) se scria corect,
  `color_primaries`/`color_transfer` rămâneau `unknown`, reprodus IDENTIC
  pe `libx264` ȘI pe `h264_videotoolbox` (deci nu un bug specific unui
  encoder). Fix găsit prin experimentare directă cu `ffmpeg`: filtrul
  `-vf setparams=color_primaries=...:color_trc=...:colorspace=...` scrie
  toate cele 3 etichete corect — verificat din nou, toate 3 corecte.
- **`MotorFFmpeg.construiesteArgumente`/`converter.py`**: `-vf setparams=...`
  adăugat DOAR la transcodare (Rewrap rămâne `-c copy`).
- **UI**: `PresetsManagerView.swift`/`presets_dialog.py` — Picker/Combobox
  nou "Spațiu de culoare", lângă "Cadre/s la ieșire".

**Verificare reală, nu presupusă**:
- Mac: test standalone (`swiftc`, cod real `MotorFFmpeg.swift`/
  `PresetsManager.swift`) — confirmă `-vf setparams=...bt709` prezent cu
  `colorSpace=.bt709`, absent complet cu `nil`. Argumentele EXACTE rulate
  apoi cu `ffmpeg` real pe un clip sintetic — `ffprobe` confirmă
  `color_primaries=bt709`, `color_transfer=bt709`, `color_space=bt709`
  toate simultan corecte.
- Windows: `converter.Converter.convert()` (cod real de producție) rulat
  cu `color_space="bt709"` ȘI `"bt2020"` ȘI `None` pe același clip
  sintetic — toate 3 etichete corecte pentru bt709
  (`bt709`/`bt709`/`bt709`) și bt2020
  (`bt2020`/`bt2020-10`/`bt2020nc`), și ZERO regresie pe cazul
  "nemodificat" (`unknown`/`unknown`/`unknown`, identic cu înainte).
- `xcodebuild -configuration Debug` — BUILD SUCCEEDED, 0 erori.
- `pyflakes` (venv izolat) — 0 erori noi (aceleași 3 avertismente
  preexistente în `converter.py`, neatinse).

**Rămas explicit neatins, aceeași amânare de scop**: Watermark, Timeline
— Cristi nu le-a cerut în această sesiune, rămân TODO reale, de reluat
doar la cerere separată explicită pe fiecare.

Versiune 3.10.0 → 3.11.0 (MINOR — funcționalitate nouă vizibilă, Mac +
Windows, fără schimbare de arhitectură, Regula 14).

## v3.12.0 (2026-09-05) — Player real-time LUT/LOG, Windows

Portul Windows al playerului v3.9.0 (Mac) — cerut explicit ("player
Windows"). **Arhitectură fundamental DIFERITĂ**, nu un port 1:1 —
Windows/Tkinter nu are un echivalent gratuit al AVFoundation. Decizii de
scop confirmate ÎNAINTE de implementare (AskUserQuestion, 2 runde):

1. **`mpv.exe` descărcat LA CERERE** (Regula 4), nu bundle-uit în
   installer — rulat ca subproces, ÎNCORPORAT în fereastra Tkinter prin
   `--wid=<hwnd>` (`Frame.winfo_id()` întoarce direct handle-ul nativ pe
   Windows). Ales în locul VLC — mpv are filtrul `lut3d` (prin puntea
   `lavfi` către FFmpeg) direct utilizabil live la redare, VLC ar cere un
   modul de shader extern, mai fragil.
2. **Controale de redare — EXCLUSIV cele native mpv (OSC)**, nu un scrub
   bar Tkinter propriu — IPC bidirecțional cu mpv pe Windows (citire
   poziție în timp real) e documentat oficial ca fragil FĂRĂ `pywin32`/
   overlapped I/O (named pipe-urile Windows nu suportă simplu citire+
   scriere concurentă prin `open()` simplu Python, spre deosebire de
   Unix). Python trimite DOAR comenzi one-way (schimbare LUT), nu
   citește niciodată răspunsuri — evită complet acea fragilitate.

**Implementare**:
- **`dependency_manager.py`**: `find_mpv()` + `download_and_install_mpv()`
  (item nou, opțional, `is_optional=True` — nu blochează bulina globală).
  Sursă: `mpv-player/mpv` (GitHub, buildul STANDALONE oficial, NU
  libmpv — acela există doar ca `.7z` prin canale comunitare
  shinchiro/zhongfly, ar fi cerut o dependință nouă grea doar pentru
  dezarhivare 7z). Tag-ul "git-release" NU e marcat "Latest" pe GitHub
  (e pre-release) — URL-ul exact al asset-ului se citește DINAMIC din
  `assets[]` al API-ului de release-uri (regex pe nume, conține un hash
  de commit care se schimbă la fiecare build), niciodată hardcodat —
  identic ca principiu cu Self-Updater-ul aplicației înseși.
- **`lut_player.py`** (nou) — `LUTPlayerWindow`, lansează `mpv.exe` cu
  `--wid`/`--input-ipc-server`/`--osc=yes`, butoane Tkinter "Alege LUT…"/
  "Elimină" (reutilizează cheile `preview_choose_lut`/`preview_clear_lut`/
  `preview_no_lut`, ca la Mac). Filtrul trimis prin IPC:
  `lavfi=[lut3d=file='<cale escapată>']` — escaparea căii
  (`\`→`/`, `:`→`\:`) e IDENTICĂ cu cea deja testată pentru FFmpeg în
  `media_inspector.py` (aceeași sintaxă de graf libavfilter dedesubt).
- **`main.py`**: intrare nouă "Redă cu LUT (live)" în meniul contextual,
  lângă "Previzualizează" — fereastră SEPARATĂ, `MediaPreviewDialog`
  static rămâne complet neatins (aceeași decizie ca pe Mac).

**BUG REAL GĂSIT LA TESTARE, reparat înainte de commit**: prima variantă
a `download_and_install_mpv()` descărca arhiva `.zip` ȘI extrăgea
conținutul ei în ACELAȘI folder temporar — cum arhiva oficială mpv e
"plată" (mpv.exe direct la rădăcină, fără subfolder), bucla de copiere
finală ("tot ce e lângă mpv.exe") copia din greșeală și `mpv.zip` însuși
în instalarea finală, lângă binar. Verificat REAL (nu presupus): rulat
`download_and_install_mpv()` efectiv, pe API-ul GitHub real, într-un
folder de test — `mpv.zip` apărea vizibil în lista de fișiere instalate.
Fix: arhiva descărcată rămâne în folderul temporar PĂRINTE, extracția
merge într-un subfolder dedicat — retestat, confirmat curat.

**Verificare reală, nu presupusă** (limitele exacte ale ce se poate
verifica de pe Mac, spuse explicit, nu ascunse):
- **Verificat REAL, de pe Mac**: regex-ul de potrivire a asset-ului rulat
  LIVE pe răspunsul curent al API-ului GitHub — un singur asset se
  potrivește (`mpv-...-x86_64-pc-windows-msvc.zip`), confirmat printre
  10 asset-uri disponibile. Arhiva reală descărcată (28MB) — conține
  efectiv `mpv.exe` + `vulkan-1.dll` la rădăcină, exact cum presupunea
  codul. `download_and_install_mpv()` rulat END-TO-END, pe API-ul real,
  cu bug-ul de mai sus găsit ȘI reparat prin testare efectivă. Sintaxa
  filtrului (`lavfi=[lut3d=file=...]`) confirmată din documentația
  OFICIALĂ mpv (`vf.rst`) + FFmpeg (`vf_lut3d.c`), nu din presupunere —
  mpv NU are un filtru `lut3d` propriu, doar prin puntea `lavfi`.
  Test GUI complet, `app.mainloop()` real (`CGConvertorApp` din codul de
  producție): fișier adăugat prin codul real, `_open_lut_player` apelat
  exact cum face meniul, fereastra se deschide corect, `find_mpv()`
  întoarce `None` pe Mac (corect — feature Windows-only) și fallback-ul
  „mpv nu e instalat” apare corect, fără crash.
- **NEVERIFICAT, necesită Parallels-ul lui Cristi** (spus explicit, nu
  ascuns): embed-ul `--wid` chiar randează video în fereastra Tkinter
  (nu doar teoretic corect); comportamentul mpv sub un build PyInstorer
  înghețat; dacă filtrul `lavfi=[lut3d=...]` chiar aplică vizibil LUT-ul
  în timpul redării (nu doar sintactic acceptat de mpv); OSC-ul mpv
  răspunde la mouse peste fereastra încorporată. Cristi confirmă manual,
  o dată, la prima utilizare reală — la fel ca restul funcționalităților
  Windows din acest repo care au necesitat testare fizică.

Versiune 3.11.0 → 3.12.0 (MINOR — funcționalitate nouă vizibilă, paritate
cu Mac deși arhitectural diferită, Regula 14).

## v3.13.0 (2026-09-05) — Fix real: Watch Folders ignora fișierele deja existente

**Raportat direct de Cristi**: "nu-mi place că în Watch Folder înseamnă
că duplic încă o dată fișierele... mă obligă să le pun în acel folder
watch". Cauza reală, confirmată în cod: `WatchFolderManager.scanAll()`/
`_scan_all()` stabilesc un "baseline" la prima trecere pe un folder nou —
TOATE fișierele deja existente sunt marcate "cunoscute" FĂRĂ să fie
adăugate în coadă (decizie originală corectă: altfel orice folder ales
ar arunca tot conținutul lui în coadă). Efect secundar neintenționat: dacă
userul indică exact folderul unde clipurile lui deja există (cazul comun,
nu unul artificial), Watch Folders nu face NIMIC pentru ele — userul ar
trebui să le copieze/mute în altă parte doar ca să "pară noi", exact
duplicarea pe care o respinge.

**Fix, ambele platforme** — la adăugarea unui folder, dacă are deja
fișiere video, apare un dialog cu lista completă + „Selectează tot"/
„Deselectează tot" (cerute explicit de Cristi, în loc de un simplu Da/Nu)
— userul alege liber ce intră ACUM în coadă, restul rămâne ignorat (nu
se adaugă automat mai târziu, comportament neschimbat pentru cazul "nu
vreau nimic din ce e deja acolo").

- **`WatchFolders.swift`**: `listExistingFiles(forPath:)` (READ-ONLY, fără
  efecte secundare) + `markBaselineKnown(forPath:files:)` (marchează
  TOATE fișierele găsite ca știute, indiferent de selecție — separă
  "ce afișez" de "ce am adăugat efectiv").
- **`WatchFolderExistingFilesSheet.swift`** (nou) — listă cu checkbox-uri,
  butoane Selectează tot/Deselectează tot, implicit toate selectate
  (cazul comun: "da, adaugă tot").
- **`watch_folders.py`**: `list_existing_files(path)` +
  `mark_baseline_known(path, files)`, identic ca separare.
- **`watch_folder_existing_dialog.py`** (nou) — `tk.Toplevel` cu
  `Canvas`+`Scrollbar` (listă potențial lungă), aceleași două butoane.

**BUG REAL GĂSIT LA TESTARE GUI, reparat înainte de commit**: butonul
"Adaugă (N)" nu se dezactiva la 0 fișiere selectate — investigat, cauza
era în TESTUL meu (`cget("state")` pe un `ttk.Button` întoarce un obiect
special de tip index pe această versiune de Python/Tkinter, nu un `str`
simplu — comparația `== "disabled"` eșua mereu, indiferent de starea
reală). Cod de producție confirmat corect după fix-ul testului
(`str(cget("state")) == "disabled"`) — `_select_all`/`_select_none`
actualizează explicit eticheta/starea butonului, nu se bazează doar pe
`trace_add` (mai robust, mai puțin "magic").

**Verificare reală, nu presupusă**:
- Mac: test standalone (`swiftc`, cod real `WatchFolders.swift`) — 2
  fișiere existente listate corect, marcate ca știute, scanarea periodică
  REALĂ (timer 2s, `RunLoop.main.run`) NU le readaugă, dar detectează
  corect un al treilea fișier creat DUPĂ marcare, o singură dată.
- Windows: `list_existing_files`/`mark_baseline_known` (cod real, nu
  reimplementare) — identic verificat, plus test GUI complet
  (`app.mainloop()` real): dialogul deschis cu 3 fișiere, Deselectează
  tot → Selectează tot → deselectare individuală a unui fișier → Adaugă
  → `on_decide` primește exact cele 2 fișiere rămase selectate.
- `xcodebuild -configuration Debug` — BUILD SUCCEEDED, 0 erori.
- `pyflakes` (venv izolat) — 0 erori.

Versiune 3.12.0 → 3.13.0 (MINOR — fix de comportament cu impact vizibil,
nu doar un patch izolat, Mac + Windows, Regula 14).

## v3.13.1 (2026-09-05) — FIX CRITIC: playerul LUT (Mac) închidea toată aplicația

**Raportat direct de Cristi, urgent**: "urc fișierele și când apăs pe
play se închide direct... toată aplicația". Confirmat exact acest
scenariu — butonul "▶" (Redă cu LUT, v3.9.0) crapă instant, de fiecare
dată, la deschiderea sheet-ului.

**Diagnostic real, nu presupus**: 3 rapoarte de crash identice găsite
direct pe disc (`~/Library/Logs/DiagnosticReports/CGConvertor-*.ips`,
scrise chiar în timpul testului lui Cristi) — `SIGABRT`,
`swift::fatalError` în timpul rezolvării de metadata generică pentru
`NSViewRepresentable._makeView`, reprodus IDENTIC în toate 3. Stack
trace-ul arată clar că punctul de eșec e chiar în interiorul mecanismului
`AVKit.VideoPlayer` (SwiftUI) — NU în codul din `LUTPlayerSheet.swift`
însuși. Un test standalone al motorului AVFoundation/CoreImage (fără
SwiftUI, `swiftc` direct) rulase deja curat mai devreme (v3.9.0) — de
asta bug-ul a scăpat: motorul de randare e corect, doar wrapper-ul SwiftUI
peste el crapă, pe această versiune de macOS (26.6.2).

**Fix**: `AVPlayerAppKitView` (nou, `NSViewRepresentable` scris manual în
`LUTPlayerSheet.swift`) — încapsulează direct `AVPlayerView` (AppKit),
EXACT view-ul pe care `VideoPlayer` îl folosește intern, ocolind complet
stratul SwiftUI care crapă. `controlsStyle = .floating` păstrează
controalele native identice (play/pause/scrub/volum/fullscreen).

**Verificare reală, nu presupusă**: harness standalone (`swiftc`, cod
real din `LUTPlayerSheet.swift`/`LUTPlayerEngine.swift`) — `NSHostingView`
+ `NSWindow` reale, afișând EXACT `LUTPlayerSheet` cu un `VideoJob` real
și un clip sintetic real, rulat printr-un `NSApplication.run()` autentic
timp de 4 secunde. ÎNAINTE de fix (cu `VideoPlayer`): nu s-a mai retestat
separat (crash-ul era deja confirmat de 3 ori pe binarul instalat) — DUPĂ
fix (cu `AVPlayerAppKitView`): rulat curat, exit code 0, ZERO fișiere noi
în `DiagnosticReports/` după rulare (confirmat cu `ls -lat`, niciun crash
nou). `xcodebuild -configuration Debug` — BUILD SUCCEEDED.

**Lecție de proces, notă pentru viitor**: un test standalone al unui
MOTOR (AVFoundation/CoreImage, fără UI) nu acoperă bug-uri care trăiesc
STRICT în stratul de integrare SwiftUI/AppKit — un `NSHostingView`+
`NSWindow` real (ca harness-ul folosit aici pentru fix) e minimul necesar
pentru orice View SwiftUI nou care înglobează un component AVKit/AppKit
matur, nu doar compilare + rulare fără fereastră.

Versiune 3.13.0 → 3.13.1 (PATCH — fix critic izolat, Regula 14).

## v3.13.2 (2026-09-05) — 2 fix-uri reale: presetarea editată nu devenea activă + Start ignora selecția

**Raportat direct de Cristi, doi bug-uri consecutive**: "am dat modificare
fps și a exportat tot în fps-ul original" → "dacă nu duplic nu pot seta
fps-ul" → "și dacă selectez doar una el transcodează tot, nu doar
selecția".

**Bug 1 — presetarea editată nu devenea activă.** Diagnostic REAL, nu
presupus: `presets.json`-ul de pe disc AL LUI CRISTI conținea deja un
preset custom (`custom_3BF78D3A`, "ProRes 422 HQ (copie)") cu
`frame_rate: "25"` salvat CORECT — persistența funcționa perfect. Un test
standalone separat, cu argumentele exacte generate din acel preset real,
rulat prin `ffmpeg` real, a produs corect 25fps dintr-o sursă de 24fps —
motorul de conversie funcționa perfect și el. Bug-ul real era în altă
parte: `reincarcaPresets()`/`_on_presets_changed()` reîncarcă lista de
presetări după ce Presets Manager se închide, dar NICIODATĂ nu actualiza
`presetSelectatID`/`selected_preset_id` — presetarea ACTIVĂ (cea folosită
efectiv la Start) rămânea cea VECHE, needitată, chiar dacă userul tocmai
editase o copie a ei. Fix (ambele platforme): `PresetsManagerSheet`/
`PresetsDialog` transmit acum și ID-ul presetării pe care userul o vedea
deschisă la închidere — aceea devine automat activă.

**Bug 2 — Start ignora selecția.** `pornesteCoada()`/`_run_queue()`
procesau necondiționat TOATĂ coada (`Array(joburi.indices)`/`self.jobs`),
fără niciun concept de "doar cele selectate" — checkbox-urile de pe
fiecare rând (adăugate pentru comparația de metadate, v3.7.0) nu aveau
nicio legătură cu Start. Fix: reutilizate ca scop dublu — Mac (checkbox
existent `esteSelectat`) / Windows (selecția nativă `Treeview`,
Ctrl/Shift+click) — dacă 1+ fișiere sunt selectate la apăsarea Start, se
procesează DOAR acelea; fără nicio selecție, comportamentul rămâne
neschimbat (toată coada). Eticheta butonului Start arată explicit „(N
selectate)” când se aplică.

**Verificare reală, nu presupusă** (ambele bug-uri, ambele platforme):
- Mac: harness standalone (`swiftc`, `ConvertorViewModel` REAL instanțiat,
  nu o reimplementare) — 3 fișiere reale în coadă, `doarSelectate` cu un
  singur ID → confirmat DOAR acel fișier procesat (fișier rezultat pe
  disc), celelalte 2 neatinse; apoi retestat cu set gol → toate 3
  procesate (zero regresie pe comportamentul vechi).
- Windows: test GUI complet, `app.mainloop()` real, cod de producție —
  selecție Treeview pe un singur job → confirmat DOAR acela apare în
  folderul de ieșire, eticheta butonului arată corect „(1 selectate)”;
  test separat pentru bug 1 — `_on_presets_changed(presets, id)` chemat
  exact ca la închiderea dialogului → `selected_preset_id` ȘI combobox-ul
  vizibil confirmate actualizate la presetarea corectă.
- `xcodebuild -configuration Debug` — BUILD SUCCEEDED. `pyflakes` (venv
  izolat) — 0 erori. Instalat real în `/Applications`, versiune
  INSTALATĂ verificată cu `PlistBuddy` (Regula 0).

Versiune 3.13.1 → 3.13.2 (PATCH — 2 fix-uri reale izolate, Mac + Windows,
Regula 14).

## v3.14.0 (2026-09-05) — Selectează tot / Deselectează tot

Cerut explicit de Cristi ("nici nu apare opțiunea de a selecta tot sau
deselecta tot"), imediat după ce a descoperit fluxul de comparație
metadate/conversie-parțială pe selecție (v3.7.0/v3.13.2) — bifarea
individuală per fișier era greoaie la o coadă lungă. Butoane noi lângă
„Golește lista"/„Generează raport" (Mac: `selectedJobIDs = Set(...)`/
`.removeAll()`; Windows: `tree.selection_set(get_children())`/
`selection_remove(selection())`, reutilizând selecția nativă Treeview).

**Verificat**: Windows — test GUI complet, `app.mainloop()` real, cod de
producție — 3 fișiere, "Selectează tot" → 3 selectate + eticheta Start
arată corect "(3 selectate)"; "Deselectează tot" → 0 selectate, eticheta
revine la normal. `xcodebuild -configuration Debug` — BUILD SUCCEEDED,
instalat real (`/Applications`, versiune confirmată `PlistBuddy`).
`pyflakes` — 0 erori.

Versiune 3.13.2 → 3.14.0 (MINOR — funcționalitate nouă vizibilă, Mac +
Windows, Regula 14).

## v3.14.1 (2026-09-06) — Fix: ferestre Mac needimensionabile

**Raportat direct de Cristi**, după ce a folosit efectiv comparația de
metadate: "nu înțeleg de ce sunt limitate dimensiunea ferestrelor... sau
să-l modific eu". Cauza reală: `MetadataCompareSheet`/`LUTPlayerSheet`/
`PresetsManagerSheet`/`HistoryView` foloseau toate `.frame(width:height:)`
cu valori FIXE la rădăcina view-ului — SwiftUI nu lasă userul să
redimensioneze un sheet al cărui conținut cere explicit o dimensiune
exactă, indiferent de fereastra din spate. Regula 18 (Standard UX) cerea
asta doar pentru fereastra PRINCIPALĂ — gap real, nemenționat explicit
până acum, pentru sheet-uri.

**Fix**: toate patru trecute pe `.frame(minWidth:idealWidth:minHeight:
idealHeight:)` (fără maxim) — playerul LUT capătă și `.aspectRatio(16/9)`
pe zona video, ca proporția să rămână corectă la orice dimensiune aleasă.
Windows verificat separat: dialogurile echivalente (`metadata_compare_view.py`,
`lut_player.py`, `presets_dialog.py`) NU dezactivează explicit resize —
`tk.Toplevel` e implicit redimensionabil, deci nu exista niciun gap acolo.

Versiune 3.14.0 → 3.14.1 (PATCH — fix UX izolat, doar Mac, Regula 14).

## v3.14.2 (2026-09-06) — Comparația de metadate: rescrisă complet ca pagină HTML

**Feedback direct de la Cristi, după ce a testat efectiv fix-ul v3.14.1**
(redimensionare sheet nativ): "Nu e bine... e o mini fereastră care e
greu de vizualizat... Trebuie să fie, nu știu, poate ca un HTML sau ca
un PDF, să fie mare, să pot umbla în el... nu ca un pop-up mic". Apoi,
confirmând direcția: "ceva în genul generează raport să fie și
metadatele". Concluzie: nu era problemă de dimensiune (v3.14.1 rezolvase
tehnic asta), ci de PARADIGMĂ — un pop-up nativ, oricât de mare, tot se
simte ca o mini-fereastră lângă un tab de browser.

**Fix Mac**: `MetadataCompareSheet.swift` REFĂCUT COMPLET — nu mai e
`View`/`.sheet`, ci `extension MetadataCompareEngine { static func
deschideComparatie(jobs:) }`. Motorul de extragere (`categorii(pentru:)`,
`MetadataCategory`) rămâne neatins în `MetadataCompare.swift` — funcția
nouă doar generează un HTML autonom (căutare live, evidențiază diferențe,
ascunde identice — JS simplu inline, temă GDC Shift dark) și îl deschide
cu `NSWorkspace.shared.open(path)`, exact tiparul deja aprobat de
"Generează raport". `ContentView.swift`: eliminat `@State showCompare` +
`.sheet(...)`, butonul „Compară (N)" apelează direct funcția nouă.

**Fix Windows (Regula 31, aceeași sesiune)**: `metadata_compare_view.py`
rescris — fostul `MetadataCompareDialog(Toplevel)` cu `ttk.Treeview`
980×640 eliminat complet, înlocuit cu `open_comparison(jobs) -> path`
care generează BYTE-cât-de-aproape-posibil același HTML (aceleași
categorii/culori/JS, doar fontul de fallback e `Segoe UI`/`Consolas` în
loc de `-apple-system`/`Menlo`). `main.py._open_metadata_compare` rulează
analiza pe thread separat (ffprobe/Sony XML poate dura pe fișiere multe)
și deschide rezultatul cu `os.startfile`, la fel ca `_generate_report`.

**Verificare**: build Xcode (`BUILD SUCCEEDED`) + harness standalone Mac
(`/tmp/compare_html_test/`, 2 clipuri ffmpeg reale, cod de producție
neschimbat) — HTML conține titlu, ambele nume de fișier, metadata video
reală (`H264`), JS-ul de filtrare, clasificare identic/diferit corectă.
Python: `python3 -m py_compile main.py metadata_compare_view.py` OK +
test real (`/tmp/win_compare_test/`, 2 clipuri ffmpeg reale) — aceleași
asserții, toate trecute.

Versiune 3.14.1 → 3.14.2 (MINOR ar fi fost dacă era funcționalitate nouă;
e o rescriere de UX pe o funcție existentă → PATCH, Regula 14).

## ⏳ Cerințe noi de la Cristi (2026-09-05), neîncepute — de adăugat la coadă

(Preview LUT fullscreen/zoom — FĂCUT, vezi v3.5.0. Discuri detectate în
Offload — FĂCUT, vezi v3.6.0. Drag&drop discuri + tabel comparativ
metadate (Mac) + flux profesional Offload complet (MHL, reîncercare,
spațiu liber, șablon nume, card, producție/branding, profile, istoric) —
FĂCUT, vezi v3.7.0, toate mai sus.)

-1. **[REZOLVAT v3.7.1, 2026-09-05]** Bug UX buton de golire Sursă în
   Offload — vezi jurnalul v3.7.1 de mai jos. Mac + Windows.
0. **[REZOLVAT v3.8.0, 2026-09-05]** Tabel comparativ metadate pe Windows —
   vezi jurnalul v3.8.0 de mai jos.
1. **[REZOLVAT v3.9.0 (Mac) + v3.12.0 (Windows), 2026-09-05]** Playerul
   real-time LUT/LOG — ambele platforme, vezi jurnalele respective mai jos.
2. **[REZOLVAT v3.10.0, 2026-09-05]** Control de cadre/s la transcodare —
   vezi jurnalul v3.10.0 de mai jos, Mac + Windows.
3. **[Parțial REZOLVAT v3.11.0, 2026-09-05]** Spații de culoare — Cristi
   a revenit explicit ("continuăm... item 3") și a scopat-o precis (doar
   etichetare metadata, nu transformare reală a pixelilor) — vezi jurnalul
   v3.11.0 mai jos. Watermark și Timeline RĂMÂN neatinse, aceeași
   amânare de scop ca înainte — de reluat DOAR la cerere separată,
   explicită pe fiecare.
Prioritate sugerată la reluare: metadata Sony/EXIF/ID3 (secțiunea
anterioară, UI de tabel comparativ neînceput) sau 2 (control fps, mediu,
atinge motorul de conversie) — oricare, la alegerea lui Cristi; 1
(playerul real-time) rămâne discuție de scop separată.

## v3.14.4 (2026-09-06) — Meniu Ajutor + PDF regenerat complet (Mac + Windows)

Audit ecosistem (cerut de Cristi): CGConvertor nu avea NICIUN meniu
Ajutor/Help — nici pe Mac, nici pe Windows — spre deosebire de restul
aplicațiilor GDC (CursorPro, GDCVault, MacMasterControlPro, toate au
deja acest tipar). Plus, `installer/Instructiuni_Utilizare.pdf` era din
26 august, cu mult în urma codului (~10 versiuni de funcții noi de atunci).

**PDF regenerat** (`installer/generate_pdf.py`, RO/EN/ES) — 4 secțiuni
noi (5-10), verificate direct în `ContentView.swift` înainte de scris
(nu presupuse): Selecție și conversie parțială (Select All/None, Start
Selected), Presetări de ieșire, Watch Folders, Previzualizare LUT/LOG,
Comparație de metadate (thumbnail-uri, căutare, evidențiere diferențe),
Generează raport. Secțiunile vechi (Moduri de conversie, Licență,
Dezinstalare, Suport) renumerotate 11-14. 13 pagini rezultate (verificat
cu `pypdf`, nu presupus).

**Mac**: `HelpGuide.swift` (nou) — `Bundle.main.url(forResource:
"Instructiuni_Utilizare", withExtension: "pdf")` + `NSWorkspace.shared.
open`. PDF adăugat ca resursă Xcode (editat manual `project.pbxproj` —
proiectul folosește `PBXFileSystemSynchronizedRootGroup` pentru folderul
`CGConvertor/`, dar `installer/` e în afara lui, deci fișierul trebuie
înregistrat explicit ca `PBXFileReference`+`PBXBuildFile`, la fel ca
`ffmpeg`/`ffprobe`). `CommandGroup(replacing: .help)` nou în
`CGConvertorApp.swift`. **Bug real la prima încercare**: path relativ
`../installer/...` rezolva greșit la `~/Developer/installer` (un nivel
prea sus) — proiectul root ESTE deja `~/Developer/CGConvertor`, fix la
`installer/Instructiuni_Utilizare.pdf` (fără `../`).

**Windows**: `main.py._build_menu_bar()`/`_open_help_guide()` (noi) —
prima dată când aplicația are un meniu de sus (avea doar meniuri
contextuale click-dreapta). `build-windows.spec` — PDF adăugat în
`datas`. Chei noi `menu_help`/`menu_help_guide` (RO/EN/ES) în
`translations.py`. `_refresh_texts()` re-etichetează meniul la schimbarea
limbii.

**Verificat REAL**: build Xcode → `BUILD SUCCEEDED`, PDF confirmat fizic
în `Contents/Resources/`. Harness Python real (venv izolat, dependențe
instalate din `requirements.txt`): `CGConvertorApp()` pornit efectiv,
meniul „Ajutor” confirmat cu eticheta corectă, `_open_help_guide()`
apelat — Preview.app confirmat deschis (`osascript`... `exists
(processes where name is "Preview")` → true) — fluxul complet,
cap-coadă, nu doar cod care compilează.

Versiune 3.14.3 → 3.14.4 (PATCH — completare UX, fără arhitectură nouă).

## v3.14.5 (2026-09-06) — „Descarcă PDF” pe rapoarte + thumbnail-uri offload + fix scrubber fullscreen

Cerere directă a lui Cristi: (1) metadatele din Compare (și "toate în
general") să poată fi descărcate ca PDF; (2) raportul HTML de offload să
aibă thumbnail-uri, la fel ca celelalte rapoarte.

**PDF**: NU s-a scris un generator PDF nou (ar fi însemnat o dependință
nouă pe Windows, vezi decizia deja documentată la v3.2.0/Faza 2 —
`reportlab` există doar ca unealtă de build a ghidului, nebundle-uit
runtime). Soluție zero-dependință: buton „Descarcă PDF" →
`window.print()` (imprimarea nativă a browserului/`NSWorkspace`-ului
implicit — orice browser oferă "Salvează ca PDF" în dialogul de print) +
CSS `@media print` care comută raportul pe fundal alb/text închis pentru
lizibilitate pe hârtie, indiferent de setarea "background graphics" a
userului. Adăugat identic în toate cele 3 rapoarte HTML, ambele platforme:
`ConvertorViewModel.swift`/`main.py` (raport conversie), `MetadataCompareSheet.swift`/
`metadata_compare_view.py` (comparație), `ProductionMeta.swift`/
`production_meta.py` (offload).

**Thumbnail-uri offload**: `OffloadReportRow` (`OffloadEngine.swift`)
capătă `destPath` (Windows: cheie `dest_path` în dict-ul de rând) — calea
reală la destinație, needisponibilă până acum. Mac: `thumbnailDataURI(path:)`
(port identic din `DataMover`/`ProductionMeta.swift`, QLThumbnailGenerator,
zero dependință nouă). **Windows: diferență reală de platformă** — fără
QuickLook, thumbnail-ul folosește motorul `ffmpeg` deja bundle-uit
(`media_inspector.generate_thumbnail`, deja folosit de coadă/preview) —
funcționează doar pe fișiere VIDEO (nu imagini/PDF ca pe Mac), fail-open
pe orice altceva (fișier lipsă/format nesuportat → fără thumbnail, nu
eroare). Documentat explicit în cod, nu o omisiune ascunsă.

**Fix real, raportat separat de Cristi în aceeași conversație**: la
fullscreen în preview-ul static cu LUT (`MediaPreviewSheet.swift`),
`fullscreenSize` calcula panoul video DOAR din lățimea ecranului (90%,
16:9) — pe multe rezoluții, `lățime × 9/16` + restul UI-ului (titlu,
slider, rândul LUT, padding) depășea ÎNĂLȚIMEA reală a ecranului,
împingând slider-ul/rândul LUT sub margine, inaccesibile. Fix: calculul
se încadrează acum în AMBELE dimensiuni ale `visibleFrame` (exclude
menu bar/Dock), rezervând explicit ~190pt vertical pentru restul
ferestrei. **Windows verificat, NU are aceeași problemă** — arhitectură
diferită (`-fullscreen` nativ + `pack()` Tkinter, care alocă spațiul
widget-urilor cu dimensiune fixă — scale/rândul LUT — INDIFERENT de
ordinea de packing, spre deosebire de un calcul explicit de dimensiune
ca în SwiftUI); niciun fix necesar acolo.

**Verificat**: `xcodebuild -configuration Debug` — BUILD SUCCEEDED (de 2
ori, după fiecare grup de modificări). Instalat real în `/Applications`,
versiune INSTALATĂ confirmată `PlistBuddy` → `3.14.5`. `python3 -m
py_compile` pe TOATE fișierele din `python/` — 0 erori.

Versiune 3.14.4 → 3.14.5 (PATCH — completări/fix-uri pe funcții
existente, fără arhitectură nouă, Regula 14).

## v3.14.6 (2026-09-06) — FIX CRITIC: crash la lansare pe Windows (meniul Ajutor)

**Raportat de Cristi cu screenshot exact**: `_tkinter.TclError: unknown
option "-label"` la lansare, in `_refresh_texts` -> `entryconfig`.

**Cauza radacina reala**: `_build_menu_bar()` (adaugat in v3.14.4, meniul
Ajutor) crea `menubar = tk.Menu(self)` FARA `tearoff=0`. Implicit,
Tkinter insereaza o intrare invizibila de "tear-off" la INDEXUL 0 (linia
punctata din capul meniului, pe Windows/X11) — orice widget adaugat dupa
aceea (`add_cascade`) ajunge la indexul 1, nu 0. `_refresh_texts` apela
insa `self._menubar.entryconfig(0, label=...)`, tintind din greseala
intrarea de tear-off, care NU suporta optiunea `label`.

**De ce a scapat la testare pe Mac**: Aqua (meniul nativ macOS) IGNORA
tearoff-ul pe meniul de sus — indexul 0 chiar corespunde primei cascade
reale acolo, deci bug-ul nu s-a manifestat niciodata in testele facute
pe Mac. Confirmat direct: un test minimal cu exact aceeasi structura,
rulat pe acest Mac, NU reproduce eroarea — dovedeste diferenta reala de
comportament Aqua vs Windows/X11, nu doar o presupunere.

**Fix**: `menubar = tk.Menu(self, tearoff=0)` — o linie. Verificat cu un
script minimal separat: ACELASI apel `entryconfig(0, label=...)` esueaza
fara `tearoff=0` pe structura corecta de test, functioneaza corect cu el
(Regula practica noua: orice `tk.Menu()` folosit ca menubar de top NEBUIE
sa aiba `tearoff=0` explicit daca urmeaza sa i se faca `entryconfig` pe
index, nu doar meniurile-copil).

**Nu s-a putut verifica REAL lansarea pe Windows** (Claude nu poate rula
GUI Windows de pe Mac) — CI-ul de build a confirmat doar ca scriptul
compileaza si se ambaleaza corect; Cristi confirma manual, o data,
lansarea curata pe Windows real.

Versiune 3.14.5 -> 3.14.6 (PATCH — fix critic izolat, Regula 14).

## v3.14.7 (2026-09-06) — mpv bundle-uit in instalator (Windows)

**Raportat de Cristi, tot cu screenshot**: panoul "Verificare &
Dependinte Sistem" arata `[Errno 13] Permission denied:
'...AppData\Roaming\CGConvertor\bin\mpv\mpv.exe'` la descarcarea
automata a playerului mpv (folosit pentru preview live cu LUT).

**Onest**: nu am putut reproduce/localiza in cod calea EXACTA din eroare
(`bin\mpv.exe`, fara sub-folderul `mpv\`) — grep in tot
`dependency_manager.py` gaseste doar calea imbricata `bin\mpv\mpv.exe`.
Discrepanta ramane neexplicata 100%. In loc sa vanez o teorie
neconfirmata, am aplicat solutia recomandata explicit de Cristi:
eliminarea intregii clase de bug, nu doar a simptomului raportat.

**Fix principal — bundling la build, nu descarcare la runtime**:
`build-windows.spec` primeste `mpv/mpv.exe` in `binaries` (acelasi tipar
ca `ffmpeg.exe`/`ffprobe.exe`, deja existent). CI
(`.github/workflows/build-windows.yml`) descarca mpv de la sursa oficiala
(`mpv-player/mpv`, tag-ul rulant "git-release", acelasi API si tipar de
asset ca in Python — `MPV_ASSET_PATTERN`) INAINTE de pasul PyInstaller.
`dependency_manager.find_mpv()` verifica ACUM INTAI calea bundle-uita
(`sys._MEIPASS/mpv/mpv.exe`, doar cand `sys.frozen`) — marea majoritate a
userilor nu mai ajung niciodata la codul de descarcare/scriere care
producea eroarea.

**Fix-uri secundare (defense-in-depth, pentru cazul rar cand descarcarea
la runtime tot se declanseaza — instalari portabile/development)**:
1. Calea de descarcare mutata din `%APPDATA%\Roaming` in `%LOCALAPPDATA%`
   (`_mpv_download_dir()`) — Roaming poate fi sincronizat de OneDrive/
   politici de domeniu, cauza tipica de PermissionError tranzitoriu pe
   fisiere proaspat scrise; LOCALAPPDATA nu are aceasta problema.
2. `_copy_with_retry()` — pana la 5 incercari cu backoff (0.6s) la copiere,
   pentru blocaje tranzitorii de antivirus pe executabile noi descarcate.

**Fix proactiv separat, gasit in acelasi fisier editat**: eliminat
`generate_release_notes: true` din pasul `softprops/action-gh-release@v2`
(`build-windows.yml`) — ar fi publicat automat, pe release PUBLIC, un
rezumat generat de GitHub din mesajele de commit (Regula 29 — commit-urile
de aici sunt jurnal tehnic intern, cu nume/cauze de debugging).

**Nu s-a putut verifica REAL playback-ul cu mpv pe Windows** — la fel ca
la v3.14.6, CI confirma doar ca build-ul si bundling-ul reusesc; Cristi
confirma manual pe Windows real ca player-ul si controalele functioneaza.

**Verificat**: `xcodebuild -configuration Debug` — BUILD SUCCEEDED dupa
bump-ul de versiune. `python3 -m py_compile dependency_manager.py` — 0
erori (verificat inainte de bump-ul final de versiune).

Versiune 3.14.6 -> 3.14.7 (PATCH — fix izolat + hardening, fara
arhitectura noua, Regula 14).

## v3.14.8 (2026-09-06) — FIX ecran negru Player LUT (Windows) + paritate buton Comparatie Metadate

**Raportat de Cristi, testat pe Windows real dupa v3.14.7**: doua
probleme separate.

**1. Ecran negru + fara controale la Player LUT (`lut_player.py`)**.
Cauza radacina reala, confirmata din citirea codului: `_launch_mpv()`
pornea `mpv.exe` FARA niciun flag `--vo` explicit — mpv face auto-probe
intre driverele de output video disponibile, iar in contextul de embed
printr-un HWND strain (`--wid=<hwnd>`, necesar ca sa deseneze DIN INTERIORUL
ferestrei Tkinter), auto-probe-ul alege des un driver care nu poate
desena acolo. Rezultat: fereastra se deschide, audio-ul ruleaza (procesul
mpv functioneaza), dar suprafata video ramane neagra — si OSC-ul
(controalele native mpv) nu apar fiindca se randeaza PESTE suprafata
video, care nu exista.

Cristi a venit cu diagnosticul tehnic corect (flag-urile `--vo=direct3d11`
etc.) — aplicat, cu o mica imbunatatire: `--vo` accepta o LISTA
prioritara separata prin virgula (documentat oficial in man mpv, nu
presupus), nu doar un singur driver, deci fix-ul foloseste
`--vo=gpu-next,gpu,direct3d11,gdi` (mpv incearca in ordine pana porneste
unul) + `--gpu-context=d3d11` + `--hwdec=auto-safe`, activate DOAR pe
`sys.platform.startswith("win")` (Mac nu foloseste deloc mpv — vezi
`LUTPlayerSheet.swift`, AVFoundation).

**2. Buton „Compara metadatele (N)" lipsa pe Windows**. Cristi a
presupus o conditionare `sys.platform == 'darwin'` gresita — verificat
direct in cod, NU exista asa ceva; cauza reala e ca feature-ul pur si
simplu nu fusese portat complet: pe Mac (`ContentView.swift`) e un buton
PERMANENT in bara de jos, langa "Genereaza raport", vizibil cand
`selectedJobIDs.count >= 2`; pe Windows exista doar ca intrare in meniul
click-dreapta (`_on_tree_right_click`), mult mai putin descoperibila -
identic din punct de vedere functional, dar nu din punct de vedere UI.
Fix: adaugat `self.compare_btn` in aceeasi bara de jos ca
`select_all_btn`/`select_none_btn`, aratat/ascuns din
`_on_tree_selection_changed` (acelasi hook care actualizeaza deja
eticheta butonului Start dupa selectie), text cu numarul de fisiere
selectate (`compare_button` din `translations.py`, deja exista, cheie
nefolosita pana acum in bara de jos). Intrarea din meniul click-dreapta
ramane neschimbata (cale alternativa, nu conflict).

**Nu s-a putut verifica REAL pe Windows** (ca la v3.14.6/v3.14.7) —
`python3 -m py_compile` confirma doar sintaxa; Cristi confirma manual pe
masina reala ca playback-ul video + OSC-ul functioneaza si ca butonul
apare corect.

Versiune 3.14.7 -> 3.14.8 (PATCH — fix-uri izolate, fara arhitectura
noua, Regula 14).

## v3.14.9 (2026-09-06) — FIX "Security validation failure" la auto-update (Windows)

**Raportat de Cristi cu screenshot exact**: dupa "Cauta actualizare" ->
gaseste v3.14.8 -> incepe descarcarea -> la lansarea installer-ului
apare un popup nativ Windows: "Security validation failure: parent
process has different executable!".

**Investigatie**: cautat explicit online (JRSoftware changelog-uri 6.3/
6.4/6.5, forumul Inno Setup) - NU exista documentatie oficiala publica
pentru acest mesaj exact; nu s-a putut confirma 100% mecanismul intern.
Onest, neconfirmat direct, dar cel mai plausibil scenariu, coroborat cu
codul nostru: `self_updater.download_and_install()` lansa Setup.exe cu
`subprocess.Popen([exe_path], creationflags=DETACHED_PROCESS,
close_fds=True)` — un `CreateProcess` "brut". `installer.iss` cere
`PrivilegesRequired=admin`, deci Setup.exe se auto-relanseaza intern,
elevat, prin UAC (`ShellExecute` cu verb "runas" - mecanism intern Inno,
nu al nostru). Un `CreateProcess` direct, detasat de consola, difera de
calea NORMALA prin care orice user lanseaza un installer descarcat
(dublu-click in Explorer = `ShellExecuteExW`) - exact calea pe care o
"asteapta" o verificare anti-hijacking mai noua din Inno Setup (adaugata
ca protectie impotriva DLL-preloading/proces-injection, documentata doar
generic in changelog: "Changes to further help protect against
potential DLL preloading attacks", 6.3.0).

**Fix**: `os.startfile(exe_path)` in loc de `subprocess.Popen(...)` -
foloseste `ShellExecuteExW`, IDENTIC mecanismului unui dublu-click din
Explorer (calea pe care niciun user care descarca manual installer-ul nu
a raportat vreodata aceasta eroare). Eliminat importul `subprocess`
(nefolosit altundeva in fisier) si `sys` (folosit doar pentru flag-ul
`DETACHED_PROCESS`, acum inutil).

**Nu s-a putut verifica REAL fluxul de auto-update pe Windows** (Claude
nu poate declansa un update real de pe Mac catre propriul sau release) -
Cristi confirma manual ca "Cauta actualizare" -> descarcare -> lansare
functioneaza fara eroare, pe un build anterior instalat.

**Al doilea fix, in aceeasi versiune** — raportat de Cristi in aceeasi
sesiune, pe acelasi build v3.14.8 confirmat inca defect: ecranul negru +
dreptunghi gri la Player LUT persista si dupa fix-ul `--vo` din v3.14.8
(`gpu-next,gpu,direct3d11,gdi`). Cristi a semnalat cauza reala: testeaza
Windows RULAT IN PARALLELS (deja mentionat in avertismentul din
docstring-ul `lut_player.py`, scris INAINTE sa apara bug-ul) - placa
grafica e VIRTUALIZATA. Explicatie: lista de prioritate `--vo` nu ajuta
aici fiindca mpv trece la urmatoarea optiune DOAR daca initializarea
esueaza explicit - pe placa virtuala Parallels, `gpu-next`/`gpu` se
INITIALIZEAZA cu succes, dar COMPUNE gresit cadrul (dreptunghiul gri =
cadru de compunere GPU corupt, simptom clasic de driver de VM). Fix:
sarit direct la `--vo=gdi` (blit direct Win32, FARA nicio compunere GPU)
+ `--hwdec=no` (decodare software - decodarea hardware ar depinde tot de
driverul GPU, posibil virtualizat). Aplicarea LUT-ului (`lavfi=[lut3d=
...]`) ruleaza deja pe CPU prin libavfilter, deci nu se pierde nimic din
calitate fata de varianta cu compunere GPU.

Versiune 3.14.8 -> 3.14.9 (PATCH — fix-uri izolate, fara arhitectura
noua, Regula 14).

## v3.14.10 (2026-09-06) — Elevare UAC explicita + fix ferestre negre consola + diagnostic mpv

**Raportat de Cristi, dupa testarea reala a v3.14.9 - AMBELE fix-uri
anterioare (update + Player LUT) au esuat identic**, plus doua probleme
noi observate.

**1. "Security validation failure" - PERSISTA identic dupa v3.14.9**.
Cristi a dat testul decisiv: dublu-click manual + "Run as administrator"
pe `.exe` -> FUNCTIONEAZA, fara nicio eroare. Asta izoleaza exact cauza:
`installer.iss` cere `PrivilegesRequired=admin`; lansat NEELEVAT (orice
metoda simpla - `Popen` VECHI sau `os.startfile()` simplu din v3.14.9),
Setup.exe trebuie sa se auto-relanseze intern prin UAC - exact acolo
esueaza verificarea lui interna (nedocumentata public, cautat explicit
prin Sourcegraph pe tot codul open-source, 0 rezultate - deci probabil
un binar precompilat intern, nu Pascal-ul open-source din issrc). Lansat
DEJA elevat (ca la "Run as administrator"), acel al doilea proces intern
nu se mai declanseaza NICIODATA. Fix real: `os.startfile(exe_path,
"runas")` - al doilea parametru documentat oficial Python (doar Windows)
cere UAC direct la apel, identic cu alegerea manuala a lui Cristi.

**2. Fereastra neagra la scrubbing in Previzualizare ("mi se fac niste
ferestre negre si se inchide")**. Cauza reala, gasita prin audit
sistematic al TUTUROR apelurilor `subprocess` din tot `python/`: ffmpeg/
ffprobe sunt aplicatii de CONSOLA; apelate din build-ul nostru "windowed"
(`build-windows.spec`, `console=False`) FARA `creationflags=
CREATE_NO_WINDOW`, Windows deschide o consola noua VIZIBILA pentru
FIECARE apel — la scrubbing rapid in Preview (un apel ffmpeg per miscare
de slider), efectul e exact "ferestre negre care clipesc". Bug LATENT,
pre-existent in tot codul (niciodata raportat inainte, probabil fiindca
o consola singura, la o conversie lunga, trece neobservata) - fix aplicat
consecvent in TOATE punctele: `converter.py` (3 apeluri: is_available,
get_duration, convert), `media_inspector.py` (2 apeluri: probe,
generate_thumbnail), `dependency_manager.py` (2 apeluri: verificare
ffmpeg/mpv), `gpu_probe.py` (1 apel: listare encodere), `machine_id.py`
(1 apel: `reg query` pentru MachineGuid).

**3. Player LUT - ecran negru PERSISTA identic dupa v3.14.9** (fix-ul
`--vo=gdi --hwdec=no` NU a rezolvat, contrar ipotezei "compunere GPU
virtualizata"). Onest: dupa 2 incercari esuate de fix "orb" pe combinatia
`--vo`/`--hwdec`, fara nicio dovada REALA a cauzei (mpv rula cu consola
ascunsa - `CREATE_NO_WINDOW` - deci orice mesaj de eroare al lui era
invizibil, si pentru user, si pentru noi), continuarea cu inca o
presupunere ar irosi inca un ciclu de build/testare al lui Cristi
degeaba. In loc sa ghicim a treia oara: adaugat `--log-file=<cale>` +
`--msg-level=all=v` la lansarea mpv, plus detectie activa
(`_check_mpv_alive`, la 1.5s dupa lansare) - daca mpv moare imediat,
fereastra arata explicit eroarea + calea jurnalului, in loc sa ramana
"muta" (negru, fara niciun indiciu). URMATORUL raport de la Cristi
trebuie sa includa continutul acelui jurnal, ca sa localizam cauza REALA
in loc sa continuam sa incercam combinatii de flag-uri la intamplare.

**Verificat**: `python3 -m py_compile` pe toate fisierele modificate - 0
erori. `xcodebuild -configuration Debug` - BUILD SUCCEEDED. NU s-a putut
verifica real pe Windows/Parallels (ca la toate versiunile anterioare) -
Cristi confirma manual update-ul + trimite jurnalul mpv daca ecranul
negru persista.

Versiune 3.14.9 -> 3.14.10 (PATCH — fix-uri + instrumentare de
diagnosticare, fara arhitectura noua, Regula 14).

## v3.14.11 (2026-09-06) — FIX REAL, dovedit cu jurnal: ecran negru Player LUT

**Instrumentarea din v3.14.10 (`--log-file`) si-a facut treaba** — Cristi
a trimis jurnalul complet mpv, prima dovada REALA (nu presupunere) a
cauzei. Linia decisiva:

```
[e][vo] Video output gdi not found!
[f][cplayer] Error opening/initializing the selected video_out (--vo) device.
```

**Ambele ipoteze anterioare erau gresite**: nu era compunere GPU
virtualizata (Parallels), nu era o combinatie subtila de flag-uri —
`--vo=gdi` (fix-ul din v3.14.9) e pur si simplu un NUME DE DRIVER care
NU MAI EXISTA in build-urile moderne mpv (vo_gdi eliminat de mult din
proiect). mpv esua sa initializeze VIDEO-UL COMPLET (nu doar randa
gresit) - audio-ul mergea perfect (`AO: [wasapi]... audio ready` in
jurnal), ceea ce explica de ce ecranul era CONSTANT negru, fara nicio
exceptie, indiferent de masina de testare.

**Fix**: `--vo=gpu` — confirmat disponibil chiar in acelasi jurnal
("List of enabled features": `d3d11`, `gl`, `libplacebo`, `vulkan`),
randorul GPU standard mpv pe Windows, fara sa fortam un `--gpu-context`
anume (mpv alege singur). `--hwdec=no` ramane (decodare software,
precautie ieftina).

**Lectie practica**: cele doua incercari anterioare (v3.14.8, v3.14.9)
au fost presupuneri plauzibile dar NECONFIRMATE - abia jurnalul real
(adaugat in v3.14.10 dupa ce a doua presupunere a esuat identic) a dat
raspunsul corect in prima incercare. Regula practica pentru viitor: la
orice bug de randare/integrare externa fara mesaj de eroare vizibil
userului, PRIMUL pas e sa facem eroarea vizibila (jurnal/log), nu sa
ghicim combinatii de configurare.

**Verificat**: `python3 -m py_compile lut_player.py` — 0 erori. NU s-a
putut verifica REAL redarea pe Windows — Cristi confirma pe masina lui.

Versiune 3.14.10 -> 3.14.11 (PATCH — fix izolat, fara arhitectura noua,
Regula 14).

## v3.14.12 (2026-09-06) — FIX real #2: ecran negru pe VM (flip-model DXGI)

**Raportat de Cristi dupa testarea v3.14.11**: tot negru. De data asta,
in loc sa presupun ("posibil e ceva cu masina virtuala" a sugerat chiar
Cristi), am cerut jurnalul din nou - metoda care a functionat exact la
v3.14.11. Jurnalul de aceasta data arata ceva neasteptat: **INIT COMPLET
REUSIT** - `Device Name: Parallels Display Adapter (WDDM)`, D3D11
feature level 11_1, swapchain configurat cu succes, `first video frame
after restart shown`, `playback restart complete... video=playing` -
NICIO eroare vizibila in jurnal, si totusi ecran negru pe masina reala a
lui Cristi.

**Cauza reala, identificata din jurnal**: linia `Using flip-model
presentation` - DXGI "flip model" (modul de prezentare implicit pe D3D11
modern) e un caz cunoscut, documentat chiar in optiunile oficiale mpv, ca
NU se compune vizual corect pe multe drivere de placa grafica VIRTUALA
(Parallels/VMware/RDP) - API-ul Windows raporteaza succes la fiecare pas
(creare swapchain, prezentare cadre), dar driverul WDDM virtual nu poate
face scanout-ul direct cerut de flip-model, deci nimic nu ajunge vizual
pe ecran, desi mpv "crede" ca a randat corect.

**Fix**: `--d3d11-flip=no` - optiune mpv documentata exact pentru acest
scenariu, forteaza modelul vechi de prezentare (bitblt), compatibil cu
drivere de VM care nu implementeaza corect flip-model. Adaugat alaturi
de `--vo=gpu --hwdec=no` (neschimbate, ambele confirmate corecte din
jurnalul anterior).

**Lectie confirmata a doua oara**: jurnalul (`--log-file`, adaugat in
v3.14.10) a dat raspunsul exact, de doua ori la rand, in locul unor
presupuneri (inclusiv a uneia de-a lui Cristi, "posibil e virtual" - corecta
ca directie, dar mecanismul exact tot a trebuit confirmat din jurnal, nu
presupus). Regula practica ramane: la orice bug de randare fara eroare
vizibila userului, jurnalul complet e primul pas, nu a treia sau a patra
incercare.

**Verificat**: `python3 -m py_compile lut_player.py` - 0 erori. NU s-a
putut verifica REAL pe masina lui Cristi - confirmare asteptata.

Versiune 3.14.11 -> 3.14.12 (PATCH — fix izolat, fara arhitectura noua,
Regula 14).
