# /usr/bin/make
TODAY = `date +%Y.%m%d`
NAME = freedombox-unstable
IMAGE = "$(NAME)_$(TODAY).img"
VBOX = "$(NAME)_$(TODAY).vdi"
ARCHIVE = "$(NAME)_$(TODAY).tar.bz2"
# make a test image the size of the build file, with a 1MB buffer.
SIZE = `expr \`du -sm build | sed 's/build.*//'\` + 1`
LOOP = /dev/loop0

# copy DreamPlug root filesystem to a usb stick 
# stick assumed to have 2 partitions, 128meg FAT and the rest ext3 partition
dreamstick:	stamp-dreamplug-rootfs predepend
# 	bin/partition-stick
	mount /media/freedom
	sudo mkdir -p /media/freedom/boot
	mount /media/freedom/boot
	sudo rsync -atvz --progress --delete --exclude=boot build/dreamplug/ /media/freedom/
	cp build/dreamplug/boot/* /media/freedom/boot/
	sync
	sleep 1
	umount /media/freedom/boot
	umount /media/freedom

predepend:
	sudo apt-get install multistrap qemu-user-static u-boot-tools git mercurial
	touch predepend

# populate a tree with DreamPlug root filesystem
stamp-dreamplug-rootfs: fbx-armel.conf fbx-base.conf mk_dreamplug_rootfs
	sudo ./mk_dreamplug_rootfs
	touch stamp-dreamplug-rootfs

clean:
	rm -f stamp-dreamplug-rootfs
# just in case I tried to build before plugging in the USB drive.
	-sudo umount `pwd`/build/dreamplug/var/cache/apt/
	sudo rm -rf build/dreamplug

distclean:	clean
	sudo rm -rf build

test-card: stamp-dreamplug-rootfs
	mount /media/freedom
	sudo mkdir -p /media/freedom/boot
	mount /media/freedom/boot
	sudo rsync -atvz --progress --delete --exclude=boot build/dreamplug/ /media/freedom/
	cp build/dreamplug/boot/* /media/freedom/boot/
# we don't need to copy2dream, this is already on the microSD card.
	sudo rm /media/freedom/sbin/copy2dream
# fix fstab for the SD card.
	sed -e 's/sdc1/sda1/g' < source/etc/fstab > /media/freedom/etc/fstab
	sync
	sleep 1
	umount /media/freedom/boot
	umount /media/freedom
	@echo "Build complete.  Remember to login as root."
