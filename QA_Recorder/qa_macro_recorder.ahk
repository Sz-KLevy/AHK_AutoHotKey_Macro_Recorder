#Requires AutoHotkey v2.0
#SingleInstance Force	;Allows only one running instance


/*-----------------------------------------------Code---------------------------*/
/*--------------------------------------Variables, options and such--------------------------*/
Version := "0.2"

class Setting{
	RecordStartKey := "F1"
	RecordEndKey := "F1"	; A fake hotkey, from the user perspective, it works as one
	PlayStartKey := "F2"
	PlayStopKey := "F3"
	MousePositionMode := "Screen"

	RecordMouse := 1
	RecordKeyboard := 1

	MouseRecordingFrequency := 2000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
}
DefaultSetting := Setting()

class State{
	static IsRecording := false
	static IsPlaying := false
	static KeysDown := Map()	; Used to prevent keyspamming
}

class DataLog{
	RecordLog :=[]	;Time: ,Type:(key), Key:, State:(up/down)
	MouseRecordLog :=[]	;Time: ,Type:(key/mouse_position), Key/x:, State/y:


	/*------------------Record handlers--------------------------*/
	/*Merging the logs, so it can be handled simultaniously*/
	MergeLogs(){	; The used logs are time-sorted
		CombinedLog :=[]

		i := 1
		j := 1
		lenRecord := this.RecordLog.Length
		lenMouse := this.MouseRecordLog.Length

		while (i <= lenRecord && j <= lenMouse) {
			if (this.RecordLog[i].Time <= this.MouseRecordLog[j].Time) {
				CombinedLog.Push(this.RecordLog[i])
				i++
			} else {
				CombinedLog.Push(this.MouseRecordLog[j])
				j++
			}
		}

		while (i <= lenRecord){
			CombinedLog.Push(this.RecordLog[i])
			i++
		}
		while (j <= lenMouse){
			CombinedLog.Push(this.MouseRecordLog[j])
			j++
		}

		return CombinedLog
		;return this.SetTick(CombinedLog, 10)
	}

	PushableEntryMaker(ArrayEntry){
		PushableEntry := {}
			for index, value in ArrayEntry{
				ArrayEntry[index] := StrSplit(ArrayEntry[index], ':')	; Works, because ':' recorded as {shift} and '.'. In the very specific case where there is ':' key, there will be error.
				Property := ArrayEntry[index][1]
				Value := ArrayEntry[index][2]

				switch Property{
				case "Time": PushableEntry.Time := Value
				case "Type": PushableEntry.Type := Value
				case "Key": PushableEntry.Key := Value
				case "State": PushableEntry.State := Value
				case "x": PushableEntry.x := Value
				case "y": PushableEntry.y := Value
				}
			}
		return PushableEntry
	}

	Simplify(CombinedLog){
		SimplifiedLog := []

		first := -1
		last_pos:={x:-1, y:-1, index:-1}

		for index, entry in CombinedLog{
			if(entry.Type = "key"){
				try{
					if(!(CombinedLog[index-1].Type = "key")){
						if(!(last_pos.index != first && last_pos.x = CombinedLog[first].x && last_pos.y = CombinedLog[first].y)){
							SimplifiedLog.push(CombinedLog[first])
							last_pos.x := CombinedLog[first].x
							last_pos.y := CombinedLog[first].y
							last_pos.index := first
						}
						if(!(last_pos.x = CombinedLog[index-1].x && last_pos.y = CombinedLog[index-1].y)){
							SimplifiedLog.push(CombinedLog[index-1])
							last_pos.x := CombinedLog[index-1].x
							last_pos.y := CombinedLog[index-1].y
							last_pos.index := index-1
						}
						first := -1
					}
				}
				SimplifiedLog.push(CombinedLog[index])
			}
			else if(index = CombinedLog.length){
				try{
					if(!(last_pos.index != first && last_pos.x = CombinedLog[first].x && last_pos.y = CombinedLog[first].y)){
						SimplifiedLog.push(CombinedLog[first])
						last_pos.x := CombinedLog[first].x
						last_pos.y := CombinedLog[first].y
						last_pos.index := first
					}
					if(!(last_pos.x = CombinedLog[index].x && last_pos.y = CombinedLog[index].y)){
						SimplifiedLog.push(CombinedLog[index])
						last_pos.x := CombinedLog[index].x
						last_pos.y := CombinedLog[index].y
						last_pos.index := index
					}
				}
				catch{
					SimplifiedLog.push(CombinedLog[index])
				}
			}
			else{
				if(first = -1){
					first := index
				}
				if(last_pos.index=-1){
					last_pos.x := CombinedLog[index].x
					last_pos.y := CombinedLog[index].y
					last_pos.index := index
				}
			}
		}

		return SimplifiedLog
	}
	SetTick(CombinedLog, tick){
		for index, entry in CombinedLog{
			if(Mod(entry.Time, tick) < tick/2){
				CombinedLog[index].Time := entry.Time-Mod(entry.Time, tick)
			}
			else{
				CombinedLog[index].Time := entry.Time+(tick-Mod(entry.Time, tick))
			}
		}
		return CombinedLog
	}

