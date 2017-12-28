# Freedom-Maker: The FreedomBox image builder

These scripts build images for FreedomBox for various support hardware
that can then be copied to SD card, USB stick or Hard Disk drive to
boot into FreedomBox.

These scripts are meant for developers of FreedomBox to build images
during releases and for advanced users who intend to build their own
images.  Regular users who wish to turn their devices into
FreedomBoxes should instead download the pre-built images.

Get a pre-built image via https://wiki.debian.org/FreedomBox .  There
are images available for all supported target devices.  You also find
the setup instructions on the Wiki.

If you wish to create your own FreedomBox image, perhaps with some
tweaks, see the *Build Images* section below.

# Build Images

## Supported Targets

Freedom-maker supports building for the following targets:

- *beaglebone*: BeagleBone Black's SD card
- *cubieboard2*: Cubieboard2's SD card
- *cubietruck*: Cubietruck's SD card
- *a20-olinuxino-lime*: A20 OLinuXino Lime's SD card
- *a20-olinuxino-lime2*: A20 OLinuXino Lime2's SD card
- *a20-olinuxino-micro*: A20 OLinuXino MICRO's SD card
- *banana-pro*: Banana Pro's SD card
- *dreamplug*: DreamPlug's internal SD card
- *raspberry*: RasbperryPi's SD card.
- *raspberry2*: RasbperryPi 2's SD card.
- *raspberry3*: RasbperryPi 3's SD card.
- *i386*: Disk image for any machine with i386 architecture
- *amd64*: Disk image for any machine with amd64 architecture.
- *virtualbox-i386*: 32-bit image for the VirtualBox virtualization tool
- *virtualbox-amd64*: 64-bit image for the VirtualBox virtualization tool
- *qemu-i386*: 32-bit image for the Qemu virtualization tool
- *qemu-amd64*: 64-bit image for the Qemu virtualization tool
- *pcDuino3*: pcDuino3  
- *test*: build virtualbox i386 image and run diagnostics tests on it

## Install dependencies

To build an image, first install the required dependencies for the
image as follows:

For all dependencies:
```shell
$ sudo apt-get -y install git \
                          sudo \
                          vmdebootstrap \
                          dosfstools \
                          btrfs-progs \
                          pxz \
                          virtualbox \
                          qemu-utils \
                          qemu-user-static \
                          binfmt-support \
                          u-boot-tools \
                          sshpass
```

For VirtualBox:
```
$ sudo apt-get -y install virtualbox
```

For Qemu:
```
$ sudo apt-get -y install qemu-utils
```

For RaspberryPi:
```
$ sudo apt-get -y install qemu-user-static binfmt-support
```

For DreamPlug:
```
$ sudo apt-get -y install qemu-user-static binfmt-support u-boot-tools
```

For Testing:
```
$ sudo apt-get install virtualbox sshpass
```

## Running Build

1. Fetch the git source of freedom-maker:
    ```
    $ git clone https://alioth.debian.org/anonscm/git/freedombox/freedom-maker.git freedom-maker
    ```

2. Build all images:
    ```
    $ python3 -m freedommaker dreamplug raspberry raspberry2 raspberry3 \
      beaglebone cubieboard2 cubietruck a20-olinuxino-lime a20-olinuxino-lime2 \
      a20-olinuxino-micro i386 amd64 virtualbox-i386 virtualbox-amd64 \
      qemu-i386 qemu-amd64 banana-pro
    ```

    or to build just a single image:
    ```
    $ python3 -m freedommaker beaglebone
    ```

    or to see the full list of options you can pass to the build proces:
    ```
    $ python3 -m freedommaker --help
    ```

