Set WshShell = WScript.CreateObject("WScript.Shell") 
If WScript.Arguments.Length = 0 Then 
  Set ObjShell = CreateObject("Shell.Application") 
  ObjShell.ShellExecute "wscript.exe" _ 
  , """" & WScript.ScriptFullName & """ RunAsAdministrator", , "runas", 1 
  WScript.Quit 
End if
Set fso = CreateObject("Scripting.FileSystemObject")
scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)
set ObjShell = CreateObject("WScript.Shell")
ObjShell.CurrentDirectory = scriptDir
ObjShell.Run """" & scriptDir & "\mihomo.exe"" -f """ & scriptDir & "\config.yaml"" -d ./", 1