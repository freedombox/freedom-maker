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

# build DreamPlug USB or SD card image
dreamplug: prep
	$(eval ARCHITECTURE = armel)
	$(eval MACHINE = dreamplug)
	$(eval DESTINATION = card)

	ARCHITECTURE=$(ARCHITECTURE) DESTINATION=$(DESTINATION) MACHINE=$(MACHINE) \
	  SOURCE=$(SOURCE) SUITE=$(SUITE) OWNER=$(OWNER) \
	  bin/mk_freedombox_image $(NAME)

	tar -cjvf $(ARCHIVE) $(IMAGE)
	-gpg --output $(SIGNATURE) --detach-sig $(ARCHIVE)
	@echo "Build complete."

# build Raspberry Pi SD card image
raspberry: prep
	$(eval ARCHITECTURE = armel)
	$(eval MACHINE = raspberry)
	$(eval DESTINATION = card)

	ARCHITECTURE=$(ARCHITECTURE) DESTINATION=$(DESTINATION) MACHINE=$(MACHINE) \
	  SOURCE=$(SOURCE) SUITE=$(SUITE) OWNER=$(OWNER) \
	  bin/mk_freedombox_image $(NAME)

	tar -cjvf $(ARCHIVE) $(IMAGE)
	-gpg --output $(SIGNATURE) --detach-sig $(ARCHIVE)
	@echo "Build complete."

# build Beaglebone SD card image
beaglebone: prep
	$(eval ARCHITECTURE = armhf)
	$(eval MACHINE = beaglebone)
	$(eval DESTINATION = card)

	ARCHITECTURE=$(ARCHITECTURE) DESTINATION=$(DESTINATION) MACHINE=$(MACHINE) \
	  SOURCE=$(SOURCE) SUITE=$(SUITE) OWNER=$(OWNER) \
	  bin/mk_freedombox_image $(NAME)

	tar -cjvf $(ARCHIVE) $(IMAGE)
	-gpg --output $(SIGNATURE) --detach-sig $(ARCHIVE)
	@echo "Build complete."

# build a virtualbox image
virtualbox: prep
	$(eval ARCHITECTURE = i386)
	$(eval MACHINE = virtualbox)
	$(eval DESTINATION = hdd)

	ARCHITECTURE=$(ARCHITECTURE) DESTINATION=$(DESTINATION) MACHINE=$(MACHINE) \
	  SOURCE=$(SOURCE) SUITE=$(SUITE) OWNER=$(OWNER) \
	  bin/mk_freedombox_image $(NAME)

# Convert image to vdi hard drive
	VBoxManage convertdd $(NAME).img $(NAME).vdi
	tar -cjvf $(ARCHIVE) $(NAME).vdi
	-gpg --output $(SIGNATURE) --detach-sig $(ARCHIVE)
	@echo "Build complete."

prep:
	mkdir -p build

clean:
	-rm -f $(IMAGE) $(ARCHIVE)

distclean: clean
	sudo rm -rf build

weekly: dreamplug raspberry virtualbox
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
