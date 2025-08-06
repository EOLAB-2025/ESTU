`timescale 1ns / 1ps

module spike_mem #(
    parameter RAM_WIDTH = 4,                         // Specify RAM data width
    parameter RAM_DEPTH = 160,                        // Specify RAM depth (number of entries)
    parameter RAM_PERFORMANCE = "LOW_LATENCY",   // Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
    parameter INIT_FILE1 = "",                          // Specify name/location of RAM initialization file if using one (leave blank if not)
    parameter INIT_FILE2 = "",                          // Specify name/location of RAM initialization file if using one (leave blank if not)
    parameter INIT_FILE3 = "",                          // Specify name/location of RAM initialization file if using one (leave blank if not)
    parameter INIT_FILE4 = "",                          // Specify name/location of RAM initialization file if using one (leave blank if not)
    parameter NUM_MEMS = 4,                              // Specify the number of logic BRAMs used in parallel. In our case are 4 
    parameter ADDR_WIDTH =clogb2(RAM_DEPTH)
)(
    input clk, rst, 
    input en_port_wr, wr_en_ext,
    input en_port_rd, rd_en,
    input [ADDR_WIDTH-1:0] wr_addr, rd_addr,
    input [RAM_WIDTH-1:0] data_in,
    output reg [RAM_WIDTH-1:0] dout_port4,
    output [4*RAM_WIDTH-1:0] dout_port16
);

wire wr_en [NUM_MEMS-1:0];
wire [RAM_WIDTH-1:0] dout [NUM_MEMS-1:0];
reg [1:0] rd_addr_sel_reg [1:0];

assign wr_en[0] = (~wr_addr[0] & ~wr_addr[1]) & wr_en_ext;  
assign wr_en[1] = (wr_addr[0] & ~wr_addr[1]) & wr_en_ext;
assign wr_en[2] = (~wr_addr[0] & wr_addr[1]) & wr_en_ext;
assign wr_en[3] = (wr_addr[0] & wr_addr[1]) &  wr_en_ext;

BRAM_singlePort_readFirst
    #(
    .RAM_WIDTH(RAM_WIDTH), // Specify RAM data width
    .RAM_DEPTH(RAM_DEPTH), // Specify RAM depth (number of entries)
    .RAM_PERFORMANCE(RAM_PERFORMANCE), // Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
    .INIT_FILE(INIT_FILE1) // Specify name/location of RAM initialization file if using one (leave blank if not)
    )
    BRAM_1_SPIKEMEM_inst
    (
        .addra(wr_addr[ADDR_WIDTH-1:2]), // Port A address bus, driven by axi bus.   l'indirizzo della voce in scrittura
        .addrb(rd_addr[ADDR_WIDTH-1:2]), // Port B address bus, it goes in the accumulator.   l'indirizzo della voce in lettura.
        .dina(data_in), // Port A RAM input data, driven by axi bus. Sono i dati in ingresso nella bram
        .clk(clk), // Clock
        .wea(wr_en[0]), // Port A write enable
        .ena(en_port_wr), // Port A RAM Enable, for additional power savings, disable port when not in use
        .enb(en_port_rd&rd_en), // Port B RAM Enable, for additional power savings, disable port when not in use
        .rst(rst), // Port A and B output reset (does not affect memory contents)
        .regceb(1'b1), // Port B output register enable
        .doutb(dout[0]) // Port B RAM output data
    ); 

BRAM_singlePort_readFirst
    #(
    .RAM_WIDTH(RAM_WIDTH), // Specify RAM data width
    .RAM_DEPTH(RAM_DEPTH), // Specify RAM depth (number of entries)
    .RAM_PERFORMANCE(RAM_PERFORMANCE), // Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
    .INIT_FILE(INIT_FILE2) // Specify name/location of RAM initialization file if using one (leave blank if not)
    )
    BRAM_2_SPIKEMEM_inst
    (
        .addra(wr_addr[ADDR_WIDTH-1:2]), // Port A address bus, driven by axi bus.   l'indirizzo della voce in scrittura
        .addrb(rd_addr[ADDR_WIDTH-1:2]), // Port B address bus, it goes in the accumulator.   l'indirizzo della voce in lettura.
        .dina(data_in), // Port A RAM input data, driven by axi bus. Sono i dati in ingresso nella bram
        .clk(clk), // Clock
        .wea(wr_en[1]), // Port A write enable
        .ena(en_port_wr), // Port A RAM Enable, for additional power savings, disable port when not in use
        .enb(en_port_rd&rd_en), // Port B RAM Enable, for additional power savings, disable port when not in use
        .rst(rst), // Port A and B output reset (does not affect memory contents)
        .regceb(1'b1), // Port B output register enable
        .doutb(dout[1]) // Port B RAM output data
    ); 

BRAM_singlePort_readFirst
    #(
    .RAM_WIDTH(RAM_WIDTH), // Specify RAM data width
    .RAM_DEPTH(RAM_DEPTH), // Specify RAM depth (number of entries)
    .RAM_PERFORMANCE(RAM_PERFORMANCE), // Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
    .INIT_FILE(INIT_FILE3) // Specify name/location of RAM initialization file if using one (leave blank if not)
    )
    BRAM_3_SPIKEMEM_inst
    (
        .addra(wr_addr[ADDR_WIDTH-1:2]), // Port A address bus, driven by axi bus.   l'indirizzo della voce in scrittura
        .addrb(rd_addr[ADDR_WIDTH-1:2]), // Port B address bus, it goes in the accumulator.   l'indirizzo della voce in lettura.
        .dina(data_in), // Port A RAM input data, driven by axi bus. Sono i dati in ingresso nella bram
        .clk(clk), // Clock
        .wea(wr_en[2]), // Port A write enable
        .ena(en_port_wr), // Port A RAM Enable, for additional power savings, disable port when not in use
        .enb(en_port_rd&rd_en), // Port B RAM Enable, for additional power savings, disable port when not in use
        .rst(rst), // Port A and B output reset (does not affect memory contents)
        .regceb(1'b1), // Port B output register enable
        .doutb(dout[2]) // Port B RAM output data
    ); 

BRAM_singlePort_readFirst
    #(
    .RAM_WIDTH(RAM_WIDTH), // Specify RAM data width
    .RAM_DEPTH(RAM_DEPTH), // Specify RAM depth (number of entries)
    .RAM_PERFORMANCE(RAM_PERFORMANCE), // Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
    .INIT_FILE(INIT_FILE4) // Specify name/location of RAM initialization file if using one (leave blank if not)
    )
    BRAM_4_SPIKEMEM_inst
    (
        .addra(wr_addr[ADDR_WIDTH-1:2]), // Port A address bus, driven by axi bus.   l'indirizzo della voce in scrittura
        .addrb(rd_addr[ADDR_WIDTH-1:2]), // Port B address bus, it goes in the accumulator.   l'indirizzo della voce in lettura.
        .dina(data_in), // Port A RAM input data, driven by axi bus. Sono i dati in ingresso nella bram
        .clk(clk), // Clock
        .wea(wr_en[3]), // Port A write enable
        .ena(en_port_wr), // Port A RAM Enable, for additional power savings, disable port when not in use
        .enb(en_port_rd&rd_en), // Port B RAM Enable, for additional power savings, disable port when not in use
        .rst(rst), // Port A and B output reset (does not affect memory contents)
        .regceb(1'b1), // Port B output register enable
        .doutb(dout[3]) // Port B RAM output data
    ); 

always @(posedge clk) begin
    if (rst) begin
        rd_addr_sel_reg[0] <= 2'b00;
        rd_addr_sel_reg[1] <= 2'b00;
    end else begin
        rd_addr_sel_reg[0] <= rd_addr[1:0];
        rd_addr_sel_reg[1] <= rd_addr_sel_reg[0]; // Used only in case of BRAM with 2 clock delays
    end
end

always @(*) begin
    case (rd_addr_sel_reg[1]) 
        2'b00: dout_port4 = dout[0];
        2'b01: dout_port4 = dout[1];
        2'b10: dout_port4 = dout[2];
        2'b11: dout_port4 = dout[3];
    endcase
end

assign dout_port16 = {dout[0], dout[1], dout[2], dout[3]};

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
