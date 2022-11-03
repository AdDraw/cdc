/*
  AdDraw @2022
  Asynchronous 2p FIFO for CDC
  Writing using CLKA
  Reading done using CLKB
  GRAY encoded ptr -> not needed if you have a 2 deep fifo (not enough addresses)
  # write the data into the register if this register is not cA_full
  # read from the register using clkB if register is not empty
 
  Simple 2 deep circular buffer with asynchronous writing and reading
 
  cA_ - signal is in CLKA domain
  cB_ - signal is in CLKB domain
 
*/
`timescale 1ns/1ps
module async_fifo_2deep #(
    parameter DATA_WIDTH = 8
  )(
    // WRITE PORT
    input                     clkA_i,
    input                     cA_rst_ni,
    input                     cA_we_i,
    input  [DATA_WIDTH-1 : 0] cA_din_i,
    output                    cA_wrdy_o,
    // READ PORT
    input                     clkB_i,
    input                     cB_rst_ni,
    input                     cB_re_i,
    output [DATA_WIDTH-1 : 0] cB_dout_o,
    output                    cB_rrdy_o
  );

  logic [DATA_WIDTH-1 :0 ] mem [2];

  logic       cA_wr_ptr;
  logic [1:0] cA_rd_ptr_sync;
  logic       cA_full  = ~(cA_wr_ptr ^ cA_rd_ptr_sync[1]);

  always_ff @( posedge clkA_i or negedge cA_rst_ni ) begin
    if (!cA_rst_ni) begin
      cA_wr_ptr      <= 1'b0;
      cA_rd_ptr_sync <= 2'b00;
    end
    else begin
      cA_rd_ptr_sync <= {cA_rd_ptr_sync[0], cB_rd_ptr};
      if (cA_we_i & ~cA_full) begin
        mem[cA_wr_ptr] <= cA_din_i;
        cA_wr_ptr      <= cA_wr_ptr ^ cA_we_i;
      end
    end
  end

  //--------------- CLOCK DOMAIN BORDER -----------------

  logic [DATA_WIDTH-1:0]  cB_dout;

  logic       cB_rd_ptr;
  logic [1:0] cB_wr_ptr_sync;
  logic       cB_empty = cB_wr_ptr_sync[1] ^ cB_rd_ptr;

  always_ff @( posedge clkB_i or negedge cB_rst_ni ) begin
    if (!cB_rst_ni) begin
      cB_rd_ptr      <= 0;
      cB_wr_ptr_sync <= 2'b00;
    end
    else begin
      cB_wr_ptr_sync <= {cB_wr_ptr_sync[0], cA_wr_ptr};
      if (cB_re_i & ~cB_empty) begin
        cB_dout   <= mem[cB_rd_ptr];
        cB_rd_ptr <= cB_rd_ptr ^ cB_re_i;
      end
    end
  end

  assign cA_wrdy_o = ~cA_full;
  assign cB_rrdy_o = ~cB_empty;
  assign cB_dout_o = cB_dout;

endmodule
