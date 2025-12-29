#include <GUIConstantsEx.au3>
#include <MsgBoxConstants.au3>
#include <Array.au3>
#include <File.au3>
#include <Date.au3>

; Thiết lập chế độ chuột cho game
Opt("MouseCoordMode", 1) ; Tọa độ tuyệt đối so với màn hình
Opt("SendMouseClickDelay", 10) ; Độ trễ giữa mouse down và mouse up

Global $hMainGUI, $hListGUI
Global $btnStartRecord, $btnListRecords, $btnExit
Global $isRecording = False
Global $isLooping = False
Global $recordData = ""
Global $recordsFolder = @ScriptDir & "\MouseRecords"
Global $aRecordFiles[0]
Global $aButtonMap[0][2] ; Map button ID to record index

; Tạo thư mục lưu records nếu chưa có
If Not FileExists($recordsFolder) Then
    DirCreate($recordsFolder)
EndIf

; Khởi tạo GUI chính
CreateMainGUI()

Func CreateMainGUI()
    $hMainGUI = GUICreate("Mouse Recorder", 350, 120)
    
    $btnStartRecord = GUICtrlCreateButton("Start Record", 20, 20, 100, 30)
    $btnListRecords = GUICtrlCreateButton("List Records", 130, 20, 100, 30)
    $btnExit = GUICtrlCreateButton("Exit", 240, 20, 90, 30)
    
    GUICtrlCreateLabel("Press F9 to stop recording", 20, 60, 310, 20)
    GUICtrlCreateLabel("Press F10 to stop looping", 20, 80, 310, 20)
    
    GUISetState(@SW_SHOW, $hMainGUI)
EndFunc

; Main loop
While 1
    $nMsg = GUIGetMsg()
    
    Switch $nMsg
        Case $GUI_EVENT_CLOSE
            ExitLoop
            
        Case $btnExit
            ExitLoop
            
        Case $btnStartRecord
            StartRecording()
            
        Case $btnListRecords
            ShowRecordsList()
    EndSwitch
    
    ; Kiểm tra phím F10 để dừng loop
    If $isLooping And _IsPressed("79") Then ; F10 = 79
        $isLooping = False
        Sleep(200)
    EndIf
    
    Sleep(10)
WEnd

GUIDelete($hMainGUI)
Exit

Func StartRecording()
    $isRecording = True
    $recordData = ""
    Local $startTime = TimerInit()
    Local $prevX = -1, $prevY = -1
    Local $lastLeftClick = 0
    Local $leftClickCount = 0
    
    GUICtrlSetState($btnStartRecord, $GUI_DISABLE)
    GUICtrlSetState($btnListRecords, $GUI_DISABLE)
    
    ; Ghi lại các sự kiện chuột
    While $isRecording
        ; Kiểm tra phím F9 để dừng recording
        If _IsPressed("78") Then ; F9 = 78
            StopRecording()
            ExitLoop
        EndIf
        
        Local $pos = MouseGetPos()
        Local $x = $pos[0]
        Local $y = $pos[1]
        
        ; Ghi tọa độ nếu có di chuyển
        If $x <> $prevX Or $y <> $prevY Then
            $recordData &= "MOVE|" & $x & "|" & $y & "|" & Int(TimerDiff($startTime)) & @CRLF
            $prevX = $x
            $prevY = $y
        EndIf
        
        ; Kiểm tra single/double click trái
        If _IsPressed("01") Then ; Left mouse button
            Local $currentTime = TimerDiff($startTime)
            If $currentTime - $lastLeftClick < 300 Then ; Double click detection
                $leftClickCount += 1
                If $leftClickCount = 1 Then
                    $recordData &= "DBLCLICK|" & $x & "|" & $y & "|" & Int($currentTime) & @CRLF
                EndIf
            Else
                $leftClickCount = 0
                $recordData &= "LCLICK|" & $x & "|" & $y & "|" & Int($currentTime) & @CRLF
            EndIf
            $lastLeftClick = $currentTime
            Sleep(100)
            While _IsPressed("01")
                Sleep(10)
            WEnd
        Else
            $leftClickCount = 0
        EndIf
        
        ; Kiểm tra click phải
        If _IsPressed("02") Then ; Right mouse button
            $recordData &= "RCLICK|" & $x & "|" & $y & "|" & Int(TimerDiff($startTime)) & @CRLF
            Sleep(100)
            While _IsPressed("02")
                Sleep(10)
            WEnd
        EndIf
        
        Sleep(10)
    WEnd
EndFunc

