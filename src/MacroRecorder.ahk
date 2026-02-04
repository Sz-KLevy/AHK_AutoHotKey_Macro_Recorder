#Requires AutoHotkey v2.0
#SingleInstance Force	;Allows only one running instance


/*-----------------------------------------------Code---------------------------*/
/*--------------------------------------Variables, options and such--------------------------*/
Version := "1.3-alpha"

class Setting{
	RecordStartKey := "F1"
	RecordEndKey := "F1"	; A fake hotkey, from the user perspective, it works as one
	PlayStartKey := "F2"
	MousePositionMode := "Screen"

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

			this.Window.AddText("w120", "Record Start Hotkey:")
			this.Settings["RecordStart"] := this.Window.AddEdit("w120", CurrentSetting.RecordStartKey)

			this.Window.AddText("w120", "Record End Hotkey:")
			this.Settings["RecordEnd"] := this.Window.AddEdit("w120", CurrentSetting.RecordEndKey)

			this.Window.AddText("w120", "Play Hotkey:")
			this.Settings["Play"] := this.Window.AddEdit("w120", CurrentSetting.PlayStartKey)

			this.Window.AddText("w120", "MouseMode:")
			this.Settings["MouseMode"] := this.Window.AddDropDownList("w120", ["Screen", "Window", "Client"])
			this.Settings["MouseMode"].Text := CurrentSetting.MousePositionMode

