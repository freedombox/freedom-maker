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
Worker class to run various command build the image.
"""

import logging
import os
import shutil
import subprocess
import tempfile

from . import vmdb2
from . import vmdebootstrap

BASE_PACKAGES = [
    'initramfs-tools',
]

logger = logging.getLogger(__name__)  # pylint: disable=invalid-name


class ImageBuilder(object):  # pylint: disable=too-many-instance-attributes
    """Base for all image builders."""
    architecture = None
    machine = 'all'
    free = True

    builder_backend = 'vmdebootstrap'
    root_filesystem_type = 'btrfs'
    boot_filesystem_type = None
    boot_size = None
    boot_offset = None
    kernel_flavor = 'default'
    debootstrap_variant = None

    @classmethod
    def get_target_name(cls):
        """Return the command line name of target for this builder."""
        return None

    @classmethod
    def get_builder_class(cls, target):
        """Return an builder class given target name."""
        for cls in cls.get_subclasses():
            if cls.get_target_name() == target:
                return cls

    @classmethod
    def get_subclasses(cls):
        """Iterate through the subclasses of this class."""
        for subclass in cls.__subclasses__():
            yield subclass
            yield from subclass.get_subclasses()

    def __init__(self, arguments):
        """Initialize object."""
        self.arguments = arguments
        self.packages = BASE_PACKAGES

        self.ram_directory = None

        self.builder_backends = {}
        self.builder_backends['vmdebootstrap'] = \
            vmdebootstrap.VmdebootstrapBuilderBackend(self)
        self.builder_backends['vmdb2'] = vmdb2.Vmdb2BuilderBackend(self)

        self.image_file = os.path.join(
            self.arguments.build_dir, self._get_image_base_name() + '.img')
        self.log_file = os.path.join(
            self.arguments.build_dir, self._get_image_base_name() + '.log')

        # Setup logging
        formatter = logging.root.handlers[0].formatter
        self.log_handler = logging.FileHandler(
            filename=self.log_file, mode='a')
        self.log_handler.setFormatter(formatter)
        logger.addHandler(self.log_handler)

        self.customization_script = os.path.join(
            os.path.dirname(__file__), 'freedombox-customize')

    def cleanup(self):
        """Finalize tasks."""
        logger.info('Cleaning up')
        if self.ram_directory:
            self._run(['sudo', 'umount', self.ram_directory.name])
            self.ram_directory.cleanup()
            self.ram_directory = None

        logger.removeHandler(self.log_handler)

    def build(self):
        """Run the image building process."""
        # Create empty log file owned by process runner
        open(self.log_file, 'w').close()

        archive_file = self.image_file + '.xz'
        if not self.should_skip_step(archive_file):
            self.make_image()
            self.compress(archive_file, self.image_file)
        else:
            logger.info('Compressed image exists, skipping')

        self.sign(archive_file)

    def make_image(self):
        """Call a builder backend to create basic image."""
        self.builder_backends[self.builder_backend].make_image()

    def _get_image_base_name(self):
        """Return the base file name of the final image."""
        free_tag = 'free' if self.free else 'nonfree'

        return 'freedombox-{distribution}-{free_tag}_{build_stamp}_{machine}' \
            '-{architecture}'.format(
                distribution=self.arguments.distribution, free_tag=free_tag,
                build_stamp=self.arguments.build_stamp, machine=self.machine,
                architecture=self.architecture)

    def get_temp_image_file(self):
        """Get the temporary path to where the image should be built.

        If building to RAM is enabled, create a temporary directory, mount
        tmpfs in it and return a path in that directory. This is so that builds
        that happen in RAM will be faster.

        If building to RAM is disabled, append .temp to the final file name and
        return it.

        """
        if not self.arguments.build_in_ram:
            return self.image_file + '.temp'

        self.ram_directory = tempfile.TemporaryDirectory()
        self._run(
            ['sudo', 'mount', '-t', 'tmpfs', 'tmpfs', self.ram_directory.name])
        return os.path.join(self.ram_directory.name,
                            os.path.basename(self.image_file))

    def compress(self, archive_file, image_file):
        """Compress the generate image."""
        if self.should_skip_step(archive_file, [image_file]):
            logger.info('Compressed image exists, skipping compression - %s',
                        archive_file)
            return

        command = ['xz', '--no-warn', '--best', '--force']
        if shutil.which('pxz'):
            command = ['pxz', '-9', '--force']

        self._run(command + [image_file])

    def sign(self, archive):
        """Signed the final output image."""
        if not self.arguments.sign:
            return

        signature = archive + '.sig'

        if self.should_skip_step(signature, [archive]):
            logger.info('Signature file up-to-date, skipping - %s', signature)
            return

        try:
            os.remove(signature)
        except FileNotFoundError:
            pass

        self._run(['gpg', '--output', signature, '--detach-sig', archive])

    def should_skip_step(self, target, dependencies=None):
        """Check whether a given build step may be skipped."""
        # Check forced rebuild
        if self.arguments.force:
            return False

        # Check if target exists
        if not os.path.isfile(target):
            return False

        # Check if a dependency is newer than the target
        for dependency in (dependencies or []):
            if os.path.getmtime(dependency) > os.path.getmtime(target):
                return False

        return True

    @staticmethod
    def _replace_extension(file_name, new_extension):
        """Replace a file's extension with a new extention."""
        return file_name.rsplit('.', maxsplit=1)[0] + new_extension

    def _run(self, *args, **kwargs):
        """Execute a program and log output to log file."""
        logger.info('Executing command - %s', args)
        with open(self.log_file, 'a') as file_handle:
            subprocess.check_call(*args, stdout=file_handle,
                                  stderr=file_handle, **kwargs)


