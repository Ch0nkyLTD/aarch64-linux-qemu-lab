# Paths
LAB_ROOT := $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
KDIR ?= $(LAB_ROOT)/linux-6.6

# Toolchain
ARCH ?= arm64
CROSS_COMPILE ?= aarch64-linux-gnu-

# Compiler Flags (Optional: Add strict warnings for students)
ccflags-y += -Wall
