echo "Preconfiguring dash - else dash and bash will be left in a broken state"
/var/lib/dpkg/info/dash.preinst install

# don't leave target image containing apt config of the build host
echo "Configuring all packages"
export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true
export LC_ALL=C LANGUAGE=C LANG=C

# allow flash-kernel to work without valid /proc contents
# ** this doesn't *really* work, since there are too many checks that fail
#    in an emulated environment!  We'll have to do it by hand below anyway...
export FK_MACHINE="Globalscale Technologies Dreamplug"

# configure all packages unpacked earlier by multistrap
dpkg --configure -a

echo "Adding source packages to filesystem"
apt-get update
dpkg --get-selections > /tmp/selections
mkdir -p /sourcecode
cd sourcecode
cut -f 1 < /tmp/selections | cut -d ':' -f 1 > /tmp/packages
apt-get source --download-only `cat /tmp/packages`

echo "Installing local binary packages, if any"
dpkg --install /sourcecode/*.deb

# sshd may be left running by the postinst, clean that up
/etc/init.d/ssh stop

# process installed kernel to create uImage, uInitrd, dtb
#  using flash-kernel would be a good approach, except it fails in the cross
#  build environment due to too many environment checks...
#FK_MACHINE="Globalscale Technologies Dreamplug" flash-kernel
#  so, let's do it manually...

# flash-kernel's hook-functions provided to mkinitramfs have the unfortunate
# side-effect of creating /conf/param.conf in the initrd when run from our
# emulated chroot environment, which means our root= on the kernel command
# line is completely ignored!  repack the initrd to remove this evil...

mkdir /tmp/initrd-repack
(cd /tmp/initrd-repack ; \
    zcat /boot/initrd.img-3.2.0-3-kirkwood | cpio -i ; \
    rm -f conf/param.conf ; \
    find . | cpio --quiet -o -H newc | \
	gzip -9 > /boot/initrd.img-3.2.0-3-kirkwood )
rm -rf /tmp/initrd-repack

(cd /boot ; \
    cp /usr/lib/linux-image-3.2.0-3-kirkwood/kirkwood-dreamplug.dtb dtb ; \
    cat vmlinuz-3.2.0-3-kirkwood dtb >> temp-kernel ; \
    mkimage -A arm -O linux -T kernel -n 'Debian kernel 3.2.0-3-kirkwood' \
	-C none -a 0x8000 -e 0x8000 -d temp-kernel uImage ; \
    rm -f temp-kernel ; \
    mkimage -A arm -O linux -T ramdisk -C gzip -a 0x0 -e 0x0 \
	-n 'Debian ramdisk 3.2.0-3-kirkwood' \
	-d initrd.img-3.2.0-3-kirkwood uInitrd )

# Establish an initial root password
echo "Set root password to "$rootpassword
echo root:$rootpassword | /usr/sbin/chpasswd

# Create a default user
echo "Creating fbx user, password: $userpassword"
useradd $user
echo $user:$userpassword | /usr/sbin/chpasswd

# By default, spawn a console on the serial port
echo "Adding a getty on the serial port"
echo "T0:12345:respawn:/sbin/getty -L ttyS0 115200 vt100" >> /etc/inittab

echo "Deleting this very same script"
rm -f /install.sh

echo "Syncing filesystem just in case something didn't get written"
sync

echo "End configuration progress by exiting from the chroot"
exit
