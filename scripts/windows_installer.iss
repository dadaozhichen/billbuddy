; Inno Setup script for BillBuddy
#define MyAppName "BillBuddy"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "zhuhkblog.cn"
#define MyAppURL "https://github.com/dadaozhichen/billbuddy"

[Setup]
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
OutputDir=..\output
OutputBaseFilename=billbuddy-setup-{#MyAppVersion}
Compression=lzma
SolidCompression=yes
UninstallDisplayIcon={app}\billbuddy.exe

[Files]
Source: "build_input\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\billbuddy.exe"
Name: "{group}\Uninstall {#MyAppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\billbuddy.exe"

[Run]
Filename: "{app}\billbuddy.exe"; Description: "Run BillBuddy"; Flags: postinstall nowait skipifsilent
