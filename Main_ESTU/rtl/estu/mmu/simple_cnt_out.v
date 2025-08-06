`timescale 1ns / 1ps

module simple_cnt_out #(
    parameter TARGET = 2
)(
    input clk,
    input rst,
    input en,
    output reg [clogb2(TARGET-1)-1:0] cnt
);
    wire end_cnt;
    always @(posedge clk) begin
        if (rst | end_cnt) begin // l'or con end_cnt è inutile se ho potenze di due di target
            cnt <= 0;
        end else if (en) begin
            cnt <= cnt + 1'b1;
        end
    end

    assign end_cnt = (cnt == TARGET-1) & en;

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
