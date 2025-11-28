nasm -f bin hello_efi.asm -o hello.efi
mkdir EFI\BOOT
copy hello.efi EFI\BOOT\BOOTX64.EFI
qemu-system-x86_64 -bios DEBUGX64_OVMF.fd -drive format=raw,file=fat:rw:.