	CombineSameTimeMouse(CombinedLog){
		CombinedLog2 := []
		i := 0
		for index, entry in CombinedLog{
			if(entry.Type = "mouse_position"){
				if(i=0){
					CombinedLog2.push(entry)
					i := CombinedLog2.Length
				}
				else{
					if(entry.Time = CombinedLog2[i].Time){
						CombinedLog2[i].x := CombinedLog2[i].x+entry.x
						CombinedLog2[i].y := CombinedLog2[i].y+entry.y
					}
					else{
						CombinedLog2.push(entry)
						i := CombinedLog2.Length
					}
				}
			}
			else{
				CombinedLog2.push(entry)
			}
		}
		return CombinedLog2
	}
}

CurrentLog := DataLog()
CurrentSetting := DefaultSetting

Controls.Setup()
/*-----------------------------------------------GUI--------------------------------------------------------------*/
class AppGUI{

	static BuildAll(){
		AppGUI.Main.Build()
		AppGUI.Options.Build()
		AppGUI.Save.Build()
		AppGUI.Credits.Build()
	}

	class Main{
		static Window := ""
		static CurrentStatusText := ""

		static Build(){
			this.Window := Gui("", "Macro Recorder", this)	; Assigning AppGUI.Main as an event handler
			this.Window.SetFont("s10")
			
			
			width := "w100"
			height := " h40"
			RecordStartButton := this.Window.AddButton("w50" height " X0" , "Start Recording")
			RecordEndButton := this.Window.AddButton("w50" height " X+" , "Stop Recording")
			PlayButton := this.Window.AddButton(width height " X+", "Play")
			SaveButton := this.Window.AddButton(width height " X+", "Save")
			LoadButton := this.Window.AddButton(width height " X+", "Load Complex")
			this.CurrentStatusText := this.Window.AddText("w400 h40 XM X0 Center", "Status: Idle")

			width := "w" 400//3
			EditButton := this.Window.AddButton(width height " XM X0 Y+150", "Edit")
			OptionsButton := this.Window.AddButton(width height " X+", "Options")	
			CreditsButton := this.Window.AddButton(width height " X+", "Credits")		


			RecordStartButton.OnEvent("Click", "ButtonStartRecord")
			RecordEndButton.OnEvent("Click", "ButtonEndRecord")
			PlayButton.OnEvent("Click", "ButtonPlay")
			SaveButton.OnEvent("Click", "ButtonSave")
			LoadButton.OnEvent("Click", "ButtonLoad")
			
			EditButton.OnEvent("Click", "ButtonEdit")
			OptionsButton.OnEvent("Click", "ButtonOptions")
			CreditsButton.OnEvent("Click", "ButtonCredits")
		}


		static Show(){
			this.Window.Show("Center w400 h300")
			
		}

		static Hide(){
			this.Window.Hide()
		}

/*---------------------------------------------------Functionality-----------------------*/
		static ButtonStartRecord(*){
			Controls.Record.Start()
		}

		static ButtonEndRecord(*){
			Controls.Record.Stop()
		}


