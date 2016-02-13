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
Command line application wrapper over image builder.
"""

import argparse
import datetime
import logging
import logging.config
import os

from .builder import ImageBuilder
import freedommaker

IMAGE_SIZE = '4G'
BUILD_MIRROR = 'http://httpredir.debian.org/debian'
MIRROR = 'http://httpredir.debian.org/debian'
DISTRIBUTION = 'unstable'
INCLUDE_SOURCE = False
BUILD_DIR = 'build'
LOG_LEVEL = 'debug'
HOSTNAME = 'freedombox'

logger = logging.getLogger(__name__)  # pylint: disable=invalid-name


class Application(object):
    """Command line application to build FreedomBox images."""
    def __init__(self):
        """Initialize object."""
        self.arguments = None

    def run(self):
        """Parse the command line args and execute the command."""
        self.parse_arguments()

        self.setup_logging()
        logger.info('Freedom Maker version - %s', freedommaker.__version__)

        try:
            logger.info('Creating directory - %s', self.arguments.build_dir)
            os.makedirs(self.arguments.build_dir)
        except os.error:
            pass

        for target in self.arguments.targets:
            logger.info('Building target - %s', target)

            cls = ImageBuilder.get_builder_class(target)
            if not cls:
                logger.warn('Unknown target - %s', target)
                continue

            builder = cls(self.arguments)
            self.setup_logging(builder.log_file)
            builder.build()
            builder.cleanup()

            logger.info('Target complete - %s', target)

    def parse_arguments(self):
        """Parse command line arguments."""
        build_stamp = datetime.datetime.today().strftime('%Y-%m-%d')

        parser = argparse.ArgumentParser(
            description='FreedomMaker - Script to build FreedomBox images',
            formatter_class=argparse.ArgumentDefaultsHelpFormatter
        )
        parser.add_argument(
            '--vmdebootstrap', default='vmdebootstrap',
            help='Path to vmdebootstrap executable')
        parser.add_argument(
            '--build-stamp', default=build_stamp,
            help='Build stamp to use on image file names')
        parser.add_argument(
            '--image-size', default=IMAGE_SIZE,
            help='Size of the image to build')
        parser.add_argument(
            '--build-mirror', default=BUILD_MIRROR,
            help='Debian mirror to use for building')
        parser.add_argument(
            '--mirror', default=MIRROR,
            help='Debian mirror to use in built image')
        parser.add_argument(
            '--distribution', default=DISTRIBUTION,
            help='Debian release to use in built image')
        parser.add_argument(
            '--include-source', action='store_true', default=INCLUDE_SOURCE,
            help='Whether to include source in build image')
        parser.add_argument(
            '--package', action='append',
            help='Install additional packages in the image')
        parser.add_argument(
            '--custom-package', action='append',
            help='Install package from DEB file into the image')
        parser.add_argument(
            '--build-dir', default=BUILD_DIR,
            help='Diretory to build images and create log file')
        parser.add_argument(
            '--log-level', default=LOG_LEVEL, help='Log level',
            choices=('critical', 'error', 'warn', 'info', 'debug'))
        parser.add_argument(
            '--hostname', default=HOSTNAME,
            help='Hostname to set inside the built images')
        parser.add_argument(
            '--sign', action='store_true',
            help='Sign the images with default GPG key after building')
        parser.add_argument(
            '--force', action='store_true',
            help='Force rebuild of images even when required image exists')
        parser.add_argument(
            'targets', nargs='+', help='Image targets to build')

        self.arguments = parser.parse_args()

    def setup_logging(self, log_file=None):
        """Setup logging."""
        config = {
            'version': 1,
            'formatters': {
                'date': {
                    'format': '%(asctime)s - %(levelname)s - %(message)s'
                }
            },
            'handlers': {
                'console': {
                    'class': 'logging.StreamHandler',
                    'formatter': 'date',
                },
            },
            'root': {
                'level': self.arguments.log_level.upper(),
                'handlers': ['console'],
            },
            'disable_existing_loggers': False
        }
        logging.config.dictConfig(config)
