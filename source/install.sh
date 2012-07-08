echo "Preconfiguring dash - else dash and bash will be left in a broken state"
/var/lib/dpkg/info/dash.preinst install

# don't leave target image containing apt config of the build host
echo "Configuring all packages"
export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true
export LC_ALL=C LANGUAGE=C LANG=C
dpkg --configure -a

# sshd may be left running by the postinst, clean that up
/etc/init.d/ssh stop

# post-install operations for kernel packages
echo "Installing kernel content"
dpkg --install /tmp/kernel/*.deb

# rename deliverables so that flash-kernel is happy using them
mv /boot/config-3.0.0 /boot/config-3.0.0-kirkwood
mv /boot/initrd.img-3.0.0 /boot/initrd.img-3.0.0-kirkwood
mv /boot/System.map-3.0.0 /boot/System.map-3.0.0-kirkwood
mv /boot/vmlinuz-3.0.0 /boot/vmlinuz-3.0.0-kirkwood

# process installed kernel to create uImage, uInitrd, dtb
FK_MACHINE="Globalscale Technologies Dreamplug" flash-kernel

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
