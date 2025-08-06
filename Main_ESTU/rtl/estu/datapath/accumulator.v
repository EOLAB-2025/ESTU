`timescale 1ns / 1ps


// This code implements a parameterizable subtractor followed by multiplier which will be packed into DSP Block
//(* use_dsp = "yes" *)
module accumulator
#(
    parameter SIZEIN = 16  // Size of inputs
)
(
input clk, // Clock
input ce1,ce2,ce3,  // Clock enable
input rst, // Reset
input clear_and_go, clear, // to reset the accumulator
input signed [SIZEIN-1:0] a,  // 1st Input to pre-subtractor
input signed [SIZEIN-1:0] b,  // 2nd input to pre-subtractor
output signed [SIZEIN:0] presubmult_out
);
    


// Declare registers for intermediate values
reg signed [SIZEIN-1:0] a_reg, b_reg; 
reg signed [SIZEIN:0]   add_reg;
reg signed [SIZEIN:0] p_reg;

always @(posedge clk)
 if (rst | clear)
  begin
    a_reg   <= 0;
    b_reg   <= 0;
	  add_reg <= 0;
    p_reg   <= 0;
  end
 else begin
    if (ce1)
      begin
        a_reg   <= a;
        b_reg   <= b;
      end
    if (ce2)
        add_reg <= a_reg + b_reg;
    if (ce3)
        if(clear_and_go)
            p_reg <= add_reg;
        else    
            p_reg   <= p_reg + add_reg;
  end

assign presubmult_out = p_reg;    
    

endmodule