#!/usr/bin/tclsh
yosys -import
echo on

set src ../src
set top_module async_fifo_Ndeep

# Define parameter names + values (values taken from EnvVars set by yosys_wrapper.sh)
array set params {
  BUFFER_DEPTH_POWER 4
  DATA_WIDTH 8
}

# File list
set files {
  bin2gray.sv
  gray2bin.sv
  synchronizer.sv
  async_fifo_Ndeep.sv
}

# Executes the basic backend for synth + opt + report
source common.tcl