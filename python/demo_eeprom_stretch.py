# SPDX-License-Identifier: Apache-2.0
# The EEPROM act on I2c.master_stretch, which reads SCL back after letting it go
# and times the high phase from the rise it sees, so SCL's rise behind the pull-up no
# longer comes off tHIGH and the START and STOP setups. demo/outside.sh eeprom_stretch.

import bench_firmware
import demo_eeprom

if __name__ == "__main__":
    demo_eeprom.main(bench_firmware.I2C_MASTER_STRETCH)
