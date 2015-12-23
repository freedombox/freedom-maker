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
ARCHIVE = $(IMAGE).xz
SIGNATURE = $(ARCHIVE).sig
OWNER = 1000
XZ = xz --best --verbose
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
	$(eval IMAGE = $(NAME).img)
	$(MAKE_IMAGE)
	@rm -f $(ARCHIVE)
	$(XZ) $(IMAGE)
	@echo ""
	$(SIGN)
	@echo "Build complete."

# build Raspberry Pi SD card image
raspberry: prep
	$(eval ARCHITECTURE = armel)
	$(eval MACHINE = raspberry)
	$(eval ENABLE_NONFREE = yes)
	$(eval IMAGE = $(NAME).img)
	$(MAKE_IMAGE)
	@rm -f $(ARCHIVE)
	$(XZ) $(IMAGE)
	@echo ""
	$(SIGN)
	@echo "Build complete."

# build Raspberry Pi 2 SD card image
raspberry2: prep
	$(eval ARCHITECTURE = armhf)
	$(eval MACHINE = raspberry2)
	$(eval ENABLE_NONFREE = yes)
	$(eval IMAGE = $(NAME).img)
	$(MAKE_IMAGE)
	@rm -f $(ARCHIVE)
	$(XZ) $(IMAGE)
	@echo ""
	$(SIGN)
	@echo "Build complete."

# build Beaglebone SD card image
beaglebone: prep
	$(eval ARCHITECTURE = armhf)
	$(eval MACHINE = beaglebone)
	$(eval IMAGE = $(NAME).img)
	$(MAKE_IMAGE)
	@rm -f $(ARCHIVE)
	$(XZ) $(IMAGE)
	@echo ""
	$(SIGN)
	@echo "Build complete."

# build Cubieboard2 SD card image
cubieboard2: prep
	$(eval ARCHITECTURE = armhf)
	$(eval MACHINE = cubieboard2)
	$(eval IMAGE = $(NAME).img)
	$(MAKE_IMAGE)
	@rm -f $(ARCHIVE)
	$(XZ) $(IMAGE)
	@echo ""
	$(SIGN)
	@echo "Build complete."

# build CubieTruck SD card image
cubietruck: prep
	$(eval ARCHITECTURE = armhf)
	$(eval MACHINE = cubietruck)
	$(eval IMAGE = $(NAME).img)
	$(MAKE_IMAGE)
	@rm -f $(ARCHIVE)
	$(XZ) $(IMAGE)
	@echo ""
	$(SIGN)
	@echo "Build complete."

# build A20 OLinuXino Lime2 SD card image
a20-olinuxino-lime2: prep
	$(eval ARCHITECTURE = armhf)
	$(eval MACHINE = a20-olinuxino-lime2)
	$(eval IMAGE = $(NAME).img)
	$(MAKE_IMAGE)
	rm -f $(ARCHIVE)
	$(XZ) $(IMAGE)
	@echo ""
	$(SIGN)
	@echo "Build complete."

# build A20 OLinuXino MIRCO SD card image
a20-olinuxino-micro: prep
	$(eval ARCHITECTURE = armhf)
	$(eval MACHINE = a20-olinuxino-micro)
	$(eval IMAGE = $(NAME).img)
	$(MAKE_IMAGE)
	@rm -f $(ARCHIVE)
	$(XZ) $(IMAGE)
	@echo ""
	$(SIGN)
	@echo "Build complete."

# build an i386 image
i386: prep
	$(eval ARCHITECTURE = i386)
	$(eval MACHINE = all)
	$(eval IMAGE = $(NAME).img)
	$(MAKE_IMAGE)
	@rm -f $(ARCHIVE)
	$(XZ) --keep $(IMAGE)
	@echo ""
	$(SIGN)
	@echo "Build complete."

# build an amd64 image
amd64: prep
	$(eval ARCHITECTURE = amd64)
	$(eval MACHINE = all)
	$(eval IMAGE = $(NAME).img)
	$(MAKE_IMAGE)
	@rm -f $(ARCHIVE)
	$(XZ) --keep $(IMAGE)
	@echo ""
	$(SIGN)
	@echo "Build complete."

# build a virtualbox image
virtualbox: virtualbox-i386

virtualbox-i386: i386
	$(eval ARCHITECTURE = i386)
	$(eval MACHINE = all)
	$(eval IMAGE = $(NAME).vdi)
	# Convert image to vdi hard drive
	VBoxManage convertdd $(NAME).img $(NAME).vdi
	@rm -f $(NAME).vdi.xz
	$(XZ) --keep $(NAME).vdi
	@echo ""
	$(SIGN)
	@echo "Build complete."

virtualbox-amd64: amd64
	$(eval ARCHITECTURE = amd64)
	$(eval MACHINE = all)
	$(eval IMAGE = $(NAME).vdi)
	# Convert image to vdi hard drive
	VBoxManage convertdd $(NAME).img $(NAME).vdi
	@rm -f $(NAME).vdi.xz
	$(XZ) $(NAME).vdi
	@echo ""
	$(SIGN)
	@echo "Build complete."

test: test-virtualbox

test-virtualbox: virtualbox
	$(eval VM_NAME = freedom-maker-test)
	./bin/passwd-in-image $(NAME).vdi fbx --password frdm
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

# build a qemu image
qemu: qemu-i386

qemu-i386: i386
	$(eval ARCHITECTURE = i386)
	$(eval MACHINE = all)
	$(eval IMAGE = $(NAME).qcow2)
	# Convert image to qemu format
	qemu-img convert -O qcow2 $(NAME).img $(IMAGE)
	@rm -f $(ARCHIVE)
	$(XZ) $(IMAGE)
	@echo ""
	$(SIGN)
	@echo "Build complete."

qemu-amd64: amd64
	$(eval ARCHITECTURE = amd64)
	$(eval MACHINE = all)
	$(eval IMAGE = $(NAME).qcow2)
	# Convert image to qemu format
	qemu-img convert -O qcow2 $(NAME).img $(IMAGE)
	@rm -f $(ARCHIVE)
	$(XZ) $(IMAGE)
	@echo ""
	$(SIGN)
	@echo "Build complete."

vendor/vmdebootstrap/vmdebootstrap: vendor-patches/vmdebootstrap/*.patch
	bin/fetch-new-vmdebootstrap

prep: vendor/vmdebootstrap/vmdebootstrap
	mkdir -p build

clean:
	-rm -f build/freedombox.log

distclean: clean
	sudo rm -rf build
