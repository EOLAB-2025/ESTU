`timescale 1ns / 1ps

module s2p #(parameter P = 2)(
    input clk, rst, en, spike_s,
    output reg [P-1:0] spike_p,
    output reg valid
    );
    
    // clear logic
    wire end_cnt;
    always @(posedge clk)
        if (rst)
            valid <= 0;
        else 
            valid <= end_cnt;
     
    reg [clogb2(P-1)-1:0] cnt;
    always @(posedge clk)
        if (rst)
            cnt <= 0;
        else if(en)
            cnt <= cnt + 1'b1;
            
     assign end_cnt = (cnt == P-1) & en;
    
    
    // Serial 2 Parallel
	integer i;
    always @(posedge clk)
        if (rst)
            spike_p <= 0;
        else if(en) begin
            spike_p[0] <= spike_s;
            for(i=1;i<P;i=i+1)
				spike_p[i] <= spike_p[i-1];
            end
                else if(valid)
                    spike_p <= 0;


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
