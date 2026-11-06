# SPDX-License-Identifier: Apache-2.0
# The EEPROM demo on I2c.master_stretch. It reads SCL back after releasing it and times the
# high phase from the rise it sees, so a slow rise behind the pull-up no longer eats into
# tHIGH or the START and STOP setups. demo/outside.sh eeprom_stretch runs it.

import bench_firmware
import demo_eeprom

if __name__ == "__main__":
    demo_eeprom.main(bench_firmware.I2C_MASTER_STRETCH)