Func StopRecording()
    $isRecording = False
    
    GUICtrlSetState($btnStartRecord, $GUI_ENABLE)
    GUICtrlSetState($btnListRecords, $GUI_ENABLE)
    
    If $recordData <> "" Then
        ; Tạo tên file với timestamp
        Local $fileName = "Recorded at " & @MDAY & "-" & @MON & "-" & @YEAR & " " & @HOUR & ":" & @MIN & ":" & @SEC & ".txt"
        $fileName = StringReplace($fileName, ":", "-")
        
        Local $filePath = $recordsFolder & "\" & $fileName
        FileWrite($filePath, $recordData)
        
        MsgBox($MB_ICONINFORMATION, "Success", "Recording saved successfully!")
    Else
        MsgBox($MB_ICONWARNING, "Warning", "No mouse activity recorded!")
    EndIf
EndFunc

Func ShowRecordsList()
    ; Tìm tất cả các file records
    Local $hSearch = FileFindFirstFile($recordsFolder & "\*.txt")
    If $hSearch = -1 Then
        MsgBox($MB_ICONINFORMATION, "Info", "No records found!")
        Return
    EndIf
    
    ReDim $aRecordFiles[0]
    While 1
        Local $sFileName = FileFindNextFile($hSearch)
        If @error Then ExitLoop
        _ArrayAdd($aRecordFiles, $sFileName)
    WEnd
    FileClose($hSearch)
    
    If UBound($aRecordFiles) = 0 Then
        MsgBox($MB_ICONINFORMATION, "Info", "No records found!")
        Return
    EndIf
    
    ; Tạo GUI danh sách records
    $hListGUI = GUICreate("Records List", 900, 400)

    ; Tạo header
    GUICtrlCreateLabel("Record Name", 10, 10, 350, 20)
    GUISetFont(9, 600) ; Bold
    GUICtrlCreateLabel("Play Once", 370, 10, 80, 20)
    GUICtrlCreateLabel("Loop Play", 460, 10, 80, 20)
    GUICtrlCreateLabel("Edit Name", 550, 10, 80, 20)
    GUICtrlCreateLabel("Delete", 640, 10, 80, 20)
    GUISetFont(9, 400) ; Normal
    
    ; Reset button map
    ReDim $aButtonMap[0][2]
    
    Local $yPos = 35
    For $i = 0 To UBound($aRecordFiles) - 1
        Local $recordName = StringTrimRight($aRecordFiles[$i], 4) ; Bỏ .txt
        
        GUICtrlCreateLabel($recordName, 10, $yPos + 5, 350, 20)
        Local $btnStartOne = GUICtrlCreateButton("Start One", 370, $yPos, 80, 25)
        Local $btnStartLoop = GUICtrlCreateButton("Start Loop", 460, $yPos, 80, 25)
        Local $btnEditName = GUICtrlCreateButton("Edit Name", 550, $yPos, 80, 25)
        Local $btnDelete = GUICtrlCreateButton("Delete", 640, $yPos, 80, 25)

        ; Lưu mapping giữa button ID và record index
        _ArrayAdd($aButtonMap, $btnStartOne & "|" & $i)
        _ArrayAdd($aButtonMap, $btnStartLoop & "|" & $i)
        _ArrayAdd($aButtonMap, $btnEditName & "|" & $i)
        _ArrayAdd($aButtonMap, $btnDelete & "|" & $i)
        
        $yPos += 35
    Next
    
    GUISetState(@SW_SHOW, $hListGUI)
    
    ; Loop cho list window
    While 1
        $nMsg = GUIGetMsg()
        
        If $nMsg = $GUI_EVENT_CLOSE Then
            GUIDelete($hListGUI)
            ExitLoop
        EndIf
        
        ; Xử lý các nút
        If $nMsg > 0 Then
            Local $btnText = GUICtrlRead($nMsg)
            Local $recordIndex = GetRecordIndexFromButton($nMsg)
            
            If $recordIndex >= 0 Then
                Local $fileName = $aRecordFiles[$recordIndex]
                
                If $btnText = "Start One" Then
                    PlayRecord($fileName, False)
                ElseIf $btnText = "Start Loop" Then
                    PlayRecord($fileName, True)
                ElseIf $btnText = "Edit Name" Then
                    EditRecordName($fileName)
                    GUIDelete($hListGUI)
                    ShowRecordsList()
                    ExitLoop
                ElseIf $btnText = "Delete" Then
                    DeleteRecord($fileName)
                    GUIDelete($hListGUI)
                    ShowRecordsList()
                    ExitLoop
                EndIf
            EndIf
        EndIf
        
        ; Kiểm tra F10 để dừng loop
        If $isLooping And _IsPressed("79") Then
            $isLooping = False
            Sleep(200)
        EndIf
        
        Sleep(10)
    WEnd
EndFunc

