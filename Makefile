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
TODAY := `date +%Y-%m-%d`
NAME = build/freedombox-unstable_$(TODAY)_$(BUILD)
WEEKLY_DIR = torrent/freedombox-unstable_$(TODAY)
IMAGE = $(NAME).img
ARCHIVE = $(NAME).tar.bz2
SIGNATURE = $(ARCHIVE).sig

image: dreamplug-image

# build DreamPlug USB or SD card image
dreamplug-image: vendor/vmdebootstrap/vmdebootstrap
	$(eval TEMP_ARCHITECTURE = $(ARCHITECTURE))
	$(eval TEMP_MACHINE = $(MACHINE))
	$(eval TEMP_DESTINATION = $(DESTINATION))
	$(eval ARCHITECTURE = armel)
	$(eval MACHINE = dreamplug)
	$(eval DESTINATION = card)
	ARCHITECTURE=$(ARCHITECTURE) MACHINE=$(MACHINE) DESTINATION=$(DESTINATION) \
	  bin/mk_freedombox_image $(NAME)
	tar -cjvf $(ARCHIVE) $(IMAGE)
	-gpg --output $(SIGNATURE) --detach-sig $(ARCHIVE)
	$(eval ARCHITECTURE = $(TEMP_ARCHITECTURE))
	$(eval MACHINE = $(TEMP_MACHINE))
	$(eval DESTINATION = $(TEMP_DESTINATION))
	@echo "Build complete."

# build Raspberry Pi SD card image
raspberry-image: vendor/vmdebootstrap/vmdebootstrap
	$(eval TEMP_ARCHITECTURE = $(ARCHITECTURE))
	$(eval TEMP_MACHINE = $(MACHINE))
	$(eval TEMP_DESTINATION = $(DESTINATION))
	$(eval ARCHITECTURE = armel)
	$(eval MACHINE = raspberry)
	$(eval DESTINATION = card)
	ARCHITECTURE=$(ARCHITECTURE) MACHINE=$(MACHINE) DESTINATION=$(DESTINATION) \
	  bin/mk_freedombox_image $(NAME)
	tar -cjvf $(ARCHIVE) $(IMAGE)
	-gpg --output $(SIGNATURE) --detach-sig $(ARCHIVE)
	$(eval ARCHITECTURE = $(TEMP_ARCHITECTURE))
	$(eval MACHINE = $(TEMP_MACHINE))
	$(eval DESTINATION = $(TEMP_DESTINATION))
	@echo "Build complete."

# build a virtualbox image
virtualbox-image: vendor/vmdebootstrap/vmdebootstrap
	$(eval TEMP_ARCHITECTURE = $(ARCHITECTURE))
	$(eval TEMP_MACHINE = $(MACHINE))
	$(eval TEMP_DESTINATION = $(DESTINATION))
	$(eval ARCHITECTURE = i386)
	$(eval MACHINE = virtualbox)
	$(eval DESTINATION = hdd)
	ARCHITECTURE=$(ARCHITECTURE) MACHINE=$(MACHINE) DESTINATION=$(DESTINATION) \
	  bin/mk_freedombox_image $(NAME)
# Convert image to vdi hard drive
	VBoxManage convertdd $IMAGE.img $IMAGE.vdi
	tar -cjvf $(ARCHIVE) $(NAME).vdi
	-gpg --output $(SIGNATURE) --detach-sig $(ARCHIVE)
	$(eval ARCHITECTURE = $(TEMP_ARCHITECTURE))
	$(eval MACHINE = $(TEMP_MACHINE))
	$(eval DESTINATION = $(TEMP_DESTINATION))
	@echo "Build complete."

vendor/vmdebootstrap/vmdebootstrap: 
	test -d vendor/vmdebootstrap || git clone git://git.liw.fi/vmdebootstrap vendor/vmdebootstrap
	cd vendor/vmdebootstrap; git pull


clean:
	sudo rm -rf $(BUILD_DIR)
	-rm -f $(IMAGE) $(ARCHIVE) $(STAMP)-*
	-rm -f rootfs-* source/etc/fstab

distclean: clean
	sudo rm -rf build

weekly-image: dreamplug-image raspberry-image virtualbox-image
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
