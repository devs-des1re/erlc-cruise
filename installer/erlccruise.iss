; ---------------------------------------------------------------------------
; Inno Setup script for ERLC Cruise Control.
;
; Build with:  ISCC.exe /DAppVersion=0.1.0 erlccruise.iss
; Expects the compiled exe at ..\dist\ERLCCruise.exe.
;
; Per-machine install. Ships the exe, icon, WebView2 loader, and the ui\ folder
; (also embedded as resources in the exe). Config and logs are written to
; %APPDATA%\ERLCCruise at runtime.
; ---------------------------------------------------------------------------

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif

#define AppName "ERLC Cruise Control"
#define AppPublisher "Arjun Patel"
#define AppExeName "ERLCCruise.exe"
#define SourceRoot ".."

[Setup]
AppId={{2E3444E9-E31E-43CB-948C-79367A036D37}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher={#AppPublisher}
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
UninstallDisplayIcon={app}\icon.ico
UninstallDisplayName={#AppName}
OutputDir=Output
OutputBaseFilename=ERLCCruise-Setup-{#AppVersion}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=admin
SetupIconFile={#SourceRoot}\icon.ico

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; Application (the UI is also embedded in the exe as resources)
Source: "{#SourceRoot}\dist\{#AppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceRoot}\icon.ico"; DestDir: "{app}"; Flags: ignoreversion

; WebView2 loader (fallback; the exe embeds its own copy)
Source: "{#SourceRoot}\vendor\webview\64bit\WebView2Loader.dll"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExeName}"
Name: "{group}\{cm:UninstallProgram,{#AppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(AppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
