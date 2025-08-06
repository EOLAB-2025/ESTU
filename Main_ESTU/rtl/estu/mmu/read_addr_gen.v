`timescale 1ns / 1ps

/*
Desription of the module:
We should generate two addresses (the third has only a different base addr.) for the read operation.
*/
module read_addr_gen#(
    parameter DIM_ADDR = 12,
    parameter DIM_INPUT_NEURONS = 5,
    parameter DIM_OUTPUT_NEURONS = 8,
    parameter DIM_MAX_LOGIC_ADDRESS = 8, // For instance if we count from 0 to 200 maximum, it must be less the DIM_ADDR
    parameter DIM_MODE = 5
)(
    input clk, 
    input rst,
    input clr,
    input [DIM_MODE-1:0] mode,                          // From the IM
    input en,                                           // From the IM
    input [DIM_INPUT_NEURONS-1:0] num_input_neurons,    // From the IM
    input [DIM_ADDR-1:0] base_addr1,                    // From the IM
    input [DIM_ADDR-1:0] base_addr2,                    // From the IM
    input use_stack,                                    // From the IM
    input use_v,                                       // From the IM
    input done_stack,
    input [DIM_MAX_LOGIC_ADDRESS-1:0] stack_ptr,
    input signed [DIM_MAX_LOGIC_ADDRESS-1:0] offset_ext,           // From the IM
    input matmul_ss_id,
    output [DIM_ADDR-1:0] out1,
    output [DIM_ADDR-1:0] out2,
    output valid_data
);

    // This counter is used to generate the input addresses for the operatione which the stack is not used (sum(spike,spike) and dense(int,int))
    // In this case the counter must count from 0 to 31.
    // In case of operations that use the stack, the counter is not used. 
    wire valid1, valid2;
    wire [DIM_INPUT_NEURONS-1:0] cnt_out1;
    wire [2:0] step_size;
    assign step_size = matmul_ss_id ? 3'b100 : 3'b001; 
    cnt #(
        .DIM_ADDR(12),
        .DIM_STEP(3) // Step size for the counter
    ) cnt_addr_gen (
        .clk(clk),
        .rst(rst),
        .clr(clr|valid1),
        .en(en),
        .step(step_size),
        .mm_ss(matmul_ss_id),
        .target(num_input_neurons),
        .valid(valid1),
        .cnt(cnt_out1)
    );

    // MUX for the counter control enable
    wire en_cnt_control;
    assign en_cnt_control = use_stack ? done_stack&(use_v ? 1'b1 : en) : valid1&en;

    reg signed [DIM_ADDR-1:0] offset;
    always @(posedge clk) begin
        if (clr|rst)
            offset <= 0;
        else if (en_cnt_control)
            offset <= offset + offset_ext;
    end


    // Counter used in sum(spike,int) operation
    reg en_sum_si;
    reg [DIM_INPUT_NEURONS-1:0] cnt_sum_si;
    wire [DIM_INPUT_NEURONS-1:0] cnt_sum_si_nxt;
    always @(posedge clk) begin
        if (clr | rst)
            en_sum_si <= 0;
        else if (en&mode[4])
            en_sum_si <= ~en_sum_si;
    end
    
    always @(posedge clk) begin
        if (clr | rst)
            cnt_sum_si <= 0;
        else if (en_sum_si)
            cnt_sum_si <= cnt_sum_si_nxt;
    end
    assign cnt_sum_si_nxt = cnt_sum_si + 1;

    wire [DIM_MAX_LOGIC_ADDRESS-1:0] adders_in;
    assign adders_in = use_stack ? stack_ptr : cnt_out1;
    wire [DIM_ADDR-1:0] extended_adders_in;
    assign extended_adders_in = { {(DIM_ADDR-DIM_MAX_LOGIC_ADDRESS){1'b0}}, adders_in };

    assign out1 = matmul_ss_id ? base_addr1 : (base_addr1 + extended_adders_in);
    wire signed [DIM_ADDR:0] out2_mux, out22;
    wire signed [DIM_ADDR:0] offset_extended;
    assign offset_extended = { {1{offset[DIM_ADDR-1]}}, offset };
    assign out2_mux = mode[4] ? cnt_sum_si : extended_adders_in;
    assign out22 = {1'b0, base_addr2} + out2_mux + offset_extended;
    assign out2 = out22[DIM_ADDR-1:0];

    assign valid_data = use_stack ? done_stack : valid1;
    
endmodule