			UpdateSettingsButton := this.Window.AddButton("w120", "Update settings")
			UpdateSettingsButton.OnEvent("Click", "UpdateSettings")
		}

		static Show(){
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
			Hotkey(CurrentSetting.RecordStartKey, "Off")
			Hotkey(CurrentSetting.PlayStartKey, "Off")
			Hotkey(CurrentSetting.RecordEndKey, "Off")

			; Installing new hotkeys
			Try{
				Hotkey(AppGUI.Options.Settings["RecordEnd"].Text, (hk) => Controls.Record.Start(), "On")	;Checks, if the key could be a hotkey, removes it's function instantly if it can
			}
			Catch{
				MsgBox "Failed to change Record End Hotkey","Error",262144
			}
			Else{
				Hotkey(AppGUI.Options.Settings["RecordEnd"].Text, "Off")
				CurrentSetting.RecordEndKey := AppGUI.Options.Settings["RecordEnd"].Text
			}

			Try{
				Hotkey(AppGUI.Options.Settings["RecordStart"].Text, (hk) => Controls.Record.Start(), "On")
			}
			Catch{
				MsgBox "Failed to change Record Start Hotkey","Error",262144
				Hotkey(CurrentSetting.RecordStartKey, (hk) => Controls.Record.Start(), "On")
			}
			Else{
				CurrentSetting.RecordStartKey := AppGUI.Options.Settings["RecordStart"].Text
			}

			Try{
				Hotkey(AppGUI.Options.Settings["Play"].Text, (hk) => Controls.Play(), "On")
			}
			Catch{
				MsgBox "Failed to change Play Start Key","Error",262144
				Hotkey(CurrentSetting.PlayStartKey, (hk) => Controls.Play(), "On")
			}
			Else{
				CurrentSetting.PlayStartKey := AppGUI.Options.Settings["Play"].Text
			}

			CurrentSetting.MousePositionMode := AppGUI.Options.Settings["MouseMode"].Text
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

/*--------------------------------------------------------------------------Mouse outside of class------------*/
/*------------Mouse activity recording---------*/
/*Only runs, when recording*/
/* Putting the activity recording to the MousHook would be possible, if we leave the hotif outside, and call the funciton when it's active
#HotIf State.IsRecording
/*Capture Standard Buttons (Down & Up)*/
~LButton::{
CoordMode "Mouse", CurrentSetting.MousePositionMode
MouseGetPos(&xpos,&ypos)
CurrentLog.MouseRecordLog.Push({Time: Counter.Time(),Type: "mouse_position",x: xpos,y: ypos})
CurrentLog.MouseRecordLog.Push({Time: Counter.Time(),Type: "key",Key: "LButton",State: "down"})
}
~LButton Up::{
CoordMode "Mouse", CurrentSetting.MousePositionMode
MouseGetPos(&xpos,&ypos)
CurrentLog.MouseRecordLog.Push({Time: Counter.Time(),Type: "mouse_position",x: xpos,y: ypos})
CurrentLog.MouseRecordLog.Push({Time: Counter.Time(),Type: "key",Key: "LButton",State: "up"})
}

~RButton::{
CoordMode "Mouse", CurrentSetting.MousePositionMode
MouseGetPos(&xpos,&ypos)
CurrentLog.MouseRecordLog.Push({Time: Counter.Time(),Type: "mouse_position",x: xpos,y: ypos})
CurrentLog.MouseRecordLog.Push({Time: Counter.Time(),Type: "key",Key: "RButton",State: "down"})
}
~RButton Up::{
CoordMode "Mouse", CurrentSetting.MousePositionMode
MouseGetPos(&xpos,&ypos)
CurrentLog.MouseRecordLog.Push({Time: Counter.Time(),Type: "mouse_position",x: xpos,y: ypos})
CurrentLog.MouseRecordLog.Push({Time: Counter.Time(),Type: "key",Key: "RButton",State: "up"})
}

~MButton::{
CoordMode "Mouse", CurrentSetting.MousePositionMode
MouseGetPos(&xpos,&ypos)
CurrentLog.MouseRecordLog.Push({Time: Counter.Time(),Type: "mouse_position",x: xpos,y: ypos})
CurrentLog.MouseRecordLog.Push({Time: Counter.Time(),Type: "key",Key: "MButton",State: "down"})
}
~MButton Up::{
CoordMode "Mouse", CurrentSetting.MousePositionMode
MouseGetPos(&xpos,&ypos)
CurrentLog.MouseRecordLog.Push({Time: Counter.Time(),Type: "mouse_position",x: xpos,y: ypos})
CurrentLog.MouseRecordLog.Push({Time: Counter.Time(),Type: "key",Key: "MButton",State: "up"})
}

/* Capture Side Buttons (XButtons) */
~XButton1::{
CoordMode "Mouse", CurrentSetting.MousePositionMode
MouseGetPos(&xpos,&ypos)
CurrentLog.MouseRecordLog.Push({Time: Counter.Time(),Type: "mouse_position",x: xpos,y: ypos})
CurrentLog.MouseRecordLog.Push({Time: Counter.Time(),Type: "key",Key: "XButton1",State: "down"})
}
~XButton1 Up::{
CoordMode "Mouse", CurrentSetting.MousePositionMode
MouseGetPos(&xpos,&ypos)
CurrentLog.MouseRecordLog.Push({Time: Counter.Time(),Type: "mouse_position",x: xpos,y: ypos})
CurrentLog.MouseRecordLog.Push({Time: Counter.Time(),Type: "key",Key: "XButton1",State: "up"})
}

~XButton2::{
CoordMode "Mouse", CurrentSetting.MousePositionMode
MouseGetPos(&xpos,&ypos)
CurrentLog.MouseRecordLog.Push({Time: Counter.Time(),Type: "mouse_position",x: xpos,y: ypos})
CurrentLog.MouseRecordLog.Push({Time: Counter.Time(),Type: "key",Key: "XButton2",State: "down"})
}
~XButton2 Up::{
CoordMode "Mouse", CurrentSetting.MousePositionMode
MouseGetPos(&xpos,&ypos)
CurrentLog.MouseRecordLog.Push({Time: Counter.Time(),Type: "mouse_position",x: xpos,y: ypos})
CurrentLog.MouseRecordLog.Push({Time: Counter.Time(),Type: "key",Key: "XButton2",State: "up"})
}

/* Capture Scroll Wheel */	;While in other mouse activity, the position may be relevant, I'm doubtfull that it is relevant here, but for consistency I record the position here too
~WheelUp::{
CoordMode "Mouse", CurrentSetting.MousePositionMode
MouseGetPos(&xpos,&ypos)
CurrentLog.MouseRecordLog.Push({Time: Counter.Time(),Type: "mouse_position",x: xpos,y: ypos})
CurrentLog.MouseRecordLog.Push({Time: Counter.Time(),Type: "key",Key: "WheelUp",State: "down"})
}
~WheelDown::{
CoordMode "Mouse", CurrentSetting.MousePositionMode
MouseGetPos(&xpos,&ypos)
CurrentLog.MouseRecordLog.Push({Time: Counter.Time(),Type: "mouse_position",x: xpos,y: ypos})
CurrentLog.MouseRecordLog.Push({Time: Counter.Time(),Type: "key",Key: "WheelDown",State: "down"})
}

#HotIf ;


class Controls{
	static Setup(){
		DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr") ; Fixes mouse offset issues
		Hotkey(CurrentSetting.RecordStartKey,(ThisHotKey) => Controls.Record.Start())
		Hotkey(CurrentSetting.PlayStartKey,(ThisHotKey) => Controls.Play())
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
			SetTimer Controls.Record.MouseHook.MousePositionLogger.Bind(this), CurrentSetting.MouseRecordingFrequency
			this.Hook.ih.Start()
			AppGUI.Main.UpdateStatus(State)
		}
		static Stop(){
			if(State.IsRecording = true){
				this.Hook.ih.Stop()
			}
		}
		static OnRecordEnd(func_ih){
			global CurrentLog
			global Counter
		
			State.IsRecording := false
			SetTimer Controls.Record.MouseHook.MousePositionLogger.Bind(this), 0
		
			/*Unstuck keys*/
			for KeyName, IsDown in State.KeysDown{
				if(IsDown){
					CurrentLog.RecordLog.Push({Time: Counter.Time(),Type: "key",Key: KeyName,State: "up"})
				}
			}
			State.KeysDown.Clear()
			AppGUI.Main.UpdateStatus(State)
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
			
				if (KeyName = CurrentSetting.RecordEndKey){
					Controls.Record.Stop()
				}
				else if(KeyName != CurrentSetting.PlayStartKey && KeyName != CurrentSetting.RecordStartKey && State.KeysDown.Has(KeyName) = false){
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
			static MousePositionLogger(){
				global Counter
				global CurrentLog
				global CurrentSetting
			
				CoordMode "Mouse", CurrentSetting.MousePositionMode
				MouseGetPos(&xpos,&ypos)
				CurrentLog.MouseRecordLog.Push({Time: Counter.Time(),Type: "mouse_position",x: xpos,y: ypos})
			}
		}
	}

	static Save(){
		if(State.IsRecording or State.IsPlaying){
			return
		}
		global CurrentLog
		
		SelectedFile := FileSelect("S",,"Select a file to save as.", "*.txt")
		if(SubStr(SelectedFile, -4) != ".txt"){
			SelectedFile := SelectedFile ".txt"
		}
		WriteFile := FileOpen(SelectedFile, "w")

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





/*--------------------------------------------------------Developer tools---------------------------*/

/*Close the file*/
!d::
{
; MsgBox "Stopping " A_ScriptName,"",262144
ExitApp
}

/*Updates the file*/
!u:: Reload
