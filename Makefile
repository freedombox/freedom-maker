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

# yes no
ENABLE_NONFREE = no
BUILD = $(MACHINE)-$(ARCHITECTURE)
TODAY := $(shell date +%Y-%m-%d)
FREE_TAG = $(if $(findstring yes, $(ENABLE_NONFREE)),nonfree,free)
NAME = build/freedombox-unstable-$(FREE_TAG)_$(TODAY)_$(BUILD)
IMAGE = $(NAME).img
ARCHIVE = $(NAME).tar.bz2
SIGNATURE = $(ARCHIVE).sig
OWNER = 1000
TAR = tar --checkpoint=1000 --checkpoint-action=dot -cjvf
SIGN = -gpg --output $(SIGNATURE) --detach-sig $(ARCHIVE)

# settings for `make test`
TEST_SSH_PORT = 2222
TEST_FIRSTRUN_WAIT_TIME = 120 # seconds

# Using taskset to pin build process to single core. This is a
# workaround for a qemu-user-static issue that causes builds to
# hang. (See Debian bug #769983 for details.)
MAKE_IMAGE = ARCHITECTURE=$(ARCHITECTURE) MACHINE=$(MACHINE) SOURCE=$(SOURCE) \
    MIRROR=$(MIRROR) SUITE=$(SUITE) OWNER=$(OWNER) \
    BUILD_MIRROR=$(BUILD_MIRROR) ENABLE_NONFREE=$(ENABLE_NONFREE) \
    CUSTOM_PLINTH=$(CUSTOM_PLINTH) CUSTOM_SETUP=$(CUSTOM_SETUP) \
    IMAGE_SIZE=$(IMAGE_SIZE) taskset 0x01 bin/mk_freedombox_image $(NAME)

# build DreamPlug USB or SD card image
dreamplug: prep
	$(eval ARCHITECTURE = armel)
	$(eval MACHINE = dreamplug)
	$(eval ENABLE_NONFREE = yes)
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

test: test-virtualbox

test-virtualbox: virtualbox
	$(eval VM_NAME = freedom-maker-test)
	VBoxManage createvm --name $(VM_NAME) --ostype "Debian" --register
	VBoxManage storagectl $(VM_NAME) --name "SATA Controller" --add sata \
		 --controller IntelAHCI
	VBoxManage storageattach $(VM_NAME) --storagectl "SATA Controller" \
		--port 0 --device 0 --type hdd --medium $(NAME).vdi
	VBoxManage modifyvm $(VM_NAME) --pae on --memory 1024 --vram 128 \
		--nic1 nat --natpf1 ,tcp,,$(TEST_SSH_PORT),,22
	VBoxManage startvm $(VM_NAME) --type headless
	sleep $(TEST_FIRSTRUN_WAIT_TIME) # wait for first-run to complete
	echo frdm |sshpass -p frdm ssh -o UserKnownHostsFile=/dev/null \
		-o StrictHostKeyChecking=no -t -t \
		-p $(TEST_SSH_PORT) fbx@127.0.0.1 \
		"sudo plinth --diagnose" \
		|tee build/$(VM_NAME)-results_$(TODAY).log
	VBoxManage controlvm $(VM_NAME) poweroff
	VBoxManage modifyvm $(VM_NAME) --hda none
	VBoxManage unregistervm $(VM_NAME) --delete

vendor/vmdebootstrap/vmdebootstrap: vendor-patches/vmdebootstrap/*.patch
	bin/fetch-new-vmdebootstrap

prep: vendor/vmdebootstrap/vmdebootstrap
	mkdir -p build

clean:
	-rm -f build/freedombox.log

distclean: clean
	sudo rm -rf build
