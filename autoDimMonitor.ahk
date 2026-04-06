#Persistent
#NoEnv
#SingleInstance Force
SetBatchLines, -1
ListLines Off

; --- TRAY MENU ---
Menu, Tray, NoStandard
Menu, Tray, Add, Settings, ShowGui
Menu, Tray, Add, Reload, GuiReload
Menu, Tray, Add, Exit, GuiExit
Menu, Tray, Default, Settings

; --- INITIAL LOAD ---
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

Global Blacklist := {}
Loop, parse, BlacklistRaw, `,
    Blacklist[Trim(A_LoopField)] := 1

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
DllCall("SetWinEventHook", "UInt", 0x800B, "UInt", 0x800B, "Ptr", 0, "Ptr", RegisterCallback("EventTimer"), "UInt", 0, "UInt", 0, "UInt", 0)
DllCall("SetWinEventHook", "UInt", 0x0001, "UInt", 0x0002, "Ptr", 0, "Ptr", RegisterCallback("EventTimer"), "UInt", 0, "UInt", 0, "UInt", 0)

UpdateMonitor()
return

; --- CORE FUNCTIONS ---
EventTimer() {
    SetTimer, UpdateMonitor, -100
}

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
            if (Blacklist.HasKey(Title))
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

; --- GUI & TRAY HANDLERS ---
ShowGui:
    MonList := ""
    SysGet, MC, MonitorCount
    Loop, %MC% {
        SysGet, MName, MonitorName, %A_Index%
        FullID := MName . "\Monitor0"
        MonList .= FullID . "|"
        if (FullID = TargetID)
            SelectedMon := A_Index
    }

    Gui, Settings:New, +AlwaysOnTop, Monitor Settings
    Gui, Margin, 15, 15
    Gui, Add, Text,, Select Target Monitor:
    Gui, Add, DropDownList, vGuiTargetID Choose%SelectedMon% w250, %MonList%
    Gui, Add, Text, y+15, Brightness (Active):
    Gui, Add, Slider, vGuiBright Range0-100 ToolTip gSliderMove w200, %BrightBrightness%
    Gui, Add, Edit, vEditBright x+10 yp-3 w40 Limit3 gEditMove, %BrightBrightness%
    Gui, Add, Text, xm y+15, Brightness (Dim):
    Gui, Add, Slider, vGuiDim Range0-100 ToolTip gSliderMove w200, %DimBrightness%
    Gui, Add, Edit, vEditDim x+10 yp-3 w40 Limit3 gEditMove, %DimBrightness%
    Gui, Add, Checkbox, xm y+15 vGuiDebug Checked%DebugMode%, Enable Debug Tooltip
    Gui, Add, Button, xm y+20 Default gSaveSettings w100 h30, Save
    Gui, Add, Button, x+10 yp w100 h30 gGuiClose, Cancel
    Gui, Show
return

SliderMove:
    Gui, Settings:Submit, NoHide
    GuiControl, Settings:, EditBright, %GuiBright%
    GuiControl, Settings:, EditDim, %GuiDim%
return

EditMove:
    Gui, Settings:Submit, NoHide
    if (EditBright ~= "^\d+$")
        GuiControl, Settings:, GuiBright, %EditBright%
    if (EditDim ~= "^\d+$")
        GuiControl, Settings:, GuiDim, %EditDim%
return

SaveSettings:
    Gui, Settings:Submit
    IniWrite, %GuiTargetID%, %ConfigFile%, Settings, TargetID
    IniWrite, %EditBright%, %ConfigFile%, Settings, BrightBrightness
    IniWrite, %EditDim%, %ConfigFile%, Settings, DimBrightness
    IniWrite, %GuiDebug%, %ConfigFile%, Settings, Debug
    Reload
return

GuiReload:
    Reload
return

GuiExit:
ExitApp
return

SettingsGuiClose:
GuiClose:
    Gui, Settings:Destroy
return

^!r::Reload