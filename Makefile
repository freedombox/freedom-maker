# copy DreamPlug root filesystem to a usb stick 
# stick assumed to have 2 partitions, 128meg FAT and the rest ext3 partition
dreamstick:	stamp-dreamplug-rootfs
	mount /media/freedom
	mount /media/freedom/boot
	sudo rsync -atvz --progress --delete --exclude=boot build/dreamplug/ /media/freedom/
	cp build/dreamplug/boot/* /media/freedom/boot/
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
	rm -rf build
