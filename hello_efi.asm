; 独立 UEFI Hello World - 直接生成 .efi 文件
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

; EfiMain(ImageHandle, SystemTable)
EfiMain:
    sub     rsp, 40
    mov     [rsp + 32], rdx     ; 保存 SystemTable

    ; 获取并保存 ConOut
    mov     rax, [rdx + 64]     ; ConOut
    mov     [rsp + 24], rax     ; 保存 ConOut 指针

    ; 调用 OutputString(hello_str1)
    mov     rcx, [rsp + 24]     ; 恢复 ConOut
    lea     rdx, [rel hello_str1]
    call    [rcx + 8]

    ; 调用 OutputString(hello_str2)
    mov     rcx, [rsp + 24]     ; 重新加载 ConOut
    lea     rdx, [rel hello_str2]
    call    [rcx + 8]

    ; 调用 OutputString(hello_str3)
    mov     rcx, [rsp + 24]     ; 重新加载 ConOut
    lea     rdx, [rel hello_str3]
    call    [rcx + 8]
    
    ; 无限循环（可选，防止程序立即退出）
.wait_loop:
    hlt
    jmp     .wait_loop
    
    ; 或者直接返回
    ; xor    eax, eax
    ; add    rsp, 40
    ; ret

; 数据
hello_str1:
    dw 'H','e','l','l','o',' ','W','o','r','l','d','1',13,10,0,0
hello_str2:
    dw 'H','e','l','l','o',' ','W','o','r','l','d','2',13,10,0,0
hello_str3:
    dw 'H','e','l','l','o',' ','W','o','r','l','d','3',13,10,0,0
image_handle:        dq -1

code_size equ ($ - code_section + 0x1FF) & ~0x1FF
image_size equ ($ - $$ + 0xFFF) & ~0xFFF

; 填充到文件对齐
times (code_start + code_size) - ($ - $$) db 0
