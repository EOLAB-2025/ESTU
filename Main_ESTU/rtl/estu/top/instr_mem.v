`timescale 1ns / 1ps

module instr_mem #(
    parameter INSTR_MEM_WIDTH = 32,
    parameter TOT_NUM_INSTR   = 30,
    parameter DIM_INSTR       = 176,
    parameter NUM_INSTR       = (DIM_INSTR >> 5) + 1, // Esempio di definizione, modifica se necessario
    parameter INSTR_MEM_DEPTH = NUM_INSTR * TOT_NUM_INSTR,
    parameter INIT_INSTR_MEM  = "",
    parameter DIM_ADDR_INSTR = clogb2(INSTR_MEM_DEPTH-1) // Used to size the program counter
)(
    input  wire                  clk,
    input  wire                  rst,
    input  wire                  clr,
    input  wire                  clr_pc,
    input  wire                  fetch_instr,   
    input  wire                  en_pc,         
    output reg  [DIM_ADDR_INSTR-1:0] pc,            
    output wire                  valid_instr,   
    output [DIM_INSTR-1:0] instruction_out_full
);
    // Internal signals and registers
    localparam DEPTH_ADDR_OFFSET = clogb2(NUM_INSTR-1);
    reg  [DEPTH_ADDR_OFFSET-1 : 0] instr_addr_offset;
    reg [NUM_INSTR-1:0] en_shift_fetch_instr;
    wire [DIM_ADDR_INSTR - 1 :0] instr_addr;
    wire en_offset_instr;
    wire [DIM_ADDR_INSTR-1:0] pc_nxt;       
    wire                  ren_instr;  
    reg  [INSTR_MEM_WIDTH-1:0] instruction_out_partial [NUM_INSTR-1:0];
    wire [INSTR_MEM_WIDTH-1:0] instruction_out;

    integer i;
    // PC
    always @(posedge clk) begin
        if (rst || clr_pc)
            pc <= 0;
        else if (en_pc)
                pc <= pc_nxt;
    end
    assign pc_nxt = pc + 6; // MAGIC NUMBER 6!

    // Fetch enable fetch shift register 
    always @(posedge clk) begin
        if (rst | clr) begin
            for (i = 0; i < NUM_INSTR; i=i+1)
                en_shift_fetch_instr[i] <= 1'b0;
        end 
        else begin
            en_shift_fetch_instr[0] <= fetch_instr;
            for (i = 1; i < NUM_INSTR; i=i+1) begin
                en_shift_fetch_instr[i] <= en_shift_fetch_instr[i-1];
            end
        end
    end

    assign en_offset_instr = |en_shift_fetch_instr[3 : 0] | fetch_instr; 
    always @(posedge clk) begin
        if (rst || clr)
            instr_addr_offset <= 0;
        else if (en_offset_instr)
            instr_addr_offset <= instr_addr_offset + 1'b1;
    end

    assign instr_addr = instr_addr_offset + pc;


    assign ren_instr   = en_shift_fetch_instr[NUM_INSTR-2] | en_offset_instr;
    assign valid_instr = en_shift_fetch_instr[NUM_INSTR-1];

    always @(posedge clk) begin
        if (rst || clr) begin
            for (i = 0; i < NUM_INSTR; i=i+1)
                instruction_out_partial[i] <= {INSTR_MEM_WIDTH{1'b0}};
            end 
        else begin
            for (i = 0; i < NUM_INSTR; i=i+1) begin
                if (en_shift_fetch_instr[i]) begin
                    instruction_out_partial[i] <= instruction_out;
                end
            end
        end
    end

  
    BRAM_singlePort_readFirst #(
        .RAM_WIDTH       (INSTR_MEM_WIDTH),
        .RAM_DEPTH       (INSTR_MEM_DEPTH),
        .RAM_PERFORMANCE ("LOW_LATENCY"),
        .INIT_FILE       (INIT_INSTR_MEM)
    ) instr_mem_inst (
        .addra  (),         
        .addrb  (instr_addr),
        .dina   (),
        .clk    (clk),
        .wea    (1'b0),
        .ena    (1'b0),
        .enb    (ren_instr),
        .rst    (rst),
        .regceb (1'b1),
        .doutb  (instruction_out)
    );

    assign instruction_out_full = {
    instruction_out_partial[0],
    instruction_out_partial[NUM_INSTR-5],
    instruction_out_partial[NUM_INSTR-4],
    instruction_out_partial[NUM_INSTR-3],
    instruction_out_partial[NUM_INSTR-2],
    instruction_out_partial[NUM_INSTR-1][INSTR_MEM_WIDTH-1 : 23]
};
    
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