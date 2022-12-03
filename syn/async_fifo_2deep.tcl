yosys -import
echo on

set src ../src
set top_module async_fifo_2deep

# Define parameter names + values (values taken from EnvVars set by yosys_wrapper.sh)
set params(0) DATA_WIDTH
set values(0) 8

# File list
set files(0) async_fifo_2deep.sv

# Executes the basic backend for synth + opt + report
source common.tcl