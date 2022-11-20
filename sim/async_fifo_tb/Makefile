# Adam Drawc 2022
# simple makefile for the cocotb 
# (VERILOG_SOURCES are all files that are inside src/)

SRC_PATH=$(shell git rev-parse --show-toplevel)/src/
VERILOG_SOURCES:=$(shell find $(SRC_PATH) | grep .sv)

COCOTB_REDUCED_LOG_FMT = FALSE
SIM ?= icarus

MODULE := test
TOPLEVEL=async_fifo_Ndeep
TOPLEVEL_LANG=verilog
COCOTB_HDL_TIMEUNIT=1us
COCOTB_HDL_TIMEPRECISION=1us

DATA_WIDTH         ?= 8 # FIFO_WORD_WIDTH
BUFFER_DEPTH_POWER ?= 2 # fifo_size = 2**BUFFER_DEPTH_POWER
VSIM_ARGS= -P $(TOPLEVEL).DATA_WIDTH=$(DATA_WIDTH)
VSIM_ARGS+=-P $(TOPLEVEL).BUFFER_DEPTH_POWER=$(BUFFER_DEPTH_POWER)
VSIM_ARGS+= -g2012

all: test

test:
	@echo $(VERILOG_SOURCES)
	@echo $(VSIM_ARGS)
	@echo " "
	@echo " Starting SIMULATION on $(shell date)"
	@echo " "

include $(shell cocotb-config --makefiles)/Makefile.sim