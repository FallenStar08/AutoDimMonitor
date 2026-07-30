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
    IniWrite, 1, %ConfigFile%, Settings, TargetMonitors
    IniWrite, 5, %ConfigFile%, Settings, DimBrightness
    IniWrite, 80, %ConfigFile%, Settings, BrightBrightness
    IniWrite, 0, %ConfigFile%, Settings, Debug
    IniWrite, Rainmeter.exe, %ConfigFile%, Settings, Blacklist
}

IniRead, LegacyTargetDisplayNum, %ConfigFile%, Settings, TargetDisplayNum, 1
IniRead, TargetMonitorsRaw, %ConfigFile%, Settings, TargetMonitors, %LegacyTargetDisplayNum%
IniRead, DimBrightness, %ConfigFile%, Settings, DimBrightness, 5
IniRead, BrightBrightness, %ConfigFile%, Settings, BrightBrightness, 80
IniRead, DebugMode, %ConfigFile%, Settings, Debug, 0
IniRead, BlacklistRaw, %ConfigFile%, Settings, Blacklist, %A_Space%

Global Blacklist := {}
Loop, parse, BlacklistRaw, `,
{
    proc := Trim(A_LoopField)
    if (proc != "")
        Blacklist[proc] := 1
}

Global TargetMonitors := {}
Loop, parse, TargetMonitorsRaw, `,
{
    monNum := Trim(A_LoopField)
    if (monNum != "")
        TargetMonitors[monNum] := 1
}

Global MonHandles := []
Global CurrentStates := {}

InitMonitors()

DllCall("SetWinEventHook", "UInt", 0x800B, "UInt", 0x800B, "Ptr", 0, "Ptr", RegisterCallback("EventTimer"), "UInt", 0, "UInt", 0, "UInt", 0)
DllCall("SetWinEventHook", "UInt", 0x0001, "UInt", 0x0002, "Ptr", 0, "Ptr", RegisterCallback("EventTimer"), "UInt", 0, "UInt", 0, "UInt", 0)

OnMessage(0x218, "WM_POWERBROADCAST")

UpdateMonitor()
return

WM_POWERBROADCAST(wParam, lParam) {
    if (wParam = 0x0012) { ; PBT_APMRESUMEAUTOMATIC
        Sleep, 1500
        Reload
    }
    return 1
}

; --- MONITOR ENUMERATION ---
InitMonitors() {
    Global MonHandles
    MonHandles := []
    DllCall("User32\EnumDisplayMonitors", "Ptr", 0, "Ptr", 0, "Ptr", RegisterCallback("EnumMonitorsCallback", "F"), "Ptr", 0)
}

EnumMonitorsCallback(hMonitor, hDC, pRect, lParam) {
    Global MonHandles
    MonHandles.Push(hMonitor)
    return 1
}

; --- CORE LOGIC ---
EventTimer() {
    SetTimer, UpdateMonitor, -100
}

UpdateMonitor() {
    Global Blacklist, TargetMonitors, MonHandles, CurrentStates, DebugMode, BrightBrightness, DimBrightness, brightIconPath, dimIconPath

    SysGet, TotalMonCount, MonitorCount
    if (MonHandles.Length() != TotalMonCount)
        InitMonitors()

    MonHasWindow := {}
    Loop, %TotalMonCount% {
        if (TargetMonitors.HasKey(A_Index))
            MonHasWindow[A_Index] := 0
    }

    FoundWindowsDebug := ""
    WinGet, idList, List
    Loop, %idList%
    {
        this_id := idList%A_Index%
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
            midX := WX + (WW / 2)
            midY := WY + (WH / 2)

            Loop, %TotalMonCount% {
                monIdx := A_Index
                if (!TargetMonitors.HasKey(monIdx))
                    continue

                SysGet, Mon, Monitor, %monIdx%
                if (midX >= MonLeft && midX <= MonRight && midY >= MonTop && midY <= MonBottom)
                {
                    MonHasWindow[monIdx] := 1
                    if (DebugMode)
                        FoundWindowsDebug .= "Mon " monIdx ": " processName " (" Title ")`n"
                }
            }
        }
    }

    AnyBright := 0
    Loop, %TotalMonCount% {
        monIdx := A_Index
        if (!TargetMonitors.HasKey(monIdx))
            continue

        hasWin := MonHasWindow[monIdx]
        prevState := CurrentStates[monIdx]
        newState := hasWin ? "Bright" : "Dim"

        if (hasWin)
            AnyBright := 1

        if (newState != prevState) {
            targetLevel := hasWin ? BrightBrightness : DimBrightness
            SetMonitorBrightnessByIdx(monIdx, targetLevel)
            CurrentStates[monIdx] := newState
        }
    }

    if (DebugMode) {
        monListStr := JoinKeys(TargetMonitors, ",")
        ToolTip, % "TARGET MONITORS: " monListStr "`nState: " (AnyBright ? "BRIGHT" : "DIM") "`nWindows:`n" (FoundWindowsDebug ? FoundWindowsDebug : "None"), 0, 0
    } else {
        ToolTip
    }

    if (AnyBright) {
        if FileExist(brightIconPath)
            Menu, Tray, Icon, %brightIconPath%
    } else {
        if FileExist(dimIconPath)
            Menu, Tray, Icon, %dimIconPath%
    }
}