		static ButtonPlay(*){
			Controls.Play()
		}

		static ButtonSave(*){
			AppGUI.Save.Show()
		}
		static ButtonLoad(*){
			Controls.Load()
		}

		static ButtonEdit(*){
			MsgBox "Not implemented yet","",262144
		}

		static ButtonOptions(*){
			AppGUI.Options.Show()
		}

		static ButtonCredits(*){
			AppGUI.Credits.Show()
		}

		static UpdateStatus(CurrentState){

			if(CurrentState.IsRecording){
				this.CurrentStatusText.Text := "Status: Recording"
			}
			else if(CurrentState.IsPlaying){
				this.CurrentStatusText.Text := "Status: Playing"
			}
			else{
				this.CurrentStatusText.Text := "Status: Idle"
			}
		}
	}

	class Options{
		static Window := ""
		static Settings := Map()

		static Build(){
			global CurrentSetting
			this.Window := Gui("+AlwaysOnTop", "Macro Recorder Options", this)	; Assigning AppGUI.Options as an event handler
			this.Window.SetFont("s10")

			this.Window.AddText("Section w120", "Record Start Hotkey:")
			this.Settings["RecordStart"] := this.Window.AddEdit("w120")

			this.Window.AddText("w120", "Record End Hotkey:")
			this.Settings["RecordEnd"] := this.Window.AddEdit("w120")

			this.Window.AddText("w120", "Play Hotkey:")
			this.Settings["Play"] := this.Window.AddEdit("w120")

			this.Window.AddText("w120", "MouseMode:")
			this.Settings["MouseMode"] := this.Window.AddDropDownList("w120", ["Screen", "Window", "Client"])

			this.Window.AddText("Section w120 xs+240 ys", "Record mouse")
			this.Settings["RecordMouse"] := this.Window.AddCheckbox("x+-25")

			this.Window.AddText("w120 xs", "Record keyboard")
			this.Settings["RecordKeyboard"] := this.Window.AddCheckbox("x+-10")

			UpdateSettingsButton := this.Window.AddButton("w120 xs-120 ys+245", "Update settings")
			UpdateSettingsButton.OnEvent("Click", "UpdateSettings")
		}

		static UpdateMenu(){
			global CurrentSetting
			this.Settings["RecordStart"].Text := CurrentSetting.RecordStartKey
			this.Settings["RecordEnd"].Text := CurrentSetting.RecordEndKey
			this.Settings["Play"].Text := CurrentSetting.PlayStartKey
			this.Settings["MouseMode"].Text := CurrentSetting.MousePositionMode
			this.Settings["RecordMouse"].Value := CurrentSetting.RecordMouse
			this.Settings["RecordKeyboard"].Value := CurrentSetting.RecordKeyboard
		}

		static Show(){
			this.UpdateMenu()
			this.Window.Show("Center w400 h300")
			
		}

		static Hide(){
			this.Window.Hide()
		}

		static UpdateSettings(*){
			global CurrentSetting
			
			if(State.IsRecording or State.IsPlaying){
				return
			}


			; Deleting previous hotkeys
			HotkeyManager.RemoveHotkey(CurrentSetting.RecordStartKey)
			HotkeyManager.RemoveHotkey(CurrentSetting.PlayStartKey)
			HotkeyManager.RemoveHotkey(CurrentSetting.RecordEndKey)

			; Installing new hotkeys
			Try{
				HotkeyManager.Add(AppGUI.Options.Settings["RecordEnd"].Text, Controls.Record.Stop.Bind(Controls.Record))
			}
			Catch{
				MsgBox "Failed to change Record End Hotkey","Error",262144
				HotkeyManager.Add(AppGUI.Options.Settings["RecordEnd"].Text, Controls.Record.Stop.Bind(Controls.Record))
			}
			Else{
				CurrentSetting.RecordEndKey := AppGUI.Options.Settings["RecordEnd"].Text
			}

			Try{
				HotkeyManager.Add(AppGUI.Options.Settings["RecordStart"].Text, Controls.Record.Start.Bind(Controls.Record))
			}
			Catch{
				MsgBox "Failed to change Record Start Hotkey","Error",262144
				HotkeyManager.Add(CurrentSetting.RecordStartKey, Controls.Record.Start.Bind(Controls.Record))
			}
			Else{
				CurrentSetting.RecordStartKey := AppGUI.Options.Settings["RecordStart"].Text
			}

			Try{
				HotkeyManager.Add(AppGUI.Options.Settings["Play"].Text, Controls.Play.Bind(Controls))
			}
			Catch{
				MsgBox "Failed to change Play Start Key","Error",262144
				HotkeyManager.Add(CurrentSetting.PlayStartKey, Controls.Play.Bind(Controls))
			}
			Else{
				CurrentSetting.PlayStartKey := AppGUI.Options.Settings["Play"].Text
			}

			; Updating settings
			CurrentSetting.MousePositionMode := AppGUI.Options.Settings["MouseMode"].Text
			CurrentSetting.RecordMouse := AppGUI.Options.Settings["RecordMouse"].Value
			CurrentSetting.RecordKeyboard := AppGUI.Options.Settings["RecordKeyboard"].Value

			this.UpdateMenu()
		}
	}
	class Save{
		static Window := ""

