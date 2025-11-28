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

; EfiMain(ImageHandle, SystemTable)
EfiMain:
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
    
    ; ========== 打印 Hello World ==========
    mov     rcx, rbx
    lea     rdx, [rel hello_str1]
    call    [rbx + 8]
    mov     rcx, rbx
    lea     rdx, [rel hello_str2]
    call    [rbx + 8]

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