class AMDIntelImageBuilder(ImageBuilder):
    """Base image build for all Intel/AMD targets."""
    boot_loader = 'grub'

    @classmethod
    def get_target_name(cls):
        """Return the name of the target for an image builder."""
        return getattr(cls, 'architecture', None)


class AMD64ImageBuilder(AMDIntelImageBuilder):
    """Image builder for all amd64 targets."""
    architecture = 'amd64'


class I386ImageBuilder(AMDIntelImageBuilder):
    """Image builder for all i386 targets."""
    architecture = 'i386'
    kernel_flavor = '686'


class VMImageBuilder(AMDIntelImageBuilder):
    """Base image builder for all virtual machine targets."""
    vm_image_extension = None

    def build(self):
        """Run the image building process."""
        archive_file = self.image_file + '.xz'
        vm_file = self._replace_extension(
            self.image_file, self.vm_image_extension)
        vm_archive_file = vm_file + '.xz'

        # Create empty log file owned by process runner
        open(self.log_file, 'w').close()

        if not self.should_skip_step(vm_archive_file):
            if not self.should_skip_step(self.image_file):
                if self.should_skip_step(archive_file):
                    logger.info('Compressed image exists, uncompressing - %s',
                                archive_file)
                    self._run(['unxz', '--keep', archive_file])
                else:
                    self.make_image()
            else:
                logger.info('Pre-built image exists, skipping build - %s',
                            self.image_file)

            self.create_vm_file(self.image_file, vm_file)
            os.remove(self.image_file)
            self.compress(vm_archive_file, vm_file)
        else:
            logger.info('Compressed VM image exists, skipping - %s',
                        vm_archive_file)

        self.sign(vm_archive_file)

    def create_vm_file(self, image_file, vm_file):
        """Create a VM image from image file."""
        raise Exception('Not reached')


class VirtualBoxImageBuilder(VMImageBuilder):
    """Base image builder for all VirutalBox targets."""
    vm_image_extension = '.vdi'

    @classmethod
    def get_target_name(cls):
        """Return the name of the target for an image builder."""
        if getattr(cls, 'architecture', None):
            return 'virtualbox-' + cls.architecture

    def create_vm_file(self, image_file, vm_file):
        """Create a VM file from image file."""
        if self.should_skip_step(vm_file, [image_file]):
            logger.info('VM file exists, skipping conversion - %s', vm_file)
            return

        self._run(['VBoxManage', 'convertdd', image_file, vm_file])


class VirtualBoxAmd64ImageBuilder(VirtualBoxImageBuilder):
    """Image builder for all VirutalBox amd64 targets."""
    architecture = 'amd64'


class VirtualBoxI386ImageBuilder(VirtualBoxImageBuilder):
    """Image builder for all VirutalBox i386 targets."""
    architecture = 'i386'
    kernel_flavor = '686'


class VagrantImageBuilder(VirtualBoxAmd64ImageBuilder):
    """Image builder for Vagrant package."""
    vagrant_extension = '.box'

    @classmethod
    def get_target_name(cls):
        """Return the name of the target for an image builder."""
        return 'vagrant'

    def build(self):
        """Run the image building process."""
        archive_file = self.image_file + '.xz'
        vm_file = self._replace_extension(
            self.image_file, self.vm_image_extension)
        vm_archive_file = vm_file + '.xz'
        vagrant_file = self._replace_extension(
            self.image_file, self.vagrant_extension)

        # Create empty log file owned by process runner
        open(self.log_file, 'w').close()

        if self.should_skip_step(vagrant_file):
            logger.info('Vagrant package exists, skipping - %s',
                        vagrant_file)
            return

        if self.should_skip_step(vm_file):
            logger.info('VM image exists, skipping - %s', vm_archive_file)
            self.vagrant_package(vm_file, vagrant_file)
            return

        if self.should_skip_step(vm_archive_file):
            logger.info('Compressed VM image exists, skipping - %s',
                        vm_archive_file)
            self._run(['unxz', '--keep', vm_archive_file])
            self.vagrant_package(vm_file, vagrant_file)
            return

        if self.should_skip_step(self.image_file):
            logger.info(
                'Pre-built image exists, skipping build - %s', self.image_file)
            self.create_vm_file(self.image_file, vm_file)
            self.vagrant_package(vm_file, vagrant_file)
            return

        if self.should_skip_step(archive_file):
            logger.info(
                'Compressed image exists, uncompressing - %s', archive_file)
            self._run(['unxz', '--keep', archive_file])
            self.create_vm_file(self.image_file, vm_file)
            os.remove(self.image_file)
            self.vagrant_package(vm_file, vagrant_file)
            return

        self.make_image()
        self.create_vm_file(self.image_file, vm_file)
        os.remove(self.image_file)
        self.vagrant_package(vm_file, vagrant_file)

    def vagrant_package(self, vm_file, vagrant_file):
        """Create a vagrant package from VM file."""
        self._run(['sudo', 'bin/vagrant-package', '--output', vagrant_file,
                   vm_file])


