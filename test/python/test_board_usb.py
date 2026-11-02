# SPDX-License-Identifier: Apache-2.0
# python/usb_board.py's Board on its own: the words the core pushes in, the replies out.
import sys

sys.path.insert(0, sys.argv[1])
import usb_board  # noqa: E402

DESCRIPTORS = {1: [18] + [0] * 17, 2: [9] * 9, 0x22: [0] * 8}
SET_CONFIGURATION = [0x00, 9, 1, 0, 0, 0, 0, 0]


def setup(board, request):
    """A SETUP's eight bytes as the core pushes them, bit reversed, and its CRC words."""
    data = request + [0, 0, 0, 0]
    board.feed(usb_board.TAG_DATA0)
    for i in range(0, 12, 2):
        board.feed(usb_board._REVERSED[data[i]] << 8 | usb_board._REVERSED[data[i + 1]])


def acknowledge(board):
    """Every queued reply sent and taken by the host."""
    while board.replies:
        board.replies.pop(0)
        board.feed(usb_board.TAG_ACK)


def report_pid(board, key):
    board.report([0, 0, key, 0, 0, 0, 0, 0])
    pid = board.replies[0][0] >> 8
    acknowledge(board)
    return pid


def test_set_configuration_resets_the_report_toggle():
    """USB 2.0 9.4.5: SET_CONFIGURATION puts an interrupt endpoint back on DATA0, with no
    bus reset in between."""
    board = usb_board.Board(DESCRIPTORS)
    setup(board, SET_CONFIGURATION)
    acknowledge(board)
    assert report_pid(board, 4) == usb_board.DATA0
    setup(board, SET_CONFIGURATION)
    acknowledge(board)
    assert report_pid(board, 5) == usb_board.DATA0
    assert report_pid(board, 6) == usb_board.DATA1


test_set_configuration_resets_the_report_toggle()
