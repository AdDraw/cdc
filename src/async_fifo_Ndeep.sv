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
*/
`timescale 1ns/1ps

module async_fifo_Ndeep #(
    parameter DATA_WIDTH         = 8,
    parameter BUFFER_DEPTH_POWER = 2
  )(
    // WRITE PORT CLKA
    input                     clkA_i,
    input                     cA_rst_ni,
    input                     cA_wea_i,
    input  [DATA_WIDTH-1 : 0] cA_dina_i,
    output                    cA_wrdy_o,
    // READ PORT CLKB
    input                     clkB_i,
    input                     cB_rst_ni,
    input                     cB_reb_i,
    output [DATA_WIDTH-1 : 0] cB_doutb_o,
    output                    cB_rrdy_o
  );
  localparam BUFFER_DEPTH = 2**BUFFER_DEPTH_POWER;

  // INTER DOMAIN FIFO
  logic [DATA_WIDTH-1 : 0 ] fifo [BUFFER_DEPTH];

  // CLK A DOMAIN
  logic [$clog2(BUFFER_DEPTH)-1 : 0] cA_wr_ptr;
  logic [$clog2(BUFFER_DEPTH)-1 : 0] cA_rd_ptr_gray;
  logic [$clog2(BUFFER_DEPTH)-1 : 0] cA_rd_ptr_bin;

  logic cA_full  = (cA_wr_ptr + 1'b1 == cA_rd_ptr_bin) ? 1'b1 : 1'b0;

  synchronizer_2ff #(
    .DATA_WIDTH(DATA_WIDTH)
  ) sync_rd_ptr (
    .clk_i(clkA_i),
    .rst_ni(cA_rst_ni),
    .data_i(cB_rd_ptr_gray),
    .data_sync_o(cA_rd_ptr_gray)
  );

  gray2bin #(
    .DATA_WIDTH($clog2(BUFFER_DEPTH))
  ) rd_ptr_gray2bin (
    .gray_i(cA_rd_ptr_gray),
    .bin_o(cA_rd_ptr_bin)
  );

  always_ff @( posedge clkA_i or negedge cA_rst_ni ) begin
    if (!cA_rst_ni) begin
      cA_wr_ptr <= 0;
    end
    else begin
      if (cA_wea_i & ~cA_full) begin
        fifo[cA_wr_ptr] <= cA_dina_i;
        cA_wr_ptr       <= cA_wr_ptr + 1'b1;
      end
    end
  end

  logic [$clog2(BUFFER_DEPTH)-1 : 0] cA_wr_ptr_gray = cA_wr_ptr ^ (cA_wr_ptr >> 1);

  //--------------- CLOCK DOMAIN BORDER -----------------
  // CLKB DOMAIN

  logic [DATA_WIDTH-1:0]             cB_doutb;
  logic [$clog2(BUFFER_DEPTH)-1 : 0] cB_rd_ptr;
  logic [$clog2(BUFFER_DEPTH)-1 : 0] cB_wr_ptr_gray; // driven by CLKA
  logic [$clog2(BUFFER_DEPTH)-1 : 0] cB_wr_ptr_bin;

  // READ WHEN NOT EMPTY
  always_ff @( posedge clkB_i or negedge cB_rst_ni ) begin
    if (!cB_rst_ni) begin
      cB_rd_ptr <= 0;
      cB_doutb  <= 0;
    end
    else begin
      if (cB_reb_i & ~cB_empty) begin
        cB_doutb  <= fifo[cB_rd_ptr];
        cB_rd_ptr <= cB_rd_ptr + 1'b1;
      end
    end
  end

  // receive WR_PTR
  synchronizer_2ff #(
    .DATA_WIDTH(DATA_WIDTH)
  ) sync_wr_ptr (
    .clk_i(clkB_i),
    .rst_ni(cB_rst_ni),
    .data_i(cA_wr_ptr_gray),
    .data_sync_o(cB_wr_ptr_gray)
  );
  gray2bin #(
    .DATA_WIDTH($clog2(BUFFER_DEPTH))
  ) wr_ptr_gray2bin (
    .gray_i(cB_wr_ptr_gray),
    .bin_o(cB_wr_ptr_bin)
  );

  // SEND RD PTR as GRAY
  logic [$clog2(BUFFER_DEPTH)-1 : 0] cB_rd_ptr_gray = cB_rd_ptr ^ (cB_rd_ptr >> 1);

  // SET EMPTY
  logic cB_empty = (cB_wr_ptr_bin == cB_rd_ptr) ? 1'b1: 1'b0;

  assign cA_wrdy_o = ~cA_full;
  assign cB_rrdy_o = ~cB_empty;
  assign cB_doutb_o = cB_doutb;

endmodule
