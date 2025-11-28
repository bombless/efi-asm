; 独立 UEFI Hello World - 带地址打印功能
; 编译: nasm -f bin hello_efi.asm -o hello.efi

BITS 64

; ==================== DOS Header ====================
section .header progbits start=0 vstart=0

dos_header:
    dw 0x5A4D                   ; MZ 签名
    times 58 db 0               ; DOS stub 填充
    dd pe_header                ; PE 头偏移 (0x3C 位置)

; ==================== PE Header ====================
align 8
pe_header:
    dd 0x00004550               ; "PE\0\0" 签名

; COFF File Header
coff_header:
    dw 0x8664                   ; Machine: x86-64
    dw 1                        ; NumberOfSections
    dd 0                        ; TimeDateStamp
    dd 0                        ; PointerToSymbolTable
    dd 0                        ; NumberOfSymbols
    dw optional_header_size     ; SizeOfOptionalHeader
    dw 0x0022                   ; Characteristics: EXECUTABLE_IMAGE | LARGE_ADDRESS_AWARE

; Optional Header (PE32+)
optional_header:
    dw 0x020B                   ; Magic: PE32+
    db 0, 0                     ; Linker version
    dd code_size                ; SizeOfCode
    dd 0                        ; SizeOfInitializedData
    dd 0                        ; SizeOfUninitializedData
    dd code_start               ; AddressOfEntryPoint
    dd code_start               ; BaseOfCode
    
    ; PE32+ specific
    dq 0x00100000               ; ImageBase
    dd 0x1000                   ; SectionAlignment
    dd 0x200                    ; FileAlignment
    dw 0, 0                     ; OS version
    dw 0, 0                     ; Image version
    dw 0, 0                     ; Subsystem version
    dd 0                        ; Win32VersionValue
    dd image_size               ; SizeOfImage
    dd header_size              ; SizeOfHeaders
    dd 0                        ; CheckSum
    dw 10                       ; Subsystem: EFI Application
    dw 0                        ; DllCharacteristics
    dq 0x10000                  ; SizeOfStackReserve
    dq 0x10000                  ; SizeOfStackCommit
    dq 0x10000                  ; SizeOfHeapReserve
    dq 0x10000                  ; SizeOfHeapCommit
    dd 0                        ; LoaderFlags
    dd 0                        ; NumberOfRvaAndSizes

optional_header_size equ $ - optional_header

; Section Table
section_table:
    db ".text", 0, 0, 0         ; Name
    dd code_size                ; VirtualSize
    dd code_start               ; VirtualAddress
    dd code_size                ; SizeOfRawData
    dd code_start               ; PointerToRawData
    dd 0                        ; PointerToRelocations
    dd 0                        ; PointerToLinenumbers
    dw 0                        ; NumberOfRelocations
    dw 0                        ; NumberOfLinenumbers
    dd 0x60000020               ; Characteristics: CODE | EXECUTE | READ

header_size equ ($ - $$  + 0x1FF) & ~0x1FF

; ==================== Code Section ====================
align 512
code_section:
code_start equ $ - $$


;------------------------------------------------------------------------------
; MACRO: RNG - Random Number Generator
;------------------------------------------------------------------------------
%macro RNG 0
    mov rcx, 0x10
%%getrnd:
    rdrand rax
    jnc %%retryrng
    jmp %%exitrng
%%retryrng:
    loop %%getrnd
%%exitrng:
%endmacro

;------------------------------------------------------------------------------
; MACRO: OUTPUT64BITNUMBER - Output 64-bit number in RAX
; Parameter: 0 = with newline, other = without
;------------------------------------------------------------------------------
%macro OUTPUT64BITNUMBER 1
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi
    
    mov rcx, 0x3F
    lea rbx, [rel BUFFER]
    lea rdx, [rel bMessage]
%%clearloop:
    mov byte [rbx + rcx], 0
    mov byte [rdx + rcx], 0
    loop %%clearloop

    xor rcx, rcx
    mov rsi, 10
%%convertloop:
    xor rdx, rdx
    div rsi
    add dl, 0x30
    mov [rbx + rcx], dl
    inc rcx
    test rax, rax
    jnz %%convertloop

    lea rdi, [rel bMessage]
%%reverseloop:
    dec rcx
    mov al, [rbx + rcx]
    mov byte [rdi], al
    inc rdi
    inc rdi
    test rcx, rcx
    jnz %%reverseloop
    
    mov al, %1
    cmp al, 0
    jnz %%write64
    mov byte [rdi], 13
    mov byte [rdi + 2], 10
%%write64:
    mov rcx, [rel conOut]
    lea rdx, [rel bMessage]
    call [rel OutputString]
    
    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
%endmacro

