#Requires AutoHotkey v2.0
/*Allows only one running instance*/
#SingleInstance Force

/*Needs to be declared before hotifs execute, not sure when it does, but if it's moved down, it's gives you error*/
IsRecording := false

DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr") ; Fixes mouse offset issues

/* runs when the program started */
MsgBox "Starting " A_ScriptName

/*Close the file*/
!d::
{
MsgBox "Stopping " A_ScriptName
ExitApp
}

/*Updates the file*/
!u:: Reload
/*-----------------------------------------------Code---------------------------*/
/*--------------------------------------Options and such--------------------------*/
RecordStartKey := "F1"
RecordEndKey := "F1"
PlayStartKey := "F2"
MousePositionMode := "Screen"



/*---------------------------------------------Counter---------------------------*/
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


/*-----------------------------------------------Record/Play---------------------------------*/
IsRecording := false
IsPlaying := false
RecordLog :=[]
MouseRecordLog :=[]
counter := TimeCounter()

/*Mouse position recording*/
MousePositionLogger(){
	global counter
	global MouseRecordLog
	global MousePositionMode	

	CoordMode "Mouse", MousePositionMode
	MouseGetPos(&xpos,&ypos)
	MouseRecordLog.Push([counter.Time(),"mouse_position",xpos,ypos])
}

/*------------------Mouse activity recording---------*/
/*Only runs, when recording*/
#HotIf IsRecording
/*Capture Standard Buttons (Down & Up)*/
~LButton::RecordLog.Push([counter.Time(), "key", "LButton", "down"])
~LButton Up::RecordLog.Push([counter.Time(), "key", "LButton", "up"])

~RButton::RecordLog.Push([counter.Time(), "key", "RButton", "down"])
~RButton Up::RecordLog.Push([counter.Time(), "key", "RButton", "up"])

~MButton::RecordLog.Push([counter.Time(), "key", "MButton", "down"])
~MButton Up::RecordLog.Push([counter.Time(), "key", "MButton", "up"])

/* Capture Side Buttons (XButtons) */
~XButton1::RecordLog.Push([counter.Time(), "key", "XButton1", "down"])
~XButton1 Up::RecordLog.Push([counter.Time(), "key", "XButton1", "up"])

~XButton2::RecordLog.Push([counter.Time(), "key", "XButton2", "down"])
~XButton2 Up::RecordLog.Push([counter.Time(), "key", "XButton2", "up"])

/* Capture Scroll Wheel */
~WheelUp::RecordLog.Push([counter.Time(), "key", "WheelUp", "down"])
~WheelDown::RecordLog.Push([counter.Time(), "key", "WheelDown", "down"]) 

#HotIf ;

/*-----------------------------------------------------*/


/*Prevents repeat spamming, by tracking the key states*/
KeysDown := Map()


/*Records all keyboard inputs, without affecting the inputs itself*/
ih := InputHook("V")
ih.KeyOpt("{All}", "+N")
ih.OnKeyDown := KeyDownHandler
ih.OnKeyUp := KeyUpHandler
ih.OnEnd := OnRecordEnd

KeyDownHandler(func_ih,VK,SC){
	KeyName := GetKeyName(Format("vk{:x}sc{:x}",VK,SC))
	global RecordEndKey
	global RecordStartKey
	global PlayStartKey
	global RecordLog
	global counter
	global KeysDown
	global ih
	if (KeyName = RecordEndKey){
		ih.Stop()
	}
	else if(KeyName != PlayStartKey && KeyName != RecordStartKey && KeysDown.Has(KeyName	) = false){
		RecordLog.Push([counter.Time(),"key",KeyName,"down"])
		KeysDown[KeyName] := true
	}

}
KeyUpHandler(func_ih,VK,SC){
	KeyName:= GetKeyName(Format("vk{:x}sc{:x}",VK,SC))
	global RecordStartKey
	global PlayStartKey
	global RecordLog
	global counter
	global KeysDown
	if(KeyName != RecordStartKey && KeyName != PlayStartKey){
		RecordLog.Push([counter.Time(),"key",KeyName,"up"])
		KeysDown.Delete(KeyName)
	}
}


/*Merging the logs, so it can be handled simultaniously*/
QuickSort(arr, left, right){
	if (left >= right){
		return
	}
    
/*Pivot is the timestamp at index 1*/
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
    
	if (left < j)
       		QuickSort(arr, left, j)
	if (i < right)
       		QuickSort(arr, i, right)
	
}

LogMerger(){
	global RecordLog
	global MouseRecordLog

	CombinedLog :=[]
	CombinedLog.Push(RecordLog*)
	CombinedLog.Push(MouseRecordLog*)

	if (CombinedLog.Length != 0)
		QuickSort(CombinedLog, 1, CombinedLog.Length)

	return CombinedLog
}



