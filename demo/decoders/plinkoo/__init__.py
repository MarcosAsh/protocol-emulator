# SPDX-License-Identifier: Apache-2.0
'''
Plinkoo (PLK-2 revision 1.3): a sync low on STB, then the length, the payload and the
checksum MSB first, DAT taken at each rise of STB, then the ack bit.
'''

from .pd import Decoder