;------------------------------------------------------------------------------
; MACRO: GETUEFIFUNCTIONS
;------------------------------------------------------------------------------
%macro GETUEFIFUNCTIONS 0
    ; RDX = SystemTable
    mov rax, qword [rdx + 0x30]     ; ConIn
    mov [rel conIn], rax
    mov rax, qword [rdx + 0x40]     ; ConOut
    mov [rel conOut], rax
    mov rax, qword [rdx + 0x58]     ; RuntimeServices
    mov [rel RuntimeServices], rax
    mov rax, qword [rdx + 0x60]     ; BootServices
    mov [rel BootServices], rax
    
    mov rax, [rel conOut]
    mov r8, qword [rax + 0x08]
    mov [rel OutputString], r8
    mov r8, qword [rax + 0x38]
    mov [rel SetCursorPosition], r8
    
    mov rax, [rel BootServices]
    mov r8, qword [rax + 0x28]
    mov [rel AllocatePages], r8
    mov r8, qword [rax + 0x60]
    mov [rel WaitForEvent], r8
    mov r8, qword [rax + 0x138]
    mov [rel LocateHandleBuffer], r8
    mov r8, qword [rax + 0x140]
    mov [rel LocateProtocol], r8
    
    mov rax, [rel conIn]
    mov r8, qword [rax + 0x08]
    mov [rel ReadKeyStroke], r8
    mov r8, qword [rax + 0x10]
    mov [rel WaitForKey], r8
    
    mov rax, [rel RuntimeServices]
    mov r8, qword [rax + 0x18]
    mov [rel getTime], r8
    
    ; Locate TextInputEX
    lea rcx, [rel TextInputExGUID]
    xor rdx, rdx
    lea r8, [rel TextInputEX]
    call [rel LocateProtocol]
    OUTPUT64BITNUMBER 0
    
    mov rax, [rel TextInputEX]
    mov r8, qword [rax + 0x20]
    mov [rel RegisterKeyNotify], r8

    ; Locate GraphicsOutputProtocol
    lea rcx, [rel GraphicsOutputGUID]
    xor rdx, rdx
    lea r8, [rel GOP]
    call [rel LocateProtocol]
    OUTPUT64BITNUMBER 0
    
    mov rax, [rel GOP]
    mov r8, qword [rax]
    mov [rel queryMode], r8
    mov r8, qword [rax + 0x08]
    mov [rel setMode], r8
    mov r8, qword [rax + 0x10]
    mov [rel BLT], r8
    mov r8, qword [rax + 0x18]
    mov [rel mode], r8
    lea rax, [rel mode]
    mov rbx, [rax]
    mov eax, [rbx]
    mov dword [rel maxMode], eax
    
    ; Locate MPServicesProtocol
    lea rcx, [rel MPServicesGUID]
    xor rdx, rdx
    lea r8, [rel MPServices]
    call [rel LocateProtocol]
    OUTPUT64BITNUMBER 0
    
    mov rax, [rel MPServices]
    mov r8, qword [rax]
    mov [rel GetNumberOfAP], r8
    mov r8, qword [rax + 0x10]
    mov [rel StartupAllAPs], r8
    mov r8, qword [rax + 0x18]
    mov [rel StartupThisAP], r8
    mov r8, qword [rax + 0x28]
    mov [rel EnableDisableAP], r8
    
    mov rcx, [rel conOut]
    lea rdx, [rel mouseMessage]
    call [rel OutputString]
    
    ; Locate SIMPLEPOINTER
    lea rcx, [rel SIMPLEPOINTERGUID]
    xor rdx, rdx
    lea r8, [rel SIMPLEPOINTER]
    call [rel LocateProtocol]
    OUTPUT64BITNUMBER 0
    
    mov rax, [rel SIMPLEPOINTER]
    mov r8, qword [rax + 0x08]
    mov [rel POINTERGETSTATESMP], r8
    mov r8, qword [rax + 0x18]
    mov [rel POINTERMODE], r8
%endmacro

;------------------------------------------------------------------------------
; MACRO: ESTIMATECYCLESFORFPS
;------------------------------------------------------------------------------
%macro ESTIMATECYCLESFORFPS 0
    lea rcx, [rel time]
    lea rdx, [rel EFI_TIME_CAPABILITIES]
    call [rel getTime]
    mov al, byte [rel time + 0x06]
    mov byte [rel SECONDS], al
%%waitfornextsecond:
    lea rcx, [rel time]
    lea rdx, [rel EFI_TIME_CAPABILITIES]
    call [rel getTime]
    mov al, byte [rel time + 0x06]
    cmp al, byte [rel SECONDS]
    jz %%waitfornextsecond
    mov byte [rel SECONDS], al
    mov byte [rel S1], al
    
    rdtsc
    mov dword [rel TSC_PS], eax
    mov dword [rel TSC_PS + 0x04], edx
%%waitfornextsecond2:
    lea rcx, [rel time]
    lea rdx, [rel EFI_TIME_CAPABILITIES]
    call [rel getTime]
    mov al, byte [rel time + 0x06]
    cmp al, byte [rel SECONDS]
    jz %%waitfornextsecond2
    mov byte [rel S2], al
    
    rdtsc
    shl rdx, 0x20
    or rax, rdx
    sub rax, [rel TSC_PS]
    mov qword [rel TSC_PS2], rax
    
    shr rax, 0x07       ; Divide by 128 for ~128 FPS
    mov qword [rel CYCLESPERFRAME], rax
%endmacro