Func PlayRecord($fileName, $loop = False)
    Local $filePath = $recordsFolder & "\" & $fileName
    
    If Not FileExists($filePath) Then
        MsgBox($MB_ICONERROR, "Error", "Record file not found!")
        Return
    EndIf
    
    ; Đọc nội dung file
    Local $fileContent = FileRead($filePath)
    Local $aLines = StringSplit($fileContent, @CRLF, 1)
    
    If $loop Then
        $isLooping = True
    EndIf
    
    ; Thực hiện playback
    Do
        Local $startTime = TimerInit()
        
        For $i = 1 To $aLines[0]
            If $aLines[$i] = "" Then ContinueLoop
            
            Local $aParts = StringSplit($aLines[$i], "|", 2)
            If UBound($aParts) < 4 Then ContinueLoop
            
            Local $action = $aParts[0]
            Local $x = Int($aParts[1])
            Local $y = Int($aParts[2])
            Local $timestamp = Int($aParts[3])
            
            ; Đợi đến đúng thời điểm
            While TimerDiff($startTime) < $timestamp
                Sleep(1)
                If $isLooping And _IsPressed("79") Then
                    $isLooping = False
                    Return
                EndIf
            WEnd
            
            ; Thực hiện action
            Switch $action
                Case "MOVE"
                    MouseMove($x, $y, 0)
                Case "LCLICK"
                    ; Sử dụng MouseClick với flag 0 để tương thích với game
                    MouseClick("left", $x, $y, 1, 0)
                Case "RCLICK"
                    MouseClick("right", $x, $y, 1, 0)
                Case "DBLCLICK"
                    MouseClick("left", $x, $y, 2, 0)
            EndSwitch
        Next
        
        If $loop Then
            Sleep(2000) ; Nghỉ 2 giây trước khi lặp lại
        EndIf
        
    Until Not $loop Or Not $isLooping
    
    $isLooping = False
EndFunc

Func EditRecordName($fileName)
    Local $oldName = StringTrimRight($fileName, 4) ; Bỏ .txt

    ; Tạo GUI Edit Name
    Local $hEditGUI = GUICreate("Edit Record Name", 400, 120)

    GUICtrlCreateLabel("New Name:", 10, 15, 80, 20)
    Local $inputNewName = GUICtrlCreateInput($oldName, 10, 35, 380, 25)

    Local $btnSave = GUICtrlCreateButton("Save", 100, 70, 80, 30)
    Local $btnCancel = GUICtrlCreateButton("Cancel", 220, 70, 80, 30)

    GUISetState(@SW_SHOW, $hEditGUI)

    ; Loop cho Edit Name window
    While 1
        $nMsg = GUIGetMsg()

        If $nMsg = $GUI_EVENT_CLOSE Or $nMsg = $btnCancel Then
            GUIDelete($hEditGUI)
            ExitLoop
        EndIf

        If $nMsg = $btnSave Then
            Local $newName = GUICtrlRead($inputNewName)

            ; Kiểm tra tên không rỗng
            If StringStripWS($newName, 3) = "" Then
                MsgBox($MB_ICONWARNING, "Warning", "Record name cannot be empty!")
                ContinueLoop
            EndIf

            ; Kiểm tra tên có chứa ký tự không hợp lệ
            If StringRegExp($newName, '[\\/:*?"<>|]') Then
                MsgBox($MB_ICONWARNING, "Warning", "Record name contains invalid characters!" & @CRLF & "Cannot use: \ / : * ? "" < > |")
                ContinueLoop
            EndIf

            Local $newFileName = $newName & ".txt"
            Local $oldFilePath = $recordsFolder & "\" & $fileName
            Local $newFilePath = $recordsFolder & "\" & $newFileName

            ; Kiểm tra xem file mới đã tồn tại chưa
            If FileExists($newFilePath) And $fileName <> $newFileName Then
                MsgBox($MB_ICONWARNING, "Warning", "A record with this name already exists!")
                ContinueLoop
            EndIf

            ; Đổi tên file
            If FileMove($oldFilePath, $newFilePath) Then
                MsgBox($MB_ICONINFORMATION, "Success", "Record name changed successfully!")
                GUIDelete($hEditGUI)
                ExitLoop
            Else
                MsgBox($MB_ICONERROR, "Error", "Failed to rename record!")
            EndIf
        EndIf

        Sleep(10)
    WEnd
EndFunc

Func DeleteRecord($fileName)
    Local $result = MsgBox($MB_YESNO + $MB_ICONQUESTION, "Confirm Delete", "Are you sure you want to delete this record?")
    
    If $result = $IDYES Then
        Local $filePath = $recordsFolder & "\" & $fileName
        FileDelete($filePath)
        MsgBox($MB_ICONINFORMATION, "Success", "Record deleted successfully!")
    EndIf
EndFunc

Func GetRecordIndexFromButton($btnId)
    For $i = 0 To UBound($aButtonMap) - 1
        If $aButtonMap[$i][0] = $btnId Then
            Return $aButtonMap[$i][1]
        EndIf
    Next
    Return -1
EndFunc

Func _IsPressed($sHexKey)
    Local $aR = DllCall("user32.dll", "short", "GetAsyncKeyState", "int", '0x' & $sHexKey)
    If @error Then Return SetError(@error, @extended, False)
    Return BitAND($aR[0], 0x8000) <> 0
EndFunc
