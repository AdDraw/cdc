# Common backend for synth + opt + report for yosys
set std_lib $::env(STD_LIB)

# Read Verilog part
for { set index 0 }  { $index < [array size files] - 1 }  { incr index } {
  read_verilog -sv -defer $src/$files($index)
}
read_verilog -sv $src/$files([expr [array size files] - 1])

log "SCRIPT_INFO: Parameters and their values:"
for { set index 0 }  { $index < [array size params] }  { incr index } {
  if { [info exists ::env($params($index))] } {
    set values($index) $::env($params($index))
  }
  log "SCRIPT_INFO: $index. : $params($index) = $values($index)"
}

# IF SHOW_PARAMS is set to 1, it only specifies what the TOPMODULE parameters are
# it also shows params and values lists of parameters that are modifiable and their default values
if {$::env(SHOW_PARAMS) == 1} {
  read_verilog -sv ../src/async_fifo_Ndeep.sv
  log "Parameters from the top-module"
  chparam -list
  exit 0
}

# Set parameter values
for { set index 0 }  { $index < [array size params] }  { incr index } {
  chparam -set $params($index) $values($index) $top_module
}

hierarchy -top $top_module -keep_portwidths -check
synth -top $top_module -flatten
dfflibmap -liberty $std_lib
abc -liberty $std_lib
clean

if { [info exists ::env(XDOT)] } {
  show -enum -long -width -signed -stretch $top_module
}

json -o $::env(JSON_PATH)/$top_module.json
write_verilog ./$top_module-netlist.sv

stat -top $top_module -liberty $std_lib -tech cmos
chparam -list

stat -top $top_module -liberty $std_lib -tech cmos