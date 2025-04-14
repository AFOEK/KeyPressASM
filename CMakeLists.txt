cmake_minimum_required(VERSION 3.12)
project(Piano LANGUAGES ASM_NASM)

# Use 32-bit output
set(CMAKE_ASM_NASM_OBJECT_FORMAT elf32)
set(CMAKE_ASM_NASM_FLAGS "-f elf32 -g -F dwarf")
set(CMAKE_EXE_LINKER_FLAGS "-m32 -no-pie -L/usr/lib/i386-linux-gnu")

# Optional: disable position-independent code
set(CMAKE_POSITION_INDEPENDENT_CODE OFF)

# Custom NASM rule to match command-line
set(CMAKE_ASM_NASM_COMPILE_OBJECT "<CMAKE_ASM_NASM_COMPILER> <FLAGS> -o <OBJECT> <SOURCE>")

# Custom linker rule to use gcc and link libraries
set(CMAKE_ASM_NASM_LINK_EXECUTABLE "gcc -m32 -no-pie -static-libgcc -nostartfiles <OBJECTS> -o <TARGET> <LINK_LIBRARIES>")

#Overwrite library path for libasound.so
set(ALSA_LIB /usr/lib/i386-linux-gnu/libasound.so)

# Find libraries
find_library(ALSA_LIB NAMES asound PATHS /usr/lib/i386-linux-gnu/libasound.so REQUIRED)
find_library(MATH_LIB NAMES m PATHS /usr/lib/i386-linux-gnu REQUIRED)

message(STATUS "Found ALSA library: ${ALSA_LIB}")
message(STATUS "Found MATH library: ${MATH_LIB}")

# Add your NASM source
add_executable(Piano main.asm)

# Link against ALSA and math
target_link_libraries(Piano ${ALSA_LIB} ${MATH_LIB})
