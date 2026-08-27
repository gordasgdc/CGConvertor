; Instalator Windows pentru CG Convertor, cu Inno Setup
; (https://jrsoftware.org/isinfo.php — gratuit). Inlocuieste arhiva .exe
; "standalone" livrata anterior fara installer (doar un executabil brut,
; fara scurtaturi, fara intrare in "Apps & Features", fara dezinstalare
; curata) — port 1:1 al tiparului installer.iss din GDCVaultWin/
; GDCPluginManagerWin, adaptat pentru un build PyInstaller (onefile),
; nu un `dotnet publish`.
;
; CI-ul (.github/workflows/build-windows.yml) face toti pasii automat.
; Pentru compilare MANUALA, pe Windows, cu Inno Setup Compiler instalat
; (gratuit, https://jrsoftware.org/isdl.php):
;   1. pip install -r requirements.txt
;   2. pyinstaller build-windows.spec   (produce dist\CGConvertor.exe)
;   3. Deschide acest fisier (installer.iss) cu Inno Setup Compiler
;   4. Apasa "Compile" (sau F9)
;   5. Rezultatul apare in Output\CGConvertorSetup.exe

#define MyAppName "CG Convertor"
#define MyAppVersion "2.2.0"
#define MyAppPublisher "Cristi Gordas"
#define MyAppExeName "CGConvertor.exe"
#define MyAppURL "https://github.com/gordasgdc/CGConvertor"

[Setup]
AppId={{B7F3E5A2-9C1D-4F6B-A8E0-CGCONVERTOR01}}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\GDC\CG Convertor
DefaultGroupName=CG Convertor
DisableProgramGroupPage=yes
OutputDir=Output
OutputBaseFilename=CGConvertorSetup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
; Iconita instalatorului insusi (fereastra Setup + Programs and Features) —
; acelasi fisier folosit ca --icon la pyinstaller (build-windows.spec) si
; ca iconita de fereastra la runtime (main.py._set_window_icon).
SetupIconFile=CGConvertor.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
; Nu semnat cu certificat platit — Windows SmartScreen arata un
; avertisment "Unrecognized app" la prima rulare a instalatorului. Normal
; pentru distributie indie, la fel ca restul ecosistemului GDC pe Windows.

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "dist\CGConvertor.exe"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
; Filename-ul .exe insusi are deja iconita corecta (pyinstaller --icon),
; deci scurtaturile o mostenesc automat — nu e nevoie de IconFilename separat.
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\Dezinstaleaza {#MyAppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#MyAppName}}"; Flags: nowait postinstall skipifsilent

; REGULA PERMANENTA de Clean Uninstall (vezi CLAUDE.md) — sterge tot ce a
; scris aplicatia: settings.json (config.py), fisierul de licenta activata
; (license_validator._license_file_path, ~/.cgconvertor_license — in HOME,
; nu %LocalAppData%, sters separat mai jos) si proba (~/.cgconvertor_trial,
; INTENTIONAT NESTERSA — dezinstalarea NU reseteaza proba gratuita, altfel
; ar fi un exploit trivial "dezinstaleaza + reinstaleaza = alte 15 zile").
[UninstallDelete]
Type: filesandordirs; Name: "{userappdata}\CGConvertor"
Type: files; Name: "{%USERPROFILE}\.cgconvertor_license"