SetMonitorBrightnessByIdx(monIdx, Level) {
    Global MonHandles
    hMon := MonHandles[monIdx]
    if (!hMon)
        return

    if !DllCall("dxva2\GetNumberOfPhysicalMonitorsFromHMONITOR", "Ptr", hMon, "UInt*", numMonitors)
        return

    structSize := A_PtrSize + 256
    VarSetCapacity(PHYSICAL_MONITORS, numMonitors * structSize, 0)

    if DllCall("dxva2\GetPhysicalMonitorsFromHMONITOR", "Ptr", hMon, "UInt", numMonitors, "Ptr", &PHYSICAL_MONITORS) {
        Loop, %numMonitors% {
            hPhysicalMonitor := NumGet(PHYSICAL_MONITORS, (A_Index - 1) * structSize, "Ptr")
            DllCall("dxva2\SetMonitorBrightness", "Ptr", hPhysicalMonitor, "UInt", Level)
        }
        DllCall("dxva2\DestroyPhysicalMonitors", "UInt", numMonitors, "Ptr", &PHYSICAL_MONITORS)
    }
}

JoinKeys(obj, delim := ",") {
    str := ""
    for k, v in obj {
        if (str != "")
            str .= delim
        str .= k
    }
    return str
}

; --- GUI & TRAY HANDLERS ---
ShowGui:
    IniRead, currentBlacklist, %ConfigFile%, Settings, Blacklist, %A_Space%
    if (currentBlacklist = " " || currentBlacklist = "")
        currentBlacklist := ""

    SysGet, MC, MonitorCount

    Gui, Settings:New, +AlwaysOnTop, Monitor Settings
    Gui, Margin, 15, 15

    Gui, Add, Text, xm y+10, Target Display(s):
    Loop, %MC% {
        chkVal := TargetMonitors.HasKey(A_Index) ? 1 : 0
        if (A_Index == 1)
            Gui, Add, Checkbox, vGuiMon_%A_Index% Checked%chkVal% xm y+5, Monitor %A_Index%
        else
            Gui, Add, Checkbox, vGuiMon_%A_Index% Checked%chkVal% x+15 yp, Monitor %A_Index%
    }

    Gui, Add, Text, xm y+15, Brightness (Active):
    Gui, Add, Slider, vGuiBright Range0-100 ToolTip gSliderMove w200, %BrightBrightness%
    Gui, Add, Edit, vEditBright x+10 yp-3 w40 Limit3 gEditMove, %BrightBrightness%

    Gui, Add, Text, xm y+15, Brightness (Dim):
    Gui, Add, Slider, vGuiDim Range0-100 ToolTip gSliderMove w200, %DimBrightness%
    Gui, Add, Edit, vEditDim x+10 yp-3 w40 Limit3 gEditMove, %DimBrightness%

    Gui, Add, Checkbox, xm y+15 vGuiDebug Checked%DebugMode%, Enable Debug Tooltip

    Gui, Add, Text, xm y+15, Blacklisted Processes:
    Gui, Add, ListBox, vGuiBlacklist w260 r4, % StrReplace(currentBlacklist, ",", "|")
    Gui, Add, Button, xm y+5 w125 h25 gShowRunningAppsPicker, From Running Apps
    Gui, Add, Button, x+10 yp w125 h25 gPickBlacklist, Click Window Picker
    Gui, Add, Button, xm y+5 w260 h25 gRemoveBlacklist, Remove Selected

    Gui, Add, Button, xm y+20 Default gSaveSettings w125 h30, Save
    Gui, Add, Button, x+10 yp w125 h30 gGuiClose, Cancel
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
    SysGet, MC, MonitorCount
    SelectedMons := ""
    Loop, %MC% {
        if (GuiMon_%A_Index%) {
            if (SelectedMons != "")
                SelectedMons .= ","
            SelectedMons .= A_Index
        }
    }
    if (SelectedMons == "")
        SelectedMons := "1"

    RegExMatch(SelectedMons, "^\d+", FirstMon)
    IniWrite, %FirstMon%, %ConfigFile%, Settings, TargetDisplayNum
    IniWrite, %SelectedMons%, %ConfigFile%, Settings, TargetMonitors
    IniWrite, %EditBright%, %ConfigFile%, Settings, BrightBrightness
    IniWrite, %EditDim%, %ConfigFile%, Settings, DimBrightness
    IniWrite, %GuiDebug%, %ConfigFile%, Settings, Debug
    Reload
