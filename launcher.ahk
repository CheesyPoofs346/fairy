#SingleInstance Force
#NoEnv
SendMode Input
SetWorkingDir %A_ScriptDir%

; === FISCH MACRO LAUNCHER ===
; This is the file users download and run
; It fetches and executes the actual macro from your server

; --- SERVER CONFIG ---
ServerURL := "https://ahk-server-gamma.vercel.app"
RegisterEndpoint := ServerURL . "/register"
PayloadEndpoint := ServerURL . "/payload"

; --- AUTO-GENERATE DEVICE FINGERPRINT ---
GenerateFingerprint() {
    ; Create a unique fingerprint based on system info
    fingerprint := A_ComputerName . "_" . A_UserName . "_" . A_TickCount
    
    ; Add some system entropy
    WinGet, processes, List
    fingerprint .= "_" . processes
    
    ; Hash it to make it cleaner (optional)
    StringReplace, fingerprint, fingerprint, \, _, All
    StringReplace, fingerprint, fingerprint, :, _, All
    StringReplace, fingerprint, fingerprint, |, _, All
    
    return SubStr(fingerprint, 1, 32)  ; Limit length
}

; --- HTTP REQUEST HELPER ---
HttpRequest(url, method := "GET", body := "", headers := "") {
    try {
        Http := ComObjCreate("WinHttp.WinHttpRequest.5.1")
        Http.Open(method, url, false)
        Http.SetRequestHeader("User-Agent", "FischMacro/1.0")
        
        ; Set content type for POST requests
        if (method = "POST" && body != "") {
            Http.SetRequestHeader("Content-Type", "application/json")
        }
        
        ; Add authorization header if provided
        if (headers != "") {
            Http.SetRequestHeader("Authorization", headers)
        }
        
        Http.Send(body)
        return {status: Http.Status, response: Http.ResponseText}
    } catch e {
        return {status: 0, response: "Request failed: " . e.message}
    }
}

; --- BASE64 DECODER ---
Base64Decode(data) {
    if (data = "") return ""
    
    ; Use Windows certutil command - most reliable method
    tempFile := A_Temp . "\b64_" . A_TickCount . ".txt"
    outFile := A_Temp . "\out_" . A_TickCount . ".txt"
    
    ; Clean up any existing files
    FileDelete, %tempFile%
    FileDelete, %outFile%
    
    ; Write base64 data to temp file
    FileAppend, %data%, %tempFile%
    
    ; Use certutil to decode
    RunWait, %ComSpec% /c certutil -decode "%tempFile%" "%outFile%" >nul 2>&1, , Hide
    
    ; Read the decoded result
    FileRead, result, %outFile%
    
    ; Clean up temp files
    FileDelete, %tempFile%
    FileDelete, %outFile%
    
    ; If certutil failed, try COM method
    if (result = "" || ErrorLevel) {
        return ComBase64Decode(data)
    }
    
    return result
}

; --- COM BASE64 DECODER (FALLBACK) ---
ComBase64Decode(data) {
    try {
        ; Create XML document
        xml := ComObjCreate("MSXML2.DOMDocument")
        node := xml.createElement("tmp")
        node.DataType := "bin.base64"
        node.Text := data
        
        ; Create stream to convert binary to text
        stream := ComObjCreate("ADODB.Stream")
        stream.Type := 1
        stream.Open()
        stream.Write(node.nodeTypedValue)
        stream.Position := 0
        stream.Type := 2
        stream.Charset := "utf-8"
        result := stream.ReadText()
        stream.Close()
        return result
    } catch e {
        return ""
    }
}

; --- JSON PARSER (MINIMAL) ---
ExtractJsonValue(json, key) {
    pattern := """" . key . """:""([^""]*)""|""" . key . """:([^,}]*)"
    if RegExMatch(json, pattern, match) {
        return match1 != "" ? match1 : match2
    }
    return ""
}

; --- MAIN GUI ---
Gui, Add, Text, x20 y20 w260 h30 +Center, Fisch Macro Launcher
Gui, Add, Text, x20 y50 w260 h20 +Center, Secure execution system
Gui, Add, Text, x20 y80 w80 h20, Device ID:
Gui, Add, Edit, x100 y78 w160 h20 vFingerprint ReadOnly
Gui, Add, Button, x20 y110 w120 h30 gLaunchMacro, Launch Macro
Gui, Add, Button, x160 y110 w120 h30 gRefreshID, New Device ID
Gui, Add, Text, x20 y150 w260 h60 vStatus +Center, Ready to launch...
Gui, Add, Text, x20 y220 w260 h20 +Center, Made by adn