		static Build(){
			global CurrentSetting
			this.Window := Gui("+AlwaysOnTop", "Macro Recorder Options", this)	; Assigning AppGUI.Options as an event handler
			this.Window.SetFont("s10")
			SaveComplexButton := this.Window.AddButton(10 10 " X+", "Save Complex")
			SaveSimpleButton := this.Window.AddButton(10 10 " X+", "Save Simple")
			SaveComplexButton.OnEvent("Click", "ButtonSaveComplex")
			SaveSimpleButton.OnEvent("Click", "ButtonSaveSimple")
		}

		static Show(){
			this.Window.Show("Center w400 h300")
			
		}

		static Hide(){
			this.Window.Hide()
		}

		static ButtonSaveComplex(*){
			Controls.Save.Complex()
		}
		static ButtonSaveSimple(*){
			Controls.Save.Simple()
		}
	}
	
	class Credits{
		static Window := ""

		static Build(){
			this.Window := Gui("+AlwaysOnTop", "Macro Recorder Credits", this)	; Assigning AppGUI.Credits as an event handler
			this.Window.SetFont("s10")

			this.Window.AddText("w500", "
( 

 ..aooo..o..       ..oooooooooo                           oooo    oooo 
d8P'     'Y8     d'""""""d888'                            '888   .8P'  
Y8bo.                  .888P                                888  d8'    
 '"Y88o.             d888'                                  88888[      
     `"Y8b          .888P               8888888        888`88b.    
o       .d8P      d888'        ...P                       888   '88b.  
 '8""8888P'   .8888888888P                       o888o  o888o

)")
		global Version
		this.Window.AddText("w500", "Version: " Version)

		this.Window.AddText("XM","Github page: ")
		Link := this.Window.Add("Text", "X+ CBlue", "https://github.com/Sz-KLevy/AHK_AutoHotKey_Macro_Recorder")
		Link.OnEvent("Click", "OpenLink")
		}

		static OpenLink(*){
			Run("https://github.com/Sz-KLevy/AHK_AutoHotKey_Macro_Recorder")
		}

		static Show(){
			this.Window.Show("Center w500 h250")
		}

		static Hide(){
			this.Window.Hide()
		}
	}
}

class TimeCounter{
	__New(){
		this.StartTime := 0
	}
	
	Start(){
		this.StartTime := A_TickCount
	}
	
	Time(){
		return A_TickCount - this.StartTime
	}
}

Counter := TimeCounter()

class Controls{
	static Setup(){

		DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr") ; Fixes mouse offset issues
		HotkeyManager.Add(CurrentSetting.RecordEndKey, Controls.Record.Stop.Bind(Controls.Record))
		HotkeyManager.Add(CurrentSetting.RecordStartKey, Controls.Record.Start.Bind(Controls.Record))
		HotkeyManager.Add(CurrentSetting.PlayStartKey, Controls.Play.Bind(Controls))
		this.Record.Hook.Build()
		this.Record.MouseHook.MouseDelta.Setup()
		AppGUI.BuildAll()
		AppGUI.Main.Show()
	}

