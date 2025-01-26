# orange

This is a minimal Ubuntu server spinoff specifically for my NAS. Samba, ZFS, and OpenSSH are pre-installed and configured during the build process. The assembled image can be written on a USB drive and runs entirely from RAM, similar to the installation live environment. Successor of [guava](https://github.com/leonrinkel/guava), where I did the same thing but using Buildroot.

This is provided only as a reference. The configuration, such as pool name and share names, is hard-coded, so don’t expect this to work on your machine.

## Features

- [x] Non-persistent, runs from RAM
- [x] DHCP on wired interfaces
- [x] Samba with auth and Time Machine share
- [x] Avahi announcing of Samba service
- [x] Automatic zpool importing
- [x] Weekly ZFS scrubbing
- [x] OpenSSH server with pubkey auth
- [ ] S.M.A.R.T.

## Build

```sh
sudo ./build.sh
```

## Emulate

```sh
sudo qemu-system-x86_64 \
    -enable-kvm \
    -m 4G \
    -bios /usr/share/ovmf/OVMF.fd \
    -drive file=orange.img,if=virtio,format=raw,readonly \
    -device e1000,netdev=net0 \
    -netdev user,id=net0,hostfwd=tcp::2222-:22
```
