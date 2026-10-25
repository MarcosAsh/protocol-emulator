# SPDX-License-Identifier: Apache-2.0
'''
Snorble (SNB-1 Rev. C): a sync low, eight data bits MSB first and odd parity, each
bit a low whose width is its value, with section 4's timing checked to a sample.
'''

from .pd import Decoder
