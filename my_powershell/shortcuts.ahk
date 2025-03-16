#Requires AutoHotkey v2.0

; Function to toggle application (open/activate or minimize)
ToggleApp(exeName, runCmd)
{
    if WinExist("ahk_exe " exeName)
    {
        if WinActive("ahk_exe " exeName)
            WinMinimize
        else
            WinActivate
    }
    else
        Run runCmd
}

; CapsLock + A to toggle Notepad
CapsLock & a::ToggleApp("notepad.exe", "notepad.exe")

; CapsLock + C to toggle Cursor
CapsLock & c::ToggleApp("Cursor.exe", "C:\Users\Jared\AppData\Local\Programs\cursor\Cursor.exe")

; CapsLock + B to toggle Browser
CapsLock & b::ToggleApp("brave.exe", "C:\Users\Jared\AppData\Local\BraveSoftware\Brave-Browser\Application\brave.exe")

; CapsLock + G to toggle Terminal
CapsLock & g::ToggleApp("WindowsTerminal.exe", "wt.exe")

; CapsLock + F to toggle F1 24
CapsLock & f::ToggleApp("F1_24.exe", "steam://rungameid/2488620") ; Adjust F1_24.exe to match the actual executable name

; CapsLock + T to toggle Termius
CapsLock & t::ToggleApp("Termius.exe", "C:\Users\Jared\AppData\Local\Programs\Termius\Termius.exe")

; Alt + Q to close the active window
!q::WinClose "A"
