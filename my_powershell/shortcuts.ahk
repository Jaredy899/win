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

; Mac-like Command key shortcuts using Alt
!c::Send("^c")  ; Copy
!v::Send("^v")  ; Paste
!x::Send("^x")  ; Cut
!s::Send("^s")  ; Save
!f::Send("^f")  ; Find
!a::Send("^a")  ; Select all
!z::Send("^z")  ; Undo
!+z::Send("^y") ; Redo
!n::Send("^n")  ; New
!p::Send("^p")  ; Print
!o::Send("^o")  ; Open
!w::Send("^w")  ; Close tab (preserved from your existing shortcuts)

; CapsLock + A to toggle T3
CapsLock & a::Run("https://t3.chat/chat")

; CapsLock + C to toggle Cursor
CapsLock & c::ToggleApp("Cursor.exe", "C:\Users\Jared\AppData\Local\Programs\cursor\Cursor.exe")

; CapsLock + B to toggle Browser
CapsLock & b::ToggleApp("thorium.exe", "C:\Users\Jared\AppData\Local\Thorium\Application\thorium.exe")

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

; CapsLock + Y to toggle Youtube
CapsLock & y::Run("https://www.youtube.com/feed/subscriptions")

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

CapsLock & x::{
    ClipSaved := A_Clipboard
    A_Clipboard := ""
    Send("{Home}+{End}^x{Del}")
    Sleep(100)
    A_Clipboard := ClipSaved
}

; Alt + Q to close the active window
!q::WinClose "A"

; Alt + T to open a new tab
!t::Send ("^t")

; Open Downloads folder
CapsLock & d::Run("explorer.exe " A_MyDocuments "\..\Downloads")

; CapsLock + Z to put the computer to sleep
CapsLock & z::DllCall("PowrProf\SetSuspendState", "Int", 0, "Int", 0, "Int", 0)

; Alt + 1-9 to switch between browser tabs
!1::Send("^1")
!2::Send("^2")
!3::Send("^3")
!4::Send("^4")
!5::Send("^5")
!6::Send("^6")
!7::Send("^7")
!8::Send("^8")
!9::Send("^9")