The images will show up in *freedom-maker/build/*. Copy the image to
target disk following the instructions in *Use Images* section.

# Use Images

You'll need to copy the image to the memory card or USB stick:

1. Figure out which device your card actually is.

    A. Unplug your card.

    B. Run "dmesg -w" to show and follow the kernel messages.

    C. Plug your card in.  You will see message such as following:

        [33299.023096] usb 4-6: new high-speed USB device number 12 using ehci-pci
        [33299.157160] usb 4-6: New USB device found, idVendor=058f, idProduct=6361
        [33299.157162] usb 4-6: New USB device strings: Mfr=1, Product=2, SerialNumber=3
        [33299.157164] usb 4-6: Product: Mass Storage Device
        [33299.157165] usb 4-6: Manufacturer: Generic
        [33299.157167] usb 4-6: SerialNumber: XXXXXXXXXXXX
        [33299.157452] usb-storage 4-6:1.0: USB Mass Storage device detected
        [33299.157683] scsi host13: usb-storage 4-6:1.0
        [33300.155626] scsi 13:0:0:0: Direct-Access     Generic- Compact Flash    1.01 PQ: 0 ANSI: 0
        [33300.156223] scsi 13:0:0:1: Direct-Access     Multiple Flash Reader     1.05 PQ: 0 ANSI: 0
        [33300.157059] sd 13:0:0:0: Attached scsi generic sg4 type 0
        [33300.157462] sd 13:0:0:1: Attached scsi generic sg5 type 0
        [33300.462115] sd 13:0:0:1: [sdg] 30367744 512-byte logical blocks: (15.5 GB/14.4 GiB)
        [33300.464144] sd 13:0:0:1: [sdg] Write Protect is off
        [33300.464159] sd 13:0:0:1: [sdg] Mode Sense: 03 00 00 00
        [33300.465896] sd 13:0:0:1: [sdg] No Caching mode page found
        [33300.465912] sd 13:0:0:1: [sdg] Assuming drive cache: write through
        [33300.470489] sd 13:0:0:0: [sdf] Attached SCSI removable disk
        [33300.479493]  sdg: sdg1
        [33300.483566] sd 13:0:0:1: [sdg] Attached SCSI removable disk

    D. In the above case, the disk that is newly inserted is available
       as */dev/sdg*.  Very carefully note this and use it in the
       copying step below.

2. Decompress the built image using tar:
    ```
    $ cd freedom-maker/build
    $ tar -xvf freedombox-unstable_2015-08-06_beaglebone-armhf-card.tar.xz
    ```

   The above command is an example for the beaglebone image built on
   2015-08-06.  Your tar file name will be different.

3. Copy the image to your card.  Double check and make sure you don't
   write to your computer's main storage (such as /dev/sda).  Also
   make sure that you don't run this step as root to avoid potentially
   overriding data on your hard drive due to a mistake in identifying
   the device or errors while typing the command.  USB disks and SD
   cards inserted into the system should typically be write accessible
   to normal users. If you don't have permission to write to your SD
   card as a user, you may need to run this command as root.  In this
   case triple check everything before you run the command.  Another
   safety precaution is to unplug all external disks except the SD
   card before running the command.

   For example, if your SD card is /dev/sdf as noted in the first step
   above, then to copy the image, run:
    ```
    $ cd build
    $ dd bs=1M if=freedombox-unstable_2015-08-06_beaglebone-armhf-card.img of=/dev/sdf conv=fdatasync
    ```

   The above command is an example for the beaglebone image built on
   2015-08-06.  Your image file name will be different.

   When picking a device, use the drive-letter destination, like
   /dev/sdf, not a numbered destination, like /dev/sdf1.  The device
   without a number refers to the entire device, while the device with
   anumber refers to a specific partition.  We want to use the whole
   device.  Downloaded images contain complete information about how
   many partitions there should be, their sizes and types. You don't
   have to format your SD card or create partitions. All the data on
   the SD card will be wiped off during the write process.

4. Use the image by inserting the SD card or USB disk into the target
   device and booting from it.  Also see hardware specific
   instructions on how to prepare your device at
   https://wiki.debian.org/FreedomBox/Hardware
