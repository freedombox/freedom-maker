# /usr/bin/make

# armel amd64 i386
ARCHITECTURE = armel
# dreamplug guruplug
MACHINE = dreamplug
# card usb
DESTINATION = card
BUILD = $(MACHINE)-$(ARCHITECTURE)-$(DESTINATION)
BUILD_DIR = build/$(ARCHITECTURE)
MOUNTPOINT = /media/freedom
BOOTPOINT = $(MOUNTPOINT)/boot
DEVICE = /dev/sdb
TODAY = `date +%Y.%m%d`
NAME = freedombox-unstable_$(TODAY)_$(BUILD)
IMAGE = $(NAME).img
ARCHIVE = $(NAME).tar.bz2
LOOP = /dev/loop0

# populate a tree with DreamPlug root filesystem
rootfs: rootfs-$(ARCHITECTURE)
rootfs-$(ARCHITECTURE): multistrap-configs/fbx-base.conf \
		multistrap-configs/fbx-$(ARCHITECTURE).conf \
		mk_dreamplug_rootfs \
		bin/projects bin/finalize bin/projects-chroot
	-sudo umount `pwd`/$(BUILD_DIR)/var/cache/apt/
	sudo ./mk_dreamplug_rootfs $(ARCHITECTURE) multistrap-configs/fbx-$(ARCHITECTURE).conf
	touch rootfs-$(ARCHITECTURE)

# copy DreamPlug root filesystem to a usb stick or microSD card
# stick assumed to have 2 partitions, 128meg FAT and the rest ext3 partition
image: rootfs-$(ARCHITECTURE)
	-umount $(BOOTPOINT)
	-umount $(MOUNTPOINT)
	mount $(MOUNTPOINT)
	sudo mkdir -p $(BOOTPOINT)
	mount $(BOOTPOINT)
	sudo rsync -atvz --progress --delete --exclude=boot $(BUILD_DIR)/ $(MOUNTPOINT)/
	cp $(BUILD_DIR)/boot/* $(BOOTPOINT)/
ifeq ($(DESTINATION),usb)
# prevent the first-run script from running during boot.
# we'll do this during copy2dream.
	rm $(MOUNTPOINT)/etc/rc1.d/S01first-run $(MOUNTPOINT)/etc/rc2.d/S01first-run
endif
ifeq ($(DESTINATION),card)
# we don't need to copy2dream, this is the microSD card.
	sudo rm $(MOUNTPOINT)/sbin/copy2dream
# fix fstab for the SD card.
	sudo sh -c "sed -e 's/sdc1/sda1/g' < $(BUILD_DIR)/etc/fstab > $(MOUNTPOINT)/etc/fstab"
endif
ifeq ($(MACHINE),guruplug)
# we can't flash the guru plug's kernel
	mkdir -p $(MOUNTPOINT)/var/freedombox/
	touch $(MOUNTPOINT)/var/freedombox/dont-tweak-kernel
endif
	sync
	sleep 1
	umount $(BOOTPOINT)
	umount $(MOUNTPOINT)
	@echo "Build complete."

# build a virtualbox image
virtualbox-image: stamp-vbox-predepend
	./mk_virtualbox_image freedombox-unstable_$(TODAY)_virtualbox-i386-hdd


# build the weekly test image
weekly-image: image
# if we aren't installing to an armel system, assume we need a bootloader.
ifneq ($(ARCHITECTURE),armel)
# also, try my best to protect users from themselves:
ifneq ($(DEVICE),/dev/sda)
	sudo grub-install $(DEVICE)
endif
endif
	dd if=$(DEVICE) of=$(IMAGE) bs=1M
	@echo "Image copied.  The microSD card may now be removed."
	tar -cjvf $(ARCHIVE) $(IMAGE)

#
# meta
#

# install required files so users don't need to do it themselves.
stamp-predepend:
	sudo sh -c "apt-get install multistrap qemu-user-static u-boot-tools git mercurial debootstrap extlinux qemu-utils parted mbr kpartx virtualbox bzr python-sphinx"
	touch stamp-predepend

stamp-vbox-predepend:
	sudo sh -c "apt-get install debootstrap extlinux qemu-utils parted mbr kpartx python-cliapp apache2"
	touch stamp-vbox-predepend

clean:
# just in case I tried to build before plugging in the USB drive.
	-sudo umount `pwd`/$(BUILD_DIR)/var/cache/apt/
	sudo rm -rf $(BUILD_DIR)
	-rm -f $(IMAGE) $(ARCHIVE)
	-rm -f rootfs-* stamp-*

distclean: clean
	sudo rm -rf build

# remove all data from the microSD card to repopulate it with a pristine image.
clean-card:
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