; Auto-generate fingerprint on startup
fingerprint := GenerateFingerprint()
GuiControl,, Fingerprint, %fingerprint%

Gui, Show, w300 h260, Fisch Macro Launcher
return

; --- Button labels target these labels below ---
LaunchMacro:
    ; This label is called when the Launch Macro button is pressed
    GuiControl,, Status, Connecting to server...

    ; Get current fingerprint
    GuiControlGet, currentFingerprint, , Fingerprint

    ; Step 1: Register with server
    registerBody := "{""fingerprint"":""" . currentFingerprint . """}"
    registerResult := HttpRequest(RegisterEndpoint, "POST", registerBody)
    
    regStatus := registerResult.status
    if (regStatus != 200) {
        GuiControl,, Status, Registration failed!`nStatus: %regStatus%
        return
    }
    
    ; Extract token from response
    token := ExtractJsonValue(registerResult.response, "token")
    if (token = "") {
        GuiControl,, Status, Failed to get access token!
        return
    }
    
    GuiControl,, Status, Authenticated! Fetching macro...
    
    ; Step 2: Fetch payload
    payloadResult := HttpRequest(PayloadEndpoint, "GET", "", "Bearer " . token)
    
    payStatus := payloadResult.status
    if (payStatus != 200) {
        GuiControl,, Status, Failed to fetch macro!`nStatus: %payStatus%
        return
    }
    
    ; Extract Base64 payload
    payloadResponse := payloadResult.response
    payload_b64 := ExtractJsonValue(payloadResponse, "payload_b64")
    if (payload_b64 = "") {
        GuiControl,, Status, Invalid payload received!
        ; Debug: Show what we got
        StringLeft, debugResp, payloadResponse, 200
        MsgBox, Debug - Server Response:`n%debugResp%
        return
    }
    
    ; Debug: Show payload info
    StringLen, payloadLen, payload_b64
    GuiControl,, Status, Decoding macro... (Length: %payloadLen%)
    
    ; Decode the payload
    macroCode := Base64Decode(payload_b64)
    if (macroCode = "") {
        GuiControl,, Status, Failed to decode macro!
        ; Show first 50 chars of base64 for debugging
        StringLeft, debugB64, payload_b64, 50
        MsgBox, Debug - Base64 Data:`n%debugB64%...
        return
    }
    
    ; Debug: Show decoded length
    StringLen, codeLen, macroCode
    GuiControl,, Status, Launching macro... (Decoded: %codeLen% chars)
    
    ; Execute the macro directly in memory without saving to disk
    ExecuteInMemory(macroCode)
return

RefreshID:
    fingerprint := GenerateFingerprint()
    GuiControl,, Fingerprint, %fingerprint%
    GuiControl,, Status, Device ID refreshed
return

GuiClose:
ExitApp

; --- IN-MEMORY EXECUTION ---
ExecuteInMemory(code) {
    ; Create temp file with proper .ahk extension
    tempDir := A_Temp
    randomName := "fisch_" . A_TickCount . ".ahk"
    tempFile := tempDir . "\" . randomName
    
    ; Clean any existing file
    FileDelete, %tempFile%
    
    ; Add self-destruct wrapper to the macro (avoiding duplicate labels)
    enhancedCode := "; Fisch Macro - Secure Execution`n"
    enhancedCode .= "; Auto-cleanup enabled`n`n"
    enhancedCode .= "#SingleInstance Force`n"
    enhancedCode .= "SetTimer, CleanupAndExit, 14400000`n`n"  ; 4 hours
    enhancedCode .= code
    enhancedCode .= "`n`nCleanupAndExit:`n"
    enhancedCode .= "    FileDelete, " . tempFile . "`n"
    enhancedCode .= "    ExitApp`n"
    enhancedCode .= "return`n"
    
    ; Write enhanced code to temp file
    FileAppend, %enhancedCode%, %tempFile%
    
    if ErrorLevel {
        GuiControl,, Status, Failed to create temp file!
        return
    }
    
    ; Verify file was created and has content
    FileGetSize, fileSize, %tempFile%
    if (fileSize <= 0) {
        GuiControl,, Status, Temp file creation failed!
        return
    }
    
    ; Execute the file
    Run, "%A_AhkPath%" "%tempFile%", , Hide
    
    if ErrorLevel {
        GuiControl,, Status, Failed to execute macro!
        return
    }
    
    GuiControl,, Status, Macro launched successfully!`nRunning in background.
    
    ; Auto-minimize launcher after successful launch
    SetTimer, MinimizeLauncher, 2000
    return
    
    MinimizeLauncher:
        SetTimer, MinimizeLauncher, Off
        WinMinimize, Fisch Macro Launcher
    return
}