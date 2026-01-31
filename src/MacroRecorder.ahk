#Requires AutoHotkey v2.0
#SingleInstance Force	;Allows only one running instance


/*-----------------------------------------------Code---------------------------*/
/*--------------------------------------Variables, options and such--------------------------*/
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
	RecordLog :=[]
	MouseRecordLog :=[]


	/*------------------Record handlers--------------------------*/
	/*Merging the logs, so it can be handled simultaniously*/
	/*Using quicksort, which might not be as effective in this special case as otherways (insertion sort might be faster).
	You could "guess" where you should put the RecordLog values in the MouseRecordLog with good accuracy.*/
	QuickSort(arr, left, right){
		if (left >= right){
			return
		}

		pivot := arr[(left + right) // 2][1]
 		i := left
		j := right

		while (i <= j) {
			while (arr[i][1] < pivot)
				i++
			while (arr[j][1] > pivot)
				j--
			if (i <= j) {
				temp := arr[i]
				arr[i] := arr[j]
				arr[j] := temp
				i++
				j--
			}
		}
		if (left < j){
			this.QuickSort(arr, left, j)
		}
		if (i < right){
			this.QuickSort(arr, i, right)
		}
	}

	MergeLogs(){
		CombinedLog :=[]
		CombinedLog.Push(this.RecordLog*)
		CombinedLog.Push(this.MouseRecordLog*)

		if (CombinedLog.Length != 0)
			this.QuickSort(CombinedLog, 1, CombinedLog.Length)

		return CombinedLog
	}
}

CurrentLog := DataLog()
CurrentSetting := DefaultSetting

/*-----------------------------------------------GUI--------------------------------------------------------------*/
class AppGUI{

	__New(){
		AppGUI.Main.Build()
		AppGUI.Options.Build()
	}

	class Main{
		static Window := Gui()
		static CurrentStatusText := this.Window.AddText()

		static Build(){
			this.Window := Gui("", "Macro Recorder")
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


			RecordStartButton.OnEvent("Click", this.ButtonStartRecord)
			RecordEndButton.OnEvent("Click", this.ButtonEndRecord)
			PlayButton.OnEvent("Click", this.ButtonPlay)
			SaveButton.OnEvent("Click", this.ButtonSave)
			LoadButton.OnEvent("Click", this.ButtonLoad)
			
			EditButton.OnEvent("Click", this.ButtonEdit)
			OptionsButton.OnEvent("Click", this.ButtonOptions)
			CreditsButton.OnEvent("Click", this.ButtonCredits)
		}


		static Show(){
			this.Window.Show("Center w400 h300")
			
		}

		static Hide(){
			this.Window.Hide()
		}

/*---------------------------------------------------Functionality-----------------------*/
		static ButtonStartRecord(*){
			if(State.IsRecording){
				return
			}
			Record()
		}

		static ButtonEndRecord(*){
			global ih
			if(!State.IsRecording){
				return
			}
			ih.Stop()
		}


		static ButtonPlay(*){
			Play()
		}

		static ButtonSave(*){
			Controlls.Save()
		}
		static ButtonLoad(*){
			Controlls.Load()
		}

		static ButtonEdit(*){
			MsgBox "Not implemented yet"
		}

		static ButtonOptions(*){
			AppGUI.Options.Show()
		}

