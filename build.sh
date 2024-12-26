#!/bin/bash

set -o pipefail
set -e
set -E

# requires root

if [ "$EUID" -ne 0 ]
then
    echo "Run as root"
    exit 1
fi

# configuration

arch=amd64
suite=noble
mirror=http://de.archive.ubuntu.com/ubuntu

username=leon
password=secret

rootfs=rootfs
image=image
size=2G

# bootstrap base system

debootstrap \
    --variant=minbase \
    --arch=$arch \
    $suite \
    $rootfs \
    $mirror

# prepare apt sources

cat <<EOF > $rootfs/etc/apt/sources.list
deb $mirror $suite main restricted universe multiverse
deb-src $mirror $suite main restricted universe multiverse

deb $mirror $suite-security main restricted universe multiverse
deb-src $mirror $suite-security main restricted universe multiverse

deb $mirror $suite-updates main restricted universe multiverse
deb-src $mirror $suite-updates main restricted universe multiverse
EOF

# mount for chroot

mount --bind /dev $rootfs/dev
mount --bind /run $rootfs/run
mount -t proc none $rootfs/proc
mount -t sysfs none $rootfs/sys
mount -t devpts none $rootfs/dev/pts
mount -t tmpfs none $rootfs/tmp
mount -t efivarfs efivarfs $rootfs/sys/firmware/efi/efivars

# run some stuff in chroot

LANG=C DEBIAN_FRONTEND=noninteractive chroot $rootfs /bin/bash <<EOT

# update and install stuff

apt-get update -yq
apt-get upgrade -yq
apt-get install -yq linux-generic ubuntu-server-minimal casper
apt-get install -yq openssh-server zfsutils-linux samba
apt-get autoremove -yq
apt-get clean -yq

# enable some services

systemctl enable systemd-networkd.service
systemctl enable ssh.service
systemctl enable zfs-import-scan.service

# add user

adduser \
    --disabled-password \
    --quiet \
    --gecos "" \
    $username
echo "$username:$password" | chpasswd
usermod -aG sudo $username
echo -e "$password\n$password" | smbpasswd -s -a $username

# prepare ssh dir

mkdir /home/$username/.ssh
chmod 700 /home/$username/.ssh
touch /home/$username/.ssh/authorized_keys
chmod 644 /home/$username/.ssh/authorized_keys
chown -R $username:$username /home/$username/.ssh

exit

EOT

# unmount

umount -lf $rootfs/dev/pts
umount -lf $rootfs/dev
umount -lf $rootfs/run
umount -lf $rootfs/proc
umount -lf $rootfs/sys/firmware/efi/efivars
umount -lf $rootfs/sys
umount -lf $rootfs/tmp

# copy some files

cp 20-wired.network $rootfs/etc/systemd/network/20-wired.network
cp smb.conf $rootfs/etc/samba/smb.conf
cat id_rsa.pub > $rootfs/home/$username/.ssh/authorized_keys

# copy kernel + initrd

mkdir -p $image/casper
cp $rootfs/boot/vmlinuz-**-**-generic $image/casper/vmlinuz
cp $rootfs/boot/initrd.img-**-**-generic $image/casper/initrd

# squash rootfs

mksquashfs $rootfs $image/casper/filesystem.squashfs -e boot
printf $(du -sx --block-size=1 $rootfs | cut -f1) > $image/casper/filesystem.size

# copy bootloader

mkdir -p $image/EFI/boot
cp /usr/lib/SYSLINUX.EFI/efi64/syslinux.efi $image/EFI/boot/bootx64.efi
cp /usr/lib/syslinux/modules/efi64/* $image/EFI/boot/
cp syslinux.cfg $image/EFI/boot/syslinux.cfg

# assemble image

dd if=/dev/zero of=orange.img bs=$size count=1 iflag=fullblock
mkdosfs -F 16 -n ORANGE orange.img
mkdir -p mnt
mount -o loop orange.img mnt
cp -a image/* mnt/
umount mnt
