# Adam Drawc 2022
# simple makefile for the cocotb
# (VERILOG_SOURCES are all files that are inside src/)

SRC_PATH=$(shell git rev-parse --show-toplevel)/src/
VERILOG_SOURCES:=$(shell find $(SRC_PATH) | grep .sv)

COCOTB_REDUCED_LOG_FMT = FALSE
SIM ?= icarus

MODULE := test

TOPLEVEL_LANG=verilog
COCOTB_HDL_TIMEUNIT=1ns
COCOTB_HDL_TIMEPRECISION=1ps

export DATA_WIDTH         ?= 8 # FIFO_WORD_WIDTH
export BUFFER_DEPTH_POWER ?= 2 # fifo_size = 2**BUFFER_DEPTH_POWER
VSIM_ARGS+= -g2012

deep2 ?= nok
ifneq ($deep2, nok)
	COMPILE_ARGS = -P $(TOPLEVEL).DATA_WIDTH=$(DATA_WIDTH)
	TOPLEVEL=async_fifo_2deep
else
	COMPILE_ARGS = -P $(TOPLEVEL).DATA_WIDTH=$(DATA_WIDTH)
	COMPILE_ARGS +=-P $(TOPLEVEL).BUFFER_DEPTH_POWER=$(BUFFER_DEPTH_POWER)
	TOPLEVEL=async_fifo_Ndeep
endif

all: prompt

prompt:
	@echo $(VERILOG_SOURCES)
	@echo $(VSIM_ARGS)
	@echo "BUFF_DEPTH_POWER=$(BUFFER_DEPTH_POWER)"
	@echo " "
	@echo " Starting SIMULATION on $(shell date)"
	@echo " "

include $(shell cocotb-config --makefiles)/Makefile.sim