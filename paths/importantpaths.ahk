HyperSleep(ms)
{
	static freq := (DllCall("QueryPerformanceFrequency", "Int64*", &f := 0), f)
	DllCall("QueryPerformanceCounter", "Int64*", &begin := 0)
	current := 0, finish := begin + ms * freq / 1000
	while (current < finish)
	{
		if ((finish - current) > 30000)
		{
			DllCall("Winmm.dll\timeBeginPeriod", "UInt", 1)
			DllCall("Sleep", "UInt", 1)
			DllCall("Winmm.dll\timeEndPeriod", "UInt", 1)
		}
		DllCall("QueryPerformanceCounter", "Int64*", &current)
	}
}
nm_gotoRamp(){
	global FwdKey, RightKey, HiveSlot, state, objective, HiveConfirmed
	HiveConfirmed := 0

	movement :=
	(
	nm_Walk(5, FwdKey) "
	" nm_Walk(9.2*HiveSlot-4, RightKey)
	)

	nm_createWalk(movement)
	KeyWait "F14", "D T5 L"
	KeyWait "F14", "T60 L"
	nm_endWalk()
}
nm_gotoCannon(){
	global LeftKey, RightKey, FwdKey, BackKey, currentWalk, objective, SC_Space, bitmaps

	nm_setShiftLock(0)

	hwnd := GetRobloxHWND()
	offsetY := GetYOffset(hwnd)
	GetRobloxClientPos(hwnd)
	MouseMove windowX+350, windowY+offsetY+100

	success := 0
	Loop 10
	{
		movement :=
		(
		'Send "{' SC_Space ' down}{' RightKey ' down}"
		Sleep 100
		Send "{' SC_Space ' up}"
		Walk(2)
		Send "{' FwdKey ' down}"
		Walk(1.5)
		Send "{' FwdKey ' up}"'
		)
		nm_createWalk(movement)
		KeyWait "F14", "D T5 L"
		DllCall("GetSystemTimeAsFileTime","int64p",&s:=0)
		n := s, f := s+200000000
		while (n < f)
		{
			pBMScreen := Gdip_BitmapFromScreen(windowX+windowWidth//2-200 "|" windowY+offsetY "|400|125")
			if (Gdip_ImageSearch(pBMScreen, bitmaps["redcannon"], , , , , , 2, , 2) = 1)
			{
				success := 1, Gdip_DisposeImage(pBMScreen)
				break
			}
			Gdip_DisposeImage(pBMScreen)
			DllCall("GetSystemTimeAsFileTime","int64p",&n)
		}
		nm_endWalk()

		if (success = 1) ; check that cannon was not overrun, at the expense of a small delay
		{
			Loop 10
			{
				if (A_Index = 10)
				{
					success := 0
					break
				}
				Sleep 500
				pBMScreen := Gdip_BitmapFromScreen(windowX+windowWidth//2-200 "|" windowY+offsetY "|400|125")
				if (Gdip_ImageSearch(pBMScreen, bitmaps["redcannon"], , , , , , 2, , 2) = 1)
				{
					Gdip_DisposeImage(pBMScreen)
					break 2
				}
				else
				{
					movement := nm_Walk(1.5, LeftKey)
					nm_createWalk(movement)
					KeyWait "F14", "D T5 L"
					KeyWait "F14", "T5 L"
					nm_endWalk()
				}
				Gdip_DisposeImage(pBMScreen)
			}
		}

		if (success = 0)
		{
			obj := objective
			nm_Reset()
			nm_setStatus("Traveling", obj)
			nm_gotoRamp()
		}
	}
	if (success = 0) { ;game frozen close roblox
		nm_setStatus("Detected", "Roblox Game Frozen, Restarting")
		CloseRoblox()
	}
}
nm_setShiftLock(state, *){
	global bitmaps, SC_LShift, ShiftLockEnabled

	if !(hwnd := WinExist("Roblox ahk_exe RobloxPlayerBeta.exe")) ; Shift Lock is not supported on UWP app at the moment
		return

	ActivateRoblox()
	GetRobloxClientPos(hwnd)

	pBMScreen := Gdip_BitmapFromScreen(windowX+5 "|" windowY+windowHeight-54 "|50|50")

	switch (v := Gdip_ImageSearch(pBMScreen, bitmaps["shiftlock"], , , , , , 2))
	{
		; shift lock enabled - disable if needed
		case 1:
		if (state = 0)
		{
			send "{" SC_LShift "}"
			result := 0
		}
		else
			result := 1

		; shift lock disabled - enable if needed
		case 0:
		if (state = 1)
		{
			send "{" SC_LShift "}"
			result := 1
		}
		else
			result := 0
	}
nm_Reset(checkAll:=1, wait:=2000, convert:=1, force:=0){
	global resetTime, youDied, VBState, KeyDelay, SC_E, SC_Esc, SC_R, SC_Enter, RotRight, RotLeft, RotUp, RotDown, ZoomOut, objective, AFBrollingDice, AFBuseGlitter, AFBuseBooster, currentField, HiveConfirmed, GameFrozenCounter, MultiReset, bitmaps
	static hivedown := 0
	;check for game frozen conditions
	if (GameFrozenCounter>=3) { ;3 strikes
		nm_setStatus("Detected", "Roblox Game Frozen, Restarting")
		CloseRoblox()
		GameFrozenCounter:=0
	}
	DisconnectCheck()
	nm_setShiftLock(0)
	nm_OpenMenu()
	if(youDied && not instr(objective, "mondo") && VBState=0){
		wait:=max(wait, 20000)
	}
	;mondo or coconut crab likely killed you here! skip over this field if possible
	if(youDied && (currentField="mountain top" || currentField="coconut"))
		nm_currentFieldDown()
	youDied:=0
	nm_AutoFieldBoost(currentField)
	;checkAll bypass to avoid infinite recursion here
	if(checkAll=1) {
		nm_fieldBoostBooster()
		nm_locateVB()
	}
	if(force=1) {
		HiveConfirmed:=0
	}
	while (!HiveConfirmed) {
		;failsafe game frozen
		if(Mod(A_Index, 10) = 0) {
			nm_setStatus("Closing", "and Re-Open Roblox")
			CloseRoblox()
			DisconnectCheck()
			continue
		}
		DisconnectCheck()
		ActivateRoblox()
		nm_setShiftLock(0)
		nm_OpenMenu()

		hwnd := GetRobloxHWND()
		offsetY := GetYOffset(hwnd)
		;check that performance stats is disabled
		GetRobloxClientPos(hwnd)
		pBMScreen := Gdip_BitmapFromScreen(windowX "|" windowY+offsetY+36 "|" windowWidth "|24")
		if ((Gdip_ImageSearch(pBMScreen, bitmaps["perfmem"], &pos, , , , , 2, , 5) = 1)
		&& (Gdip_ImageSearch(pBMScreen, bitmaps["perfwhitefill"], , x := SubStr(pos, 1, (comma := InStr(pos, ",")) - 1), y := SubStr(pos, comma + 1), x + 17, y + 7, 2) = 0)) {
			if ((Gdip_ImageSearch(pBMScreen, bitmaps["perfcpu"], &pos, x + 17, y, , y + 7, 2) = 1)
			&& (Gdip_ImageSearch(pBMScreen, bitmaps["perfwhitefill"], , x := SubStr(pos, 1, (comma := InStr(pos, ",")) - 1), y := SubStr(pos, comma + 1), x + 17, y + 7, 2) = 0)) {
				if ((Gdip_ImageSearch(pBMScreen, bitmaps["perfgpu"], &pos, x + 17, y, , y + 7, 2) = 1)
				&& (Gdip_ImageSearch(pBMScreen, bitmaps["perfwhitefill"], , x := SubStr(pos, 1, (comma := InStr(pos, ",")) - 1), y := SubStr(pos, comma + 1), x + 17, y + 7, 2) = 0)) {
					Send "^{F7}"
				}
			}
		}
		Gdip_DisposeImage(pBMScreen)
		;check to make sure you are not in dialog before reset
		Loop 500
		{
			GetRobloxClientPos(hwnd)
			pBMScreen := Gdip_BitmapFromScreen(windowX+windowWidth//2-50 "|" windowY+2*windowHeight//3 "|100|" windowHeight//3)
			if (Gdip_ImageSearch(pBMScreen, bitmaps["dialog"], &pos, , , , , 10, , 3) != 1) {
				Gdip_DisposeImage(pBMScreen)
				break
			}
			Gdip_DisposeImage(pBMScreen)
			MouseMove windowX+windowWidth//2, windowY+2*windowHeight//3+SubStr(pos, InStr(pos, ",")+1)-15
			Click
			Sleep 150
		}
		MouseMove windowX+350, windowY+offsetY+100
		;check to make sure you are not in a yes/no prompt
		GetRobloxClientPos(hwnd)
		pBMScreen := Gdip_BitmapFromScreen(windowX+windowWidth//2-250 "|" windowY+windowHeight//2-52 "|500|150")
		if (Gdip_ImageSearch(pBMScreen, bitmaps["no"], &pos, , , , , 2, , 3) = 1) {
			MouseMove windowX+windowWidth//2-250+SubStr(pos, 1, InStr(pos, ",")-1), windowY+windowHeight//2-52+SubStr(pos, InStr(pos, ",")+1)
			Click
			MouseMove windowX+350, windowY+offsetY+100
		}
		Gdip_DisposeImage(pBMScreen)
		;check to make sure you are not in feed window on accident
		imgPos := nm_imgSearch("cancel.png",30)
		If (imgPos[1] = 0){
			MouseMove windowX+(imgPos[2]), windowY+(imgPos[3])
			Click
			MouseMove windowX+350, windowY+offsetY+100
		}
		;check to make sure you are not in blender screen
		BlenderSS := Gdip_BitmapFromScreen(windowX+windowWidth//2 - 275 "|" windowY+Floor(0.48*windowHeight) - 220 "|550|400")
		if (Gdip_ImageSearch(BlenderSS, bitmaps["CloseGUI"], , , , , , 5) > 0) {
			MouseMove windowX+windowWidth//2 - 250, windowY+Floor(0.48*windowHeight) - 200
			Sleep 150
			click
		}
		Gdip_DisposeImage(BlenderSS)
		;check to make sure you are not in sticker screen
		pBMScreen := Gdip_BitmapFromScreen(windowX+windowWidth//2 - 275 "|" windowY+4*windowHeight//10-178 "|56|56")
		if (Gdip_ImageSearch(pBMScreen, bitmaps["CloseGUI"], , , , , , 5) > 0) {
			MouseMove windowX+windowWidth//2 - 250, windowY+4*windowHeight//10 - 150
			sleep 150
			click
		}
		Gdip_DisposeImage(pBMScreen)
		;check to make sure you are not in shop before reset
		searchRet := nm_imgSearch("e_button.png",30,"high")
		If (searchRet[1] = 0) {
			loop 2 {
				shopG := nm_imgSearch("shop_corner_G.png",30,"right")
				shopR := nm_imgSearch("shop_corner_R.png",30,"right")
				If (shopG[1] = 0 || shopR[1] = 0) {
					sendinput "{" SC_E " down}"
					Sleep 100
					sendinput "{" SC_E " up}"
					Sleep 1000
				}
			}
		}
		;check to make sure there is not a window open
		searchRet := nm_imgSearch("close.png",30,"full")
		If (searchRet[1] = 0) {
			MouseMove windowX+searchRet[2],windowY+searchRet[3]
			click
			MouseMove windowX+350, windowY+offsetY+100
			Sleep 1000
		}
		;check to make sure there is no Memory Match
		nm_SolveMemoryMatch()

		nm_setStatus("Resetting", "Character " . Mod(A_Index, 10))
		MouseMove windowX+350, windowY+offsetY+100
		PrevKeyDelay:=A_KeyDelay
		SetKeyDelay 250+KeyDelay
		Loop (VBState = 0) ? (1 + MultiReset + (GatherDoubleReset && (CheckAll=2))) : 1
		{
			resetTime:=nowUnix()
			PostSubmacroMessage("background", 0x5554, 1, resetTime)
			;reset
			ActivateRoblox()
			GetRobloxClientPos()
			send "{" SC_Esc "}{" SC_R "}{" SC_Enter "}"
			n := 0
			while ((n < 2) && (A_Index <= 80))
			{
				Sleep 100
				pBMScreen := Gdip_BitmapFromScreen(windowX "|" windowY "|" windowWidth "|50")
				n += (Gdip_ImageSearch(pBMScreen, bitmaps["emptyhealth"], , , , , , 10) = (n = 0))
				Gdip_DisposeImage(pBMScreen)
			}
			Sleep 1000
		}
		SetKeyDelay PrevKeyDelay

		; hive check
		if hivedown
			sendinput "{" RotDown "}"
		region := windowX "|" windowY+3*windowHeight//4 "|" windowWidth "|" windowHeight//4
		sconf := windowWidth**2//3200
		loop 4 {
			sleep 250+KeyDelay
			pBMScreen := Gdip_BitmapFromScreen(region), s := 0
			for i, k in bitmaps["hive"] {
				s := Max(s, Gdip_ImageSearch(pBMScreen, k, , , , , , 4, , , sconf))
				if (s >= sconf) {
					Gdip_DisposeImage(pBMScreen)
					HiveConfirmed := 1
					sendinput "{" RotRight " 4}" (hivedown ? ("{" RotUp "}") : "")
					Send "{" ZoomOut " 5}"
					break 2
				}
			}
			Gdip_DisposeImage(pBMScreen)
			sendinput "{" RotRight " 4}" ((A_Index = 2) ? ("{" ((hivedown := !hivedown) ? RotDown : RotUp) "}") : "")
		}
	}
	;convert
	(convert=1) && nm_convert()
	;ensure minimum delay has been met
	if((nowUnix()-resetTime)<wait) {
		remaining:=floor((wait-(nowUnix()-resetTime))/1000) ;seconds
		if(remaining>5){
			Sleep 1000
			nm_setStatus("Waiting", remaining . " Seconds")
			Sleep (remaining-1)*1000
		}
		else {
			Sleep (remaining*1000) ;miliseconds
		}
	}
}