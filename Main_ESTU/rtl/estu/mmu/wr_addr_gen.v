`timescale 1ns / 1ps

module wr_addr_gen #(
    parameter DIM_MAX_LOGIC_ADDRESS = 10,
    parameter DIM_MAX_MEM = 14,
    parameter VCOMP_K_Q = 800,
    parameter DIM_MODE = 5,
    parameter DIM_BRAM = 12,
    parameter DIM_SPRAM = 14,
    parameter DIM_TIMESTEP = 8,
    parameter DIM_OFFSET = 6
)(
    input clk, rst, clr,
    input wr_en,
    input [DIM_MODE - 1:0] mode,
    input [DIM_MAX_MEM-1 : 0] wr_baddr1, wr_baddr2, // From IM
    input v_gen_id, k_gen_id, // From IM. Flag to indicate that the stack is used in the V-generation stage or K-generation stage
    input valid_op,
    input [DIM_OFFSET-1:0] offset_v_ext,
    input matmul_ss_id, // Signal that indicates the matmul operation
    input use_v, // Signal that indicates the use of V in the matmul operation
    input end_inference,
    // Outputs
    output [DIM_MAX_LOGIC_ADDRESS-1:0] logic_addr,
    output [DIM_BRAM-1:0] dest_addr_bram1,
    output [DIM_BRAM-1:0] dest_addr_bram2,
    output [DIM_SPRAM-1:0] dest_addr_spram1,
    output [DIM_SPRAM-1:0] dest_addr_spram2,
    output [DIM_TIMESTEP-1:0] timestep,
    output [DIM_MAX_LOGIC_ADDRESS-1:0] k_ptr, 
    output reg [DIM_MAX_LOGIC_ADDRESS - 1 : 0] v_ptr,
    output [1:0] sel_data_int,
    output reg [DIM_MAX_LOGIC_ADDRESS-1:0] gen_cnt,
    output offset_mm_si
);

    // General Counter
    // It is used for the generation of the logic address for all the operations that doesn't concerne K and V generation
    
    wire en_gen_cnt;
    always @(posedge clk) begin
        if (clr | rst)
            gen_cnt <= 0;
        else if (valid_op)
            gen_cnt <= 0;
        else if (en_gen_cnt)
            gen_cnt <= gen_cnt + 1;
    end 
    reg [1:0] cnt_mm_ss;
    wire [2:0] cnt_mm_ss_nxt;
    wire valid_cnt_mm_ss;
    always @(posedge clk) begin
        if (rst|valid_op|valid_cnt_mm_ss) begin
            cnt_mm_ss <= 0;
        end
        else if (wr_en) begin
            cnt_mm_ss <= cnt_mm_ss_nxt;
        end
    end
    assign valid_cnt_mm_ss = (cnt_mm_ss_nxt == 4) & wr_en;
    assign cnt_mm_ss_nxt = cnt_mm_ss + 1;
    assign en_gen_cnt = matmul_ss_id ? valid_cnt_mm_ss : wr_en;
    assign sel_data_int = cnt_mm_ss;
    
    // K and V pointers generation
    wire [DIM_MAX_LOGIC_ADDRESS - 1 : 0] v_ptr_nxt;
    wire en_k, en_v;
    wire clr_ptrs, comp_out_v;
    assign en_k = k_gen_id&wr_en;
    assign en_v = v_gen_id&valid_op;
    // k pointer
    reg [DIM_MAX_LOGIC_ADDRESS - 1 : 0] k_ptr0, k_ptr1, k_ptr2, k_ptr3;
    reg [1:0] k_ptr_sel;
    always @(posedge clk) begin
        if (rst) 
            k_ptr_sel <= 0;
        else if (k_gen_id & valid_op) begin
            k_ptr_sel <= k_ptr_sel + 1;
        end
    end
    always @(posedge clk) begin
        if (clr_ptrs | rst) begin
            k_ptr0 <= 0;
            k_ptr1 <= 0;
            k_ptr2 <= 0;
            k_ptr3 <= 0;
        end
        else if (en_k) begin
            case (k_ptr_sel)
                2'b00: k_ptr0 <= k_ptr0 + 1;
                2'b01: k_ptr1 <= k_ptr1 + 1;
                2'b10: k_ptr2 <= k_ptr2 + 1;
                2'b11: k_ptr3 <= k_ptr3 + 1;
            endcase
        end
    end
    assign k_ptr = (k_ptr_sel == 2'b00) ? k_ptr0 :
                  (k_ptr_sel == 2'b01) ? k_ptr1 :
                  (k_ptr_sel == 2'b10) ? k_ptr2 : k_ptr3;
    // v pointer
    always @(posedge clk) begin
        if (clr_ptrs | rst) begin
            v_ptr <= 0;
        end
        else if (en_v) begin
            v_ptr <= v_ptr_nxt;
        end
    end
    // Next pointers logic
    assign v_ptr_nxt = v_ptr + 1;
    // Clear of the pointers
    assign comp_out_v = v_ptr == VCOMP_K_Q;
    assign clr_ptrs = end_inference;
    // V specific generation
    assign timestep = v_ptr>>2;
    wire [DIM_MAX_LOGIC_ADDRESS - 1 : 0] v_ptr2;
    reg [DIM_MAX_LOGIC_ADDRESS - 1 : 0] offset_v;
    always @(posedge clk) begin
        if (clr | rst) begin
            offset_v <= 0;
        end
        else if (wr_en & v_gen_id) begin
            offset_v <= offset_v + offset_v_ext;
        end
    end
    assign v_ptr2 = offset_v + (timestep>>2);

    // Offset use_v logic address
    reg [4:0] offset_logic_addr_use_v;
    wire clr_offset_use_v_la;

    always @(posedge clk) begin
        if (rst | clr_offset_use_v_la) begin
            offset_logic_addr_use_v <= 0;
        end
        else if (valid_op & use_v) begin
            offset_logic_addr_use_v <= offset_logic_addr_use_v + 4; // Magic number!
        end
    end
    assign offset_mm_si =(offset_logic_addr_use_v == 16); // Magic number!
    assign clr_offset_use_v_la = offset_mm_si&valid_op; // Magic number!
    
    // Physical address generation and logic address routing
    // The underlying combinational logic is valid only if a correct programming of the v_gen_id and k_gen_id signals is done
    // These two signals must be high with mutual exclusion. When they are both low the logic address is used.
    assign logic_addr = (v_gen_id) ? v_ptr2 : (k_gen_id) ? k_ptr : (use_v ? gen_cnt + offset_logic_addr_use_v : gen_cnt);
    wire [DIM_MAX_MEM-1:0] phy_addr1, phy_addr2;
    assign phy_addr1 = wr_baddr1 + logic_addr;
    assign phy_addr2 = wr_baddr2 + logic_addr;
    // Output address asssignment
    assign dest_addr_bram1 = phy_addr1[DIM_BRAM-1 -: DIM_BRAM];
    assign dest_addr_bram2 = phy_addr2[DIM_BRAM-1 -: DIM_BRAM];
    assign dest_addr_spram1 = phy_addr1[DIM_SPRAM-1 -: DIM_SPRAM];
    assign dest_addr_spram2 = phy_addr2[DIM_SPRAM-1 -: DIM_SPRAM];

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