/*
    Converts Gray to Binary
*/

module gray2bin #(
  parameter DATA_WIDTH = 3
) (
  input  [DATA_WIDTH-1:0] gray_i,
  output [DATA_WIDTH-1:0] bin_o
);

logic [DATA_WIDTH-1 :0] xor_res_array [DATA_WIDTH];
assign xor_res_array[0] = gray_i;
genvar gi;
generate
  for (gi = 1; gi < DATA_WIDTH ; gi = gi + 1 ) begin
    xor_res_array[gi] = xor_res_array[gi - 1] ^ (gray_i >> gi); 
  end
endgenerate

assign bin_o = xor_res_array[DATA_WIDTH-1];

endmodule