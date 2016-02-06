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
Tests for checking built image with VirtualBox.
"""

import logging
import os
import random
import string
import subprocess
import time
import unittest

logger = logging.getLogger(__name__)


class TestVirtualBox(unittest.TestCase):
    """Tests for checking built image with VirtualBox."""

    def setUp(self):
        """Setup test case."""
        self.path = os.path.dirname(__file__)
        self.binary = 'freedommaker'
        self.output_dir = os.path.join(self.path, 'output')

        self.build_stamp = self.random_string()
        self.current_target = 'virtualbox-i386'

    def random_string(self):
        """Generate a random string."""
        return ''.join([random.choice(string.ascii_lowercase)
                        for _ in range(8)])

    def invoke(self, targets=None, **kwargs):
        """Invoke Freedom Maker."""
        parameters = ['--build-dir', self.output_dir]

        if 'build_stamp' not in kwargs:
            parameters += ['--build-stamp', self.build_stamp]

        command = ['python3', '-m', self.binary] + parameters + targets
        subprocess.check_call(command)

    def get_built_file(self):
        """Return the path of the expected built file."""
        target = self.current_target
        extra_map = {
            'virtualbox-amd64': 'all-amd64.vdi',
            'virtualbox-i386': 'all-i386.vdi',
        }

        file_name = 'freedombox-unstable-free_{build_stamp}_{extra}.xz' \
            .format(build_stamp=self.build_stamp, extra=extra_map[target])

        return os.path.join(self.output_dir, file_name)

    def _run(self, *args):
        """Execute a command."""
        subprocess.check_call(*args)

    @unittest.skipUnless(os.environ.get('FM_RUN_VM_TESTS') == 'true',
                         'Not requested')
    def test_basic_build(self):
        """Test booting and opening SSH shell.

        Also:
          - Output the plinth diagnostic log.
        """
        self.invoke(['virtualbox-i386'])

        vm_name = 'freedom-maker-test'
        test_ssh_port = 2222
        first_run_wait_time = 120

        compressed_built_file = self.get_built_file()
        built_file = compressed_built_file.rsplit('.', maxsplit=1)[0]

        if not os.path.isfile(built_file):
            subprocess.check_call(['unxz', '--keep', '--force',
                                   compressed_built_file])

        passwd_tool = os.path.join(self.path, '..', '..', 'bin',
                                   'passwd-in-image')
        self._run(
            ['sudo', 'python3', passwd_tool, built_file, 'fbx', '--password',
             'frdm'])
        try:
            self._run(
                ['VBoxManage', 'createvm', '--name', vm_name, '--ostype',
                 'Debian', '--register'])
            self._run(
                ['VBoxManage', 'storagectl', vm_name, '--name',
                 'SATA Controller', '--add', 'sata', '--controller',
                 'IntelAHCI'])
            self._run(
                ['VBoxManage', 'storageattach', vm_name, '--storagectl',
                 'SATA Controller', '--port', '0', '--device', '0', '--type',
                 'hdd', '--medium', built_file])
            self._run(
                ['VBoxManage', 'modifyvm', vm_name, '--pae', 'on', '--memory',
                 '1024', '--vram', '128', '--nic1', 'nat', '--natpf1',
                 ',tcp,,{port},,22'.format(port=test_ssh_port)])
            self._run(
                ['VBoxManage', 'startvm', vm_name, '--type', 'headless'])
            time.sleep(first_run_wait_time)

            echo = subprocess.Popen(['echo', 'frdm'], stdout=subprocess.PIPE)
            process = subprocess.Popen(
                ['sshpass', '-p', 'frdm', 'ssh',
                 '-o', 'UserKnownHostsFile=/dev/null',
                 '-o', 'StrictHostKeyChecking=no',
                 '-t', '-t', '-p', str(test_ssh_port), 'fbx@127.0.0.1',
                 'sudo plinth --diagnose'], stdin=echo.stdout)
            process.communicate()
        finally:
            self._run(['VBoxManage', 'controlvm', vm_name, 'poweroff'])
            self._run(['VBoxManage', 'modifyvm', vm_name, '--hda', 'none'])
            self._run(['VBoxManage', 'unregistervm', vm_name])
