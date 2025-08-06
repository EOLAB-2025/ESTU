`timescale 1ns / 1ps

module neuron_lp#(
    parameter DEPTH = 717,  // FIFO depth 
    parameter WIDTH = 23,   // Data width
    parameter WEIGHT = 7,   // Weight width 
    parameter LAYERS = 4    // Number of layers: we have exactly 11 layers
    )
    (
    // ------------------------ Sync and global input signals ----------------------
    input clk, rst, rst_fifo,
    input en, en_d,
    //--------------------- LIF Input Values ------------------------------------------
    //First layer: emmbedding
    input [13:0] voltage_decay, 
    input [WIDTH-1:0] threshold, 
    input block_rd_cnt_lif,
    // TO COMPLETE...
    // ----------------------------------------------------
    input [WIDTH-1:0] synaptic_current, 
    // --------------------- Uscite ----------------------------------------------------------
    output valid,
    output [1:0] spike_p, // Spike in parallelo
    output voltage_ready,
    output [WIDTH-1:0] voltage,
    output spike_s
    );

integrator_and_fifo #(.DEPTH(DEPTH), .WIDTH(WIDTH)) Voltage_i (clk, rst, rst_fifo, en, 1'b1, en_d, block_rd_cnt_lif, voltage_decay,synaptic_current,threshold,voltage_ready,spike_s,voltage `ifdef CONFIGURABILITY , clear_counter `endif);   
s2p #(2) s2p_i (clk, rst, voltage_ready, spike_s, spike_p, valid);    
   
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
