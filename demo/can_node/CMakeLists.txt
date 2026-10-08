# Pico B's CAN node for the CAN act, on can2040 at a pinned commit (GPL-3.0, fetched at
# configure time, not kept here). Needs pico-sdk 2.x and arm-none-eabi-gcc:
#   cmake -S demo/can_node -B demo/out/can_node -D PICO_SDK_PATH=<pico-sdk> -D PICO_BOARD=pico
#   make -C demo/out/can_node
cmake_minimum_required(VERSION 3.13)

include(${PICO_SDK_PATH}/external/pico_sdk_import.cmake)
include(FetchContent)

project(can_node C CXX ASM)
pico_sdk_init()

FetchContent_Declare(can2040
  GIT_REPOSITORY https://github.com/KevinOConnor/can2040.git
  GIT_TAG 2988d4f11d8bff93f5a3d317fcd5e384a6aa3481)
FetchContent_MakeAvailable(can2040)

add_executable(can_node can_node.c ${can2040_SOURCE_DIR}/src/can2040.c)
target_include_directories(can_node PRIVATE ${can2040_SOURCE_DIR}/src)
# can2040 misses bits when it waits on flash, so everything runs from RAM
pico_set_binary_type(can_node copy_to_ram)
target_link_libraries(can_node pico_stdlib)
pico_enable_stdio_usb(can_node 1)
pico_enable_stdio_uart(can_node 0)
pico_add_extra_outputs(can_node)