	static Play(){
		; Prevents double starts
		if(State.IsRecording or State.IsPlaying){
			return
		}
	
		global CurrentSetting
		global CurrentLog
		CoordMode "Mouse", CurrentSetting.MousePositionMode
		SetStoreCapsLockMode(false)
		SetKeyDelay -1, -1
		CombinedLog := CurrentLog.MergeLogs()
		
		if(CombinedLog.Length = 0){
			MsgBox "No recording found","",262144
			return
		}
	
		State.IsPlaying := true
		AppGUI.Main.UpdateStatus(State)
	
		StartTime := A_TickCount

		for index,entry in CombinedLog{
			TargetTime := entry.Time
			SourceType := entry.Type
	
	
			elapsed := A_TickCount - StartTime
			SleepNeeded := TargetTime - elapsed
			
			if(SleepNeeded > 10){	;The input precision will vary a bit, because of this, but sleep is varied at 0-20ms
				Sleep(SleepNeeded)
			}
	
			if (SourceType = "key"){
				CurrentKey := entry.Key		
				KeyState := entry.State
				/*Capslock configuration and key sending*/
				if(CurrentKey = "CapsLock"){
					if(KeyState = "down"){
						/*Switches states*/
						SetCapsLockState(!GetKeyState("Capslock", "T"))
					}
				}
				else{
					SendEvent("{Blind}{" CurrentKey " " KeyState "}")
				}
			}
			else if(SourceType = "mouse_position"){
				static input := Buffer(40, 0)

				NumPut("UInt", 0, input, 0)          ; INPUT_MOUSE
				NumPut("Int", entry.x, input, 8)     ; dx
				NumPut("Int", entry.y, input, 12)    ; dy
				NumPut("UInt", 0, input, 16)         ; mouseData
				NumPut("UInt", 0x2001, input, 20)    ; MOUSEEVENTF_MOVE | MOUSEEVENTF_MOVE_NOCOALESCE

				DllCall(
					"SendInput",
					"UInt", 1,
					"Ptr", input.Ptr,
					"Int", 40
				)
			}
	
		}
		SetStoreCapsLockMode(true)
		State.IsPlaying := false
		AppGUI.Main.UpdateStatus(State)
	}

	class Record{
		static MouseTimer := 0

		static Start(){
			; Prevents double starts
			if(State.IsRecording or State.IsPlaying){
				return
			}	

			global Counter
			global CurrentLog
			global CurrentSetting
		
		
			State.IsRecording := true
			CurrentLog.RecordLog := []
			CurrentLog.MouseRecordLog := []
			State.KeysDown.Clear()
			
			Counter.Start()
			if(CurrentSetting.RecordMouse = 1){
				Controls.Record.MouseTimer := Controls.Record.MouseHook.LogPosition.Bind(this)
				SetTimer Controls.Record.MouseTimer, CurrentSetting.MouseRecordingFrequency
				this.MouseHook.EnableCaptureButtons()
				OnMessage(0xFF, this.MouseHook.MouseDelta.callback)
			}
			if(CurrentSetting.RecordKeyboard = 1){
				this.Hook.ih.Start()
			}
			AppGUI.Main.UpdateStatus(State)
		}
		static Stop(){
			Thread "Priority", 100
			if(State.IsRecording){
				global CurrentSetting
				if(CurrentSetting.RecordKeyboard = 1){
					this.Hook.ih.Stop()
				}
				if(CurrentSetting.RecordMouse = 1){
					SetTimer Controls.Record.MouseTimer, 0
					Controls.Record.MouseHook.DisableCaptureButtons()
					OnMessage(0xFF, this.MouseHook.MouseDelta.callback, 0)
				}
				State.IsRecording := false
				AppGUI.Main.UpdateStatus(State)
				return "break"
			}
		}
		static OnRecordEnd(func_ih){
			global CurrentLog
			global Counter
			
			/*Unstuck keys*/
			for KeyName, IsDown in State.KeysDown{
				if(IsDown){
					CurrentLog.RecordLog.Push({Time: Counter.Time(),Type: "key",Key: KeyName,State: "up"})
				}
			}
			State.KeysDown.Clear()
		}
		class Hook{
			/*----------------Keyboard inputs-----------------------*/
			/*Records all keyboard inputs, without affecting the inputs itself*/
			static ih := InputHook("V")

