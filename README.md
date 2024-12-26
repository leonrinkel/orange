# orange

OS for my NAS

```sh
sudo ./build.sh
```

```sh
sudo qemu-system-x86_64 \
    -enable-kvm \
    -m 4G \
    -bios /usr/share/ovmf/OVMF.fd \
    -drive file=orange.img,if=virtio,format=raw,readonly \
    -device e1000,netdev=net0 \
    -netdev user,id=net0,hostfwd=tcp::2222-:22
```
