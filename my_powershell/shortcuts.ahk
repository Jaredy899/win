﻿#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases
#SingleInstance Force  ; Ensures that only one instance of this script is running
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory

; Alt+Q - Close active window
!q::WinClose A

; Alt+X - Open Terminal (Windows Terminal if available, otherwise Command Prompt)
!x::
if FileExist("C:\Program Files\WindowsApps\Microsoft.WindowsTerminal*") {
    Run wt.exe
} else {
    Run cmd.exe
}
return

; Alt+B - Open Vivaldi browser
!b::
if FileExist("C:\Users\" A_UserName "\AppData\Local\Vivaldi\Application\vivaldi.exe") {
    Run "C:\Users\%A_UserName%\AppData\Local\Vivaldi\Application\vivaldi.exe"
} else if FileExist("C:\Program Files\Vivaldi\Application\vivaldi.exe") {
    Run "C:\Program Files\Vivaldi\Application\vivaldi.exe"
} else if FileExist("C:\Program Files (x86)\Vivaldi\Application\vivaldi.exe") {
    Run "C:\Program Files (x86)\Vivaldi\Application\vivaldi.exe"
} else {
    MsgBox, Vivaldi browser not found in common installation locations.
}
return