;------------------------------------------------------------------------------
; MACRO: SETUPKEYNOTIFICATIONS
;------------------------------------------------------------------------------
%macro SETUPKEYNOTIFICATIONS 0
    ; W key (up)
    mov rcx, [rel TextInputEX]
    lea rdx, [rel WkeyDescriptor]
    lea r8, [rel KeyNotificationCallbackFunctionUp]
    lea r9, [rel WkeyNotifyHandle]
    call [rel RegisterKeyNotify]
    
    mov rcx, [rel TextInputEX]
    lea rdx, [rel littleWkeyDescriptor]
    lea r8, [rel KeyNotificationCallbackFunctionUp]
    lea r9, [rel littleWkeyNotifyHandle]
    call [rel RegisterKeyNotify]
    
    mov rcx, [rel TextInputEX]
    lea rdx, [rel upkeyDescriptor]
    lea r8, [rel KeyNotificationCallbackFunctionUp]
    lea r9, [rel upkeyNotifyHandle]
    call [rel RegisterKeyNotify]
    
    ; S key (down)
    mov rcx, [rel TextInputEX]
    lea rdx, [rel SkeyDescriptor]
    lea r8, [rel KeyNotificationCallbackFunctionDown]
    lea r9, [rel SkeyNotifyHandle]
    call [rel RegisterKeyNotify]
    
    mov rcx, [rel TextInputEX]
    lea rdx, [rel littleSkeyDescriptor]
    lea r8, [rel KeyNotificationCallbackFunctionDown]
    lea r9, [rel littleSkeyNotifyHandle]
    call [rel RegisterKeyNotify]
    
    mov rcx, [rel TextInputEX]
    lea rdx, [rel downkeyDescriptor]
    lea r8, [rel KeyNotificationCallbackFunctionDown]
    lea r9, [rel downkeyNotifyHandle]
    call [rel RegisterKeyNotify]
    
    ; A key (left)
    mov rcx, [rel TextInputEX]
    lea rdx, [rel AkeyDescriptor]
    lea r8, [rel KeyNotificationCallbackFunctionLeft]
    lea r9, [rel AkeyNotifyHandle]
    call [rel RegisterKeyNotify]
    
    mov rcx, [rel TextInputEX]
    lea rdx, [rel littleAkeyDescriptor]
    lea r8, [rel KeyNotificationCallbackFunctionLeft]
    lea r9, [rel littleAkeyNotifyHandle]
    call [rel RegisterKeyNotify]
    
    mov rcx, [rel TextInputEX]
    lea rdx, [rel leftkeyDescriptor]
    lea r8, [rel KeyNotificationCallbackFunctionLeft]
    lea r9, [rel leftkeyNotifyHandle]
    call [rel RegisterKeyNotify]
    
    ; D key (right)
    mov rcx, [rel TextInputEX]
    lea rdx, [rel DkeyDescriptor]
    lea r8, [rel KeyNotificationCallbackFunctionRight]
    lea r9, [rel DkeyNotifyHandle]
    call [rel RegisterKeyNotify]
    
    mov rcx, [rel TextInputEX]
    lea rdx, [rel littleDkeyDescriptor]
    lea r8, [rel KeyNotificationCallbackFunctionRight]
    lea r9, [rel littleDkeyNotifyHandle]
    call [rel RegisterKeyNotify]
    
    mov rcx, [rel TextInputEX]
    lea rdx, [rel rightkeyDescriptor]
    lea r8, [rel KeyNotificationCallbackFunctionRight]
    lea r9, [rel rightkeyNotifyHandle]
    call [rel RegisterKeyNotify]
    
    ; Fire keys (Z, ?, /, space)
    mov rcx, [rel TextInputEX]
    lea rdx, [rel ZkeyDescriptor]
    lea r8, [rel KeyNotificationCallbackFunctionFire]
    lea r9, [rel ZkeyNotifyHandle]
    call [rel RegisterKeyNotify]
    
    mov rcx, [rel TextInputEX]
    lea rdx, [rel littleZkeyDescriptor]
    lea r8, [rel KeyNotificationCallbackFunctionFire]
    lea r9, [rel littleZkeyNotifyHandle]
    call [rel RegisterKeyNotify]
    
    mov rcx, [rel TextInputEX]
    lea rdx, [rel spacekeyDescriptor]
    lea r8, [rel KeyNotificationCallbackFunctionFire]
    lea r9, [rel spacekeyNotifyHandle]
    call [rel RegisterKeyNotify]
%endmacro

;------------------------------------------------------------------------------
; MACRO: KEYLOGIC
;------------------------------------------------------------------------------
%macro KEYLOGIC 0
    ; UP COUNT
    xor rax, rax
    mov al, byte [rel KEYTIMERUP]
    cmp al, 0
    jz %%afterupcount
    dec byte [rel KEYTIMERUP]
    jnz %%afterupcount
    mov byte [rel PRESSEDUP], 0
%%afterupcount:
    ; DOWN COUNT
    xor rax, rax
    mov al, byte [rel KEYTIMERDOWN]
    cmp al, 0
    jz %%afterdowncount
    dec byte [rel KEYTIMERDOWN]
    jnz %%afterdowncount
    mov byte [rel PRESSEDDOWN], 0
%%afterdowncount:
    ; LEFT COUNT
    xor rax, rax
    mov al, byte [rel KEYTIMERLEFT]
    cmp al, 0
    jz %%afterleftcount
    dec byte [rel KEYTIMERLEFT]
    jnz %%afterleftcount
    mov byte [rel PRESSEDLEFT], 0
%%afterleftcount:
    ; RIGHT COUNT
    xor rax, rax
    mov al, byte [rel KEYTIMERRIGHT]
    cmp al, 0
    jz %%afterrightcount
    dec byte [rel KEYTIMERRIGHT]
    jnz %%afterrightcount
    mov byte [rel PRESSEDRIGHT], 0
%%afterrightcount:
    ; FIRE COUNT
    xor rax, rax
    mov al, byte [rel KEYTIMERFIRE]
    cmp al, 0
    jz %%afterfirecount
    dec byte [rel KEYTIMERFIRE]
    jnz %%afterfirecount
    mov byte [rel PRESSEDFIRE], 0
%%afterfirecount:
%endmacro

