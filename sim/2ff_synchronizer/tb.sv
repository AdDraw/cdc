/*
    2 FF Synchronizer TB

    TB limitations:
    - ratio of slow to fast clock should be at least 4
    - won't work if CLOCK that sends the data is faster than the CLOCK that receives it
    - hard not to run into oversampling

    Problems of a 2FF synchronizer:
    - In case where data changes on every SLOW_CLK, how do we know if we have already sampled it in the FAST domain.
    - Not applicable to domain crossing from FAST to SLOW since we might lose signal transitions (receiving domain won't be fast enough, needs some form of acknowledge)
    - I would assume this solution is good for battling metastability on single bit control signals and nothing more.
      - for control signals, seems ideal since it won't allow for metastability
    - On buses it has a problem of different path skews/delays on each bit(different metastability possibility per bit) unless you move to gray codes
      but that is a solution that is applicable only to signals that will change 1 bit at a time when using said gray codes -> COUNTERS for example.
*/

`timescale 1ns/1ps
`include "synchronizer_2ff.sv"

module tb;

    localparam integer CLK_SLOW_PERIOD = 20;
    localparam integer CLK_FAST_PERIOD = 5;
    bit rst_ni;
    bit clk_slow = 1'b0;
    bit clk_fast = 1'b0;
    logic data_send;
    bit data_rec;

    logic val2send;
    logic input_arr [100];
    logic data_valid = 0;

    int delay = 0;
    int i = 0;
    int rec_i = 0;
    logic rec_arr [100];
    logic data_valid_d = 0;

    // CLOCK GENERATION
    always #(CLK_SLOW_PERIOD/2) clk_slow <= ~clk_slow;
    always #(CLK_FAST_PERIOD/2) clk_fast <= ~clk_fast;


    // SEND DATA
    always @(posedge clk_slow or negedge rst_ni) begin
      if (!rst_ni) begin
        data_send = 0;
        data_valid = 0;
      end else begin
        delay = $urandom_range(0, CLK_FAST_PERIOD);
        val2send = $urandom_range(0,1);
        input_arr[i] = val2send;
        $display("%0t ns: Current Delay %0d; Data2Send %0l",
                 $time, delay, val2send);
        #(delay) data_send = val2send;
        data_valid = 1'b1;
        #(CLK_FAST_PERIOD*1.25) data_valid = 1'b0;
        i = i + 1'b1;
      end
    end

    // RECEIVE DATA
    logic cnt_en = 0;
    logic [1:0] cnt = 2'b00;
    always @(posedge clk_fast or negedge rst_ni) begin
      if (!rst_ni) begin
        for (int k=0; k < 100; k =  k + 1 )begin
          rec_arr[k] = 0;
        end
        data_valid_d <= 0;
      end else begin
        data_valid_d <= data_valid;

        if (cnt_en == 1'b0 && data_valid & !data_valid_d) begin
          cnt_en <= 1'b1;
        end
        else begin
          if (cnt_en) begin
            cnt <= cnt + 1'b1;
            if (cnt == 2'b10) begin
              $display("%0t ns: DataRec %0l", $time, data_rec);
              rec_arr[rec_i] <= data_rec;
              rec_i          <= rec_i + 1'b1;
              cnt_en <= 1'b0;
              cnt    <= 2'b00;
            end
          end
        end
      end
    end

    // START & FINISH
    initial begin
      $dumpvars(0, tb);
      rst_ni = 1'b0;
      #200 rst_ni = 1'b1;
      while (i < 100) #300;
      $display("SIM FINISH....");
      $display("I = %0d; REC_I = %0d", i, rec_i);
      for (int j = 0; j < 100; j = j + 1) begin
        if (input_arr[j] != rec_arr[j]) begin
          $error("Found a mismatch!");
          $display("%0d: %0d <-> %0d", j, input_arr[j], rec_arr[j]);
          $finish(1);
        end
      end
      $display("Every value has matched!");
      $finish(0);
    end


    synchronizer_2ff #(
      .DATA_WIDTH(1)
    ) sync (
      .clk_i(clk_fast),
      .rst_ni(rst_ni),
      .data_i(data_send),
      .data_sync_o(data_rec)
    );

endmodule