		static ButtonCredits(*){
			MsgBox "Not implemented yet"
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
		static Window := Gui()
		static Settings := Map()

		static Build(){
			global CurrentSetting
			this.Window := Gui("+AlwaysOnTop", "Macro Recorder")
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
			UpdateSettingsButton.OnEvent("Click", this.UpdateSettings)
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
				Hotkey(AppGUI.Options.Settings["RecordEnd"].Text, (hk) => Record(), "On")	;Checks, if the key could be a hotkey, removes it's function instantly if it can
			}
			Catch{
				MsgBox "Failed to change Record End Hotkey"
			}
			Else{
				Hotkey(AppGUI.Options.Settings["RecordEnd"].Text, "Off")
				CurrentSetting.RecordEndKey := AppGUI.Options.Settings["RecordEnd"].Text
			}

			Try{
				Hotkey(AppGUI.Options.Settings["RecordStart"].Text, (hk) => Record(), "On")
			}
			Catch{
				MsgBox "Failed to change Record Start Hotkey"
				Hotkey(CurrentSetting.RecordStartKey, (hk) => Record(), "On")
			}
			Else{
				CurrentSetting.RecordStartKey := AppGUI.Options.Settings["RecordStart"].Text
			}

			Try{
				Hotkey(AppGUI.Options.Settings["Play"].Text, (hk) => Play(), "On")
			}
			Catch{
				MsgBox "Failed to change Play Start Key"
				Hotkey(CurrentSetting.PlayStartKey, (hk) => Play(), "On")
			}
			Else{
				CurrentSetting.PlayStartKey := AppGUI.Options.Settings["Play"].Text
			}

			CurrentSetting.MousePositionMode := AppGUI.Options.Settings["MouseMode"].Text
		}
	}
}

AppGUI()
AppGUI.Main.Show()

/*--------------------------------------------------------------Input reciving---------------------------*/
/*----------------------Mouse inputs---------------------------------*/
DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr") ; Fixes mouse offset issues

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

/*Mouse position recording*/
/*Works fine for now, but might change it to either record position if it moved x pixels*/
MousePositionLogger(){
	global Counter
	global CurrentLog
	global CurrentSetting

	CoordMode "Mouse", CurrentSetting.MousePositionMode
	MouseGetPos(&xpos,&ypos)
	CurrentLog.MouseRecordLog.Push([Counter.Time(),"mouse_position",xpos,ypos])
}

/*------------Mouse activity recording---------*/
/*Only runs, when recording*/
#HotIf State.IsRecording
/*Capture Standard Buttons (Down & Up)*/
~LButton::{
CoordMode "Mouse", CurrentSetting.MousePositionMode
MouseGetPos(&xpos,&ypos)
CurrentLog.MouseRecordLog.Push([Counter.Time(),"mouse_position",xpos,ypos])
CurrentLog.MouseRecordLog.Push([Counter.Time(), "key", "LButton", "down"])
}
~LButton Up::{
CoordMode "Mouse", CurrentSetting.MousePositionMode
MouseGetPos(&xpos,&ypos)
CurrentLog.MouseRecordLog.Push([Counter.Time(),"mouse_position",xpos,ypos])
CurrentLog.MouseRecordLog.Push([Counter.Time(), "key", "LButton", "up"])
}

~RButton::{
CoordMode "Mouse", CurrentSetting.MousePositionMode
MouseGetPos(&xpos,&ypos)
CurrentLog.MouseRecordLog.Push([Counter.Time(),"mouse_position",xpos,ypos])
CurrentLog.MouseRecordLog.Push([Counter.Time(), "key", "RButton", "down"])
}
~RButton Up::{
CoordMode "Mouse", CurrentSetting.MousePositionMode
MouseGetPos(&xpos,&ypos)
CurrentLog.MouseRecordLog.Push([Counter.Time(),"mouse_position",xpos,ypos])
CurrentLog.MouseRecordLog.Push([Counter.Time(), "key", "RButton", "up"])
}

~MButton::{
CoordMode "Mouse", CurrentSetting.MousePositionMode
MouseGetPos(&xpos,&ypos)
CurrentLog.MouseRecordLog.Push([Counter.Time(),"mouse_position",xpos,ypos])
CurrentLog.MouseRecordLog.Push([Counter.Time(), "key", "MButton", "down"])
}
~MButton Up::{
CoordMode "Mouse", CurrentSetting.MousePositionMode
MouseGetPos(&xpos,&ypos)
CurrentLog.MouseRecordLog.Push([Counter.Time(),"mouse_position",xpos,ypos])
CurrentLog.MouseRecordLog.Push([Counter.Time(), "key", "MButton", "up"])
}

