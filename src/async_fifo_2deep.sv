/*
  AdDraw @2022
  Asynchronous 2p FIFO for CDC
  Writing using CLKA
  Reading done using CLKB
  GRAY encoded ptr -> not needed if you have a 2 deep fifo (not enough addresses)
  # write the data into the register if this register is not full
  # read from the register using clkB if register is not empty
 
  Simple 2 deep circular buffer with asynchronous writing and reading
*/
`timescale 1ns/1ps
module async_fifo_2deep #(
    parameter DATA_WIDTH = 8
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

  logic [DATA_WIDTH-1 :0 ] fifo [2];
  logic [DATA_WIDTH-1:0] doutb;

  logic wr_ptr;
  logic rd_ptr_clkA_synced1, rd_ptr_clkA_synced2;
  logic full  = ~(wr_ptr ^ rd_ptr_clkA_synced2);

  always_ff @( posedge clka_i or negedge wrst_ni ) begin
    if (!wrst_ni) begin
      wr_ptr <= 0;
      rd_ptr_clkA_synced1 <= 0;
      rd_ptr_clkA_synced2 <= 0;
    end
    else begin
      rd_ptr_clkA_synced1 <= rd_ptr;
      rd_ptr_clkA_synced2 <= rd_ptr_clkA_synced1;
      if (wea_i & ~full) begin
        fifo[wr_ptr] <= dina_i;
        wr_ptr       <= wr_ptr ^ wea_i;
      end
    end
  end

  //--------------- CLOCK DOMAIN BORDER -----------------

  logic rd_ptr;
  logic wr_ptr_clkB_synced1, wr_ptr_clkB_synced2;
  logic empty = wr_ptr_clkB_synced2 ^ rd_ptr;
  always_ff @( posedge clkb_i or negedge rrst_ni ) begin
    if (!rrst_ni) begin
      rd_ptr <= 0;
      wr_ptr_clkB_synced1 <= 0;
      wr_ptr_clkB_synced2 <= 0;
    end
    else begin
      wr_ptr_clkB_synced1 <= wr_ptr;
      wr_ptr_clkB_synced2 <= wr_ptr_clkB_synced1;
      if (reb_i & ~empty) begin
        doutb  <= fifo[rd_ptr];
        rd_ptr <= rd_ptr ^ reb_i;
      end
    end
  end

  assign wrdy_o = ~full;
  assign rrdy_o = ~empty;
  assign doutb_o = doutb;

endmodule
