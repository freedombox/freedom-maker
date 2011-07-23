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

mount /dev/sda2 /media
(cd / ; tar cf - `/bin/ls | grep -v proc | grep -v sys | grep -v media`) | \
	(cd /media ; tar xvf -)
umount /dev/sda2
