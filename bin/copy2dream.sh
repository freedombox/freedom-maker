#!/bin/sh
#
# this script assumes the current root filesystem is the source, and the
# internal microSD on a DreamPlug is the target .. all existing content on
# the microSD card will be lost.
#

# partition microSD card inside DreamPlug
echo "=> partition internal microSD card"
parted -s /dev/sda mklabel msdos
parted -s /dev/sda mkpart primary fat16 0 128
parted -s /dev/sda mkpart primary ext2 128 100%

# create filesystems on new partitions
echo "=> create filesystems on internal microSD card"
mkdosfs /dev/sda1
mke2fs -j /dev/sda2

echo "=> mount target partitions"
mount /dev/sda2 /media
mkdir -p /media/boot
mount /dev/sda1 /media/boot

echo "=> copy filesystem content from USB stick to target partitions"
(cd / ; tar cpSf - `/bin/ls | grep -v boot | grep -v proc | grep -v sys | grep -v media | grep -v dev`) | (cd /media ; tar xpf -)
cp /boot/* /media/boot/

echo "=> touch up target root partition"
mkdir /media/proc /media/sys /media/media /media/dev
mknod /media/dev/console c 5 1
mknod /media/dev/random c 1 8
mknod /media/dev/urandom c 1 9
mknod /media/dev/null c 1 3
mknod /media/dev/ptmx c 5 2

# patch up /etc/fstab entry for /boot
sed -e 's/sdc1/sda1/g' < /etc/fstab > /media/etc/fstab

echo "#!/bin/sh" > /media/root/tweak-kernel
echo "mount -t proc proc /proc" >> /media/root/tweak-kernel
echo "flash-kernel 3.0.0-kirkwood" >> /media/root/tweak-kernel
echo "umount /proc" >> /media/root/tweak-kernel
echo "exit" >> /media/root/tweak-kernel
chmod +x /media/root/tweak-kernel

chroot /media /root/tweak-kernel

echo "unmount target partitions"
umount /dev/sda1
umount /dev/sda2

echo "=> installation complete, see docs to boot from internal microSD"

