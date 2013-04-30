#! /usr/bin/make

# armel amd64 i386
ARCHITECTURE = armel
# dreamplug guruplug virtualbox
MACHINE = dreamplug
# card usb hdd
DESTINATION = card
BUILD = $(MACHINE)-$(ARCHITECTURE)-$(DESTINATION)
STAMP = build/stamp
BUILD_DIR = build/$(ARCHITECTURE)
MOUNTPOINT = /media/freedom
BOOTPOINT = $(MOUNTPOINT)/boot
DEVICE = /dev/sdb
TODAY := `date +%Y.%m%d`
NAME = build/freedombox-unstable_$(TODAY)_$(BUILD)
WEEKLY_DIR = torrent/freedombox-unstable_$(TODAY)
IMAGE = $(NAME).img
ARCHIVE = $(NAME).tar.bz2
SIGNATURE = $(ARCHIVE).sig
LOOP = /dev/loop0

# populate a tree with DreamPlug root filesystem
rootfs: $(STAMP)-rootfs-$(ARCHITECTURE)
$(STAMP)-rootfs-$(ARCHITECTURE): multistrap-configs/fbx-base.conf \
		multistrap-configs/fbx-$(ARCHITECTURE).conf \
		bin/mk_dreamplug_rootfs \
		bin/projects bin/finalize bin/projects-chroot \
		$(STAMP)-predepend

	-sudo umount `pwd`/$(BUILD_DIR)/var/cache/apt/
	ln -sf fstab-$(DESTINATION) fstab
	mv fstab source/etc
	sudo bin/mk_dreamplug_rootfs $(ARCHITECTURE) multistrap-configs/fbx-$(ARCHITECTURE).conf
	touch $(STAMP)-rootfs-$(ARCHITECTURE)

# copy DreamPlug root filesystem to a usb stick or microSD card
# stick assumed to have 2 partitions, 128meg FAT and the rest ext3 partition
image: $(STAMP)-rootfs-$(ARCHITECTURE)
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
# add u-boot binary for the DreamPlug to the FAT partition for easy access
	cp -r $(MOUNTPOINT)/usr/lib/u-boot/dreamplug $(MOUNTPOINT)/boot
endif
ifeq ($(DESTINATION),card)
# we don't need to copy2dream, this is the microSD card.
	sudo rm $(MOUNTPOINT)/sbin/copy2dream
endif
ifeq ($(MACHINE),guruplug)
# we can't flash the guru plug's kernel
	touch $(MOUNTPOINT)/var/freedombox/dont-tweak-kernel
endif
	sync
	sleep 1
	umount $(BOOTPOINT)
	umount $(MOUNTPOINT)
	@echo "Build complete."

# build a virtualbox image
virtualbox-image: $(STAMP)-vbox-predepend
	$(eval TEMP_ARCHITECTURE=$(ARCHITECTURE))
	$(eval TEMP_MACHINE$(MACHINE))
	$(eval TEMP_DESTINATION$(DESTINATION))
	$(eval ARCHITECTURE=i386)
	$(eval MACHINE=virtualbox)
	$(eval DESTINATION=hdd)
	bin/mk_virtualbox_image $(NAME)
	tar -cjvf $(ARCHIVE) $(NAME).vdi
	-gpg --output $(SIGNATURE) --detach-sig $(ARCHIVE)
	$(eval ARCHITECTURE=$(TEMP_ARCHITECTURE))
	$(eval MACHINE=$(TEMP_MACHINE)
	$(eval DESTINATION=$(TEMP_DESTINATION)

# build the weekly test image
plugserver-image: image
# if we aren't installing to an armel system, assume we need a bootloader.
ifneq ($(ARCHITECTURE),armel)
# also, try my best to protect users from themselves:
ifneq ($(DEVICE),/dev/sda)
	sudo grub-install $(DEVICE)
endif
endif
	dd if=$(DEVICE) of=$(IMAGE) bs=1M count=1900
	@echo "Image copied.  The microSD card may now be removed."
	tar -cjvf $(ARCHIVE) $(IMAGE)
	-gpg --output $(SIGNATURE) --detach-sig $(ARCHIVE)

#
# meta
#

# install required files so users don't need to do it themselves.
$(STAMP)-vbox-predepend: $(STAMP)-predepend
	sudo sh -c "apt-get install debootstrap extlinux qemu-utils parted mbr kpartx python-cliapp virtualbox"
	touch $(STAMP)-vbox-predepend

$(STAMP)-predepend:
	mkdir -p build vendor
	sudo sh -c "apt-get install multistrap qemu-user-static u-boot-tools git mercurial python-docutils mktorrent"
	touch $(STAMP)-predepend

clean:
# just in case I tried to build before plugging in the USB drive.
	-sudo umount `pwd`/$(BUILD_DIR)/var/cache/apt/
	sudo rm -rf $(BUILD_DIR)
	-rm -f $(IMAGE) $(ARCHIVE) $(STAMP)-*

distclean: clean clean-card
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

weekly-image: plugserver-image virtualbox-image
	mkdir -p $(WEEKLY_DIR)
	mv build/*bz2 build/*sig $(WEEKLY_DIR)
	cp weekly_template.org $(WEEKLY_DIR)/README.org
	echo "http://betweennowhere.net/freedombox-images/$(WEEKLY_DIR)" > torrent/webseed
	@echo ""
	@echo "----------"
	@echo "When the README has been updated, hit Enter."
	read X
	mktorrent -a `cat torrent/trackers` -w `cat torrent/webseed` $(WEEKLY_DIR)
	mv $(WEEKLY_DIR).torrent torrent/
