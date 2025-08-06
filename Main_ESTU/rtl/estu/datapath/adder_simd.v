`timescale 1ns / 1ps


// This module describes SIMD Inference 
// 4 small adders can be packed into signle DSP block

// Apply this attribute on the module definition
//(* use_dsp = "simd" *)
module adder_simd
    #(
    parameter N = 2,    // Number of Adders
    parameter W = 15   // Width of the Adders
    )
    (
    input clk, en, clr,
    input [W-1:0] a_0, a_1,
    input [W-1:0] b_0, b_1,
    output reg signed [W:0] out_0,
    output reg signed [W:0] out_1
    );


                   
integer i;
reg signed [W-1:0] a_r [N-1:0];
reg signed [W-1:0] b_r [N-1:0];

always @ (posedge clk)
    if (clr)
        begin
            for (i = 0; i < N; i = i + 1)
            begin
                a_r[i] <= 0;
                b_r[i] <= 0;
                out_0 <= 0;
                out_1 <= 0;
            end
        end
    else if(en)
      begin 
      a_r[0] <= a_0;
      b_r[0] <= b_0;
      out_0 <= a_r[0] + b_r[0];
      a_r[1] <= a_1;
      b_r[1] <= b_1;
      out_1 <= a_r[1] + b_r[1];
      end   

endmodule
