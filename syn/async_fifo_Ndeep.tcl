yosys -import
echo on

set src ../src
set top_module async_fifo_Ndeep

# Define parameter names + values (values taken from EnvVars set by yosys_wrapper.sh)
set params(0) BUFFER_DEPTH_POWER
set params(1) DATA_WIDTH
set values(0) 4
set values(1) 8

# File list
set files(0) bin2gray.sv
set files(1) gray2bin.sv
set files(2) synchronizer.sv
set files(3) async_fifo_Ndeep.sv

# Executes the basic backend for synth + opt + report
source common.tcl