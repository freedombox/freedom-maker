#!/bin/sh
#
# Copyright 2012 by Nick Daly (Nick.M.Daly@gmail.com)
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

set -e

IMAGE=$1
LOOP=$2
MOUNT=$3
SIZE=$4

echo start
# to partition the image or not?  Virtualbox won't boot off it either way.
# http://wiki.osdev.org/Loopback_Device: ocnapw
#fdisk -u -C$SIZE -S63 -H16 $IMAGE
#losetup -o32256 $LOOP $IMAGE
losetup $LOOP $IMAGE
mkfs -t ext2 $LOOP

echo mount the image
mkdir -p $MOUNT
mount -t ext2 $LOOP $MOUNT

echo copy important files
cp -r build/dreamplug/* $MOUNT/
git clone git://github.com/NickDaly/Plinth.git $MOUNT/home/fbx/plinth
hg clone https://hg@bitbucket.org/nickdaly/plugserver $MOUNT/home/fbx/plugserver
chown -R 1000:1000 $MOUNT/home/fbx

echo clean up
umount $MOUNT
losetup -d $LOOP
