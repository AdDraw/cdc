/* Adam Drawc @2022
    Simple 2 FF synchronizer for SLOW -> FAST clock domain crossing
    Ideally should only be used for a single bit
    IF DATA_WIDTH > 1 then it should encoded in GRAY
*/

module synchronizer_2ff #(
    parameter integer DATA_WIDTH = 1
  ) (
    input clk_i,
    input rst_ni,
    input  [DATA_WIDTH-1:0] data_i,
    output [DATA_WIDTH-1:0] data_sync_o
  );

  logic [DATA_WIDTH-1:0] sync_2ff [2];
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      sync_2ff[0] <= 0;
      sync_2ff[1] <= 0;
    end
    else begin
      sync_2ff[0] <= data_i;
      sync_2ff[1] <= sync_2ff[0];
    end
  end

  assign data_sync_o = sync_2ff[1];

endmodule



