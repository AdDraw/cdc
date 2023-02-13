/*
  AdDraw @2022
  Asynchronous 2p FIFO for CDC
  Writing using CLKA
  Reading done using CLKB
  GRAY encoded ptr -> not needed if you have a 2 deep fifo (not enough addresses)
  # write the data into the register if this register is not a_full
  # read from the register using clkB if register is not empty

  Simple 2 deep circular buffer with asynchronous writing and reading

  a_ - signal is in CLKA domain
  b_ - signal is in CLKB domain

*/
`timescale 1ns/1ps
module async_fifo_2deep #(
    parameter integer DATA_WIDTH = 8
  )(
    // WRITE PORT
    input                     clk_a_i,
    input                     a_rst_ni,
    input                     a_we_i,
    input  [DATA_WIDTH-1 : 0] a_din_i,
    output                    a_wrdy_o,
    // READ PORT
    input                     clk_b_i,
    input                     b_rst_ni,
    input                     b_re_i,
    output [DATA_WIDTH-1 : 0] b_dout_o,
    output                    b_rrdy_o
  );
  // FIFO MEM
  logic [DATA_WIDTH-1 :0 ] mem [2];

  // CLKA Domain (WritePart)
  logic                    a_wr_ptr;
  logic [1:0]              a_rd_ptr_sync;
  wire                     a_full  = a_wr_ptr ^ a_rd_ptr_sync[1];

  always_ff @( posedge clk_a_i or negedge a_rst_ni ) begin
    if (!a_rst_ni) begin
      a_wr_ptr      <= 1'b0;
      a_rd_ptr_sync <= 2'b00;
    end
    else begin
      a_rd_ptr_sync <= {a_rd_ptr_sync[0], b_rd_ptr};
      if (a_we_i & ~a_full) begin
        mem[a_wr_ptr] <= a_din_i;
        a_wr_ptr      <= a_wr_ptr ^ a_we_i;
      end
    end
  end

  //--------------- CLOCK DOMAIN BORDER -----------------
  // CLKB Domain (ReadPart)
  logic [DATA_WIDTH-1:0]  b_dout;
  logic                   b_rd_ptr;
  logic [1:0]             b_wr_ptr_sync;
  wire                    b_empty = ~(b_wr_ptr_sync[1] ^ b_rd_ptr);

  always_ff @( posedge clk_b_i or negedge b_rst_ni ) begin
    if (!b_rst_ni) begin
      b_rd_ptr      <= 0;
      b_wr_ptr_sync <= 2'b00;
    end
    else begin
      b_wr_ptr_sync <= {b_wr_ptr_sync[0], a_wr_ptr};
      if (b_re_i & ~b_empty) begin
        b_dout   <= mem[b_rd_ptr];
        b_rd_ptr <= b_rd_ptr ^ b_re_i;
      end
    end
  end

  assign a_wrdy_o = ~a_full;
  assign b_rrdy_o = ~b_empty;
  assign b_dout_o = b_dout;

  // START & FINISH
  initial begin
    $dumpvars(0, async_fifo_2deep);
  end

endmodule
