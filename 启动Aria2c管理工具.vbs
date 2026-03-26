Set objShell = CreateObject("WScript.Shell")
Set objFSO = CreateObject("Scripting.FileSystemObject")

strCurrentDir = objFSO.GetParentFolderName(WScript.ScriptFullName)
strPSScript = objFSO.BuildPath(strCurrentDir, "Aria2c_Manager.ps1")

objShell.Run "powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & strPSScript & """", 0, False
