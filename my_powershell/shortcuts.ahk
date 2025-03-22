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

; CapsLock + S to toggle Signal
CapsLock & s::ToggleApp("Signal.exe", "C:\Users\Jared\AppData\Local\Programs\signal-desktop\Signal.exe")

; CapsLock + P to toggle Proton Mail
CapsLock & p::ToggleApp("Proton Mail.exe", "C:\Users\Jared\AppData\Local\proton_mail\Proton Mail.exe")

; CapsLock + W to open 3 tabs at once
CapsLock & w::
{
    Run "https://outlook.office.com/mail/"
    Sleep 500
    Run "https://highlands365-my.sharepoint.com/:x:/r/personal/jcervantes_highlandscsb_org/_layouts/15/Doc.aspx?sourcedoc=%7B37546E0A-8DD7-464D-8BF7-77E6371E4ACB%7D&file=Contacts.xlsx&action=default&mobileredirect=true"
    Sleep 500
    Run "https://login.cbh3.crediblebh.com/"
}

; Global copy-paste hotkey (backtick)
`::
{
    Send "^c"
    Sleep 50
    Send "^v"
}

; Alt + Q to close the active window
!q::WinClose "A"

; Alt + W to close the active tab in a browser
!w::Send ("^w")

; Alt + T to open a new tab
!t::Send ("^t")

; Alt + Z to put the computer to sleep
!z::DllCall("PowrProf\SetSuspendState", "Int", 0, "Int", 0, "Int", 0)