;------------------------------------------------------------------------------
; MACRO: POINTERLOGIC
;------------------------------------------------------------------------------
%macro POINTERLOGIC 0
    mov rcx, [rel SIMPLEPOINTER]
    lea rdx, [rel POINTERSTATE]
    call [rel POINTERGETSTATESMP]
    cmp rax, 0
    jnz %%endpointerlogic
    
    xor rax, rax
    mov al, byte [rel POINTERSTATE + 0x0C]
    mov byte [rel POINTERBUTTON], al
    xor rax, rax
    mov al, byte [rel POINTERSTATE + 0x0D]
    mov byte [rel POINTERBUTTON + 0x08], al
    
    mov al, byte [rel POINTERBUTTON]
    cmp al, 1
    jz %%setpointerx
    mov rax, 600
    mov qword [rel POINTERLOC], rax
    mov qword [rel POINTERLOC + 0x08], rax
    jmp %%endpointerlogic
    
%%setpointerx:
    mov r8, [rel POINTERMODE]
    xor rax, rax
    xor rdx, rdx
    mov eax, dword [rel POINTERSTATE]
    movsxd rax, eax
    mov rbx, [r8]
    cqo
    idiv rbx
    mov rbx, qword [rel POINTERLOC]
    add rax, rbx
    cmp rax, MAXX
    ja %%setpointery
    cmp rax, MINX
    jb %%setpointery
    mov qword [rel POINTERLOC], rax
    
%%setpointery:
    xor rax, rax
    xor rdx, rdx
    mov eax, dword [rel POINTERSTATE + 0x04]
    movsxd rax, eax
    mov rbx, [r8 + 0x08]
    cqo
    idiv rbx
    mov rbx, qword [rel POINTERLOC + 0x08]
    add rax, rbx
    cmp rax, MAXY
    ja %%endpointerlogic
    cmp rax, MINY
    jb %%endpointerlogic
    mov qword [rel POINTERLOC + 0x08], rax
    
%%endpointerlogic:
    mov al, byte [rel POINTERBUTTON + 0x08]
    mov byte [rel POINTERFIRE], al
    
    xor rax, rax
    mov dword [rel POINTERLEFT], eax
    
    mov rax, qword [rel POINTERLOC]
    cmp rax, TRIGGERLOW
    jb %%setpleft
    cmp rax, TRIGGERHIGH
    jb %%checkpointerupdown
    inc byte [rel POINTERRIGHT]
    jmp %%checkpointerupdown
%%setpleft:
    inc byte [rel POINTERLEFT]
%%checkpointerupdown:
    mov rax, qword [rel POINTERLOC + 0x08]
    cmp rax, TRIGGERLOW
    jb %%setpup
    cmp rax, TRIGGERHIGH
    jb %%afterpointerset
    inc byte [rel POINTERDOWN]
    jmp %%afterpointerset
%%setpup:
    inc byte [rel POINTERUP]
%%afterpointerset:
%endmacro

;------------------------------------------------------------------------------
; MACRO: RESETCONSOLEPOSITION
;------------------------------------------------------------------------------
%macro RESETCONSOLEPOSITION 0
    mov rcx, [rel conOut]
    mov rdx, 0
    mov r8, 0
    call [rel SetCursorPosition]
%endmacro

;------------------------------------------------------------------------------
; MACRO: BLTRECT - Draw filled rectangle
;------------------------------------------------------------------------------
%macro BLTRECT 6  ; sourceX, sourceY, destX, destY, W, H
    mov rcx, [rel GOP]
    mov r8, 0           ; EfiBltVideoFill
    mov r9, %1          ; sourceX
    push 0              ; delta
    push %6             ; H
    push %5             ; W
    push %4             ; destY
    push %3             ; destX
    push %2             ; sourceY
    sub rsp, 0x20
    call [rel BLT]
    add rsp, 0x20
    add rsp, 0x30
%endmacro

;------------------------------------------------------------------------------
; MACRO: BLTBUFF - BLT buffer to video
;------------------------------------------------------------------------------
%macro BLTBUFF 6  ; sourceX, sourceY, destX, destY, W, H
    mov rcx, [rel GOP]
    ; RDX already has buffer pointer
    mov r8, 2           ; EfiBltBufferToVideo
    mov r9, %1          ; sourceX
    push 0              ; delta
    push %6             ; H
    push %5             ; W
    push %4             ; destY
    push %3             ; destX
    push %2             ; sourceY
    sub rsp, 0x20
    call [rel BLT]
    add rsp, 0x20
    add rsp, 0x30
%endmacro


; EfiMain(ImageHandle, SystemTable)
EfiMain:

    ; Save parameters
    mov [rel imageHandle], rcx
    mov [rel systemTable], rdx
    
    ; Get UEFI functions
    GETUEFIFUNCTIONS
    
    ; Reset console
    RESETCONSOLEPOSITION
    
    ; Output hello message
    mov rcx, [rel conOut]
    lea rdx, [rel helloMessage]
    call [rel OutputString]
    
    ; Read time
    lea rcx, [rel time]
    lea rdx, [rel EFI_TIME_CAPABILITIES]
    call [rel getTime]
    
    ; Output cycles message
    mov rcx, [rel conOut]
    lea rdx, [rel cyclesMessage]
    call [rel OutputString]
    
    ; Estimate cycles for FPS
    ESTIMATECYCLESFORFPS
    mov rax, qword [rel CYCLESPERFRAME]
    OUTPUT64BITNUMBER 0
    
    ; Store initial seconds
    mov al, byte [rel time + 0x06]
    mov byte [rel SECONDS], al
    
    ; Setup key notifications
    SETUPKEYNOTIFICATIONS
    
    ; Initialize title (would call INITTITLE macro)
    mov qword [rel TITLEON], 1
    
    ; Set initial frame time
    rdtsc
    shl rdx, 0x20
    or rax, rdx
    add rax, [rel CYCLESPERFRAME]
    mov [rel NEXTFRAME_AT], rax

