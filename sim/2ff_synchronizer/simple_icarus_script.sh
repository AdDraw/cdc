#!/bin/sh

iverilog -I/home/adam/git_repos/cdc/src -oout.vvp tb.sv -g2012 -s tb
vvp -l test.log out.vvp
