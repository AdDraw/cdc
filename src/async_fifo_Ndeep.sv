/*
  AdDraw @2022
  Asynchronous 2p FIFO for CDC
  Writing using CLKA
  Reading done using CLKB
  GRAY encoded ptr -> not needed if you have a 2 deep fifo (not enough addresses)
  # write the data into the register if this register is not full
  # read from the register using clkB if register is not empty
  
  Asynchronous Circular buffer N words deep:
  - wr_ptr & rd_ptr in binary
  - converted to GRAY and send with the use of 2FF sync over to the other clock domain
  - In this domain to simplify EMPTY | FULL flag comb logic convert gray back to BINARY
  - use binary with binary for empty and full
*/
`timescale 1ns/1ps
`include "synchronizer.sv"

module async_fifo_Ndeep #(
    parameter DATA_WIDTH   = 8,
    parameter BUFFER_DEPTH = 4
  )(
    // WRITE PORT
    input clka_i,
    input wrst_ni,
    input wea_i,
    input [DATA_WIDTH-1 : 0] dina_i,
    output wrdy_o,
    // READ PORT
    input clkb_i,
    input rrst_ni,
    input reb_i,
    output [DATA_WIDTH-1 : 0] doutb_o,
    output rrdy_o
  );

  logic [DATA_WIDTH-1 :0 ] fifo [BUFFER_DEPTH];
  logic [DATA_WIDTH-1:0] doutb;

  logic [$clog2(BUFFER_DEPTH)-1 : 0] wr_ptr;

  logic [$clog2(BUFFER_DEPTH)-1 : 0] rd_ptr_gray_clkA_synced;
  logic [$clog2(BUFFER_DEPTH)-1 : 0] rd_ptr_bin_clkA_synced;

  logic [$clog2(BUFFER_DEPTH)-1 : 0] wr_ptr_gray_clkA_synced_w;
  logic [$clog2(BUFFER_DEPTH)-1 : 0] wr_ptr_bin_clkA_synced_w;

  logic full  = (wr_ptr + 1'b1 == rd_ptr_clkA_synced) ? 1'b1 : 1'b0;

  // SEND RD PTR as GRAY
  logic [$clog2(BUFFER_DEPTH)-1 : 0] rd_ptr_gray = rd_ptr ^ (rd_ptr >> 1);

  synchronizer_2ff #(
                     .DATA_WIDTH(DATA_WIDTH)
                   ) sync_rd_ptr (
                     .clk_i(clka_i),
                     .rst_ni(wrst_ni),
                     .data_i(rd_ptr_gray),
                     .data_sync_o(rd_ptr_gray_clkA_synced)
                   );

  gray2bin #(
             .DATA_WIDTH($clog2(BUFFER_DEPTH))
           ) rd_ptr_gray2bin (
             .gray_i(rd_ptr_gray_clkA_synced),
             .bin_o(rd_ptr_bin_clkA_synced)
           );

  always_ff @( posedge clka_i or negedge wrst_ni ) begin
    if (!wrst_ni) begin
      wr_ptr <= 0;
    end
    else begin
      if (wea_i & ~full) begin
        fifo[wr_ptr] <= dina_i;
        wr_ptr       <= wr_ptr + 1'b1;
      end
    end
  end

  logic [$clog2(BUFFER_DEPTH)-1 : 0] wr_ptr_gray = wr_ptr ^ (wr_ptr >> 1);

  //--------------- CLOCK DOMAIN BORDER -----------------

  logic [$clog2(BUFFER_DEPTH)-1 : 0] rd_ptr;
  logic [$clog2(BUFFER_DEPTH)-1 : 0] wr_ptr_gray_clkB_synced; // send over CLOCK border
  logic [$clog2(BUFFER_DEPTH)-1 : 0] wr_ptr_bin_clkB_synced;

  // READ WHEN NOT EMPTY
  always_ff @( posedge clkb_i or negedge rrst_ni ) begin
    if (!rrst_ni) begin
      rd_ptr <= 0;
      wr_ptr_clkB_synced1 <= 0;
      wr_ptr_clkB_synced2 <= 0;
    end
    else begin
      if (reb_i & ~empty) begin
        doutb  <= fifo[rd_ptr];
        rd_ptr <= rd_ptr + 1'b1;
      end
    end
  end

  // receive WR_PTR
  synchronizer_2ff #(
    .DATA_WIDTH(DATA_WIDTH)
  ) sync_wr_ptr (
    .clk_i(clkb_i),
    .rst_ni(rrst_ni),
    .data_i(wr_ptr_gray),
    .data_sync_o(wr_ptr_gray_clkA_synced_w)
  );
  gray2bin #(
    .DATA_WIDTH($clog2(BUFFER_DEPTH))
  ) wr_ptr_gray2bin (
    .gray_i(wr_ptr_gray_clkB_synced),
    .bin_o(wr_ptr_bin_clkB_synced)
  );

  // SET EMPTY
  logic empty = (wr_ptr_bin_clkB_synced == rd_ptr) ? 1'b1: 1'b0;

  assign wrdy_o = ~full;
  assign rrdy_o = ~empty;
  assign doutb_o = doutb;

endmodule
