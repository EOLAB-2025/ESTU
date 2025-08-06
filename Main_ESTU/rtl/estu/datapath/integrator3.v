`timescale 1ns / 1ps
/*
 This module implements the neuron jelly integrator.
*/
module integrator3 #(parameter WIDTH = 20)(
    input clk, rst, en, detection,
    input signed [WIDTH-1:0] output_old,
    input [13:0] decay,
    input [WIDTH-1:0] stimolo,
    input [WIDTH-1:0] threshold,
    
    output valid,
    output spike,
    output [WIDTH-1:0] output_new
);

    localparam P_SIZE = WIDTH + 13;

    reg signed [WIDTH-1:0] r_threshold [3:0];
    reg [3:0] en_shift;
    reg signed [WIDTH-1:0] comparator_in;

    // Pipeline
    integer i;
    // Shift register enable
    always @(posedge clk) begin 
        if (rst) 
            en_shift <= 0;
        else begin
            en_shift[0] <= en;
            en_shift[1] <= en_shift[0];
            en_shift[2] <= en_shift[1];
            en_shift[3] <= en_shift[2];
        end
    end

reg signed [13:0] decay_int_r0, decay_int_r1;
always @(posedge clk) begin
    if (rst)
        decay_int_r0 <= 0;
    else 
        decay_int_r0 <= decay; 
end

reg signed [WIDTH-1 : 0] output_old_r0;
reg signed [P_SIZE-1 :0] output_old_shifted_r1;

always @(posedge clk) begin
    if (rst) 
        output_old_r0 <= 0;
    else 
        output_old_r0 <= output_old;
end

always @(posedge clk) begin
    if (rst) 
        output_old_shifted_r1 <= 0;
    else if (en_shift[0]) begin
        output_old_shifted_r1 <= output_old_r0<<12; 
    end
end


(* use_dsp = "yes" *) reg signed [P_SIZE-1:0] output_old_decay_r1;
always @(posedge clk) begin
    if (rst) begin
        output_old_decay_r1 <= 0;
    end
    else if (en_shift[0])
        output_old_decay_r1 <= output_old_r0*decay_int_r0;
end

(* use_dsp = "yes" *) reg signed [P_SIZE-1:0] current_r1;
reg signed [WIDTH-1:0] stimolo_r0;
always @(posedge clk) begin
    if (rst)
        stimolo_r0 <= 0;
    else
        stimolo_r0 <= stimolo;
end

always @(posedge clk) begin
    if (rst) begin
        current_r1 <= 0;
    end
    else if (en_shift[0]) begin
        current_r1 <= (stimolo_r0 * decay_int_r0)<<6; 
    end
end

reg [P_SIZE-1:0] supporto_1, supporto_2;
wire signed [P_SIZE-1:0] p;
assign p = current_r1  - output_old_decay_r1 + output_old_shifted_r1;
reg signed [WIDTH-1:0] p_shift; // Valid at stage3


always @(posedge clk) begin
    if (rst) begin
        p_shift <= 0;
        supporto_1 <= 0;
        supporto_2 <= 0;
    end
    else if (en_shift[1]) begin
        if(p[P_SIZE-1]) begin :p_negativo
            supporto_1 = ~p+1'b1;  // Complemento a 1, contiene il valore positivo di "p", equivale a moltiplicare per -1        
            supporto_2 = supporto_1[P_SIZE-1:12]; // Versione con i primi 12 bit di supporto_1 "tagliati"
            p_shift <= ~supporto_2+1'b1; // Riconversione in complemento a 2
        end
        else 
            p_shift <= p[P_SIZE-1:12]; // Versione con i primi 12 bit di p "tagliati"
    end
end

always @(posedge clk) begin
    if (rst)
        comparator_in <= 0;
    else if (en_shift[2]) 
        comparator_in <= p_shift; // Valid at stage 4
end


    // Threshold in a 4 stage pipeline
    always @(posedge clk) begin
        if(rst) begin
            for(i=0;i<4;i=i+1)
                r_threshold[i] <= 0;     
        end 
        else begin
            r_threshold[0] <= threshold;
            r_threshold[1] <= r_threshold[0];
            r_threshold[2] <= r_threshold[1];
            r_threshold[3] <= r_threshold[2];
        end
    end


    assign spike = (comparator_in >= r_threshold[3]) & detection? 1'b1 : 1'b0; 
    assign output_new = spike ? 0 : comparator_in;
    assign valid = en_shift[3];
endmodule