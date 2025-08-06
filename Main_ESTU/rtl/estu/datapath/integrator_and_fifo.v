`timescale 1ns / 1ps

module integrator_and_fifo #(
    parameter DEPTH = 589, 
    parameter WIDTH = 25)
    (
    input clk, rst, rst_fifo, en, detection, en_d,
    input block_rd_cnt_lif,
    input [13:0] decay,
    input [WIDTH-1:0] stimolo, // synaptic current
    input [WIDTH-1:0] threshold,
    
    output valid,
    output spike,
    output [WIDTH-1:0] output_new
	`ifdef CONFIGURABILITY
		,input clear_counter
	`endif
    );
    
    wire [WIDTH-1:0] output_old;
    localparam PIPE_BLOCK = 5;
    reg [PIPE_BLOCK -1:0] block_wr_cnt_lif;
    integer i;
    always @(posedge clk) begin
        if (rst) begin
            block_wr_cnt_lif <= 0;
        end
        else  begin
            block_wr_cnt_lif[0] <= block_rd_cnt_lif;
            for (i = 1; i < PIPE_BLOCK; i = i + 1) begin
                block_wr_cnt_lif[i] <= block_wr_cnt_lif[i-1];
            end
        end
    end
    // FIFO
    bram_fifo #( .DATA_WIDTH(WIDTH), .DEPTH(DEPTH) ) fifo_i (.clk(clk),.rst(rst_fifo),.DI(output_new[WIDTH-1:0]),.rden(en&block_rd_cnt_lif),.wren(block_wr_cnt_lif[PIPE_BLOCK-1] & valid & ~rst),.DO(output_old) `ifdef CONFIGURABILITY , .clear_counter(clear_counter) `endif); 
    // wait fifo output
    reg [WIDTH-1:0] stimolo_d;
    always @(posedge clk)
        if (rst) begin
            stimolo_d <= 0;
         end
        else begin 
            if(en)
                stimolo_d <= stimolo;
        end
    // INTEGRATOR
    integrator3 #(.WIDTH(WIDTH)) integrator_i (clk, rst, en_d, detection, output_old, decay, stimolo_d, threshold, valid, spike, output_new);
    
    ////////////////////////////
    //  _               ____  //
    // | | ___   __ _  |___ \ //
    // | |/ _ \ / _` |   __)  //
    // | | (_) | (_| |  / __/ //
    // |_|\___/ \__, | |_____ //
    //          |___/         //
    ////////////////////////////
    
    //  The following function calculates the address width based on specified RAM depth
    function integer clogb2;
    input integer depth;
        for (clogb2=0; depth>0; clogb2=clogb2+1)
        depth = depth >> 1;
    endfunction       

    endmodule

