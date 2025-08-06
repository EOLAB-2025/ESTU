`timescale 1ns / 1ps

module cnt#
(
    parameter DIM_ADDR = 12,
    parameter DIM_STEP = 3 // Number of bits to represent the step size
)(
    input clk, rst,
    input clr,      // Clear the counter
    input en,
    input [DIM_ADDR-1:0] target,
    input [DIM_STEP-1:0] step, // Step size for the counter
    input mm_ss,
    output valid,
    output reg [DIM_ADDR-1:0] cnt
);

wire [DIM_ADDR:0] cnt_nxt;
always @(posedge clk) begin
    if (rst | clr)
        cnt <= 0;   
    else if (en)
        cnt <= cnt_nxt;     
end

assign cnt_nxt = cnt + step;
assign valid = mm_ss ? ((cnt_nxt>>2)==target) : (cnt_nxt == target);

endmodule