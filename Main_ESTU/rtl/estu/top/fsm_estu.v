`timescale 1ns / 1ps

module fsm_estu (
    input clk, rst,
    input start_inference, use_v, valid_instr, valid_op, last_instr, v_gen_id, valid_data,
    output reg en, clr, fetch_instr, r_en_ext_stack, load_push_stack, valid_inference, clr_pc
);

    localparam  IDLE        = 4'b0000,
                CLR         = 4'b0001,
                FETCH       = 4'b0010,
                WAIT_INSTR  = 4'b0011,
                CHECK_V     = 4'b0100,
                READ_AE     = 4'b0101,
                LOAD_AE     = 4'b0110,
                SAVE_AE     = 4'b0111,
                RUN         = 4'b1000,
                VALID_OP    = 4'b1001;

    reg [3:0] state, state_nxt;

    always @(posedge clk)
        if (rst) state <= IDLE;
        else     state <= state_nxt;

    always @(*)
        case (state)
            IDLE: begin
                if (start_inference) begin
                    state_nxt = CLR;
                end 
                else begin
                    state_nxt = IDLE;
                end
            end
            CLR: begin
                state_nxt = FETCH;
            end
            FETCH: begin
                state_nxt = WAIT_INSTR;
            end
            WAIT_INSTR: begin
                if (valid_instr) begin
                    state_nxt = CHECK_V;
                end 
                else begin
                    state_nxt = WAIT_INSTR;
                end
            end
            CHECK_V: begin
                if (use_v | v_gen_id) begin
                    state_nxt = READ_AE;
                end 
                else begin
                    state_nxt = RUN;
                end
            end
            READ_AE: begin
                state_nxt = LOAD_AE;
            end
            LOAD_AE: begin
                    state_nxt = SAVE_AE;
            end
            SAVE_AE: begin
                state_nxt = RUN;
            end
            RUN: begin
                if (valid_op & last_instr) begin
                    state_nxt = VALID_OP;
                end 
                else if (valid_op & ~last_instr) begin
                    state_nxt = CLR;
                end
                else if (valid_data & (v_gen_id|use_v)) 
                    state_nxt = READ_AE;
                else 
                    state_nxt = RUN;
            end
            VALID_OP: begin
                state_nxt = IDLE;
            end
            default: state_nxt = IDLE;
        endcase

    always@(*) begin
        case (state) 
            IDLE:      {en, clr, fetch_instr, r_en_ext_stack, load_push_stack, valid_inference, clr_pc} = 7'b0000001;
            CLR:       {en, clr, fetch_instr, r_en_ext_stack, load_push_stack, valid_inference, clr_pc} = 7'b0100000;
            FETCH:     {en, clr, fetch_instr, r_en_ext_stack, load_push_stack, valid_inference, clr_pc} = 7'b0010000;
            WAIT_INSTR:{en, clr, fetch_instr, r_en_ext_stack, load_push_stack, valid_inference, clr_pc} = 7'b0000000;
            CHECK_V:   {en, clr, fetch_instr, r_en_ext_stack, load_push_stack, valid_inference, clr_pc} = 7'b0000000;
            READ_AE:   {en, clr, fetch_instr, r_en_ext_stack, load_push_stack, valid_inference, clr_pc} = 7'b0001000;
            LOAD_AE:   {en, clr, fetch_instr, r_en_ext_stack, load_push_stack, valid_inference, clr_pc} = 7'b0000100;
            SAVE_AE:   {en, clr, fetch_instr, r_en_ext_stack, load_push_stack, valid_inference, clr_pc} = 7'b0000000;
            RUN:       {en, clr, fetch_instr, r_en_ext_stack, load_push_stack, valid_inference, clr_pc} = 7'b1000000;
            VALID_OP:  {en, clr, fetch_instr, r_en_ext_stack, load_push_stack, valid_inference, clr_pc} = 7'b0000100;
            default:   {en, clr, fetch_instr, r_en_ext_stack, load_push_stack, valid_inference, clr_pc} = 7'b0000000;
        endcase
    end

endmodule