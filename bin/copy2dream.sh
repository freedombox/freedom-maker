#!/bin/sh
#
# this script assumes the current root filesystem is the source, and the
# internal microSD on a DreamPlug is the target .. copy the kernel uImage to
# the FAT partition on sda1, and the root contents to the ext3 on sda2
#
mount /dev/sda1 /media
mv /media/uImage /media/uImage.old
cp /boot/uImage /media/uImage
umount /media

mke2fs -j /dev/sda2
mount /dev/sda2 /media
(cd / ; tar cf - `/bin/ls | grep -v proc | grep -v sys | grep -v media | grep -v dev`) | \
	(cd /media ; tar xvf -)

mkdir /media/proc /media/sys /media/media

echo "Creating basic device nodes"
mkdir /media/dev
mknod /media/dev/console c 5 1
mknod /media/dev/random c 1 8
mknod /media/dev/urandom c 1 9
mknod /media/dev/null c 1 3
mknod /media/dev/ptmx c 5 2

umount /dev/sda2

echo "interrupt the next boot and change the root path to /dev/sda2"

