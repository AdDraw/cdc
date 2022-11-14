# Adam Drawc 2022
# simple makefile for the cocotb 
# (VERILOG_SOURCES are all files that are inside src/)

SRC_PATH=$(shell git rev-parse --show-toplevel)/src/
VERILOG_SOURCES:=$(shell find $(SRC_PATH) | grep .sv)

COCOTB_REDUCED_LOG_FMT = False
SIM ?= icarus

MODULE := test
TOPLEVEL=async_fifo_Ndeep
TOPLEVEL_LANG=verilog
COCOTB_HDL_TIMEUNIT=1us
COCOTB_HDL_TIMEPRECISION=1us

# test:
# 	@echo $(VERILOG_SOURCES)

include $(shell cocotb-config --makefiles)/Makefile.sim