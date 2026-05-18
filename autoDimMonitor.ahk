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
    IniWrite, 1, %ConfigFile%, Settings, TargetDisplayNum
    IniWrite, 5, %ConfigFile%, Settings, DimBrightness
    IniWrite, 80, %ConfigFile%, Settings, BrightBrightness
    IniWrite, 0, %ConfigFile%, Settings, Debug
    IniWrite, Rainmeter.exe, %ConfigFile%, Settings, Blacklist
}

IniRead, TargetDisplayNum, %ConfigFile%, Settings, TargetDisplayNum
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

; Get the Win32 monitor handle for our specific target AHK Index
Global hTargetMonitor := 0
DllCall("User32\EnumDisplayMonitors", "Ptr", 0, "Ptr", 0, "Ptr", RegisterCallback("GetTargetMonitorHandle", "F"), "Ptr", 0)

DllCall("SetWinEventHook", "UInt", 0x800B, "UInt", 0x800B, "Ptr", 0, "Ptr", RegisterCallback("EventTimer"), "UInt", 0, "UInt", 0, "UInt", 0)
DllCall("SetWinEventHook", "UInt", 0x0001, "UInt", 0x0002, "Ptr", 0, "Ptr", RegisterCallback("EventTimer"), "UInt", 0, "UInt", 0, "UInt", 0)

UpdateMonitor()
return

; --- ENUMERATION CALLBACK TO CACHE THE TARGET HANDLE ---
GetTargetMonitorHandle(hMonitor, hDC, pRect, lParam) {
    static currentEnumIndex := 0
    currentEnumIndex++
    if (currentEnumIndex = TargetIndex) {
        hTargetMonitor := hMonitor
        return UpdateMonitor()
    }
    return 1
}

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
        WinGet, processName, ProcessName, ahk_id %this_id%
        if ((Style & 0x10000000) && class != "tooltips_class32")
        {
            if (Blacklist.HasKey(processName))
                continue
            WinGetPos, WX, WY, WW, WH, ahk_id %this_id%
            if (WX+(WW/2) >= mLeft && WX+(WW/2) <= mRight && WY+(WH/2) >= mTop && WY+(WH/2) <= mBottom)
            {
                HasWindow := 1
                if (DebugMode)
                    FoundWindows .= "- " . processName . " (" . Title . ")`n"
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
        if FileExist(brightIconPath)
            Menu, Tray, Icon, %brightIconPath%
    }
    else if (!HasWindow && CurrentState != "Dim") {
        BroadcastBrightness(DimBrightness)
        CurrentState := "Dim"
        if FileExist(dimIconPath)
            Menu, Tray, Icon, %dimIconPath%
    }
}

BroadcastBrightness(Level) {
    global hTargetMonitor
    if (!hTargetMonitor)
        return

    if !DllCall("dxva2\GetNumberOfPhysicalMonitorsFromHMONITOR", "Ptr", hTargetMonitor, "UInt*", numMonitors)
        return

    structSize := A_PtrSize + 256
    VarSetCapacity(PHYSICAL_MONITORS, numMonitors * structSize, 0)

    if DllCall("dxva2\GetPhysicalMonitorsFromHMONITOR", "Ptr", hTargetMonitor, "UInt", numMonitors, "Ptr", &PHYSICAL_MONITORS) {
        Loop, %numMonitors% {
            hPhysicalMonitor := NumGet(PHYSICAL_MONITORS, (A_Index - 1) * structSize, "Ptr")

            DllCall("dxva2\SetMonitorBrightness", "Ptr", hPhysicalMonitor, "UInt", Level)
        }
        DllCall("dxva2\DestroyPhysicalMonitors", "UInt", numMonitors, "Ptr", &PHYSICAL_MONITORS)
    }
}

