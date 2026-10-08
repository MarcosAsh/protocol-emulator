# Pico B as the bus master for the start hold act, in two builds: start_hold_pio through
# pico-examples' pio_i2c at a pinned commit (BSD-3-Clause, fetched at configure time, not
# kept here, built unmodified), start_hold_hw through the RP2040's I2C block. Needs
# pico-sdk 2.x and arm-none-eabi-gcc:
#   cmake -S demo/start_hold_master -B demo/out/start_hold_master -D PICO_SDK_PATH=<pico-sdk> -D PICO_BOARD=pico
#   make -C demo/out/start_hold_master
cmake_minimum_required(VERSION 3.13)

include(${PICO_SDK_PATH}/external/pico_sdk_import.cmake)
include(FetchContent)

project(start_hold_master C CXX ASM)
pico_sdk_init()

# only the sources are wanted, so no subdirectory is added
FetchContent_Declare(pico_examples
  GIT_REPOSITORY https://github.com/raspberrypi/pico-examples.git
  GIT_TAG 0d62f75bafc2c8120d3276c3343d1a9195e909e9
  SOURCE_SUBDIR none)
FetchContent_MakeAvailable(pico_examples)
set(pio_i2c ${pico_examples_SOURCE_DIR}/pio/i2c)

add_executable(start_hold_pio start_hold_master.c ${pio_i2c}/pio_i2c.c)
pico_generate_pio_header(start_hold_pio ${pio_i2c}/i2c.pio)
target_include_directories(start_hold_pio PRIVATE ${pio_i2c})
target_compile_definitions(start_hold_pio PRIVATE START_HOLD_PIO)
target_link_libraries(start_hold_pio pico_stdlib hardware_pio)

add_executable(start_hold_hw start_hold_master.c)
target_link_libraries(start_hold_hw pico_stdlib hardware_i2c)

foreach(build start_hold_pio start_hold_hw)
  pico_enable_stdio_usb(${build} 1)
  pico_enable_stdio_uart(${build} 0)
  pico_add_extra_outputs(${build})
endforeach()
