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


; ========== OUTPUT64BITNUMBER 宏 ==========
%macro OUTPUT64BITNUMBER 1
    push rax
    push rcx
    push rdx
    push r8
    mov rdi, %1
    lea rsi, [rel hex_buffer]
    call uint64_to_hex
    mov rcx, [rel conOut]
    lea rdx, [rel hex_buffer]
    call [rel OutputString]
    mov rcx, [rel conOut]
    lea rdx, [rel newline]
    call [rel OutputString]
    pop r8
    pop rdx
    pop rcx
    pop rax
%endmacro

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

; EfiMain(ImageHandle, SystemTable)
EfiMain:
    mov [image_handle], rcx
    mov [system_table], rdx

    push    rbx
    push    r12
    push    r13
    sub     rsp, 64             ; 栈空间（包含临时缓冲区）

    ; 保存重要值
    mov     r12, rdx            ; r12 = SystemTable
    mov     rax, [rdx + 64]     ; ConOut
    mov     rbx, rax            ; rbx = ConOut (保存到 callee-saved 寄存器)

    ; ========== 打印提示信息 ==========
    mov     rcx, rbx
    lea     rdx, [rel msg_conout]
    call    [rbx + 8]
    
    ; ========== 打印 ConOut 地址 ==========
    ; rbx 已经是 ConOut 的地址值
    mov     rdi, rbx            ; 要打印的地址值
    lea     rsi, [rel hex_buffer] ; 输出缓冲区
    call    uint64_to_hex       ; 转换为十六进制字符串
    
    ; 打印地址
    mov     rcx, rbx
    lea     rdx, [rel hex_buffer]
    call    [rbx + 8]
    
    ; 打印换行
    mov     rcx, rbx
    lea     rdx, [rel newline]
    call    [rbx + 8]
    
    ; ========== 打印 SystemTable 地址 ==========
    mov     rcx, rbx
    lea     rdx, [rel msg_systable]
    call    [rbx + 8]
    
    mov     rdi, r12            ; SystemTable 地址
    lea     rsi, [rel hex_buffer]
    call    uint64_to_hex
    
    mov     rcx, rbx
    lea     rdx, [rel hex_buffer]
    call    [rbx + 8]
    
    mov     rcx, rbx
    lea     rdx, [rel newline]
    call    [rbx + 8]

    ; ========== 再次打印 SystemTable 地址 ==========
    mov     rcx, rbx
    lea     rdx, [rel msg_systable]
    call    [rbx + 8]
    
    mov     rdi, [system_table]            ; SystemTable 地址
    lea     rsi, [rel hex_buffer]
    call    uint64_to_hex
    
    mov     rcx, rbx
    lea     rdx, [rel hex_buffer]
    call    [rbx + 8]
    
    mov     rcx, rbx
    lea     rdx, [rel newline]
    call    [rbx + 8]
    
    ; ========== 打印 Hello World ==========
    mov     rcx, rbx
    lea     rdx, [rel hello_str1]
    call    [rbx + 8]
    mov     rcx, rbx
    lea     rdx, [rel hello_str2]
    call    [rbx + 8]

    
    ; 获取 UEFI 函数
    
    mov rcx, [image_handle]
    mov rdx, [system_table]

    GETUEFIFUNCTIONS

    
    mov     rcx, [rel conOut]
    lea     rdx, [rel hello_str1]
    call    [rel OutputString]
    

    ; 无限循环
.wait_loop:
    hlt
    jmp     .wait_loop


; ==================== 辅助函数 ====================
; uint64_to_hex: 将 64 位数转换为十六进制 Unicode 字符串
; 输入: rdi = 要转换的数值
;       rsi = 输出缓冲区指针 (需要至少 38 字节: "0x" + 16字符 + 换行 + null，每字符2字节)
; 破坏: rax, rcx, rdx, rdi, rsi
uint64_to_hex:
    push    rbx
    
    ; 写入 "0x" 前缀
    mov     word [rsi], '0'
    mov     word [rsi + 2], 'x'
    add     rsi, 4
    
    ; 转换 16 个十六进制数字（从高位到低位）
    mov     rcx, 16             ; 16 个 nibbles
    
.convert_loop:
    ; 取最高 4 位
    mov     rax, rdi
    shr     rax, 60             ; 移动最高 4 位到最低位
    
    ; 转换为 ASCII
    cmp     al, 10
    jb      .is_digit
    add     al, 'A' - 10        ; A-F
    jmp     .store_char
.is_digit:
    add     al, '0'             ; 0-9
    
.store_char:
    mov     word [rsi], ax      ; 存储 Unicode 字符
    add     rsi, 2
    
    ; 左移 4 位，处理下一个 nibble
    shl     rdi, 4
    
    dec     rcx
    jnz     .convert_loop
    
    ; 写入 null 终止符
    mov     word [rsi], 0
    
    pop     rbx
    ret


; ==================== 数据区 ====================
image_handle: dq -1
system_table: dq -1

; ========== UEFI 函数指针存储 ==========
conIn:              dq 0
conOut:             dq 0
RuntimeServices:    dq 0
BootServices:       dq 0

; ConOut 函数
OutputString:       dq 0
SetCursorPosition:  dq 0

; BootServices 函数
AllocatePages:      dq 0
WaitForEvent:       dq 0
LocateHandleBuffer: dq 0
LocateProtocol:     dq 0

; ConIn 函数
ReadKeyStroke:      dq 0
WaitForKey:         dq 0

; RuntimeServices 函数
getTime:            dq 0

; TextInputEX
TextInputEX:        dq 0
RegisterKeyNotify:  dq 0

; Graphics Output Protocol (GOP)
GOP:                dq 0
queryMode:          dq 0
setMode:            dq 0
BLT:                dq 0
mode:               dq 0
maxMode:            dd 0

; MP Services Protocol
MPServices:         dq 0
GetNumberOfAP:      dq 0
StartupAllAPs:      dq 0
StartupThisAP:      dq 0
EnableDisableAP:    dq 0

; Simple Pointer Protocol
SIMPLEPOINTER:      dq 0
POINTERGETSTATESMP: dq 0
POINTERMODE:        dq 0

; ========== GUIDs ==========
align 8
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

SIMPLEPOINTERGUID:
    dd 0x31878C87
    dw 0x0B75, 0x11D5
    db 0x9A, 0x4F, 0x00, 0x90, 0x27, 0x3F, 0xC1, 0x4D

; ========== 消息字符串 ==========
mouseMessage:
    dw 'L','o','c','a','t','i','n','g',' ','M','o','u','s','e','.','.','.',13,10,0


msg_conout:
    dw 'C','o','n','O','u','t',' ','a','d','d','r',':',' ',0

msg_systable:
    dw 'S','y','s','T','a','b','l','e',' ','a','d','d','r',':',' ',0

hello_str1:
    dw 'H','e','l','l','o',' ','W','o','r','l','d','1',13,10,0

hello_str2:
    dw 'H','e','l','l','o',' ','W','o','r','l','d','2',13,10,0

newline:
    dw 13, 10, 0

; 十六进制输出缓冲区 (需要空间: 2 + 16 + 1 = 19 个 Unicode 字符 = 38 字节)
hex_buffer:
    times 40 db 0

code_size equ ($ - code_section + 0x1FF) & ~0x1FF
image_size equ ($ - $$ + 0xFFF) & ~0xFFF

; 填充到文件对齐
times (code_start + code_size) - ($ - $$) db 0
