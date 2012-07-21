# /usr/bin/make

MOUNTPOINT = /media/freedom
BOOTPOINT = $(MOUNTPOINT)/boot
DEVICE = /dev/sdb
TODAY = `date +%Y.%m%d`
NAME = freedombox-unstable
IMAGE = "$(NAME)_$(TODAY).img"
ARCHIVE = "$(NAME)_$(TODAY).tar.bz2"
LOOP = /dev/loop0

#
# armel
#

# copy DreamPlug root filesystem to a usb stick
# stick assumed to have 2 partitions, 128meg FAT and the rest ext3 partition
dreamstick:	stamp-dreamplug-rootfs predepend
# 	bin/partition-stick
	mount $(MOUNTPOINT)
	sudo mkdir -p $(BOOTPOINT)
	mount $(BOOTPOINT)
	sudo rsync -atvz --progress --delete --exclude=boot build/dreamplug/ $(MOUNTPOINT)/
	cp kernel/* $(BOOTPOINT)/
	cp build/dreamplug/boot/* $(BOOTPOINT)/

# prevent the first-run script from running during boot.
# we'll do that during copy2dream.
	rm $(MOUNTPOINT)/etc/init.d/first-run $(MOUNTPOINT)/etc/rc1.d/S01first-run $(MOUNTPOINT)/etc/rc2.d/S01first-run

# and finish!
	sync
	sleep 1
	umount $(BOOTPOINT)
	umount $(MOUNTPOINT)

# populate a tree with DreamPlug root filesystem
stamp-dreamplug-rootfs: multistrap-configs/fbx-armel.conf \
		multistrap-configs/fbx-base.conf mk_dreamplug_rootfs \
		bin/projects bin/finalize
	sudo ./mk_dreamplug_rootfs multistrap-configs/fbx-armel.conf
	touch stamp-dreamplug-rootfs

# install required files so users don't need to do it themselves.
predepend:
	sudo sh -c "apt-get install multistrap qemu-user-static u-boot-tools git mercurial"
	touch predepend

# populate the microSD card with a bootable file system
microSd-armel: stamp-dreamplug-rootfs
	-umount $(BOOTPOINT)
	-umount $(MOUNTPOINT)
	mount $(MOUNTPOINT)
	sudo mkdir -p $(BOOTPOINT)
	mount $(BOOTPOINT)
	sudo rsync -atvz --progress --delete --exclude=boot build/dreamplug/ $(MOUNTPOINT)/
	cp kernel/* $(BOOTPOINT)/
	cp build/dreamplug/boot/* $(BOOTPOINT)/
# we don't need to copy2dream, this is the microSD card.
	sudo rm $(MOUNTPOINT)/sbin/copy2dream
# fix fstab for the SD card.
	sudo sh -c "sed -e 's/sdc1/sda1/g' < source/etc/fstab > $(MOUNTPOINT)/etc/fstab"
	sync
	sleep 1
	umount $(BOOTPOINT)
	umount $(MOUNTPOINT)
	@echo "Build complete."

# build the weekly test image
weekly-armel: clean-card microSd-armel
	dd if=$(DEVICE) of=$(IMAGE)-armel bs=1M
	@echo "Image copied.  The microSD card may now be removed."
	tar -cjvf $(ARCHIVE)-armel $(IMAGE)-armel

#
# i386
#

#
# amd64
#

rootfs-amd64: multistrap-configs/fbx-armel.conf \
		multistrap-configs/fbx-base.conf mk_dreamplug_rootfs bin/projects \
        bin/finalize
	sudo ./mk_dreamplug_rootfs multistrap-configs/fbx-amd64.conf
	touch stamp-dreamplug-rootfs

#
# meta
#

clean:
	rm -f stamp-dreamplug-rootfs
# just in case I tried to build before plugging in the USB drive.
	-sudo umount `pwd`/build/dreamplug/var/cache/apt/
	sudo rm -rf build/dreamplug
	-rm $(IMAGE) $(ARCHIVE)

distclean: clean
	sudo rm -rf build

# remove all data from the microSD card to repopulate it with a pristine image.
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
