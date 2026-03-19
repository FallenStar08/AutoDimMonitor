#Persistent
#NoEnv
#SingleInstance Force
SetBatchLines, -1
ListLines Off

ConfigFile := A_ScriptDir "\config.ini"

if !FileExist(ConfigFile) {
    IniWrite, \\.\DISPLAY3\Monitor0, %ConfigFile%, Settings, TargetID
    IniWrite, C:\Path\To\controlmymonitor.exe, %ConfigFile%, Settings, PathToControl
    IniWrite, 5, %ConfigFile%, Settings, DimBrightness
    IniWrite, 80, %ConfigFile%, Settings, BrightBrightness
    IniWrite, 0, %ConfigFile%, Settings, Debug
    IniWrite, NVIDIA Container`,Overwolf, %ConfigFile%, Settings, Blacklist
}

IniRead, TargetID, %ConfigFile%, Settings, TargetID
IniRead, PathToControl, %ConfigFile%, Settings, PathToControl
IniRead, DimBrightness, %ConfigFile%, Settings, DimBrightness
IniRead, BrightBrightness, %ConfigFile%, Settings, BrightBrightness
IniRead, DebugMode, %ConfigFile%, Settings, Debug, 0
IniRead, BlacklistRaw, %ConfigFile%, Settings, Blacklist, %A_Space%

Global Blacklist := []
Loop, parse, BlacklistRaw, `,
    Blacklist.Push(Trim(A_LoopField))

RegExMatch(TargetID, "DISPLAY\d+", SearchName)

Global TargetIndex := 0
SysGet, MonCount, MonitorCount
Loop, %MonCount% {
    SysGet, Name, MonitorName, %A_Index%
    if (SearchName && InStr(Name, SearchName) || InStr(TargetID, Name)) {
        TargetIndex := A_Index
        Break
    }
}

if (TargetIndex = 0) {
    RegExMatch(TargetID, "DISPLAY(\d+)", MonNum)
    TargetIndex := MonNum1 ? MonNum1 : 1
}

SysGet, Mon, Monitor, %TargetIndex%
Global mLeft := MonLeft, mTop := MonTop, mRight := MonRight, mBottom := MonBottom
Global CurrentState := ""

; Hooks for Window Events
; 0x800B = EVENT_OBJECT_LOCATIONCHANGE, 0x0001 = CREATE, 0x0002 = DESTROY
DllCall("SetWinEventHook", "UInt", 0x800B, "UInt", 0x800B, "Ptr", 0, "Ptr", RegisterCallback("UpdateMonitor"), "UInt", 0, "UInt", 0, "UInt", 0)
DllCall("SetWinEventHook", "UInt", 0x0001, "UInt", 0x0002, "Ptr", 0, "Ptr", RegisterCallback("UpdateMonitor"), "UInt", 0, "UInt", 0, "UInt", 0)

UpdateMonitor()
return

UpdateMonitor() {
    global

    HasWindow := 0
    FoundWindows := ""
    WinGet, id, List
    Loop, %id%
    {
        this_id := id%A_Index%
        WinGetTitle, Title, ahk_id %this_id%

        if (Title = "" || InStr(Title, "DEBUG"))
            continue

        WinGet, Style, Style, ahk_id %this_id%
        WinGetClass, class, ahk_id %this_id%

        if ((Style & 0x10000000) && class != "tooltips_class32")
        {
            IsBlacklisted := 0
            for each, item in Blacklist {
                if (Title = item) {
                    IsBlacklisted := 1
                    break
                }
            }
            if (IsBlacklisted)
                continue

            WinGetPos, WX, WY, WW, WH, ahk_id %this_id%

            if (WX+(WW/2) >= mLeft && WX+(WW/2) <= mRight && WY+(WH/2) >= mTop && WY+(WH/2) <= mBottom)
            {
                HasWindow := 1
                if (DebugMode)
                    FoundWindows .= "- " . Title . "`n"
                else
                    break
            }
        }
    }

    if (DebugMode)
        ToolTip, % "TARGET: " TargetID "`nAHK INDEX: " TargetIndex "`nState: " (HasWindow ? "BRIGHT" : "DIM") "`nWindows:`n" (FoundWindows ? FoundWindows : "None"), 0, 0
    else
        ToolTip

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