#Requires AutoHotkey v2.0
#SingleInstance Force	;Allows only one running instance


/*-----------------------------------------------Code---------------------------*/
/*--------------------------------------Variables, options and such--------------------------*/
Version := "1.4-alpha"

class Setting{
	RecordStartKey := "F1"
	RecordEndKey := "F1"	; A fake hotkey, from the user perspective, it works as one
	PlayStartKey := "F2"
	PlayStopKey := "F3"
	MousePositionMode := "Screen"

	RecordMouse := 1
	RecordKeyboard := 1
	DisableMouseDuringPlay := 1
	DisableKeyboardDuringPlay := 1

	MouseRecordingFrequency := 20
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
}

CurrentLog := DataLog()
CurrentSetting := DefaultSetting

Controls.Setup()
/*-----------------------------------------------GUI--------------------------------------------------------------*/
class AppGUI{

	static BuildAll(){
		AppGUI.Main.Build()
		AppGUI.Options.Build()
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
			LoadButton := this.Window.AddButton(width height " X+", "Load")
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
			Controls.Save()
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

			this.Window.AddText("w120 xs", "Disable mouse during play")
			this.Settings["DisableMouseDuringPlay"] := this.Window.AddCheckbox("x+-25")

			this.Window.AddText("w120 xs", "Disable keyboard during play")
			this.Settings["DisableKeyboardDuringPlay"] := this.Window.AddCheckbox("x+-10")

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
			this.Settings["DisableMouseDuringPlay"].Value := CurrentSetting.DisableMouseDuringPlay
			this.Settings["DisableKeyboardDuringPlay"].Value := CurrentSetting.DisableKeyboardDuringPlay
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
			CurrentSetting.DisableMouseDuringPlay := AppGUI.Options.Settings["DisableMouseDuringPlay"].Value
			CurrentSetting.DisableKeyboardDuringPlay := AppGUI.Options.Settings["DisableKeyboardDuringPlay"].Value

			this.UpdateMenu()
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
				MouseMove(entry.x, entry.y, 0)
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
		}
	}

	static Save(){
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