			static Build(){
				this.ih.KeyOpt("{All}", "+N")
				this.ih.OnKeyDown := this.KeyDownHandler.Bind(this)
				this.ih.OnKeyUp := this.KeyUpHandler.Bind(this)
				this.ih.OnEnd := Controls.Record.OnRecordEnd.Bind(this)
			}

			static KeyDownHandler(func_ih,VK,SC){
				KeyName := GetKeyName(Format("vk{:x}sc{:x}",VK,SC))
				global CurrentSetting
				global CurrentLog
				global Counter
			
				if(KeyName != CurrentSetting.PlayStartKey && KeyName != CurrentSetting.RecordStartKey && KeyName != CurrentSetting.RecordEndKey && State.KeysDown.Has(KeyName) = false){
					CurrentLog.RecordLog.Push({Time: Counter.Time(),Type: "key",Key: KeyName,State: "down"})
					State.KeysDown[KeyName] := true
				}
			
			}
			static KeyUpHandler(func_ih,VK,SC){
				KeyName:= GetKeyName(Format("vk{:x}sc{:x}",VK,SC))
				global CurrentSetting
				global CurrentLog
				global Counter
			
				if(KeyName != CurrentSetting.RecordStartKey && KeyName != CurrentSetting.PlayStartKey){
					CurrentLog.RecordLog.Push({Time: Counter.Time(),Type: "key",Key: KeyName,State: "up"})
					State.KeysDown.Delete(KeyName)
				}
			}
		}
		class MouseHook{		
			/*Mouse position recording*/
			/*Works fine for now, but might change it to either record position if it moved x pixels*/
			static LogPosition(){
				global Counter
				global CurrentLog
				global CurrentSetting
			
				CoordMode "Mouse", CurrentSetting.MousePositionMode
				MouseGetPos(&xpos,&ypos)
				CurrentLog.MouseRecordLog.Push({Time: Counter.Time(),Type: "mouse_position",x: xpos,y: ypos})
			}

			static EnableCaptureButtons(){	; Could be written in a for loop like: for key in [LButton, RButton...]{Hotkey "~" key, ...}
				/*Capture Standard Buttons (Down & Up)*/
				Hotkey "~LButton", this.OnDown.Bind(this, "LButton"), "On"
				Hotkey "~LButton Up", this.OnUp.Bind(this, "LButton"), "On"

				Hotkey "~RButton", this.OnDown.Bind(this, "RButton"), "On"
				Hotkey "~RButton Up", this.OnUp.Bind(this, "RButton"), "On"

				Hotkey "~MButton", this.OnDown.Bind(this, "MButton"), "On"
				Hotkey "~MButton Up", this.OnUp.Bind(this, "MButton"), "On"

				Hotkey "~XButton1", this.OnDown.Bind(this, "XButton1"), "On"
				Hotkey "~XButton1 Up", this.OnUp.Bind(this, "XButton1"), "On"

				Hotkey "~XButton2", this.OnDown.Bind(this, "XButton2"), "On"
				Hotkey "~XButton2 Up", this.OnUp.Bind(this, "XButton2"), "On"
				
				Hotkey "~WheelUp", this.OnDown.Bind(this, "WheelUp"), "On"
				Hotkey "~WheelDown", this.OnDown.Bind(this, "WheelDown"), "On"
			}

			static DisableCaptureButtons(){	; Could be written in a for loop
				Hotkey "~LButton", "Off"
				Hotkey "~LButton Up", "Off"

				Hotkey "~RButton", "Off"
				Hotkey "~RButton Up", "Off"

				Hotkey "~MButton", "Off"
				Hotkey "~MButton Up", "Off"

				Hotkey "~XButton1", "Off"
				Hotkey "~XButton1 Up", "Off"

				Hotkey "~XButton2", "Off"
				Hotkey "~XButton2 Up", "Off"
				
				Hotkey "~WheelUp", "Off"
				Hotkey "~WheelDown", "Off"
			}

