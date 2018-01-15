"""Treadmill node bootstrap.
"""

from __future__ import absolute_import
from __future__ import division
from __future__ import print_function
from __future__ import unicode_literals

import os

from .. import aliases

if os.name == 'nt':
    _DEFAULT_RUNTIME = 'docker'
else:
    _DEFAULT_RUNTIME = 'linux'

_DEFAULT_TREADMILL_VG = 'treadmill'

DEFAULTS = {
    'treadmill_runtime': _DEFAULT_RUNTIME,
    'treadmill_host_ticket': None,
    'treadmill_cpu': '90%',
    'treadmill_cpu_cores': 0,
    'treadmill_mem': '-1G',
    'treadmill_core_mem': '1G',
    'localdisk_img_location': '/var/tmp/treadmill-node/',
    'localdisk_img_size': '-2G',
    'localdisk_block_dev': None,
    'localdisk_vg_name': _DEFAULT_TREADMILL_VG,
    'block_dev_configuration': None,
    'block_dev_read_bps': None,
    'block_dev_write_bps': None,
    'block_dev_read_iops': None,
    'block_dev_write_iops': None,
    'localdisk_default_read_bps': '20M',
    'localdisk_default_read_iops': '100',
    'localdisk_default_write_bps': '20M',
    'localdisk_default_write_iops': '100',
    'docker_network': 'nat',
}

ALIASES = aliases.ALIASES
