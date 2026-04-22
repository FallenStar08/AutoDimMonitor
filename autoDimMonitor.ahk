#Persistent
#NoEnv
#SingleInstance Force
SetBatchLines, -1
ListLines Off

dimIconPath := A_ScriptDir "\resources\dim.ico"
brightIconPath := A_ScriptDir "\resources\bright.ico"

; --- TRAY MENU ---
Menu, Tray, NoStandard
Menu, Tray, Add, Settings, ShowGui
Menu, Tray, Add, Reload, GuiReload
Menu, Tray, Add, Exit, GuiExit
Menu, Tray, Default, Settings

; --- INITIAL LOAD ---
ConfigFile := A_ScriptDir "\config.ini"

if !FileExist(ConfigFile) {
    IniWrite, 3, %ConfigFile%, Settings, TargetDisplayNum
    IniWrite, C:\Path\To\controlmymonitor.exe, %ConfigFile%, Settings, PathToControl
    IniWrite, 5, %ConfigFile%, Settings, DimBrightness
    IniWrite, 80, %ConfigFile%, Settings, BrightBrightness
    IniWrite, 0, %ConfigFile%, Settings, Debug
    IniWrite, NVIDIA Container`,Overwolf, %ConfigFile%, Settings, Blacklist
}

IniRead, TargetDisplayNum, %ConfigFile%, Settings, TargetDisplayNum
IniRead, PathToControl, %ConfigFile%, Settings, PathToControl
IniRead, DimBrightness, %ConfigFile%, Settings, DimBrightness
IniRead, BrightBrightness, %ConfigFile%, Settings, BrightBrightness
IniRead, DebugMode, %ConfigFile%, Settings, Debug, 0
IniRead, BlacklistRaw, %ConfigFile%, Settings, Blacklist, %A_Space%

Global Blacklist := {}
Loop, parse, BlacklistRaw, `,
    Blacklist[Trim(A_LoopField)] := 1

Global TargetIndex := 0
SysGet, MonCount, MonitorCount
Loop, %MonCount% {
    SysGet, Name, MonitorName, %A_Index%
    if InStr(Name, "DISPLAY" . TargetDisplayNum) {
        TargetIndex := A_Index
        Break
    }
}

if (TargetIndex = 0)
    TargetIndex := 1

SysGet, Mon, Monitor, %TargetIndex%
Global mLeft := MonLeft, mTop := MonTop, mRight := MonRight, mBottom := MonBottom
Global CurrentState := ""

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
        ToolTip, % "TARGET DISPLAY: " TargetDisplayNum "`nAHK INDEX: " TargetIndex "`nState: " (HasWindow ? "BRIGHT" : "DIM") "`nWindows:`n" (FoundWindows ? FoundWindows : "None"), 0, 0
    else
        ToolTip

    if (HasWindow && CurrentState != "Bright") {
        BroadcastBrightness(BrightBrightness)
        CurrentState := "Bright"
        Menu, Tray, Icon, %brightIconPath%
    }
    else if (!HasWindow && CurrentState != "Dim") {
        BroadcastBrightness(DimBrightness)
        CurrentState := "Dim"
        Menu, Tray, Icon, %dimIconPath%
    }
}

BroadcastBrightness(Level) {
    global PathToControl, TargetDisplayNum
    Loop, 2 {
        Idx := A_Index - 1
        Run, "%PathToControl%" /SetValue "\\.\DISPLAY%TargetDisplayNum%\Monitor%Idx%" 10 %Level%, , Hide
    }
}

; --- GUI & TRAY HANDLERS ---
ShowGui:
    MonList := ""
    SysGet, MC, MonitorCount
    Loop, %MC% {
        MonList .= "Monitor " . A_Index . "|"
    }

    Gui, Settings:New, +AlwaysOnTop, Monitor Settings
    Gui, Margin, 15, 15
    Gui, Add, Text,, Select Target Display Number:
    Gui, Add, DropDownList, vGuiDispNum Choose%TargetDisplayNum% w250, %MonList%
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
    ; Extract the digit from "Monitor X"
    RegExMatch(GuiDispNum, "\d+", NewDispNum)
    IniWrite, %NewDispNum%, %ConfigFile%, Settings, TargetDisplayNum
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