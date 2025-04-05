cmake_minimum_required(VERSION 3.12)
project(Piano LANGUAGES ASM_NASM C)

set(CMAKE_ASM_NASM_FLAGS "-f elf32 -g -F dwarf")
set(CMAKE_ASM_NASM_OBJECT_FORMAT elf32)

find_package(Pkgconfig REQUIRED)
pkg_check_modules(ALSA REQUIRED alsa)

if(NOT ALSA_FOUND)
    message(FATAL_ERROR "ALSA library not found!")
endif()

add_executable(Piano main.asm)

target_link_libraries(Piano ${ALSA_LIBRARIES} m)

if(CMAKE_SIZEOF_VOID_P EQUAL 4)
    set_target_properties(Piano PROPERTIES COMPILE_FLAGS "-m32" LINK_FLAGS "-m32")
endif()