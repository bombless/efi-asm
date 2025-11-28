nasm -f bin hello_efi.asm -o hello.efi
mkdir -p EFI/BOOT
cp hello.efi EFI/BOOT/BOOTX64.EFI
qemu-system-x86_64 -bios /usr/share/edk2/x64/OVMF.4m.fd -drive format=raw,file=fat:rw:.