Hotkey(RecordStartKey,(ThisHotKey) => Record())
Record(){

	/*Prevents double starts*/
	global IsRecording
	if(IsRecording){
		return
	}

	global ih
	global RecordLog :=[]
	global MouseRecordLog :=[]
	global counter
	global KeysDown
	

	KeysDown.Clear()
	
	counter.Start()
	/*Records mouse position every 20 milisecond*/
	SetTimer MousePositionLogger, 20
	ih.Start()
	IsRecording := true
	UpdateStatus()
	ih.Wait()
}

OnRecordEnd(func_ih){
	global IsRecording
	global RecordLog
	global counter
	global KeysDown

	IsRecording := false
	SetTimer MousePositionLogger, 0

	/*Unstuck keys*/
	for KeyName, IsDown in KeysDown{
		if(IsDown){
			RecordLog.Push([counter.Time(),"key",KeyName, "up"])
		}
	}
	KeysDown.Clear()
	UpdateStatus()
}




Hotkey(PlayStartKey,(ThisHotKey) => Play())
Play(){
	global MousePositionMode
	CoordMode "Mouse", MousePositionMode
	SetStoreCapsLockMode(false)
	SetKeyDelay -1, -1
	CombinedLog := LogMerger()

	if(CombinedLog.Length = 0){
		MsgBox "No recording found"
		return
	}

	global IsPlaying
	IsPlaying := true
	UpdateStatus()

	StartTime := A_TickCount

	for index,entry in CombinedLog{
		TargetTime := entry[1]
		SourceType := entry[2]


		elapsed := A_TickCount - StartTime
		SleepNeeded := TargetTime - elapsed
		
		if(SleepNeeded > 10){
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
	IsPlaying := false
	UpdateStatus()
}

/*-----------------------------------------------GUI------------------------------*/
MainGui := Gui("+AlwaysOnTop", "Macro Recorder")

MainGui.SetFont("s10")

MainGui.AddText("w120", "Record Start Hotkey:")
EditRecordStart := MainGui.AddEdit("w120", RecordStartKey)

MainGui.AddText("w120", "Record End Hotkey:")
EditRecordEnd := MainGui.AddEdit("w120", RecordEndKey)

MainGui.AddText("w120", "Play Hotkey:")
EditPlay := MainGui.AddEdit("w120", PlayStartKey)

MainGui.AddText("w120", "MouseMode:")
EditMouseMode := MainGui.AddDropDownList("w120", ["Screen", "Window", "Client"])
EditMouseMode.Text := MousePositionMode 

UpdateSettingsButton := MainGui.AddButton("w120", "Update Settings")
UpdateSettingsButton.OnEvent("Click", UpdateSettings)


RecordStartButton := MainGui.AddButton("w120", "Start Recording")
RecordStartButton.OnEvent("Click", ButtonStartRecord)
RecordEndButton := MainGui.AddButton("w120", "End Recording")
RecordEndButton.OnEvent("Click", ButtonEndRecord)
PlayStartButton := MainGui.AddButton("w120", "Play")
PlayStartButton.OnEvent("Click", ButtonStartPlay)

CurrentStatusText := MainGui.AddText("w120", "Status: Idle")

MainGui.Show("w300 h500")

/*----------GUI functions--------------*/

ButtonStartRecord(*){
	global IsRecording
	if(IsRecording){
		MsgBox "Already recording"
		return
	}
	Record()
}

ButtonEndRecord(*){
	global ih
	global IsRecording
	if(!IsRecording){
		return
	}
	ih.Stop()
}

ButtonStartPlay(*){
	Play()
}

UpdateStatus(){
	global IsRecording
	global IsPlaying

	if(IsRecording){
		CurrentStatusText.Text := "Status: Recording"
	}
	else if(IsPlaying){
		CurrentStatusText.Text := "Status: Playing"
	}
	else{
		CurrentStatusText.Text := "Status: Idle"
	}
}

UpdateSettings(*){
	global EditRecord, EditPlay, EditMouseMode
	global RecordStartKey, RecordEndKey, PlayStartKey, MousePositionMode

	/*Deleting previous hotkeys*/
	Hotkey(RecordStartKey, "Off")
	Hotkey(PlayStartKey, "Off")
	Hotkey(RecordEndKey, "Off")

	/*Installing new hotkeys*/
	Try{
		Hotkey(EditRecordEnd.Text, (hk) => Record(), "On")
	}
	Catch{
		MsgBox "Failed to change Record End Hotkey"
	}
	Else{
		RecordEndKey := EditRecordEnd.Text
		Hotkey(RecordEndKey, "Off")
	}

	Try{
		Hotkey(EditRecordStart.Text, (hk) => Record(), "On")
	}
	Catch{
		MsgBox "Failed to change Record Start Hotkey"
		Hotkey(RecordStartKey, (hk) => Record(), "On")
	}
	Else{
		RecordStartKey := EditRecordStart.Text
	}

	Try{
		Hotkey(EditPlay.Text, (hk) => Play(), "On")
	}
	Catch{
		MsgBox "Failed to change Play Start Key"
		Hotkey(PlayStartKey, (hk) => Play(), "On")
	}
	Else{
		PlayStartKey := EditPlay.Text
	}

	MousePositionMode := EditMouseMode.Text

}
