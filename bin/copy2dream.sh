#!/bin/sh
#
# this script assumes the current root filesystem is the source, and the
# internal microSD on a DreamPlug is the target .. all existing content on
# the microSD card will be lost.
#

# partition microSD card inside DreamPlug
parted -s /dev/sda mklabel msdos
parted -s /dev/sda mkpart primary fat16 0 128
parted -s /dev/sda mkpart primary ext2 128 100%

# create filesystems on new partitions
mkdosfs /dev/sda1
mke2fs -j /dev/sda2

mount /dev/sda2 /media
mkdir -p /media/boot
mount /dev/sda1 /media/boot

rsync -atvz --progress --exclude=boot --exclude proc --exclude sys --exclude media --exclude dev / /media/freedom/

cp /boot/* /media/boot/
mkdir /media/proc /media/sys /media/media

echo "Creating basic device nodes"
mkdir /media/dev
mknod /media/dev/console c 5 1
mknod /media/dev/random c 1 8
mknod /media/dev/urandom c 1 9
mknod /media/dev/null c 1 3
mknod /media/dev/ptmx c 5 2

# patch up /etc/fstab entry for /boot
sed -e 's/sdc1/sda1/g' < /etc/fstab > /media/etc/fstab

umount /dev/sda1
umount /dev/sda2

echo "installation complete .. see docs for how to boot from internal microSD"

