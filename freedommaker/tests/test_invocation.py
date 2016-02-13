#!/usr/bin/python3
#
# This file is part of Freedom Maker.
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
#

"""
Tests for checking Freedom Maker's invocation of vmdeboostrap.

Also test:
  - Arguments given to Freedom Maker.
  - Other basic behavior
"""

import json
import logging
import os
import random
import string
import subprocess
import time
import unittest

logger = logging.getLogger(__name__)


ARCHITECTURES = {
    'amd64': 'amd64',
    'i386': 'i386',
    'virtualbox-amd64': 'amd64',
    'virtualbox-i386': 'i386',
    'qemu-amd64': 'amd64',
    'qemu-i386': 'i386',
    'beaglebone': 'armhf',
    'a20-olinuxino-lime': 'armhf',
    'a20-olinuxino-lime2': 'armhf',
    'a20-olinuxino-micro': 'armhf',
    'cubieboard2': 'armhf',
    'cubietruck': 'armhf',
    'dreamplug': 'armel',
    'raspberry': 'armel',
    'raspberry2': 'armhf',
}


class TestInvocation(unittest.TestCase):
    """Tests for Freedom Maker's invocation of vmdeboostrap."""

    def setUp(self):
        """Setup test case."""
        self.path = os.path.dirname(__file__)
        self.binary = 'freedommaker'
        self.output_dir = os.path.join(self.path, 'output')

        self.build_stamp = self.random_string()
        self.current_target = 'amd64'

    def random_string(self):
        """Generate a random string."""
        return ''.join([random.choice(string.ascii_lowercase)
                        for _ in range(8)])

    def invoke(self, targets=None, **kwargs):
        """Invoke Freedom Maker."""
        if targets:
            if len(targets) == 1:
                self.current_target = targets[0]
        else:
            targets = [self.current_target]

        parameters = [
            '--vmdebootstrap', os.path.join(self.path, 'vmdebootstrap-stub'),
            '--build-dir', self.output_dir
        ]

        if 'build_stamp' not in kwargs:
            parameters += ['--build-stamp', self.build_stamp]

        for parameter, value in kwargs.items():
            parameter = '--' + parameter.replace('_', '-')

            if isinstance(value, bool):
                if value:
                    parameters += [parameter]
            else:
                parameters += [parameter, value]

        command = ['python3', '-m', self.binary] + parameters + targets
        subprocess.check_call(command)

    def get_built_file(self, target=None, distribution=None):
        """Return the path of the expected built file.

        Also tests:
          - free flag
        """
        target = target or self.current_target
        extra_map = {
            'amd64': 'all-amd64.img',
            'i386': 'all-i386.img',
            'virtualbox-amd64': 'all-amd64.vdi',
            'virtualbox-i386': 'all-i386.vdi',
            'qemu-amd64': 'all-amd64.qcow2',
            'qemu-i386': 'all-i386.qcow2',
            'beaglebone': 'beaglebone-armhf.img',
            'a20-olinuxino-lime': 'a20-olinuxino-lime-armhf.img',
            'a20-olinuxino-lime2': 'a20-olinuxino-lime2-armhf.img',
            'a20-olinuxino-micro': 'a20-olinuxino-micro-armhf.img',
            'cubieboard2': 'cubieboard2-armhf.img',
            'cubietruck': 'cubietruck-armhf.img',
            'dreamplug': 'dreamplug-armel.img',
            'raspberry': 'raspberry-armel.img',
            'raspberry2': 'raspberry2-armhf.img',
        }

        distribution = distribution or 'unstable'

        free_tag = 'free'
        if target in ('dreamplug', 'raspberry', 'raspberry2'):
            free_tag = 'nonfree'

        file_name = 'freedombox-{distribution}-{free_tag}_{build_stamp}_' \
            '{extra}.xz' \
            .format(distribution=distribution, build_stamp=self.build_stamp,
                    extra=extra_map[target], free_tag=free_tag)

        return os.path.join(self.output_dir, file_name)

    def get_parameters_passed(self, distribution=None):
        """Return parameters passed to vmdeboostrap during invocation."""
        compressed_built_file = self.get_built_file(distribution=distribution)

        built_file = compressed_built_file.rsplit('.', maxsplit=1)[0]

        if not os.path.isfile(built_file):
            subprocess.check_call(['unxz', '--keep', '--force',
                                   compressed_built_file])

        if built_file.endswith('.qcow2'):
            built_file = self.convert_qcow2_to_raw(built_file)
        elif built_file.endswith('.vdi'):
            built_file = self.convert_vdi_to_raw(built_file)

        with open(built_file, 'r') as file_handle:
            return json.loads(file_handle.read().strip('\0'))

    def convert_qcow2_to_raw(self, built_file):
        """Convert back a QCOW2 image to raw image file."""
        new_file = built_file.rstrip('.qcow2') + '.img'
        subprocess.check_call(['qemu-img', 'convert', '-O', 'raw', built_file,
                               new_file])
        return new_file

    def convert_vdi_to_raw(self, built_file):
        """Convert back a VDI image to raw image file."""
        new_file = built_file.rstrip('.vdi') + '.img'
        subprocess.check_call(['qemu-img', 'convert', '-O', 'raw', built_file,
                               new_file])
        return new_file

    def assert_file_exists(self, file_name):
        """Check that a file exists in build directory."""
        self.assertTrue(os.path.isfile(
            os.path.join(self.output_dir, file_name)))

    def assert_arguments_passed(self, expected_arguments, distribution=None):
        """Check that a sequence of arguments are passed to vmdeboostrap."""
        arguments = self.get_parameters_passed(
            distribution=distribution)['arguments']
        arguments = '@'.join(arguments)
        expected_arguments = '@'.join(expected_arguments)
        self.assertIn(expected_arguments, arguments)

    def assert_arguments_not_passed(self, expected_arguments):
        """Check that a sequence of arguments are passed to vmdeboostrap."""
        arguments = self.get_parameters_passed()['arguments']
        arguments = '@'.join(arguments)
        expected_arguments = '@'.join(expected_arguments)
        self.assertNotIn(expected_arguments, arguments)

    def assert_environment_passed(self, expected_environment,
                                  distribution=None):
        """Check that expected environment is passed to vmdeboostrap."""
        environment = self.get_parameters_passed(
            distribution=distribution)['environment']
        for key, value in expected_environment.items():
            self.assertEqual(environment[key], value)

    def test_basic_build(self):
        """Test whether building works.

        Tests the following parameters:
          - build-stamp
          - build-dir
          - vmdebootstrap
        """
        self.invoke()
        self.assert_file_exists(self.get_built_file())

    def test_image_size(self):
        """Test that image size parameter works."""
        size = str(random.randint(2, 1024)) + 'G'
        self.invoke(image_size=size)
        self.assert_arguments_passed(['--size', size])

    def test_build_mirror(self):
        """Test that build-mirror parameter works."""
        mirror = 'http://' + self.random_string() + '/debian/'
        self.invoke(build_mirror=mirror)
        self.assert_arguments_passed(['--mirror', mirror])
        self.assert_environment_passed({'BUILD_MIRROR': mirror})

    def test_mirror(self):
        """Test that mirror parameter works."""
        mirror = 'http://' + self.random_string() + '/debian/'
        self.invoke(mirror=mirror)
        self.assert_environment_passed({'MIRROR': mirror})

    def test_distribution(self):
        """Test that distribution parameter works."""
        distribution = self.random_string()
        self.invoke(distribution=distribution)
        self.assert_arguments_passed(['--distribution', distribution],
                                     distribution=distribution)
        self.assert_environment_passed({'SUITE': distribution},
                                       distribution=distribution)

    def test_include_source(self):
        """Test that include-source parameter works."""
        self.invoke()
        self.assert_environment_passed({'SOURCE': 'false'})

        self.invoke(include_source=True, force=True)
        self.assert_environment_passed({'SOURCE': 'true'})

    def test_package(self):
        """Test that package parameter works."""
        package = self.random_string()
        self.invoke(package=package)
        self.assert_arguments_passed(['--package', package])

    def test_custom_package(self):
        """Test that custom-package parameter works."""
        custom_package = self.random_string()
        self.invoke(custom_package=custom_package)
        self.assert_arguments_passed(['--custom-package', custom_package])

    def test_custom_package_plinth(self):
        """Test that custom-package parameter works for plinth."""
        custom_package = self.random_string() + '/plinth_0.7-1_all.deb'
        self.invoke(custom_package=custom_package)
        self.assert_environment_passed({'CUSTOM_PLINTH': custom_package})

    def test_custom_package_setup(self):
        """Test that custom-package parameter works for freedombox-setup."""
        custom_package = \
            self.random_string() + '/freedombox-setup_0.7_all.deb'
        self.invoke(custom_package=custom_package)
        self.assert_environment_passed({'CUSTOM_SETUP': custom_package})

    def test_hostname(self):
        """Test that hostname parameter works."""
        hostname = self.random_string()
        self.invoke(hostname=hostname)
        self.assert_arguments_passed(['--hostname', hostname])

    def test_no_force(self):
        """Test that not giving force parameter works."""
        self.invoke()
        mtime1 = os.path.getmtime(self.get_built_file())
        time.sleep(2)
        self.invoke()
        mtime2 = os.path.getmtime(self.get_built_file())
        self.assertEqual(mtime1, mtime2)

    def test_force(self):
        """Test that force parameter works."""
        self.invoke()
        mtime1 = os.path.getmtime(self.get_built_file())
        time.sleep(2)
        self.invoke(force=True)
        mtime2 = os.path.getmtime(self.get_built_file())
        self.assertNotEqual(mtime1, mtime2)

    def test_sign(self):
        """Test that sign parameter works."""
        # XXX: Implement

    def test_multiple_targets(self):
        """Test that passing multiple targets works."""
        self.invoke(['amd64', 'i386'])
        self.assert_file_exists(self.get_built_file(target='amd64'))
        self.assert_file_exists(self.get_built_file(target='i386'))

    def test_all_targets(self):
        """Test that each target works.

        Also tests:
          - machine names are correct
        """
        for target in ARCHITECTURES:
            self.build_stamp = self.random_string()
            self.invoke([target])
            self.assert_file_exists(self.get_built_file(target=target))

    def test_architecture(self):
        """Test that architecture is properly choosen."""
        for target, architecture in ARCHITECTURES.items():
            self.build_stamp = self.random_string()
            self.invoke([target])
            self.assert_arguments_passed(['--arch', architecture])

    def test_lock_root_password(self):
        """Test that root password is locked."""
        self.invoke()
        self.assert_arguments_passed(['--lock-root-password'])

    def test_log_level(self):
        """Test that log level is set properly.

        Also tests:
          - verbose flag
          - log file path
        """
        self.invoke(log_level='debug')
        self.assert_arguments_passed(['--verbose'])
        self.assert_arguments_passed(['--log-level', 'debug'])
        log_file = self.get_built_file().rstrip('.img.xz') + '.log'
        self.assert_file_exists(log_file)

        self.invoke(log_level='info', force=True)
        self.assert_arguments_passed(['--log-level', 'info'])

    def test_base_packages(self):
        """Test that base packages are availble."""
        self.invoke()
        for package in ['apt', 'base-files', 'debian-archive-keyring',
                        'ifupdown', 'initramfs-tools', 'kmod', 'logrotate',
                        'netbase', 'rsyslog', 'udev']:
            self.assert_arguments_passed(['--package', package])

    def test_foreign_architecture(self):
        """Test that foreign arch parameter is passed."""
        for target, architecture in ARCHITECTURES.items():
            self.build_stamp = self.random_string()
            self.invoke([target])
            if architecture in ('i386', 'amd64'):
                self.assert_arguments_not_passed(
                    ['--foreign', '/usr/bin/qemu-arm-static'])
            else:
                self.assert_arguments_passed(
                    ['--foreign', '/usr/bin/qemu-arm-static'])

    def test_boot_loader(self):
        """Test proper boot loader arguments."""
        for target, architecture in ARCHITECTURES.items():
            self.build_stamp = self.random_string()
            self.invoke([target])
            if architecture in ('i386', 'amd64'):
                self.assert_arguments_passed(['--grub'])
                self.assert_arguments_not_passed(['--package', 'u-boot'])
                self.assert_arguments_not_passed(['--package', 'u-boot-tools'])
                self.assert_arguments_not_passed(['--no-extlinux'])
            elif target in ('raspberry', 'raspberry2'):
                self.assert_arguments_not_passed(['--grub'])
                self.assert_arguments_not_passed(['--package', 'u-boot'])
                self.assert_arguments_not_passed(['--package', 'u-boot-tools'])
                self.assert_arguments_passed(['--no-extlinux'])
            else:
                self.assert_arguments_not_passed(['--grub'])
                self.assert_arguments_passed(['--package', 'u-boot'])
                self.assert_arguments_passed(['--package', 'u-boot-tools'])
                self.assert_arguments_passed(['--no-extlinux'])

    def test_filesystems(self):
        """Test proper filesystem arguments.

        Also tests:
         - boot size
        """
        for target, architecture in ARCHITECTURES.items():
            self.build_stamp = self.random_string()
            self.invoke([target])
            if architecture in ('i386', 'amd64'):
                self.assert_arguments_passed(['--roottype', 'btrfs'])
                self.assert_arguments_not_passed(['--boottype'])
                self.assert_arguments_passed(['--package', 'btrfs-tools'])
                self.assert_arguments_not_passed(['--bootsize', '128M'])
            elif target in ('raspberry', 'raspberry2'):
                self.assert_arguments_passed(['--roottype', 'ext4'])
                self.assert_arguments_passed(['--boottype', 'vfat'])
                self.assert_arguments_not_passed(['--package', 'btrfs-tools'])
                self.assert_arguments_passed(['--bootsize', '128M'])
            elif target in ('dreamplug'):
                self.assert_arguments_passed(['--roottype', 'btrfs'])
                self.assert_arguments_passed(['--boottype', 'vfat'])
                self.assert_arguments_passed(['--package', 'btrfs-tools'])
                self.assert_arguments_passed(['--bootsize', '128M'])
            else:
                self.assert_arguments_passed(['--roottype', 'btrfs'])
                self.assert_arguments_passed(['--boottype', 'ext2'])
                self.assert_arguments_passed(['--package', 'btrfs-tools'])
                self.assert_arguments_passed(['--bootsize', '128M'])

    def test_boot_offset(self):
        """Test proper boot offset arguments."""
        for target, architecture in ARCHITECTURES.items():
            self.build_stamp = self.random_string()
            self.invoke([target])
            if target in ('raspberry', 'raspberry2', 'dreamplug') or \
               architecture in ('i386', 'amd64'):
                self.assert_arguments_not_passed(['--bootoffset'])
            elif target in ('beaglebone'):
                self.assert_arguments_passed(['--bootoffset', '2mib'])
            else:
                self.assert_arguments_passed(['--bootoffset', '1mib'])

    def test_kernel_flavor(self):
        """Test proper kernel flavor arguments."""
        for target, architecture in ARCHITECTURES.items():
            self.build_stamp = self.random_string()
            self.invoke([target])
            if architecture in ('i386', 'amd64'):
                self.assert_arguments_not_passed(['--no-kernel'])
                self.assert_arguments_not_passed(['--kernel-package'])
            elif target in ('beaglebone'):
                self.assert_arguments_not_passed(['--no-kernel'])
                self.assert_arguments_passed(
                    ['--kernel-package', 'linux-image-armmp'])
            elif target in ('raspberry', 'raspberry2'):
                self.assert_arguments_passed(['--no-kernel'])
                self.assert_arguments_not_passed(['--kernel-package'])
            elif target in ('dreamplug'):
                self.assert_arguments_not_passed(['--no-kernel'])
                self.assert_arguments_passed(
                    ['--kernel-package', 'linux-image-kirkwood'])
            else:
                self.assert_arguments_not_passed(['--no-kernel'])
                self.assert_arguments_passed(
                    ['--kernel-package', 'linux-image-armmp-lpae'])

    def test_variant(self):
        """Test that variant targets works."""
        for target, architecture in ARCHITECTURES.items():
            self.build_stamp = self.random_string()
            self.invoke([target])
            if architecture in ('i386', 'amd64'):
                self.assert_arguments_not_passed(['--debootstrapopts'])
            else:
                self.assert_arguments_passed(
                    ['--debootstrapopts', 'variant=minbase'])
