#!/usr/bin/make
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# Where to fetch packages
MIRROR ?= http://httpredir.debian.org/debian
BUILD_MIRROR ?= http://httpredir.debian.org/debian
IMAGE_SIZE ?= 4G
SUITE ?= sid
# include source packages in image?
SOURCE ?= false

# armel armhf i386 amd64
ARCHITECTURE = armel
# dreamplug raspberry raspberry2 beaglebone cubietruck all virtualbox
MACHINE = dreamplug
# yes no
ENABLE_NONFREE = no
BUILD = $(MACHINE)-$(ARCHITECTURE)
TODAY := $(shell date +%Y-%m-%d)
NAME = build/freedombox-unstable-$(NON)free_$(TODAY)_$(BUILD)
IMAGE = $(NAME).img
ARCHIVE = $(NAME).tar.bz2
SIGNATURE = $(ARCHIVE).sig
OWNER = 1000
TAR = tar --checkpoint=1000 --checkpoint-action=dot -cjvf
SIGN = -gpg --output $(SIGNATURE) --detach-sig $(ARCHIVE)

# Using taskset to pin build process to single core. This is a
# workaround for a qemu-user-static issue that causes builds to
# hang. (See Debian bug #769983 for details.)
MAKE_IMAGE = ARCHITECTURE=$(ARCHITECTURE) MACHINE=$(MACHINE) SOURCE=$(SOURCE) \
    MIRROR=$(MIRROR) SUITE=$(SUITE) OWNER=$(OWNER) \
    BUILD_MIRROR=$(BUILD_MIRROR) ENABLE_NONFREE=$(ENABLE_NONFREE) \
    IMAGE_SIZE=$(IMAGE_SIZE) taskset 0x01 bin/mk_freedombox_image $(NAME)

# build DreamPlug USB or SD card image
dreamplug: prep
	$(eval ARCHITECTURE = armel)
	$(eval MACHINE = dreamplug)
	$(eval ENABLE_NONFREE = yes)
	$(eval NON = non)
	$(MAKE_IMAGE)
	$(TAR) $(ARCHIVE) $(IMAGE)
	@echo ""
	$(SIGN)
	@echo "Build complete."

# build Raspberry Pi SD card image
raspberry: prep
	$(eval ARCHITECTURE = armel)
	$(eval MACHINE = raspberry)
	$(eval ENABLE_NONFREE = yes)
	$(eval NON = non)
	$(MAKE_IMAGE)
	$(TAR) $(ARCHIVE) $(IMAGE)
	@echo ""
	$(SIGN)
	@echo "Build complete."

# build Raspberry Pi 2 SD card image
raspberry2: prep
	$(eval ARCHITECTURE = armhf)
	$(eval MACHINE = raspberry2)
	$(eval ENABLE_NONFREE = yes)
	$(eval NON = non)
	$(MAKE_IMAGE)
	$(TAR) $(ARCHIVE) $(IMAGE)
	@echo ""
	$(SIGN)
	@echo "Build complete."

# build Beaglebone SD card image
beaglebone: prep
	$(eval ARCHITECTURE = armhf)
	$(eval MACHINE = beaglebone)
	$(MAKE_IMAGE)
	$(TAR) $(ARCHIVE) $(IMAGE)
	@echo ""
	$(SIGN)
	@echo "Build complete."

# build CubieTruck SD card image
cubietruck: prep
	$(eval ARCHITECTURE = armhf)
	$(eval MACHINE = cubietruck)
	$(MAKE_IMAGE)
	$(TAR) $(ARCHIVE) $(IMAGE)
	@echo ""
	$(SIGN)
	@echo "Build complete."

# build an i386 image
i386: prep
	$(eval ARCHITECTURE = i386)
	$(eval MACHINE = all)
	$(MAKE_IMAGE)
	$(TAR) $(ARCHIVE) $(IMAGE)
	@echo ""
	$(SIGN)
	@echo "Build complete."

# build an amd64 image
amd64: prep
	$(eval ARCHITECTURE = amd64)
	$(eval MACHINE = all)
	$(MAKE_IMAGE)
	$(TAR) $(ARCHIVE) $(IMAGE)
	@echo ""
	$(SIGN)
	@echo "Build complete."

# build a virtualbox image
virtualbox: virtualbox-i386

virtualbox-i386: prep
	$(eval ARCHITECTURE = i386)
	$(eval MACHINE = virtualbox)
	$(MAKE_IMAGE)
	# Convert image to vdi hard drive
	VBoxManage convertdd $(NAME).img $(NAME).vdi
	$(TAR) $(ARCHIVE) $(NAME).vdi
	@echo ""
	$(SIGN)
	@echo "Build complete."

virtualbox-amd64: prep
	$(eval ARCHITECTURE = amd64)
	$(eval MACHINE = virtualbox)
	$(MAKE_IMAGE)
	# Convert image to vdi hard drive
	VBoxManage convertdd $(NAME).img $(NAME).vdi
	$(TAR) $(ARCHIVE) $(NAME).vdi
	@echo ""
	$(SIGN)
	@echo "Build complete."

vendor/vmdebootstrap/vmdebootstrap: vendor-patches/vmdebootstrap/*.patch
	bin/fetch-new-vmdebootstrap

prep: vendor/vmdebootstrap/vmdebootstrap
	mkdir -p build

clean:
	-rm -f build/freedombox.log
	-rm -f $(IMAGE) $(ARCHIVE)

distclean: clean
	sudo rm -rf build
