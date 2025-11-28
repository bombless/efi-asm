
mkdir -p EFI\BOOT
cp hello.efi EFI\BOOT\BOOTX64.EFI
qemu-system-x86_64 -bios DEBUGX64_OVMF.fd -drive format=raw,file=fat:rw:.