return

; --- RUNNING APPS PICKER DIALOG ---
ShowRunningAppsPicker:
    Gui, AppPicker:New, +AlwaysOnTop +OwnerSettings, Select Running Application
    Gui, Margin, 10, 10
    Gui, Add, Text,, Select an app to add to the exclusion list:
    Gui, Add, ListView, vAppLV w360 r10 gAppLVSelect, Process Name|Window Title

    WinGet, winList, List
    ProcessMap := {}
    Loop, %winList% {
        wId := winList%A_Index%
        WinGetTitle, wTitle, ahk_id %wId%
        WinGet, wStyle, Style, ahk_id %wId%
        WinGetClass, wClass, ahk_id %wId%
        WinGet, pName, ProcessName, ahk_id %wId%

        if (wTitle != "" && (wStyle & 0x10000000) && wClass != "tooltips_class32" && pName != "") {
            if (!ProcessMap.HasKey(pName)) {
                ProcessMap[pName] := wTitle
                LV_Add("", pName, wTitle)
            }
        }
    }
    LV_ModifyCol(1, 140)
    LV_ModifyCol(2, 200)

    Gui, Add, Button, gAddSelectedApp w110 h28 Default, Add Selected
    Gui, Add, Button, x+10 yp gAppPickerClose w110 h28, Cancel
    Gui, Show
return

AppLVSelect:
    if (A_GuiEvent == "DoubleClick")
        gosub, AddSelectedApp
return

AddSelectedApp:
    Gui, AppPicker:Default
    Row := LV_GetNext(0)
    if (!Row) {
        MsgBox, 48, Blacklist, Please select an application from the list.
        return
    }
    LV_GetText(selectedProc, Row, 1)
    Gui, AppPicker:Destroy
    AddProcessToBlacklist(selectedProc)
return

AppPickerGuiClose:
AppPickerClose:
    Gui, AppPicker:Destroy
return

; --- CLICK PICKER ---
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
    if (clickedProcess != "") {
        AddProcessToBlacklist(clickedProcess)
    } else {
        MsgBox, 48, Blacklist, No valid window selected.
    }
    Gui, Settings:Show
return

PickerCancel:
    Hotkey, LButton, Off
    Hotkey, Escape, Off
    SetTimer, PickerTooltip, Off
    ToolTip, , , , 2
    Gui, Settings:Show
return

AddProcessToBlacklist(procName) {
    Global ConfigFile, Blacklist
    procName := Trim(StrReplace(procName, ",", ""))
    if (procName = "")
        return

    if (!Blacklist.HasKey(procName)) {
        Blacklist[procName] := 1
        IniRead, currentBlacklist, %ConfigFile%, Settings, Blacklist, %A_Space%
        currentBlacklist := Trim(currentBlacklist)
        if (currentBlacklist == "" || currentBlacklist == " ")
            newBlacklist := procName
        else
            newBlacklist := currentBlacklist . "," . procName
        IniWrite, %newBlacklist%, %ConfigFile%, Settings, Blacklist
        GuiControl, Settings:, GuiBlacklist, % "|" StrReplace(newBlacklist, ",", "|")
        MsgBox, 64, Blacklist, Added "%procName%" to the blacklist!
    } else {
        MsgBox, 64, Blacklist, "%procName%" is already in the blacklist.
    }
}

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
        t := Trim(A_LoopField)
        if (t != GuiBlacklist && t != "") {
            if (newBlacklist = "")
                newBlacklist := t
            else
                newBlacklist .= "," . t
        }
    }
    IniWrite, %newBlacklist%, %ConfigFile%, Settings, Blacklist
    Blacklist.Delete(GuiBlacklist)
    GuiControl, Settings:, GuiBlacklist, % "|" StrReplace(newBlacklist, ",", "|")
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