; --- GUI & TRAY HANDLERS ---
ShowGui:
    IniRead, currentBlacklist, %ConfigFile%, Settings, Blacklist, %A_Space%
    if (currentBlacklist = " " || currentBlacklist = "")
        currentBlacklist := ""
    MonList := ""
    SysGet, MC, MonitorCount
    Loop, %MC% {
        MonList .= "Monitor " . A_Index . "|"
    }

    Gui, Settings:New, +AlwaysOnTop, Monitor Settings
    Gui, Margin, 15, 15

    Gui, Add, Text, xm y+15, Select Target Display Number:
    Gui, Add, DropDownList, vGuiDispNum Choose%TargetDisplayNum% w250, %MonList%

    Gui, Add, Text, y+15, Brightness (Active):
    Gui, Add, Slider, vGuiBright Range0-100 ToolTip gSliderMove w200, %BrightBrightness%
    Gui, Add, Edit, vEditBright x+10 yp-3 w40 Limit3 gEditMove, %BrightBrightness%

    Gui, Add, Text, xm y+15, Brightness (Dim):
    Gui, Add, Slider, vGuiDim Range0-100 ToolTip gSliderMove w200, %DimBrightness%
    Gui, Add, Edit, vEditDim x+10 yp-3 w40 Limit3 gEditMove, %DimBrightness%

    Gui, Add, Checkbox, xm y+15 vGuiDebug Checked%DebugMode%, Enable Debug Tooltip

    Gui, Add, Text, xm y+15, Blacklisted Processes:
    Gui, Add, ListBox, vGuiBlacklist w250 r4, % StrReplace(currentBlacklist, ",", "|")
    Gui, Add, Button, xm y+5 w120 h25 gPickBlacklist, Add (Picker)
    Gui, Add, Button, x+10 yp w120 h25 gRemoveBlacklist, Remove Selected

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
    RegExMatch(GuiDispNum, "\d+", NewDispNum)
    IniWrite, %NewDispNum%, %ConfigFile%, Settings, TargetDisplayNum
    IniWrite, %EditBright%, %ConfigFile%, Settings, BrightBrightness
    IniWrite, %EditDim%, %ConfigFile%, Settings, DimBrightness
    IniWrite, %GuiDebug%, %ConfigFile%, Settings, Debug
    Reload
return

PickBlacklist:
    Gui, Settings:Hide
    Hotkey, LButton, PickerClick, On
    Hotkey, Escape, PickerCancel, On
    SetTimer, PickerTooltip, 50
return

PickerTooltip:
    CoordMode, Mouse, Screen
    CoordMode, ToolTip, Screen
    MouseGetPos, mX, mY
    ToolTip, Click on a window to add it to the Blacklist.`nPress Esc to cancel., % mX + 15, % mY + 15, 2
return

PickerClick:
    Hotkey, LButton, Off
    Hotkey, Escape, Off
    SetTimer, PickerTooltip, Off
    ToolTip, , , , 2
    MouseGetPos, , , clickedWinId
    WinGet, clickedProcess, ProcessName, ahk_id %clickedWinId%
    clickedProcess := StrReplace(clickedProcess, ",", "")
    if (clickedProcess != "") {
        if (!Blacklist.HasKey(clickedProcess)) {
            Blacklist[clickedProcess] := 1
            IniRead, currentBlacklist, %ConfigFile%, Settings, Blacklist, %A_Space%
            if (currentBlacklist == " " || currentBlacklist == "")
                newBlacklist := clickedProcess
            else
                newBlacklist := currentBlacklist . "," . clickedProcess
            IniWrite, %newBlacklist%, %ConfigFile%, Settings, Blacklist
            GuiControl, Settings:, GuiBlacklist, % "|" StrReplace(newBlacklist, ",", "|")
            MsgBox, 64, Blacklist, Added "%clickedProcess%" to the blacklist!
        } else {
            MsgBox, 64, Blacklist, "%clickedProcess%" is already in the blacklist.
        }
    } else {
        MsgBox, 48, Blacklist, No valid window selected.
    }
    Gui, Settings:Show
return

RemoveBlacklist:
    Gui, Settings:Submit, NoHide
    if (GuiBlacklist = "") {
        MsgBox, 48, Blacklist, Please select a process to remove.
        return
    }

    IniRead, currentBlacklist, %ConfigFile%, Settings, Blacklist, %A_Space%
    newBlacklist := ""
    Loop, parse, currentBlacklist, `,
    {
        if (Trim(A_LoopField) != GuiBlacklist) {
            if (newBlacklist = "")
                newBlacklist := Trim(A_LoopField)
            else
                newBlacklist .= "," . Trim(A_LoopField)
        }
    }
    IniWrite, %newBlacklist%, %ConfigFile%, Settings, Blacklist
    Blacklist.Delete(GuiBlacklist)
    GuiControl, Settings:, GuiBlacklist, % "|" StrReplace(newBlacklist, ",", "|")
return

PickerCancel:
    Hotkey, LButton, Off
    Hotkey, Escape, Off
    SetTimer, PickerTooltip, Off
    ToolTip, , , , 2
    Gui, Settings:Show
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