.waitnextframe:
    rdtsc
    shl rdx, 0x20
    or rax, rdx
    cmp [rel NEXTFRAME_AT], rax
    ja .waitnextframe
    add rax, [rel CYCLESPERFRAME]
    mov [rel NEXTFRAME_AT], rax

.runframe:
    mov rax, [rel TITLEON]
    cmp al, 0
    jz .aftertitle
    
    KEYLOGIC
    POINTERLOGIC
    ; TITLELOGIC would go here
    jmp .waitnextframe

.aftertitle:
    RESETCONSOLEPOSITION
    KEYLOGIC
    POINTERLOGIC
    
    mov rax, [rel PAUSEGAME]
    cmp rax, 0
    jnz .aftergamelogic
    ; GAMELOGIC would go here
.aftergamelogic:
    mov rax, [rel TITLEON]
    cmp rax, 1
    jz .afterhitbox
    ; RENDERGRAPHICS would go here
    mov rax, [rel SHOW_HITBOX]
    cmp rax, 1
    jnz .afterhitbox
    ; RENDERHITBOXES would go here
.afterhitbox:
    
    ; Check FPS
    inc qword [rel FRAMECOUNT]
    lea rcx, [rel time]
    lea rdx, [rel EFI_TIME_CAPABILITIES]
    call [rel getTime]
    mov al, byte [rel time + 0x06]
    cmp al, byte [rel SECONDS]
    jz .outputfps
    mov rax, qword [rel FRAMECOUNT]
    mov [rel FRAMERATE], rax
    mov qword [rel FRAMECOUNT], 0
.outputfps:
    mov rcx, [rel conOut]
    lea rdx, [rel fpsMessage]
    call [rel OutputString]
    mov rax, [rel FRAMERATE]
    OUTPUT64BITNUMBER 0
    
    jmp .waitnextframe

.waitevent:
    mov rcx, 1
    lea rdx, [rel WaitForKey]
    lea r8, [rel index]
    call [rel WaitForEvent]
    
    mov rcx, [rel conIn]
    lea rdx, [rel key]
    call [rel ReadKeyStroke]
    
    mov rcx, [rel conOut]
    lea rdx, [rel endMessage]
    call [rel OutputString]
    
    mov rcx, 1
    lea rdx, [rel WaitForKey]
    lea r8, [rel index]
    call [rel WaitForEvent]
    
    xor rax, rax        ; EFI_SUCCESS
    ret
    


;------------------------------------------------------------------------------
; Key Callback Functions
;------------------------------------------------------------------------------
KeyNotificationCallbackFunctionUp:
    xor rax, rax
    mov al, byte [rel KEYTIMERUP]
    cmp al, 0
    jz .setfirsttimer
    mov byte [rel KEYTIMERUP], SECONDKEYTIMELIMIT
    jmp .exit
.setfirsttimer:
    mov byte [rel KEYTIMERUP], FIRSTKEYTIMELIMIT
    mov byte [rel PRESSEDUP], 1
.exit:
    ret

KeyNotificationCallbackFunctionDown:
    xor rax, rax
    mov al, byte [rel KEYTIMERDOWN]
    cmp al, 0
    jz .setfirsttimer
    mov byte [rel KEYTIMERDOWN], SECONDKEYTIMELIMIT
    jmp .exit
.setfirsttimer:
    mov byte [rel KEYTIMERDOWN], FIRSTKEYTIMELIMIT
    mov byte [rel PRESSEDDOWN], 1
.exit:
    ret

KeyNotificationCallbackFunctionLeft:
    xor rax, rax
    mov al, byte [rel KEYTIMERLEFT]
    cmp al, 0
    jz .setfirsttimer
    mov byte [rel KEYTIMERLEFT], SECONDKEYTIMELIMIT
    jmp .exit
.setfirsttimer:
    mov byte [rel KEYTIMERLEFT], FIRSTKEYTIMELIMIT
    mov byte [rel PRESSEDLEFT], 1
.exit:
    ret

KeyNotificationCallbackFunctionRight:
    xor rax, rax
    mov al, byte [rel KEYTIMERRIGHT]
    cmp al, 0
    jz .setfirsttimer
    mov byte [rel KEYTIMERRIGHT], SECONDKEYTIMELIMIT
    jmp .exit
.setfirsttimer:
    mov byte [rel KEYTIMERRIGHT], FIRSTKEYTIMELIMIT
    mov byte [rel PRESSEDRIGHT], 1
.exit:
    ret

KeyNotificationCallbackFunctionFire:
    xor rax, rax
    mov al, byte [rel KEYTIMERFIRE]
    cmp al, 0
    jz .setfirsttimer
    mov byte [rel KEYTIMERFIRE], SECONDKEYTIMELIMIT
    jmp .exit
.setfirsttimer:
    mov byte [rel KEYTIMERFIRE], FIRSTKEYTIMELIMIT
    mov byte [rel PRESSEDFIRE], 1
.exit:
    ret

;------------------------------------------------------------------------------
; PARALLELRENDERTOSCREEN - Parallel upscaling procedure for APs
;------------------------------------------------------------------------------
PARALLELRENDERTOSCREEN:
    xor rcx, rcx
    lea r11, [rel UPSCALEDROW]
