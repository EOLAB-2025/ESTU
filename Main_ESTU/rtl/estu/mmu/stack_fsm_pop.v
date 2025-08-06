`timescale 1ns / 1ps

module stack_fsm_pop(
    input clk, rst, stream_out, done, last_op, use_v, valid_data,
    output reg r_en, load, valid_addr_stack
    );
    localparam IDLE = 3'b000,  
           READ_AE = 3'b001,  
           SAVE_AE = 3'b010, 
           LOAD_AE = 3'b011, 
           POP_STACK = 3'b100,
           WAIT_V = 3'b101;

    reg [2:0] state, state_nxt;

    always @(posedge clk)
        if (rst) state <=IDLE;
        else state<=state_nxt;
    
    always @(*)
        case (state)
        IDLE: begin
            if (stream_out)
                state_nxt = READ_AE;
            else 
                state_nxt = IDLE;
        end
        READ_AE:begin
            if (last_op)
                state_nxt = IDLE;
            else
                state_nxt = SAVE_AE;
        end
        SAVE_AE: begin
            if (last_op)
                state_nxt = IDLE;
            else
                state_nxt = LOAD_AE;
        end
        LOAD_AE: begin
            if (last_op)
                state_nxt = IDLE;
            else
                state_nxt = POP_STACK;
        end
        POP_STACK: begin
            if (last_op)
                state_nxt = IDLE;
            else if (done & ~last_op & use_v)
                state_nxt = WAIT_V;
            else if (done & ~last_op & ~use_v)
                state_nxt = LOAD_AE;
            else
                state_nxt = POP_STACK;
        end 
        WAIT_V: begin
            if (valid_data)
                state_nxt = READ_AE;
            else if (last_op)
                state_nxt = IDLE;
            else
                state_nxt = WAIT_V;
        end
        default: state_nxt = IDLE;
        endcase
        
    always @(*) begin
        {r_en, load, valid_addr_stack} = 3'b000; // evita latch

        case (state)
            IDLE:       {r_en, load, valid_addr_stack} = 3'b000;
            READ_AE:    {r_en, load, valid_addr_stack} = 3'b100;
            SAVE_AE:    {r_en, load, valid_addr_stack} = 3'b010;
            LOAD_AE:    {r_en, load, valid_addr_stack} = 3'b100;
            POP_STACK:  {r_en, load, valid_addr_stack} = 3'b101;
            WAIT_V:     {r_en, load, valid_addr_stack} = 3'b000;
        endcase
    end

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