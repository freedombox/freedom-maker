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
Basic image builder using vmdebootstrap.
"""

import json
import logging
import shutil
import subprocess

logger = logging.getLogger(__name__)


class VmdebootstrapBuilderBackend():
    """Build an image using vmdebootstrap tool."""

    def __init__(self, builder):
        """Initialize the builder."""
        self.builder = builder
        self.parameters = []
        self.environment = []
        self.execution_wrapper = []

    def make_image(self):
        """Create a disk image."""
        if self.builder.should_skip_step(self.builder.image_file):
            logger.info('Image exists, skipping build - %s',
                        self.builder.image_file)
            return

        temp_image_file = self.builder.get_temp_image_file()
        logger.info('Building image in temporary file - %s', temp_image_file)
        self.execution_wrapper = ['sudo', '-H']
        self.parameters = [
            '--hostname',
            self.builder.arguments.hostname,
            '--image',
            temp_image_file,
            '--size',
            self.builder.arguments.image_size,
            '--mirror',
            self.builder.arguments.build_mirror,
            '--distribution',
            self.builder.arguments.distribution,
            '--arch',
            self.builder.architecture,
            '--lock-root-password',
            '--log',
            self.builder.log_file,
            '--log-level',
            self.builder.arguments.log_level,
            '--verbose',
            '--customize',
            self.builder.customization_script,
        ]
        self.environment = {
            'MIRROR': self.builder.arguments.mirror,
            'BUILD_MIRROR': self.builder.arguments.build_mirror,
            'MACHINE': self.builder.machine,
            'SOURCE': 'true'
            if self.builder.arguments.download_source else 'false',
            'SOURCE_IN_IMAGE': 'true'
            if self.builder.arguments.include_source else 'false',
            'SUITE': self.builder.arguments.distribution,
            'ENABLE_NONFREE': 'no' if self.builder.free else 'yes',
        }
        self.process_variant()
        self.process_architecture()
        self.process_boot_loader()
        self.process_kernel_flavor()
        self.process_filesystems()
        self.process_packages()
        self.process_custom_packages()
        self.process_environment()

        command = self.execution_wrapper + [
            self.builder.arguments.vmdebootstrap
        ] + self.parameters

        try:
            self.builder._run(command)
        finally:
            self._cleanup_vmdebootstrap(temp_image_file)

        logger.info('Moving file: %s -> %s', temp_image_file,
                    self.builder.image_file)
        shutil.move(temp_image_file, self.builder.image_file)

    def _cleanup_vmdebootstrap(self, image_file):
        """Cleanup those that vmdebootstrap is supposed to have cleaned up."""
        # XXX: Remove this when vmdebootstrap removes kpartx mappings properly
        # after a successful build.
        process = subprocess.run(['losetup', '--json'],
                                 stdout=subprocess.PIPE,
                                 check=True)
        output = process.stdout.decode()
        if not output:
            return

        loop_data = json.loads(output)
        loop_device = None
        for device_data in loop_data['loopdevices']:
            if image_file == device_data['back-file']:
                loop_device = device_data['name']
                break

        if not loop_device:
            return

        partition_devices = [
            '/dev/mapper/' + loop_device.split('/')[-1] + 'p' + str(number)
            for number in range(1, 4)
        ]
        # Don't log command, ignore errors, force
        for device in partition_devices:
            subprocess.run(['dmsetup', 'remove', '-f', device],
                           stdout=subprocess.DEVNULL,
                           stderr=subprocess.DEVNULL)

        subprocess.run(['losetup', '-d', loop_device],
                       stdout=subprocess.DEVNULL,
                       stderr=subprocess.DEVNULL)

    def process_variant(self):
        """Add paramaters for deboostrap variant."""
        if self.builder.debootstrap_variant:
            self.parameters += [
                '--debootstrapopts',
                'variant=' + self.builder.debootstrap_variant
            ]

    def process_architecture(self):
        """Add parameters specific to the architecture."""
        if self.builder.architecture not in ('i386', 'amd64'):
            self.parameters += ['--foreign', '/usr/bin/qemu-arm-static']

            # Using taskset to pin build process to single core. This
            # is a workaround for a qemu-user-static issue that causes
            # builds to hang. (See Debian bug #769983 for details.)
            self.execution_wrapper = \
                ['taskset', '0x01'] + self.execution_wrapper

    def process_boot_loader(self):
        """Add parameters related to boot loader."""
        option_map = {
            'grub': ['--grub'],
            'u-boot': ['--no-extlinux'],
            None: ['--no-extlinux']
        }
        self.parameters += option_map[self.builder.boot_loader]

        if self.builder.boot_loader == 'u-boot':
            self.parameters += [
                '--package', 'u-boot-tools', '--package', 'u-boot'
            ]

        if self.builder.boot_size:
            self.parameters += ['--bootsize', self.builder.boot_size]

        if self.builder.boot_offset:
            self.parameters += ['--bootoffset', self.builder.boot_offset]

    def process_kernel_flavor(self):
        """Add parameters for kernel flavor."""
        if self.builder.kernel_flavor == 'default':
            return

        if self.builder.kernel_flavor is None:
            self.parameters += ['--no-kernel']
            return

        self.parameters += [
            '--kernel-package', 'linux-image-' + self.builder.kernel_flavor
        ]

    def process_filesystems(self):
        """Add parameters necessary for file systems."""
        self.parameters += ['--roottype', self.builder.root_filesystem_type]
        if self.builder.boot_filesystem_type:
            self.parameters += [
                '--boottype', self.builder.boot_filesystem_type
            ]

        if 'btrfs' in [
                self.builder.root_filesystem_type,
                self.builder.boot_filesystem_type
        ]:
            self.builder.packages += ['btrfs-progs']

    def process_packages(self):
        """Add parameters for additional packages to install in image."""
        for package in self.builder.packages + (self.builder.arguments.package
                                                or []):
            self.parameters += ['--package', package]

    def process_custom_packages(self):
        """Add parameters for custom DEB packages to install in image."""
        for package in (self.builder.arguments.custom_package or []):
            if 'plinth_' in package:
                self.environment['CUSTOM_PLINTH'] = package
            elif 'freedombox-setup_' in package:
                self.environment['CUSTOM_SETUP'] = package
            else:
                self.parameters += ['--custom-package', package]

    def process_environment(self):
        """Add environment we wish to pass to the command wrapper: sudo."""
        for key, value in self.environment.items():
            self.execution_wrapper += [key + '=' + value]