.rowrenderloop:
    mov al, byte [r11 + rcx]
    cmp al, 0
    jnz .nextrenderrowcheck
    inc byte [r11 + rcx]
    
    mov rdx, rcx
    shl rdx, 0x0E       ; * 16384
    add rdx, [rel UPSCALEDBUFFER]
    
    mov r9, rcx
    shl r9, 0x0A        ; * 1024
    lea r10, [rel OUTPUTFBUFFER]
    add r9, r10
    
    xor r8, r8
    xor r10, r10
    xor rax, rax
.renderfirstrow:
    mov eax, dword [r9]
    mov dword [rdx + r10], eax
    add r10, 4
    test r8, 3
    jnz .notnextpixelyet
    add r9, 4
.notnextpixelyet:
    inc r8
    cmp r8, 0x400
    jnz .renderfirstrow
    
    xor r8, r8
    xor r9, r9
    xor rax, rax
.copyfirstrow:
    mov rax, qword [rdx + r8]
    mov qword [rdx + r8 + 0x1000], rax
    mov qword [rdx + r8 + 0x2000], rax
    mov qword [rdx + r8 + 0x3000], rax
    add r8, 8
    inc r9
    cmp r9, 0x200
    jnz .copyfirstrow
    
    inc qword [rel UPSCALEDCOUNT]
.nextrenderrowcheck:
    inc rcx
    cmp rcx, 0x100
    jnz .rowrenderloop
    ret


; ==================== 数据区 ====================

; 基本变量
imageHandle:        times 1 dq 0
systemTable:        times 1 dq 0
bMessage:           times 64 dw 0
BUFFER:             times 64 db 0
modeInfoBuffer:     times 1 dq 0
sizeOfInfo:         times 1 dq 0
curMode:            times 1 dq 0
VIDEOX:             times 1 dd 0
VIDEOY:             times 1 dd 0
selectedMode:       times 1 dq 0

; Key handles
index:              times 1 dq 0
key:                times 1 dq 0
WkeyNotifyHandle:           times 1 dq 0
littleWkeyNotifyHandle:     times 1 dq 0
upkeyNotifyHandle:          times 1 dq 0
SkeyNotifyHandle:           times 1 dq 0
littleSkeyNotifyHandle:     times 1 dq 0
downkeyNotifyHandle:        times 1 dq 0
AkeyNotifyHandle:           times 1 dq 0
littleAkeyNotifyHandle:     times 1 dq 0
leftkeyNotifyHandle:        times 1 dq 0
DkeyNotifyHandle:           times 1 dq 0
littleDkeyNotifyHandle:     times 1 dq 0
rightkeyNotifyHandle:       times 1 dq 0
ZkeyNotifyHandle:           times 1 dq 0
littleZkeyNotifyHandle:     times 1 dq 0
QkeyNotifyHandle:           times 1 dq 0
littleQkeyNotifyHandle:     times 1 dq 0
spacekeyNotifyHandle:       times 1 dq 0

; Key states
PRESSEDLEFT:        times 1 db 0
KEYTIMERLEFT:       times 1 db 0
PRESSEDRIGHT:       times 1 db 0
KEYTIMERRIGHT:      times 1 db 0
PRESSEDUP:          times 1 db 0
KEYTIMERUP:         times 1 db 0
PRESSEDDOWN:        times 1 db 0
KEYTIMERDOWN:       times 1 db 0
PRESSEDFIRE:        times 1 db 0
KEYTIMERFIRE:       times 1 db 0
POINTERSTATE:       times 6 dd 0    ; X, Y, Z, and buttons
POINTERLOC:         times 2 dq 0
POINTERBUTTON:      times 2 dq 0
POINTERLEFT:        times 1 db 0
POINTERRIGHT:       times 1 db 0
POINTERUP:          times 1 db 0
POINTERDOWN:        times 1 db 0
POINTERFIRE:        times 1 db 0
COMBLEFT:           times 1 db 0
COMBRIGHT:          times 1 db 0
COMBUP:             times 1 db 0
COMBDOWN:           times 1 db 0
COMBFIRE:           times 1 db 0

; GRAPHICS
SPRITEVERSION:      times 1 dq 0
TILEMAP0:           times 0x400 dw 0
TILEMAP1:           times 0x400 dw 0
TM0XOFFSET:         times 1 db 0
TM0YOFFSET:         times 1 db 0
TM1XOFFSET:         times 1 db 0
TM1YOFFSET:         times 1 db 0
OUTPUTFBUFFER:      times 0x10000 dd 0    ; 256x256px frame buffer
OUTPUTFBUFFER_2:    times 0x10000 dd 0    ; spare frame buffer
UPSCALEDBUFFER:     times 1 dq 0          ; pointer to 1024x1024 buffer
UPSCALEDROW:        times 256 db 0
UPSCALEDCOUNT:      times 1 dq 0
FAILEDCPULIST:      times 1 dq 0
SUCESSCPUS:         times 1 dq 0
NUMBERAP:           times 1 dq 0
ENABLEDAP:          times 1 dq 0

; SPRITES - 128 sprite objects (8 bytes each)
SPRITES:            times 0x400 db 0      ; 128 * 8 bytes

; ENEMIES - 64 enemy objects (14 bytes each)
ENEMY:              times (64 * 14) db 0  ;  NUMBEROFENEMY=64, ENEMYOBJSIZE=14

