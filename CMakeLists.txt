cmake_minimum_required(VERSION 3.12)
project(Piano LANGUAGES ASM_NASM C)

set(CMAKE_ASM_NASM_FLAGS "-f elf32 -g -F dwarf")
set(CMAKE_ASM_NASM_OBJECT_FORMAT elf32)
set(CMAKE_POSITION_INDEPENDENT_CODE OFF)

set(CMAKE_EXE_LINKER_FLAGS "-m32 -L/usr/lib/i386-linux-gnu")

set(CMAKE_ASM_NASM_COMPILE_OBJECT "<CMAKE_ASM_NASM_COMPILER> <FLAGS> -o <OBJECT> <SOURCE>")
set(CMAKE_ASM_NASM_LINK_EXECUTABLE "gcc -m32 -no-pie -static-libgcc -nostartfiles -L/usr/lib/i386-linux-gnu <OBJECTS> -o <TARGET> <LINK_LIBRARIES>")

find_library(ALSA_LIB NAMES asound)
find_library(MATH_LIB NAMES m)

message(STATUS "Found ALSA library: ${ALSA_LIB}")
message(STATUS "Found ALSA headers: ${ALSA_INCLUDE_DIR}")
message(STATUS "Found MATH library: ${MATH_LIB}")

add_executable(Piano main.asm)

target_link_libraries(Piano ${ALSA_LIB} ${MATH_LIB})