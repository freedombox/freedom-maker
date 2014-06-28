#! /usr/bin/make

# armel amd64 i386
ARCHITECTURE = armel
# dreamplug guruplug virtualbox raspberry(pi)
MACHINE = dreamplug
# card usb hdd
DESTINATION = card
BUILD = $(MACHINE)-$(ARCHITECTURE)-$(DESTINATION)
TODAY := `date +%Y-%m-%d`
NAME = build/freedombox-unstable_$(TODAY)_$(BUILD)
WEEKLY_DIR = torrent/freedombox-unstable_$(TODAY)
IMAGE = $(NAME).img
ARCHIVE = $(NAME).tar.bz2
SIGNATURE = $(ARCHIVE).sig
SUITE = sid
SOURCE = false
OWNER = 1000
TAR = tar --checkpoint=1000 --checkpoint-action=dot -cjvf
MAKE_IMAGE = ARCHITECTURE=$(ARCHITECTURE) DESTINATION=$(DESTINATION) \
    MACHINE=$(MACHINE) SOURCE=$(SOURCE) SUITE=$(SUITE) OWNER=$(OWNER) \
    bin/mk_freedombox_image $(NAME)
SIGN = -gpg --output $(SIGNATURE) --detach-sig $(ARCHIVE)


# build DreamPlug USB or SD card image
dreamplug: prep
	$(eval ARCHITECTURE = armel)
	$(eval MACHINE = dreamplug)
	$(eval DESTINATION = card)
	$(MAKE_IMAGE)
	$(TAR) $(ARCHIVE) $(IMAGE)
	@echo ""
	$(SIGN)
	@echo "Build complete."

# build Raspberry Pi SD card image
raspberry: prep
	$(eval ARCHITECTURE = armel)
	$(eval MACHINE = raspberry)
	$(eval DESTINATION = card)
	$(MAKE_IMAGE)
	$(TAR) $(ARCHIVE) $(IMAGE)
	@echo ""
	$(SIGN)
	@echo "Build complete."

# build Beaglebone SD card image
beaglebone: prep
	$(eval ARCHITECTURE = armhf)
	$(eval MACHINE = beaglebone)
	$(eval DESTINATION = card)
	$(MAKE_IMAGE)
	$(TAR) $(ARCHIVE) $(IMAGE)
	@echo ""
	$(SIGN)
	@echo "Build complete."

# build a virtualbox image
virtualbox: prep
	$(eval ARCHITECTURE = i386)
	$(eval MACHINE = virtualbox)
	$(eval DESTINATION = hdd)
	$(MAKE_IMAGE)
# Convert image to vdi hard drive
	VBoxManage convertdd $(NAME).img $(NAME).vdi
	$(TAR) $(ARCHIVE) $(NAME).vdi
	@echo ""
	$(SIGN)
	@echo "Build complete."

prep:
	mkdir -p build

clean:
	-rm -f $(IMAGE) $(ARCHIVE)

distclean: clean
	sudo rm -rf build
