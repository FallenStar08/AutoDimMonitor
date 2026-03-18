#Persistent
#NoEnv
#SingleInstance Force
SetBatchLines, -1
ListLines Off

ConfigFile := A_ScriptDir "\config.ini"

if !FileExist(ConfigFile) {
    IniWrite, \\.\DISPLAY3\Monitor0, %ConfigFile%, Settings, TargetID
    IniWrite, F:\Documents\Outils\Nirsoft\NirSoft\controlmymonitor.exe, %ConfigFile%, Settings, PathToControl
    IniWrite, 5, %ConfigFile%, Settings, DimBrightness
    IniWrite, 100, %ConfigFile%, Settings, BrightBrightness
}

IniRead, TargetID, %ConfigFile%, Settings, TargetID
IniRead, PathToControl, %ConfigFile%, Settings, PathToControl
IniRead, DimBrightness, %ConfigFile%, Settings, DimBrightness
IniRead, BrightBrightness, %ConfigFile%, Settings, BrightBrightness

RegExMatch(TargetID, "DISPLAY(\d+)", MonNum)
Global TargetIndex := MonNum1
Global CurrentState := ""

; Hooks for Window Events
; 0x800B = EVENT_OBJECT_LOCATIONCHANGE, 0x0001 = CREATE, 0x0002 = DESTROY
DllCall("SetWinEventHook", "UInt", 0x800B, "UInt", 0x800B, "Ptr", 0, "Ptr", RegisterCallback("UpdateMonitor"), "UInt", 0, "UInt", 0, "UInt", 0)
DllCall("SetWinEventHook", "UInt", 0x0001, "UInt", 0x0002, "Ptr", 0, "Ptr", RegisterCallback("UpdateMonitor"), "UInt", 0, "UInt", 0, "UInt", 0)

UpdateMonitor()
return

UpdateMonitor() {
    global TargetID, PathToControl, DimBrightness, BrightBrightness, TargetIndex, CurrentState

    SysGet, Mon, Monitor, %TargetIndex%

    HasWindow := 0
    WinGet, id, List
    Loop, %id%
    {
        this_id := id%A_Index%
        WinGetTitle, Title, ahk_id %this_id%
        WinGet, Style, Style, ahk_id %this_id%

        if (Title != "" && (Style & 0x10000000) && Title != "Program Manager")
        {
            WinGetPos, WX, WY, WW, WH, ahk_id %this_id%
            if (WX < MonRight && WX + WW > MonLeft && WY < MonBottom && WY + WH > MonTop)
            {
                HasWindow := 1
                break
            }
        }
    }

    if (HasWindow && CurrentState != "Bright") {
        Run, "%PathToControl%" /SetValue "%TargetID%" 10 %BrightBrightness%, , Hide
        CurrentState := "Bright"
    }
    else if (!HasWindow && CurrentState != "Dim") {
        Run, "%PathToControl%" /SetValue "%TargetID%" 10 %DimBrightness%, , Hide
        CurrentState := "Dim"
    }
}

^!r::Reload