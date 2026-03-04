#!/bin/sh
clang -W -Wall -Wno-unused-parameter -framework IOKit -framework CoreFoundation -o CPUFlash main.c keyboard_leds.c

