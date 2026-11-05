; Installeur Windows d'Akonta (Inno Setup 6). Compilation : iscc /DAppVersion=0.1.0 akonta.iss
; Le dossier Release doit déjà contenir l'application et les DLL Visual C++ (étape de la CI).
#ifndef AppVersion
  #define AppVersion "0.1.0"
#endif
#define BuildDir "..\..\build\windows\x64\runner\Release"

[Setup]
AppId={{B3D1C2A4-6E7F-4A18-9C55-2F0A7D3E9B61}
AppName=Akonta
AppVersion={#AppVersion}
AppPublisher=Simetriik Solutions
AppPublisherURL=https://simetriik.com
DefaultDirName={autopf}\Akonta
DefaultGroupName=Akonta
DisableProgramGroupPage=yes
; Installation sans droits administrateur par défaut ; l'utilisateur peut choisir « pour tous »
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=..\..\build\installer
OutputBaseFilename=akonta-setup-{#AppVersion}
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\akonta.exe
Compression=lzma2
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "french"; MessagesFile: "compiler:Languages\French.isl"

[Tasks]
Name: "desktopicon"; Description: "Créer un raccourci sur le Bureau"; GroupDescription: "Raccourcis :"

[Files]
Source: "{#BuildDir}\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion

[Icons]
Name: "{autoprograms}\Akonta"; Filename: "{app}\akonta.exe"
Name: "{autodesktop}\Akonta"; Filename: "{app}\akonta.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\akonta.exe"; Description: "Lancer Akonta"; Flags: nowait postinstall skipifsilent
