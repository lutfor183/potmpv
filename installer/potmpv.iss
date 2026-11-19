#define MyAppName "PotMPV"
#ifndef MyAppVersion
  #define MyAppVersion "1.1.0"
#endif
#define MyAppPublisher "PotMPV"
#define MyAppExeName "mpv.exe"

[Setup]
AppId={{7D1F8C42-6B3E-4E2B-9C7A-5D9E1F2A3B44}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
OutputDir=..\dist
OutputBaseFilename=PotMPV-{#MyAppVersion}-setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayIcon={app}\mpv\{#MyAppExeName}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional icons:"
Name: "associate"; Description: "Use PotMPV for video files"; GroupDescription: "Integration:"; Flags: unchecked

[Files]
Source: "..\dist\win\mpv\*"; DestDir: "{app}\mpv"; Flags: recursesubdirs ignoreversion
Source: "..\mpv.conf"; DestDir: "{app}\config"; Flags: ignoreversion
Source: "..\input.conf"; DestDir: "{app}\config"; Flags: ignoreversion
Source: "..\scripts\*"; DestDir: "{app}\config\scripts"; Flags: recursesubdirs ignoreversion
Source: "..\script-opts\*"; DestDir: "{app}\config\script-opts"; Flags: recursesubdirs ignoreversion
Source: "..\fonts\*"; DestDir: "{app}\config\fonts"; Flags: recursesubdirs ignoreversion
Source: "..\README.md"; DestDir: "{app}"; Flags: ignoreversion isreadme

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\mpv\{#MyAppExeName}"; Parameters: "--config-dir=""{app}\config"""
Name: "{group}\Uninstall {#MyAppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\mpv\{#MyAppExeName}"; Parameters: "--config-dir=""{app}\config"""; Tasks: desktopicon

[Run]
Filename: "{app}\mpv\{#MyAppExeName}"; Parameters: "--config-dir=""{app}\config"""; Description: "Launch {#MyAppName}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
Type: filesandordirs; Name: "{app}\config"
