#!/usr/bin/tclsh
yosys -import
echo on

set src ../src
set top_module bin2gray

# Define parameter names + values (values taken from EnvVars set by yosys_wrapper.sh)
array set params {
  DATA_WIDTH 8
}

# File list
set files {
  bin2gray.sv
}

# Executes the basic backend for synth + opt + report
source common.tcl