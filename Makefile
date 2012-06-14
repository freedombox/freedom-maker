# /usr/bin/make
TODAY = `date +%Y.%m%d`
NAME = freedombox-unstable
IMAGE = "$(NAME)_$(TODAY).img"
VBOX = "$(NAME)_$(TODAY).vdi"
ARCHIVE = "$(NAME)_$(TODAY).tar.bz2"
SIZE = 600
LOOP = /dev/loop0
MOUNT = /mnt/fbx

kitty:
	echo $(TODAY)
	echo $(IMAGE)

# copy DreamPlug root filesystem to a usb stick 
# stick assumed to have 2 partitions, 128meg FAT and the rest ext3 partition
dreamstick:	stamp-dreamplug-rootfs
# 	bin/partition-stick
	mount /media/freedom
	sudo mkdir -p /media/freedom/boot
	mount /media/freedom/boot
	sudo rsync -atvz --progress --delete --exclude=boot build/dreamplug/ /media/freedom/
	cp build/dreamplug/boot/* /media/freedom/boot/
	sleep 1
	umount /media/freedom/boot
	umount /media/freedom

# populate a tree with DreamPlug root filesystem
stamp-dreamplug-rootfs: fbx-armel.conf fbx-base.conf mk_dreamplug_rootfs
	sudo ./mk_dreamplug_rootfs
	touch stamp-dreamplug-rootfs

clean:
	rm -f stamp-dreamplug-rootfs
	sudo rm -rf build/dreamplug

distclean:	clean
	sudo rm -rf build

clean-image:
	rm -f $(IMAGE)
	rm -f $(ARCHIVE)

# taking lots of hints from http://wiki.osdev.org/Loopback_Device
# and from http://wiki.mandriva.com/en/VirtualBox
test-image: clean-image stamp-dreamplug-rootfs
	dd if=/dev/zero of=$(IMAGE) bs=1M count=$(SIZE)
	sudo ./bin/build_image.sh $(IMAGE) $(LOOP) $(MOUNT) $(SIZE)
	tar -cvjf $(ARCHIVE) $(IMAGE)
#	vboxmanage convertfromraw $(IMAGE) $(VBOX)
#	vboxmanage modifyhd --resize 2048 $(VBOX)
#	echo Remember to resize the partition with gParted and install Grub.