class QemuImageBuilder(VMImageBuilder):
    """Base image builder for all Qemu targets."""
    vm_image_extension = '.qcow2'

    @classmethod
    def get_target_name(cls):
        """Return the name of the target for an image builder."""
        if getattr(cls, 'architecture', None):
            return 'qemu-' + cls.architecture

    def create_vm_file(self, image_file, vm_file):
        """Create a VM image file from image file."""
        if self.should_skip_step(vm_file, [image_file]):
            logger.info('VM file exists, skipping conversion - %s', vm_file)
            return

        self._run(['qemu-img', 'convert', '-O', 'qcow2', image_file, vm_file])


class QemuAmd64ImageBuilder(QemuImageBuilder):
    """Image builder for all Qemu amd64 targets."""
    architecture = 'amd64'


class QemuI386ImageBuilder(QemuImageBuilder):
    """Image builder for all Qemu i386 targets."""
    architecture = 'i386'
    kernel_flavor = '686'


class ARMImageBuilder(ImageBuilder):
    """Base image builder for all ARM targets."""
    boot_loader = 'u-boot'
    boot_filesystem_type = 'ext2'
    boot_size = '128M'

    @classmethod
    def get_target_name(cls):
        """Return the name of the target for an image builder."""
        return getattr(cls, 'machine', None)


class BeagleBoneImageBuilder(ARMImageBuilder):
    """Image builder for BeagleBone target."""
    architecture = 'armhf'
    machine = 'beaglebone'
    kernel_flavor = 'armmp'
    boot_offset = '2mib'


class A20ImageBuilder(ARMImageBuilder):
    """Base image builder for all Allwinner A20 board based targets."""
    architecture = 'armhf'
    kernel_flavor = 'armmp-lpae'
    boot_offset = '1mib'


class A20OLinuXinoLimeImageBuilder(A20ImageBuilder):
    """Image builder for A20 OLinuXino Lime targets."""
    machine = 'a20-olinuxino-lime'


class A20OLinuXinoLime2ImageBuilder(A20ImageBuilder):
    """Image builder for A20 OLinuXino Lime2 targets."""
    machine = 'a20-olinuxino-lime2'


class A20OLinuXinoMicroImageBuilder(A20ImageBuilder):
    """Image builder for A20 OLinuXino Micro targets."""
    machine = 'a20-olinuxino-micro'


class BananaProImageBuilder(A20ImageBuilder):
    """Image builder for Banana Pro target."""
    machine = 'banana-pro'


class Cubieboard2ImageBuilder(A20ImageBuilder):
    """Image builder for Cubieboard 2 target."""
    machine = 'cubieboard2'


class CubietruckImageBuilder(A20ImageBuilder):
    """Image builder for Cubietruck (Cubieboard 3) target."""
    machine = 'cubietruck'


class PCDuino3ImageBuilder(A20ImageBuilder):
    """Image builder for PCDuino3 target."""
    machine = 'pcduino3'


class DreamPlugImageBuilder(ARMImageBuilder):
    """Image builder for DreamPlug target."""
    architecture = 'armel'
    machine = 'dreamplug'
    kernel_flavor = 'marvell'
    boot_filesystem_type = 'vfat'


class RaspberryPiImageBuilder(ARMImageBuilder):
    """Image builder for Raspberry Pi target."""
    architecture = 'armel'
    machine = 'raspberry'
    free = False
    boot_loader = None
    root_filesystem_type = 'ext4'
    boot_filesystem_type = 'vfat'
    kernel_flavor = None


class RaspberryPi2ImageBuilder(ARMImageBuilder):
    """Image builder for Raspberry Pi 2 target."""
    architecture = 'armhf'
    machine = 'raspberry2'
    free = False
    boot_offset = '64mib'
    kernel_flavor = 'armmp'


class RaspberryPi3ImageBuilder(ARMImageBuilder):
    """Image builder for Raspberry Pi 3 target."""
    architecture = 'armhf'
    machine = 'raspberry3'
    free = False
    boot_offset = '64mib'
    kernel_flavor = 'armmp'