			static OnDown(key, *){
				global Counter
				global CurrentLog
				this.LogPosition()
				CurrentLog.MouseRecordLog.Push({Time: Counter.Time(),Type: "key",Key: key,State: "down"})
			}

			static OnUp(key, *){
				global Counter
				global CurrentLog
				this.LogPosition()
				CurrentLog.MouseRecordLog.Push({Time: Counter.Time(),Type: "key",Key: key,State: "up"})
			}

			class MouseDelta{

				static callback := ObjBindMethod(this, "WM_INPUT")

				static Setup(){
					rid := Buffer(8 + A_PtrSize, 0)
					result := 0

					NumPut(
						"UShort", 1,
						"UShort", 2,
						"UInt", 0x100,
						"UPtr", A_ScriptHwnd,
						rid.Ptr
					)

					result := DllCall(
						"RegisterRawInputDevices",
						"UPtr", rid.Ptr,
						"UInt", 1,
						"UInt", 8 + A_PtrSize
					)

					if(result = -1){
						MsgBox "GetRawInputData failed: " A_LastError
						return -1
					}
				}

				static WM_INPUT(wParam, lParam, msg, hwnd){

					result := 0
					size := 8 + (2 * A_PtrSize)
					header := Buffer(size, 0)

					;Gets raw input size
					result := DllCall(
						"GetRawInputData",
						"UPtr", lParam,
						"UInt", 0x10000005,
						"UPtr", header.Ptr,
						"UInt*", &size,
						"UInt", size
					)

					if(result = -1){
						MsgBox "GetRawInputData failed: " A_LastError
						return -1
					}	

					structSize := Numget(header, 4, "UInt")
					raw := Buffer(structSize)

					;Gets raw input
					result := DllCall(
						"GetRawInputData",
						"UPtr", lParam,
						"UInt", 0x10000003,
						"UPtr", raw.Ptr,
						"UInt*", &structSize,
						"UInt", size
					)
	
					if(result = -1){
						MsgBox "GetRawInputData failed: " A_LastError
						return -1
					}	

					mouseStart := 8 + 2*A_PtrSize

					delta_x := NumGet(raw, mouseStart + 12, "Int")
					delta_y := NumGet(raw, mouseStart + 16, "Int")


					CurrentLog.MouseRecordLog.Push({Time: Counter.Time(),Type: "mouse_position",x: delta_x,y: delta_y})
					ToolTip delta_x "   " delta_y
				}
			}
		}
	}

	class Save{
		static Complex(){
			if(State.IsRecording or State.IsPlaying){
				return
			}
			global CurrentLog
			global Version

			SelectedFile := FileSelect("S",,"Select a file to save as.", "*.txt")
			if(SubStr(SelectedFile, -4) != ".txt"){
				SelectedFile := SelectedFile ".txt"
			}
			WriteFile := FileOpen(SelectedFile, "w")

			WriteFile.WriteLine(Version)
			WriteFile.WriteLine("Keyboard")
			WriteFile.WriteLine("[")
			for index, entry in CurrentLog.RecordLog{
				line := ""
				for property, value in entry.OwnProps(){
					line .= property ":" value " "
				}
				WriteFile.WriteLine(RTrim(line))
			}
			WriteFile.WriteLine("]")

			WriteFile.WriteLine("Mouse")
			WriteFile.WriteLine("[")
			for index, entry in CurrentLog.MouseRecordLog{
				line := ""
				for property, value in entry.OwnProps(){
					line .= property ":" value " "
				}
				WriteFile.WriteLine(RTrim(line))
			}
			WriteFile.WriteLine("]")
			WriteFile.Write("END")
			WriteFile.Close()
		}