/* Capture Side Buttons (XButtons) */
~XButton1::{
CoordMode "Mouse", CurrentSetting.MousePositionMode
MouseGetPos(&xpos,&ypos)
CurrentLog.MouseRecordLog.Push([Counter.Time(),"mouse_position",xpos,ypos])
CurrentLog.MouseRecordLog.Push([Counter.Time(), "key", "XButton1", "down"])
}
~XButton1 Up::{
CoordMode "Mouse", CurrentSetting.MousePositionMode
MouseGetPos(&xpos,&ypos)
CurrentLog.MouseRecordLog.Push([Counter.Time(),"mouse_position",xpos,ypos])
CurrentLog.MouseRecordLog.Push([Counter.Time(), "key", "XButton1", "up"])
}

~XButton2::{
CoordMode "Mouse", CurrentSetting.MousePositionMode
MouseGetPos(&xpos,&ypos)
CurrentLog.MouseRecordLog.Push([Counter.Time(),"mouse_position",xpos,ypos])
CurrentLog.MouseRecordLog.Push([Counter.Time(), "key", "XButton2", "down"])
}
~XButton2 Up::{
CoordMode "Mouse", CurrentSetting.MousePositionMode
MouseGetPos(&xpos,&ypos)
CurrentLog.MouseRecordLog.Push([Counter.Time(),"mouse_position",xpos,ypos])
CurrentLog.MouseRecordLog.Push([Counter.Time(), "key", "XButton2", "up"])
}

/* Capture Scroll Wheel */	;While in other mouse activity, the position may be relevant, I'm doubtfull that it is relevant here, but for consistency I record the position here too
~WheelUp::{
CoordMode "Mouse", CurrentSetting.MousePositionMode
MouseGetPos(&xpos,&ypos)
CurrentLog.MouseRecordLog.Push([Counter.Time(),"mouse_position",xpos,ypos])
CurrentLog.MouseRecordLog.Push([Counter.Time(), "key", "WheelUp", "down"])
}
~WheelDown::{
CoordMode "Mouse", CurrentSetting.MousePositionMode
MouseGetPos(&xpos,&ypos)
CurrentLog.MouseRecordLog.Push([Counter.Time(),"mouse_position",xpos,ypos])
CurrentLog.MouseRecordLog.Push([Counter.Time(), "key", "WheelDown", "down"])
}

#HotIf ;

/*----------------Keyboard inputs-----------------------*/
/*Records all keyboard inputs, without affecting the inputs itself*/
ih := InputHook("V")
ih.KeyOpt("{All}", "+N")
ih.OnKeyDown := KeyDownHandler
ih.OnKeyUp := KeyUpHandler
ih.OnEnd := OnRecordEnd

KeyDownHandler(func_ih,VK,SC){
	KeyName := GetKeyName(Format("vk{:x}sc{:x}",VK,SC))
	global CurrentSetting
	global CurrentLog
	global Counter
	global ih

	if (KeyName = CurrentSetting.RecordEndKey){
		ih.Stop()
	}
	else if(KeyName != CurrentSetting.PlayStartKey && KeyName != CurrentSetting.RecordStartKey && State.KeysDown.Has(KeyName) = false){
		CurrentLog.RecordLog.Push([Counter.Time(),"key",KeyName,"down"])
		State.KeysDown[KeyName] := true
	}

}
KeyUpHandler(func_ih,VK,SC){
	KeyName:= GetKeyName(Format("vk{:x}sc{:x}",VK,SC))
	global CurrentSetting
	global CurrentLog
	global Counter

	if(KeyName != CurrentSetting.RecordStartKey && KeyName != CurrentSetting.PlayStartKey){
		CurrentLog.RecordLog.Push([counter.Time(),"key",KeyName,"up"])
		State.KeysDown.Delete(KeyName)
	}
}


/*--------------------------------------------------------Record and play----------------------------*/

Hotkey(CurrentSetting.RecordStartKey,(ThisHotKey) => Record())
Record(){
	; Prevents double starts
	if(State.IsRecording or State.IsPlaying){
		return
	}	

	global ih
	global Counter
	global CurrentLog
	global CurrentSetting


	State.IsRecording := true
	CurrentLog.RecordLog := []
	CurrentLog.MouseRecordLog := []
	State.KeysDown.Clear()
	
	Counter.Start()
	SetTimer MousePositionLogger, CurrentSetting.MouseRecordingFrequency
	ih.Start()
	AppGUI.Main.UpdateStatus(State)
	ih.Wait()
}

