# copy DreamPlug root filesystem to a usb stick with an ext3 partition 
dreamstick:	stamp-dreamplug-rootfs
	mount /media/freedom
	sudo rsync -atvz --progress --delete build/dreamplug/ /media/freedom/
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
