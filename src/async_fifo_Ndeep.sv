/*
  AdDraw @2022
  Asynchronous 2p FIFO for CDC
  Writing using CLKA
  Reading done using CLKB
  GRAY encoded ptr -> not needed if you have a 2 deep fifo (not enough addresses)
  # write the data into the register if this register is not full
  # read from the register using clkB if register is not empty

  Asynchronous Circular buffer N words deep:
  - wr_ptr & clkb_rd_ptr in binary
  - converted to GRAY and send with the use of 2FF sync over to the other clock domain
  - In this domain to simplify EMPTY | FULL flag comb logic convert gray back to BINARY
  - use binary with binary for empty and full

  a_ - signal is driven from the CLKA domain
  b_ - signal is driven from the CLKB domain
*/
`timescale 1ns/1ps

module async_fifo_Ndeep #(
    parameter int DATA_WIDTH         = 8,
    parameter int BUFFER_DEPTH_POWER = 2
  )(
    // WRITE PORT CLKA
    input                     clk_a_i,
    input                     a_rst_ni,
    input                     a_we_i,
    input  [DATA_WIDTH-1 : 0] a_din_i,
    output                    a_wasdassdrdy_o,
    // READ PORT CLKB
    input                     clk_b_i,
    input                     b_rst_ni,
    input                     b_re_i,
    output [DATA_WIDTH-1 : 0] b_dout_o,
    output                    b_rrdy_o
  );
  localparam int BUFFER_DEPTH = 2**BUFFER_DEPTH_POWER;

  // INTER DOMAIN FIFO
  logic [DATA_WIDTH-1 : 0 ] fifo [BUFFER_DEPTH];

  // CLK A DOMAIN
  logic [BUFFER_DEPTH_POWER-1 : 0] a_wr_ptr;
  logic [BUFFER_DEPTH_POWER-1 : 0] a_rd_ptr_gray_sync;
  logic [BUFFER_DEPTH_POWER-1 : 0] a_rd_ptr_bin;

  wire a_full  = (a_wr_ptr + 1'b1 == a_rd_ptr_bin) ? 1'b1 : 1'b0;

  wire [BUFFER_DEPTH_POWER-1 : 0] a_wr_ptr_gray = a_wr_ptr ^ (a_wr_ptr >> 1);

  synchronizer_2ff #(
    .DATA_WIDTH(BUFFER_DEPTH_POWER)
  ) sync_rd_ptr (
    .clk_i(clk_a_i),
    .rst_ni(a_rst_ni),
    .data_i(b_rd_ptr_gray),
    .data_sync_o(a_rd_ptr_gray_sync)
  );

  gray2bin #(
    .DATA_WIDTH(BUFFER_DEPTH_POWER)
  ) rd_ptr_gray2bin (
    .gray_i(a_rd_ptr_gray_sync),
    .bin_o(a_rd_ptr_bin)
  );

  always_ff @( posedge clk_a_i or negedge a_rst_ni ) begin
    if (~a_rst_ni) begin
      a_wr_ptr <= 0;
    end
    else begin
      if (a_we_i & ~a_full) begin
        fifo[a_wr_ptr] <= a_din_i;
        a_wr_ptr       <= a_wr_ptr + 1'b1;
      end
    end
  end


  //--------------- CLOCK DOMAIN BORDER -----------------
  // CLKB DOMAIN

  logic [DATA_WIDTH-1:0]           b_dout;
  logic [BUFFER_DEPTH_POWER-1 : 0] b_rd_ptr;
  logic [BUFFER_DEPTH_POWER-1 : 0] b_wr_ptr_gray_sync; // driven by CLKA
  logic [BUFFER_DEPTH_POWER-1 : 0] b_wr_ptr_bin;

  wire b_empty = (b_wr_ptr_bin == b_rd_ptr) ? 1'b1: 1'b0;

  // SEND RD PTR as GRAY
  wire [BUFFER_DEPTH_POWER-1 : 0] b_rd_ptr_gray = b_rd_ptr ^ (b_rd_ptr >> 1);

  // READ WHEN NOT EMPTY
  always_ff @( posedge clk_b_i or negedge b_rst_ni ) begin
    if (~b_rst_ni) begin
      b_rd_ptr <= 0;
      b_dout   <= 0;
    end
    else begin
      if (b_re_i & ~b_empty) begin
        b_dout   <= fifo[b_rd_ptr];
        b_rd_ptr <= b_rd_ptr + 1'b1;
      end
    end
  end

  // receive WR_PTR
  synchronizer_2ff #(
    .DATA_WIDTH(BUFFER_DEPTH_POWER)
  ) sync_wr_ptr (
    .clk_i(clk_b_i),
    .rst_ni(b_rst_ni),
    .data_i(a_wr_ptr_gray),
    .data_sync_o(b_wr_ptr_gray_sync)
  );
  gray2bin #(
    .DATA_WIDTH(BUFFER_DEPTH_POWER)
  ) wr_ptr_gray2bin (
    .gray_i(b_wr_ptr_gray_sync),
    .bin_o(b_wr_ptr_bin)
  );

  assign a_wrdy_o = ~a_full;
  assign b_rrdy_o = ~b_empty;
  assign b_dout_o = b_dout;

  // START & FINISH
  initial begin
    $dumpvars(0, async_fifo_Ndeep);
  end


endmodule
