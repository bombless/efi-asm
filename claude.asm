; SPACE GAME FOR x64 SYSTEMS - NASM/Linux Version
; Build with: nasm -f elf64 game.asm -o game.o
; Link with GNU-EFI for UEFI application

BITS 64
DEFAULT REL

; UEFI Calling Convention: RCX, RDX, R8, R9, then stack (Microsoft x64 ABI)

;==============================================================================
; DATA SECTION
;==============================================================================
section .data

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

;==============================================================================
; BSS SECTION (Uninitialized Data)
;==============================================================================
section .bss

imageHandle:        resq 1
systemTable:        resq 1
bMessage:           resw 64
BUFFER:             resb 64
modeInfoBuffer:     resq 1
sizeOfInfo:         resq 1
curMode:            resq 1
VIDEOX:             resd 1
VIDEOY:             resd 1
selectedMode:       resq 1

; Key handles
index:              resq 1
key:                resq 1
WkeyNotifyHandle:           resq 1
littleWkeyNotifyHandle:     resq 1
upkeyNotifyHandle:          resq 1
SkeyNotifyHandle:           resq 1
littleSkeyNotifyHandle:     resq 1
downkeyNotifyHandle:        resq 1
AkeyNotifyHandle:           resq 1
littleAkeyNotifyHandle:     resq 1
leftkeyNotifyHandle:        resq 1
DkeyNotifyHandle:           resq 1
littleDkeyNotifyHandle:     resq 1
rightkeyNotifyHandle:       resq 1
ZkeyNotifyHandle:           resq 1
littleZkeyNotifyHandle:     resq 1
QkeyNotifyHandle:           resq 1
littleQkeyNotifyHandle:     resq 1
spacekeyNotifyHandle:       resq 1

; Key states
PRESSEDLEFT:        resb 1
KEYTIMERLEFT:       resb 1
PRESSEDRIGHT:       resb 1
KEYTIMERRIGHT:      resb 1
PRESSEDUP:          resb 1
KEYTIMERUP:         resb 1
PRESSEDDOWN:        resb 1
KEYTIMERDOWN:       resb 1
PRESSEDFIRE:        resb 1
KEYTIMERFIRE:       resb 1
POINTERSTATE:       resd 6  ; X, Y, Z, and buttons
POINTERLOC:         resq 2
POINTERBUTTON:      resq 2
POINTERLEFT:        resb 1
POINTERRIGHT:       resb 1
POINTERUP:          resb 1
POINTERDOWN:        resb 1
POINTERFIRE:        resb 1
COMBLEFT:           resb 1
COMBRIGHT:          resb 1
COMBUP:             resb 1
COMBDOWN:           resb 1
COMBFIRE:           resb 1

; GRAPHICS
SPRITEVERSION:      resq 1
TILEMAP0:           resw 0x400
TILEMAP1:           resw 0x400
TM0XOFFSET:         resb 1
TM0YOFFSET:         resb 1
TM1XOFFSET:         resb 1
TM1YOFFSET:         resb 1
OUTPUTFBUFFER:      resd 0x10000    ; 256x256px frame buffer
OUTPUTFBUFFER_2:    resd 0x10000    ; spare frame buffer
UPSCALEDBUFFER:     resq 1          ; pointer to 1024x1024 buffer
UPSCALEDROW:        resb 256
UPSCALEDCOUNT:      resq 1
FAILEDCPULIST:      resq 1
SUCESSCPUS:         resq 1
NUMBERAP:           resq 1
ENABLEDAP:          resq 1

; SPRITES - 128 sprite objects (8 bytes each)
SPRITES:            resb 0x400      ; 128 * 8 bytes

; ENEMIES - 64 enemy objects (14 bytes each)
ENEMY:              resb (NUMBEROFENEMY * ENEMYOBJSIZE)

; BOLTS - 8 bolt objects
BOLTS:              resb (8 * BOLTOBJSIZE)
BOLTCOOLDOWN:       resq 1

; GAME VARIABLES
TITLEON:            resq 1
STAGE:              resq 1
SHIPX:              resq 1
SHIPY:              resq 1
SHIPTILTY:          resq 1
SHIPHITBOX:         resb 4  ; X, Y, W, H
SHIPALT:            resb 1
SHIPFUEL:           resb 1
SCROLLTIMER:        resq 1
SCROLLX:            resq 1
SCROLLY:            resq 1
LASTSCROLLX:        resq 1
LASTSCROOLY:        resq 1
GAMEMAPOFFSET:      resq 1
COLUMNTICK:         resq 1
HIDESHADOW:         resq 1
HIT:                resq 1
NOFUEL:             resq 1
PAUSESCROLL:        resq 1
EXPLODETIMER:       resq 1
EXPLODEDELAYTIMER:  resq 1
RESET:              resq 1
WINTIMER:           resq 1

; FRAMERULE COUNTERS
MOVEMENTFRAMERULEC: resq 1
SCROLLFRAMERULEC:   resq 1
FUELFRAMERULEC:     resq 1
ELOGICFRAMERULEC:   resq 1
EXPLODEFRAMERULEC:  resq 1
BOSSMOVEFRAMERULEC: resq 1
TITLECOUNTER:       resq 1
TITLESWAPCOUNTER:   resq 1

; TIME RELATED
time:               resq 4
EFI_TIME_CAPABILITIES: resq 2
SECONDS:            resb 1
TSC_PS:             resq 1
TSC_PS2:            resq 1
CYCLESPERFRAME:     resq 1
NEXTFRAME_AT:       resq 1
FRAMERATE:          resq 1
FRAMECOUNT:         resq 1
S1:                 resq 1
S2:                 resq 1

; FRAME COUNTERS
MOVEMENTFC:         resb 1

; FUNCTION POINTERS
conIn:              resq 1
conOut:             resq 1
RuntimeServices:    resq 1
BootServices:       resq 1
AllocatePages:      resq 1
OutputString:       resq 1
WaitForEvent:       resq 1
ReadKeyStroke:      resq 1
WaitForKey:         resq 1
SetCursorPosition:  resq 1
LocateProtocol:     resq 1
TextInputEX:        resq 1
RegisterKeyNotify:  resq 1
MPServices:         resq 1
StartupThisAP:      resq 1
StartupAllAPs:      resq 1
GetNumberOfAP:      resq 1
EnableDisableAP:    resq 1
LocateHandleBuffer: resq 1
ABSOLUTEPOINTER:    resq 1
SIMPLEPOINTER:      resq 1
POINTERGETSTATEABS: resq 1
POINTERGETSTATESMP: resq 1
POINTERMODE:        resq 1
getTime:            resq 1
GOP:                resq 1
queryMode:          resq 1
setMode:            resq 1
BLT:                resq 1
mode:               resq 1
maxMode:            resd 1

;==============================================================================
; INCLUDE EXTERNAL DATA FILES
;==============================================================================
section .rodata

; These would be converted from your .inc files
%include "graphics/loadImg.inc"
%include "graphics/loadImgShip.inc"
%include "graphics/bgTiles.inc"
%include "graphics/tilemap.inc"
%include "graphics/spriteTiles.inc"
%include "graphics/spriteTiles2.inc"

;==============================================================================
; CODE SECTION
;==============================================================================
section .text

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

;------------------------------------------------------------------------------
; MAIN ENTRY POINT
;------------------------------------------------------------------------------
global EFI_MAIN
EFI_MAIN:
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
    