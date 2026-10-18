#define AppName "Hazuki"
#define AppPublisher "LuckyLxi"
#define AppExeName "hazuki.exe"
#define SourceDir "..\build\windows\x64\runner\Release"

[Setup]
AppId={{6F3A8C2D-1E47-4B90-A5D3-8C7F2E9B4061}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
OutputDir=.
OutputBaseFilename=hazuki-windows-x64-{#AppVersion}-setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
WizardSizePercent=100
WizardResizable=no
ShowLanguageDialog=auto
UsePreviousLanguage=no
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
UninstallDisplayIcon={app}\{#AppExeName}
CloseApplications=force

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "chinesesimplified"; MessagesFile: "compiler:Languages\ChineseSimplified.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExeName}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(AppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[Registry]
Root: HKCU; Subkey: "Software\Classes\hazuki-auth"; ValueType: string; ValueData: "URL:Hazuki authorization"
Root: HKCU; Subkey: "Software\Classes\hazuki-auth"; ValueType: string; ValueName: "URL Protocol"; ValueData: ""
Root: HKCU; Subkey: "Software\Classes\hazuki-auth\shell\open\command"; ValueType: string; ValueData: """{app}\{#AppExeName}"" ""%1"""

[Code]
procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  Names: TArrayOfString;
  I: Integer;
  Command, OwnedCommand, Key: String;
begin
  if CurUninstallStep <> usUninstall then Exit;
  OwnedCommand := '"' + ExpandConstant('{app}\{#AppExeName}') + '" "%1"';
  if RegGetSubkeyNames(HKCU, 'Software\Classes', Names) then
    for I := 0 to GetArrayLength(Names) - 1 do
      if (Names[I] = 'hazuki-auth') or (Pos('hazuki-auth-portable-', Names[I]) = 1) then
      begin
        Key := 'Software\Classes\' + Names[I];
        if RegQueryStringValue(HKCU, Key + '\shell\open\command', '', Command) and
           (CompareText(Command, OwnedCommand) = 0) then
          RegDeleteKeyIncludingSubkeys(HKCU, Key);
      end;
end;