; BOLTS - 8 bolt objects
; 注意：需要定义 BOLTOBJSIZE 常量
BOLTS:              times (8 * 14) db 0    ;  BOLTOBJSIZE=14
BOLTCOOLDOWN:       times 1 dq 0

; GAME VARIABLES
TITLEON:            times 1 dq 0
STAGE:              times 1 dq 0
SHIPX:              times 1 dq 0
SHIPY:              times 1 dq 0
SHIPTILTY:          times 1 dq 0
SHIPHITBOX:         times 4 db 0  ; X, Y, W, H
SHIPALT:            times 1 db 0
SHIPFUEL:           times 1 db 0
SCROLLTIMER:        times 1 dq 0
SCROLLX:            times 1 dq 0
SCROLLY:            times 1 dq 0
LASTSCROLLX:        times 1 dq 0
LASTSCROOLY:        times 1 dq 0
GAMEMAPOFFSET:      times 1 dq 0
COLUMNTICK:         times 1 dq 0
HIDESHADOW:         times 1 dq 0
HIT:                times 1 dq 0
NOFUEL:             times 1 dq 0
PAUSESCROLL:        times 1 dq 0
EXPLODETIMER:       times 1 dq 0
EXPLODEDELAYTIMER:  times 1 dq 0
RESET:              times 1 dq 0
WINTIMER:           times 1 dq 0

; FRAMERULE COUNTERS
MOVEMENTFRAMERULEC: times 1 dq 0
SCROLLFRAMERULEC:   times 1 dq 0
FUELFRAMERULEC:     times 1 dq 0
ELOGICFRAMERULEC:   times 1 dq 0
EXPLODEFRAMERULEC:  times 1 dq 0
BOSSMOVEFRAMERULEC: times 1 dq 0
TITLECOUNTER:       times 1 dq 0
TITLESWAPCOUNTER:   times 1 dq 0

; TIME RELATED
time:               times 4 dq 0
EFI_TIME_CAPABILITIES: times 2 dq 0
SECONDS:            times 1 db 0
TSC_PS:             times 1 dq 0
TSC_PS2:            times 1 dq 0
CYCLESPERFRAME:     times 1 dq 0
NEXTFRAME_AT:       times 1 dq 0
FRAMERATE:          times 1 dq 0
FRAMECOUNT:         times 1 dq 0
S1:                 times 1 dq 0
S2:                 times 1 dq 0

; FRAME COUNTERS
MOVEMENTFC:         times 1 db 0

; FUNCTION POINTERS
conIn:              times 1 dq 0
conOut:             times 1 dq 0
RuntimeServices:    times 1 dq 0
BootServices:       times 1 dq 0
AllocatePages:      times 1 dq 0
OutputString:       times 1 dq 0
WaitForEvent:       times 1 dq 0
ReadKeyStroke:      times 1 dq 0
WaitForKey:         times 1 dq 0
SetCursorPosition:  times 1 dq 0
LocateProtocol:     times 1 dq 0
TextInputEX:        times 1 dq 0
RegisterKeyNotify:  times 1 dq 0
MPServices:         times 1 dq 0
StartupThisAP:      times 1 dq 0
StartupAllAPs:      times 1 dq 0
GetNumberOfAP:      times 1 dq 0
EnableDisableAP:    times 1 dq 0
LocateHandleBuffer: times 1 dq 0
ABSOLUTEPOINTER:    times 1 dq 0
SIMPLEPOINTER:      times 1 dq 0
POINTERGETSTATEABS: times 1 dq 0
POINTERGETSTATESMP: times 1 dq 0
POINTERMODE:        times 1 dq 0
getTime:            times 1 dq 0
GOP:                times 1 dq 0
queryMode:          times 1 dq 0
setMode:            times 1 dq 0
BLT:                times 1 dq 0
mode:               times 1 dq 0
maxMode:            times 1 dd 0

%include "graphics/loadImg.inc"
%include "graphics/loadImgShip.inc"
%include "graphics/bgTiles.inc"
%include "graphics/tilemap.inc"
%include "graphics/spriteTiles.inc"
%include "graphics/spriteTiles2.inc"


PAUSEGAME:          dq 0
UPSCALE_MODE:       dq 0    ; 0 FOR MULTI-CORE HARDWARE UPSCALED IMAGE OUTPUT
SHOW_HITBOX:        dq 0    ; 1 TO SHOW HIT BOXES

helloMessage:
    dw 'S', 'T', 'A', 'R', 'T', 'I', 'N', 'G', ' ', 'U', 'E', 'F', 'I', ' ', 'P', 'R', 'G', 13, 10
    dw 'W', 'R', 'I', 'T', 'T', 'E', 'N', ' ', 'B', 'Y', ' '
    dw 'I', 'N', 'K', 'B', 'O', 'X', 13, 10, 0

endMessage:         dw 'O', 'K', 13, 10, 0
monthMessage:       dw '-', '>', ' ', 'M', 13, 10, 0
fpsMessage:         dw 'F', 'P', 'S', ':', ' ', 0
timeCapMessage:     dw 'N', 'A', 'N', 'O', ' ', 'O', 'U', 'T', ':', ' '
timeCapVal:         dw 0, 0
cyclesMessage:      dw 'C', 'A', 'L', 'C', 'U', 'L', 'A', 'T', 'I', 'N', 'G'
                    dw ' ', 'C', 'P', 'U', ' ', 'S', 'P', 'E', 'E', 'D', 0
