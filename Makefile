# /usr/bin/make
MOUNTPOINT = /media/freedom
BOOTPOINT = $(MOUNTPOINT)/boot
DEVICE = /dev/sdb
TODAY = `date +%Y.%m%d`
NAME = freedombox-unstable
IMAGE = "$(NAME)_$(TODAY).img"
ARCHIVE = "$(NAME)_$(TODAY).tar.bz2"
# make a test image the size of the build file, with a 1MB buffer.
SIZE = `expr \`du -sm build | sed 's/build.*//'\` + 1`
LOOP = /dev/loop0

# copy DreamPlug root filesystem to a usb stick 
# stick assumed to have 2 partitions, 128meg FAT and the rest ext3 partition
dreamstick:	stamp-dreamplug-rootfs predepend
# 	bin/partition-stick
	mount $(MOUNTPOINT)
	sudo mkdir -p $(BOOTPOINT)
	mount $(BOOTPOINT)
	sudo rsync -atvz --progress --delete --exclude=boot build/dreamplug/ $(MOUNTPOINT)/
	cp build/dreamplug/boot/* $(BOOTPOINT)/
	sync
	sleep 1
	umount $(BOOTPOINT)
	umount $(MOUNTPOINT)

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
	-umount $(BOOTPOINT)
	-umount $(MOUNTPOINT)
	mount $(MOUNTPOINT)
	sudo mkdir -p $(BOOTPOINT)
	mount $(BOOTPOINT)
	sudo rsync -atvz --progress --delete --exclude=boot build/dreamplug/ $(MOUNTPOINT)/
	cp build/dreamplug/boot/* $(BOOTPOINT)/
# we don't need to copy2dream, this is already on the microSD card.
	sudo rm $(MOUNTPOINT)/sbin/copy2dream
# fix fstab for the SD card.
	sudo sh -c "sed -e 's/sdc1/sda1/g' < source/etc/fstab > $(MOUNTPOINT)/etc/fstab"
	sync
	sleep 1
	umount $(BOOTPOINT)
	umount $(MOUNTPOINT)
	@echo "Build complete.  Remember to login as root."

clean-card: clean
	-umount $(BOOTPOINT)
	-umount $(MOUNTPOINT)

	sudo mkdir -p $(BOOTPOINT)
	mount $(BOOTPOINT)
	sudo rm -rf $(BOOTPOINT)/*
	umount $(BOOTPOINT)

	sudo mkdir -p $(MOUNTPOINT)
	mount $(MOUNTPOINT)
	sudo rm -rf $(MOUNTPOINT)/*
	umount $(MOUNTPOINT)

weekly-card: clean-card test-card
	dd if=$(DEVICE) of=$(IMAGE) bs=1M
	tar -cjvf $(ARCHIVE) $(IMAGE)
