/*
    Converts binary to Gray
*/
module bin2gray #(
    parameter DATA_WIDTH = 3
) (
    input  [DATA_WIDTH-1:0] bin_data_i,
    output [DATA_WIDTH-1:0] gray_data_o
);

assign gray_data_o = (bin_data_i >> 1) ^ bin_data_i;

endmodule