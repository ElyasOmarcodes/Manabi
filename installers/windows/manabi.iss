; Inno Setup script for the Manabi Windows installer.
; Built in CI: iscc /DAppVersion=x.y.z /DSourceDir=...\Release /DOutputDir=...\dist manabi.iss
#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif

[Setup]
AppId={{6E7B2D1C-4F2A-4C5B-9E0D-3A8F1B6C2D41}
AppName=Manabi
AppVersion={#AppVersion}
AppPublisher=Manabi
AppPublisherURL=https://github.com/ElyasOmarcodes/Manabi
DefaultDirName={autopf}\Manabi
DefaultGroupName=Manabi
DisableProgramGroupPage=yes
OutputDir={#OutputDir}
OutputBaseFilename=Manabi-windows-x64-setup
SetupIconFile={#SourceDir}\..\..\..\..\..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\manabi.exe
Compression=lzma2
SolidCompression=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequiredOverridesAllowed=dialog
WizardStyle=modern

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Manabi"; Filename: "{app}\manabi.exe"
Name: "{autodesktop}\Manabi"; Filename: "{app}\manabi.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\manabi.exe"; Description: "{cm:LaunchProgram,Manabi}"; Flags: nowait postinstall skipifsilent