controlMessage:     dw 'U', 'D', 'L', 'R', 'F', 13, 10, 0
PRESSEDLEFTMessage: dw 'A', ' ', 'P', 'R', 'E', 'S', 'S', 'E', 'D', ':', ' ', 0
videoMessage1:      dw 'M', 'A', 'X', ' ', 'V', 'I', 'D', 'E', 'O', ' ', 'M', 'O', 'D', 'E', 'S', ':', ' ', 0
videoMessage2:      dw 'M', ':', ' ', 0
videoMessage3:      dw 'F', 'O', 'R', 'M', 'A', 'T', ':', ' ', 0
videoMessage4:      dw 'V', 'I', 'D', 'E', 'O', ' ', 'M', 'O', 'D', 'E', ' ', 'S', 'E', 'L', ':', ' ', 0
mouseMessage:       dw 'M', 'O', 'U', 'S', 'E', ':', ' ', 10, 13, 0
columnMessage:      dw 'C', 'O', 'L', 'U', 'M', 'N', ' ', 'C', 'O', 'U', 'N', 'T', ':', ' ', 10, 13, 0
returnLineMes:      dw 0x0D, 0
spaceMessage:       dw ' ', 0
xMessage:           dw 'x', 0

TITLECARD:          dw 0x0612, 0x060F, 0x0600, 0x0602, 0x0604, 0x05ED, 0x0606, 0x0600, 0x060C, 0x0604
                    dw 0x05ED, 0x0605, 0x060E, 0x0611, 0x05ED, 0x0617, 0x0620, 0x061E

; KEY RELATED - Key Descriptors (SCANCODE, UNICODE CHAR, KeyShiftState + KeyToggleState)
WkeyDescriptor:         dw 0, 'W', 0, 0
littleWkeyDescriptor:   dw 0, 'w', 0, 0
upkeyDescriptor:        dw 0x01, 0, 0, 0
SkeyDescriptor:         dw 0, 'S', 0, 0
littleSkeyDescriptor:   dw 0, 's', 0, 0
downkeyDescriptor:      dw 0x02, 0, 0, 0
AkeyDescriptor:         dw 0, 'A', 0, 0
littleAkeyDescriptor:   dw 0, 'a', 0, 0
leftkeyDescriptor:      dw 0x04, 0, 0, 0
DkeyDescriptor:         dw 0, 'D', 0, 0
littleDkeyDescriptor:   dw 0, 'd', 0, 0
rightkeyDescriptor:     dw 0x03, 0, 0, 0
ZkeyDescriptor:         dw 0, 'Z', 0, 0
littleZkeyDescriptor:   dw 0, 'z', 0, 0
QkeyDescriptor:         dw 0, '?', 0, 0
littleQkeyDescriptor:   dw 0, '/', 0, 0
spacekeyDescriptor:     dw 0, ' ', 0, 0

; COLOR DEFINITIONS
COLORRED:       dd 0x00FF0000
COLORORANGE:    dd 0x00FF8000
COLORYELLOW:    dd 0x00FFFF00
COLORGREENN:    dd 0x0039FF14
COLORBLUE:      dd 0x000000FF
COLORGREEN:     dd 0x0000FF00
COLORBLACK:     dd 0x00000000

; Protocol GUIDs
TextInputExGUID:
    dd 0xDD9E7534
    dw 0x7762, 0x4698
    db 0x8C, 0x14, 0xF5, 0x85, 0x17, 0xA6, 0x25, 0xAA

GraphicsOutputGUID:
    dd 0x9042A9DE
    dw 0x23DC, 0x4A38
    db 0x96, 0xFB, 0x7A, 0xDE, 0xD0, 0x80, 0x51, 0x6A

MPServicesGUID:
    dd 0x3FDDA605
    dw 0xA76E, 0x4F46
    db 0xAD, 0x29, 0x12, 0xF4, 0x53, 0x1B, 0x3D, 0x08

ABSOLUTEPOINTERGUID:
    dd 0x8D59D32B
    dw 0xC655, 0x4AE9
    db 0x9B, 0x15, 0xF2, 0x59, 0x04, 0x99, 0x2A, 0x43

SIMPLEPOINTERGUID:
    dd 0x31878C87
    dw 0x0B75, 0x11D5
    db 0x9A, 0x4F, 0x00, 0x90, 0x27, 0x3F, 0xC1, 0x4D

; GAME CONSTANTS
SHIPORGINX      equ 12
SHIPORGINY      equ 70
SHIPMAXX        equ 112
SHIPMAXY        equ 112
NUMBEROFENEMY   equ 0x40
ENEMYOBJSIZE    equ 0x0E
BOLTOBJSIZE     equ 0x0E
BOLTCOOLDOWNFRAMES equ 24
BONUSFUEL       equ 0x20
MOVEMENTFRAMERULE   equ 2
SCROLLFRAMERULE     equ 3
FUELFRAMERULE       equ 20
ELOGICFRAMERULE     equ 2
EXPLODEFRAMERULE    equ 8
BOSSMOVEFRAMERULE   equ 4
FIRSTKEYTIMELIMIT   equ 0x50
SECONDKEYTIMELIMIT  equ 0x0C
MINX            equ 500
MINY            equ 500
MAXX            equ 700
MAXY            equ 700
TRIGGERLOW      equ 596
TRIGGERHIGH     equ 604

code_size equ ($ - code_section + 0x1FF) & ~0x1FF
image_size equ ($ - $$ + 0xFFF) & ~0xFFF

; 填充到文件对齐
times (code_start + code_size) - ($ - $$) db 0
