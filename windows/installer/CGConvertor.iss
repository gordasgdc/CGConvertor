; Instalator Windows CG Convertor 3.18.0 (aplicație WPF .NET 8 self-contained).
; Compilare: ISCC.exe /DPublishDir=<folder publish> /DOutDir=<folder ieșire> /DAppVersion=3.18.0 CGConvertor.iss
; Același AppId și același folder de instalare ca 3.15.0 (Python) => upgrade pe loc; datele utilizatorului
; (licență, probă în %USERPROFILE%\.cgconvertor_*) nu sunt atinse de instalare.

#ifndef AppVersion
  #define AppVersion "3.18.0"
#endif
#ifndef PublishDir
  #define PublishDir "publish"
#endif
#ifndef OutDir
  #define OutDir "Output"
#endif
#define MyAppName "CG Convertor"
#define MyAppExeName "CGConvertor.exe"

[Setup]
AppId={{B7F3E5A2-9C1D-4F6B-A8E0-CGCONVERTOR01}}
AppName={#MyAppName}
AppVersion={#AppVersion}
VersionInfoVersion={#AppVersion}
AppPublisher=Cristi Gordas
AppPublisherURL=https://gordas.dev/cgconvertor/
AppUpdatesURL=https://gordas.dev/cgconvertor/
DefaultDirName={autopf}\GDC\CG Convertor
DefaultGroupName=CG Convertor
DisableProgramGroupPage=yes
OutputDir={#OutDir}
OutputBaseFilename=CGConvertor-Windows-{#AppVersion}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
SetupIconFile=..\CGConvertor.Client\app.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
CloseApplications=yes
RestartApplications=no
PrivilegesRequired=admin

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"; LicenseFile: "license-en.txt"
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"; LicenseFile: "license-es.txt"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#PublishDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\Uninstall {#MyAppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#MyAppName}}"; Flags: nowait postinstall skipifsilent

; Dezinstalare curată: setări, temă, loguri și copia protejată; probă INTENȚIONAT păstrată (nu se resetează prin reinstalare);
; fișierul de licență din profil se păstrează la fel ca la 3.15.0 doar dacă utilizatorul reinstalează — aici îl ștergem ca înainte.
[UninstallDelete]
Type: filesandordirs; Name: "{userappdata}\CGConvertor"
Type: filesandordirs; Name: "{localappdata}\GDC\CGConvertor"
Type: files; Name: "{%USERPROFILE}\.cgconvertor_license"
