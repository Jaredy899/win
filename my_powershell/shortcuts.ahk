#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases
#SingleInstance Force  ; Ensures that only one instance of this script is running
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory

; Alt+Q - Close active window
!q::WinClose A

; Alt+X - Open Terminal (Windows Terminal if available, otherwise PowerShell)
!x::
if FileExist("C:\Program Files\WindowsApps\Microsoft.WindowsTerminal*") {
    Run wt.exe
} else {
    Run powershell.exe
}
return

; Alt+B - Open default browser
!b::Run "http://"
return