OnRecordEnd(func_ih){
	global CurrentLog
	global Counter

	State.IsRecording := false
	SetTimer MousePositionLogger, 0

	/*Unstuck keys*/
	for KeyName, IsDown in State.KeysDown{
		if(IsDown){
			CurrentLog.RecordLog.Push([Counter.Time(),"key",KeyName, "up"])
		}
	}
	State.KeysDown.Clear()
	AppGUI.Main.UpdateStatus(State)
}




Hotkey(CurrentSetting.PlayStartKey,(ThisHotKey) => Play())
Play(){
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
		MsgBox "No recording found"
		return
	}

	State.IsPlaying := true
	AppGUI.Main.UpdateStatus(State)

	StartTime := A_TickCount

	for index,entry in CombinedLog{
		TargetTime := entry[1]
		SourceType := entry[2]


		elapsed := A_TickCount - StartTime
		SleepNeeded := TargetTime - elapsed
		
		if(SleepNeeded > 10){	;The input precision will vary a bit, because of this, but sleep is varied at 0-20ms
			Sleep(SleepNeeded)
		}

		if (SourceType = "key"){
			CurrentKey := entry[3]		
			KeyState := entry[4]
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
			x_pos := entry[3]
			y_pos := entry[4]
			MouseMove(x_pos, y_pos, 0)
		}

	}
	SetStoreCapsLockMode(true)
	State.IsPlaying := false
	AppGUI.Main.UpdateStatus(State)
}

class Controlls{
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
		for index, entry in CurrentLog.RecordLog{
			for index2, EntryElement in entry{
				if(index2 = entry.Length){
					WriteFile.Write(EntryElement)
				}
				else WriteFile.Write(EntryElement " ")	
			}
			WriteFile.WriteLine("")
		}
		WriteFile.WriteLine("Mouse")
		for index, entry in CurrentLog.MouseRecordLog{
			for index2, EntryElement in entry{
				if(index2 = entry.Length){
					WriteFile.Write(EntryElement)
				}
				else WriteFile.Write(EntryElement " ")	
			}
			WriteFile.WriteLine("")
		}
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
			MsgBox "Not .txt file"
			return
		}
		ReadFile := FileOpen(SelectedFile, "r")
		
		ReadFile.Seek(-4,2)	; Goes before the end of the file, if there is an enter, or anything after END, it wouldn't run
		ReadFile.ReadLine()
		if(ReadFile.ReadLine() != "END"){
			MsgBox "Failed to load the file, didn't found the `"END`""
			return
		}
		ReadFile.Seek(0,0)	; Goes to the start of the file
		KeyboardStartPosition := 0
		while(true){
			Line := ReadFile.ReadLine()
			if(Line = "Keyboard"){
				KeyboardStartPosition := ReadFile.Pos
				break
			}
			else if(Line = "END"){
				MsgBox "Failed to load the file, didn't found the `"Keyboard`""
				return
			}
		}
		while(true){
			Line := ReadFile.ReadLine()
			if(Line = "Mouse"){
				break
			}
			else if(Line = "END"){
				MsgBox "Failed to load the file, didn't found the `"Mouse`""
				return
			}
		}

	/*--------------------Actual reading of the file----------*/
		CurrentLog.RecordLog := []
		CurrentLog.MouseRecordLog := []
		ReadFile.Seek(KeyboardStartPosition,0)
		while(true){
			Line := ReadFile.ReadLine()
			if(Line = "Mouse"){
				break
			}
			Entry := StrSplit(Line,' ')
			CurrentLog.RecordLog.Push(Entry)
		}
		while(true){
			Line := ReadFile.ReadLine()
			if(Line = "END"){
				break
			}
			Entry := StrSplit(Line,' ')
			CurrentLog.MouseRecordLog.Push(Entry)
		}
		ReadFile.Close()
		MsgBox "Succesfull Load"
	}
}





/*--------------------------------------------------------Developer tools---------------------------*/

/*Close the file*/
!d::
{
; MsgBox "Stopping " A_ScriptName
ExitApp
}

/*Updates the file*/
!u:: Reload