		static Simple(){
			if(State.IsRecording or State.IsPlaying){
				return
			}
			global CurrentLog

			SelectedFile := FileSelect("S",,"Select a file to save as.", "*.txt")
			if(SubStr(SelectedFile, -4) != ".txt"){
				SelectedFile := SelectedFile ".txt"
			}
			WriteFile := FileOpen(SelectedFile, "w")

			CombinedLog := CurrentLog.Simplify(CurrentLog.MergeLogs())

			for index, entry in CombinedLog{
				line := ""
				if(entry.Type = "key"){
					line := "Time:" entry.Time " Type:" entry.Type " Key:" entry.Key " State:" entry.State
				}
				else if(entry.type = "mouse_position"){
					line := "Time:" entry.Time " Type:" entry.Type " x:" entry.x " y:" entry.y
				}
				WriteFile.WriteLine(line)
			}
			WriteFile.Close()
		}
	}

	static Load(){
		if(State.IsRecording or State.IsPlaying){
			return
		}
		global CurrentLog
		
		SelectedFile := FileSelect("1",,"Select a file to load", "*txt")
		if(SubStr(SelectedFile, -4) != ".txt"){
			MsgBox "Not .txt file","Error",262144
			return
		}
		ReadFile := FileOpen(SelectedFile, "r")
		
		ReadFile.Seek(-4,2)	; Goes before the end of the file, if there is an enter, or anything after END, it wouldn't run
		ReadFile.ReadLine()
		if(ReadFile.ReadLine() != "END"){
			MsgBox "Failed to load the file, didn't found the `"END`"","File load error",262144
			return
		}
		ReadFile.Seek(0,0)	; Goes to the start of the file
		KeyboardStartPosition := 0
		while(true){
			Line := ReadFile.ReadLine()
			if(Line = "Keyboard"){
				ReadFile.ReadLine()
				KeyboardStartPosition := ReadFile.Pos
				break
			}
			else if(Line = "END"){
				MsgBox "Failed to load the file, didn't found the `"Keyboard`"","File load error",262144
				return
			}
		}
		while(true){
			Line := ReadFile.ReadLine()
			if(Line = "Mouse"){
				break
			}
			else if(Line = "END"){
				MsgBox "Failed to load the file, didn't found the `"Mouse`"","File load error",262144
				return
			}
		}

	/*--------------------Actual reading of the file----------*/

		
		CurrentLog.RecordLog := []
		CurrentLog.MouseRecordLog := []
		ReadFile.Seek(KeyboardStartPosition,0)
		while(true){
			Line := ReadFile.ReadLine()
			if(Line = "]"){
				break
			}
			Entry := StrSplit(Line,' ')
			CurrentLog.RecordLog.Push(CurrentLog.PushableEntryMaker(Entry))
		}
		while(true){
			Line := ReadFile.ReadLine()
			if(Line = "Mouse"){
				ReadFile.ReadLine()
				break
			}
		}
		while(true){
			Line := ReadFile.ReadLine()
			if(Line = "]"){
				break
			}
			Entry := StrSplit(Line,' ')
			CurrentLog.MouseRecordLog.Push(CurrentLog.PushableEntryMaker(Entry))
		}
		ReadFile.Close()
		MsgBox "Succesfull Load","",262144
	}
}

class HotkeyManager{
	static Handlers := map()

	static Add(key,function){
		if(!this.Handlers.Has(key)){
			this.Handlers[key] := []
			Hotkey(key, this.Dispatch.Bind(this, key))
			Hotkey(key, "On")
		}
		this.Handlers[key].Push(function)
	}

	static Remove(key,function){
		if(!this.Handlers.Has(key)){
			return
		}
		for i, f in this.Handlers[key]{
			if(f=function){
				this.Handlers[key].RemoveAt(i)
				break
			}
		}
	}

	static RemoveAll(key){
		this.Handlers[key] := []
	}

	static RemoveHotkey(key){
		try{
			this.Handlers.Delete(key)
			Hotkey(key, "Off")
		}
	}

	static Dispatch(key,*){
		Thread "Priority", -100
		for function in this.Handlers[key]{
			if("break" = function()){
				break
			}
		}
	}

}



/*--------------------------------------------------------Developer tools---------------------------*/

/*Close the file*/
!d::
{
; MsgBox "Stopping " A_ScriptName,"",262144
ExitApp
}

/*Updates the file*/
!u:: Reload
