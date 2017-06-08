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
Freedom Maker setup file
"""

import setuptools

from freedommaker import __version__


setuptools.setup(
    name='freedom-maker',
    version=__version__,
    description='The FreedomBox image builder',
    author='FreedomBox Authors',
    author_email='freedombox-discuss@lists.alioth.debian.org',
    url='http://freedomboxfoundation.org',
    packages=setuptools.find_packages(),
    entry_points={
        'console_scripts': [
            'freedom-maker = freedommaker:main'
        ]
    },
    test_suite='freedommaker.tests',
    license='COPYING',
    classifiers=[
        'Development Status :: 4 - Beta',
        'Environment :: Console',
        'Intended Audience :: End Users/Desktop',
        'License :: DFSG approved',
        'License :: OSI Approved :: GNU General Public License v3 or later (GPLv3+)',
        'Natural Language :: English',
        'Operating System :: POSIX :: Linux',
        'Programming Language :: Python',
        'Programming Language :: Python :: 3',
        'Programming Language :: Unix Shell',
        'Topic :: System :: Software Distribution',
    ],
    include_package_data=True,
)
