`timescale 1ns / 1ps

module control_unit #(
    // ---------------------- Spike mem parameters ------------------
    parameter SPIKE_MEM_WIDTH = 4,                         // Spike mem bram width
    parameter SPIKE_MEM_DEPTH = 1024,                      // Specify spike mem depth (number of entries). 1024 because we have maximum 800 + delta entries
    parameter RAM_PERFORMANCE = "HIGH_PERFORMANCE",        // Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
    parameter INIT_FILE_SM1 = "scripts/outputs/inputs_bram1.txt",                          // Specify name/location of RAM initialization file if using one (leave blank if not)
    parameter INIT_FILE_SM2 = "scripts/outputs/inputs_bram2.txt",                          // Specify name/location of RAM initialization file if using one (leave blank if not)
    parameter INIT_FILE_SM3 = "scripts/outputs/inputs_bram3.txt",                          // Specify name/location of RAM initialization file if using one (leave blank if not)
    parameter INIT_FILE_SM4 = "scripts/outputs/inputs_bram4.txt",                          // Specify name/location of RAM initialization file if using one (leave blank if not)
    parameter NUM_MEMS_SPIKE_MEM = 4,                       // Specify the number of logic BRAMs used in parallel for the spike mem. In our case are 4 
    // ---------------------- Spike mem parameters ------------------
    
    // ---------------------- Int mem parameters ------------------
    parameter DEPTH_INT_MEM = 1024, // Specify int mem depth (number of entries). 1024 because we have maximum 800 + delta entries
    parameter INIT_FILE_INTMEM1 = "scripts/outputs/INTMEM1.txt", // Specify name/location of RAM initialization file if using one (leave blank if not)
    parameter INIT_FILE_INTMEM2 = "scripts/outputs/INTMEM2.txt",
    // ----------------------- Int mem parameters ------------------

    // ---------------------- MMU parameters ------------------
    parameter DIM_ADDR_SPIKE_MEM = 12,
    parameter DIM_ADDR_SPRAM = 14,
    parameter DIM_MAX_MEM = 14,// Maximum number of entries in the memory, is the maximum value between DIM_ADDR_SPIKE_MEM and DIM_ADDR_SPRAM
    parameter DIM_INPUT_NEURONS = 6, // Used for the counter cnt_addr_gen and need to count from 0 to 31.
    parameter DIM_OUTPUT_NEURONS = 10, // Used for the counter cnt_control and need to count from 0 to 799.
    parameter DIM_MAX_LOGIC_ADDRESS = 10, // Size of the stack entries. The stack need to store the logic addresses that is maximum 10 bits
    parameter DEPTH_STACK = 3468, // Maximum number of entries in the stack 3200 for the 4 heads of V and 128 for each stack frame used (e.g. used in Dense(spike,int) layers)
    parameter INIT_STACK = "scripts/stack_init.txt", // Specify name/location of stack initialization file if using one 
    parameter DATA_WIDTH = 8, // Size of the entries in the SPRAM
    parameter V_COMP_K_Q = 800, // Refers to the number of entries needed to store a single head of Q and K (supposed to be of equal dimension)
    parameter WIDTH_BRAM = 4,
    parameter WIDTH_SPRAM = 16,
    parameter DIM_MODE = 5,
    parameter DIM_GROUP_SPIKES = 2,
    parameter DIM_SUMS_SPIKES = 16,
    parameter NUM_MEMS = 4,
    parameter DIM_OFFSET = 7, // The number of offset is usually maximum 50 or 51 
    parameter DIM_OFFSET_STACK = 6,
    parameter DIM_TIMESTEP = 8,
    // ---------------------- MMU parameters ------------------

    // ---------------------- Datapath parameters ------------------    
    parameter DIM_GROUP_SPIKE4 = 4, // Most of the operations such as dense(spike,int) are done in groups of 4
    parameter DIM_GROUP_16 = 16, // matmul(spike,spike) is done in groups of 16
    parameter DIM_CURRENT = 22,
    parameter DIM_CTRL = 7,
    // LIF Section
    parameter NEURON = 717,
    parameter DIM_CURR_DECAY_LIF = 14,
    parameter DIM_VOLT_DECAY_LIF = 14,
    parameter WIDTH_LIF = 23,
    // ---------------------- Datapath parameters ------------------

    // ---------------------- Instruction memory parameters ------------------
    parameter INSTR_MEM_WIDTH = 32, // Instruction memory width
    parameter TOT_NUM_INSTR = 30,
    parameter DIM_INSTR = 169,
    parameter NUM_INSTR       = (DIM_INSTR >> 5) + 1, // Number of entries for each instruction. It is equal to 6 in our case
    parameter DIM_NUM_INSTR = 8,
    parameter INSTR_MEM_DEPTH = NUM_INSTR*TOT_NUM_INSTR,
    parameter INIT_INSTR_MEM = "", // Specify name/location of RAM initialization file if using one (leave blank if not)

    // ------------------------- Encoding Slot -------------------
    parameter CHANNELS = 16
)(
    input clk, 
    input rst, 
    input i_clr_valid_ll_ext,
    input valid_bin,
    input [3:0] spike_bin,
    input [clogb2(CHANNELS/2)-1:0] input_adr,
    input load_input_stack_entries,
    input [DIM_NUM_INSTR-1 : 0] num_instr, 
    input  valid_datapath,
    input [SPIKE_MEM_WIDTH/2 - 1 : 0] spike_p_out,
    input spike_s_out, // ingresso
    input [DATA_WIDTH - 1 : 0] data_int_out,
    input [DATA_WIDTH*2 - 1 : 0] data_int_out_sums,
    input [SPIKE_MEM_WIDTH-1 : 0] dout_port4_sm1, dout_port4_sm2, 
    input start_inf_dd,
    // output
    output [DIM_VOLT_DECAY_LIF - 1 : 0] voltage_decay,
    output [WIDTH_LIF-1 : 0] threshold,
    output [SPIKE_MEM_WIDTH-1 : 0]  data_in_sm1, data_in_sm2,
    output [WIDTH_SPRAM-1:0] data_in_intmem1, data_in_intmem2,
    output o_valid_last_layer,
    output [PIPE - 1 : 0] en_pipe,
    output end_inference, rd_en_sm,
    output valid_data_mmu, wr_en_sm1, wr_en_sm2, wr_en_intmem1, wr_en_intmem2, 
    output block_rd_cnt_lif, last_instr, valid_instr, en_datapath, use_v, empty_stack, use_stack, v_gen_id,
    output [DIM_MODE-1 : 0] mode,
    output [3:0] r_en_ext, en_port_wr,
    output [DIM_ADDR_SPIKE_MEM-1 : 0] wr_addr_sm1, wr_addr_sm2, rd_addr_sm1, rd_addr_sm2,
    output [DIM_ADDR_SPRAM -1 : 0] wr_addr_intmem1, wr_addr_intmem2, rd_addr_intmem1, rd_addr_intmem2,
    output [12:0] o_data_last_layer,
    output valid_op_mmu,
    output clr
);

localparam INPUT_BASE_ADDR = 4016;
localparam PIPE = 9;
localparam DIM_ADDR_STACK = clogb2(DEPTH_STACK-1); // Address size of the stack
// Internal signals
// Instruction Mem
localparam DEPTH_PC = clogb2(INSTR_MEM_DEPTH-1);
wire [DEPTH_PC-1:0] pc;
wire [DIM_INSTR-1:0] instruction_out_full;
// Instruction signals
wire [DIM_ADDR_STACK-1:0] stack_rbaddr, stack_wbaddr;
wire signed [DIM_OFFSET-1 : 0] addr_offset_ext; 
wire [DIM_OFFSET_STACK - 1 : 0] ext_offset_stack;
wire k_gen_id;

wire [DIM_INPUT_NEURONS-1 : 0] num_input_neurons;
wire [DIM_OUTPUT_NEURONS-1 : 0] num_output_neurons;
wire [DIM_MAX_MEM-1 : 0] r_baddr1, r_baddr2, wr_baddr1, wr_baddr2;
wire [3:0] raddr_sel;
wire load_stack_wentries_en;
wire en_wr_stack;
// FSM and control
wire en, fetch_instr, r_en_ext_stack, load_push_stack, valid_inference, clr_pc;
wire valid_op;
wire matmul_ss_id;

// Shifter of enables

// MMU
 wire valid_addr_stack_sig;
(* keep *)  wire [DIM_TIMESTEP - 1 : 0] timestep;
(* keep *) wire valid_result;
(* keep *) wire wren_wr_addr_gen_ext;
(* keep *)  wire [3:0] group_in_spikes;
(* keep *)  wire  empty_stack_to_dp;
// Datapath

integer i;
// ----------------------- FSM and general Control ----------------------------
assign last_instr = (pc == num_instr);
fsm_estu u_fsm_estu (
    .clk(clk),
    .rst(rst),
    .start_inference(start_inf_dd),
    .use_v(use_v),
    .valid_instr(valid_instr),
    .valid_op(valid_op),
    .last_instr(last_instr),
    .v_gen_id(v_gen_id),
    .valid_data(valid_data_mmu),
    .en(en),
    .clr(clr),
    .fetch_instr(fetch_instr),
    .r_en_ext_stack(r_en_ext_stack),
    .load_push_stack(load_push_stack),
    .valid_inference(valid_inference),
    .clr_pc(clr_pc)
);
// ----------------------- End of FSM ----------------------------

// ---------------------- Instruction Mem ----------------------------
(* keep_hierarchy *)    instr_mem #(
    .INSTR_MEM_WIDTH (INSTR_MEM_WIDTH),
    .TOT_NUM_INSTR   (TOT_NUM_INSTR),
    .DIM_INSTR       (DIM_INSTR),
    .NUM_INSTR       ((DIM_INSTR >> 5) + 1),
    .INSTR_MEM_DEPTH (INSTR_MEM_DEPTH),
    .INIT_INSTR_MEM  (INIT_INSTR_MEM)
  ) u_instr_mem (
    .clk                  (clk),
    .rst                  (rst),
    .clr                  (clr),
    .clr_pc               (clr_pc),
    .fetch_instr          (fetch_instr),
    .en_pc                (valid_op),
    .pc                   (pc),
    .valid_instr          (valid_instr),
    .instruction_out_full (instruction_out_full)
  );

  // Decoding instruction
    assign stack_rbaddr = instruction_out_full[DIM_INSTR-1 -: DIM_ADDR_STACK];
    assign stack_wbaddr = instruction_out_full[DIM_INSTR-1-DIM_ADDR_STACK -: DIM_ADDR_STACK];
    assign ext_offset_stack = instruction_out_full[DIM_INSTR-1-DIM_ADDR_STACK-DIM_ADDR_STACK -: DIM_OFFSET_STACK];
    assign v_gen_id = instruction_out_full[DIM_INSTR-1-DIM_ADDR_STACK-DIM_ADDR_STACK-DIM_OFFSET_STACK -: 1];
    assign use_v = instruction_out_full[DIM_INSTR-1-DIM_ADDR_STACK-DIM_ADDR_STACK-DIM_OFFSET_STACK-1 -: 1];
    assign mode = instruction_out_full[DIM_INSTR-1-DIM_ADDR_STACK-DIM_ADDR_STACK-DIM_OFFSET_STACK-2 -: DIM_MODE];
    assign num_input_neurons = instruction_out_full[DIM_INSTR-1-DIM_ADDR_STACK-DIM_ADDR_STACK-DIM_OFFSET_STACK-2-DIM_MODE -: DIM_INPUT_NEURONS];
    assign num_output_neurons = instruction_out_full[DIM_INSTR-1-DIM_ADDR_STACK-DIM_ADDR_STACK-DIM_OFFSET_STACK-2-DIM_MODE-DIM_INPUT_NEURONS -: DIM_OUTPUT_NEURONS];
    assign r_baddr1 = instruction_out_full[DIM_INSTR-1-DIM_ADDR_STACK-DIM_ADDR_STACK-DIM_OFFSET_STACK-2-DIM_MODE-DIM_INPUT_NEURONS-DIM_OUTPUT_NEURONS -: DIM_MAX_MEM];
    assign r_baddr2 = instruction_out_full[DIM_INSTR-1-DIM_ADDR_STACK-DIM_ADDR_STACK-DIM_OFFSET_STACK-2-DIM_MODE-DIM_INPUT_NEURONS-DIM_OUTPUT_NEURONS-DIM_MAX_MEM -: DIM_MAX_MEM];
    assign use_stack = instruction_out_full[DIM_INSTR-1-DIM_ADDR_STACK-DIM_ADDR_STACK-DIM_OFFSET_STACK-2-DIM_MODE-DIM_INPUT_NEURONS-DIM_OUTPUT_NEURONS-DIM_MAX_MEM-DIM_MAX_MEM -: 1];
    assign addr_offset_ext = instruction_out_full[DIM_INSTR-1-DIM_ADDR_STACK-DIM_ADDR_STACK-DIM_OFFSET_STACK-2-DIM_MODE-DIM_INPUT_NEURONS-DIM_OUTPUT_NEURONS-DIM_MAX_MEM-DIM_MAX_MEM-1 -: DIM_OFFSET];
    assign wr_baddr1 = instruction_out_full[DIM_INSTR-1-DIM_ADDR_STACK-DIM_ADDR_STACK-DIM_OFFSET_STACK-2-DIM_MODE-DIM_INPUT_NEURONS-DIM_OUTPUT_NEURONS-DIM_MAX_MEM-DIM_MAX_MEM-1-DIM_OFFSET -: DIM_MAX_MEM];
    assign wr_baddr2 = instruction_out_full[DIM_INSTR-1-DIM_ADDR_STACK-DIM_ADDR_STACK-DIM_OFFSET_STACK-2-DIM_MODE-DIM_INPUT_NEURONS-DIM_OUTPUT_NEURONS-DIM_MAX_MEM-DIM_MAX_MEM-1-DIM_OFFSET-DIM_MAX_MEM -: DIM_MAX_MEM];
    assign k_gen_id = instruction_out_full[DIM_INSTR-1-DIM_ADDR_STACK-DIM_ADDR_STACK-DIM_OFFSET_STACK-2-DIM_MODE-DIM_INPUT_NEURONS-DIM_OUTPUT_NEURONS-DIM_MAX_MEM-DIM_MAX_MEM-1-DIM_OFFSET-DIM_MAX_MEM- DIM_MAX_MEM -: 1];
    assign raddr_sel = instruction_out_full[DIM_INSTR-1-DIM_ADDR_STACK-DIM_ADDR_STACK-DIM_OFFSET_STACK-2-DIM_MODE-DIM_INPUT_NEURONS-DIM_OUTPUT_NEURONS-DIM_MAX_MEM-DIM_MAX_MEM-1-DIM_OFFSET-DIM_MAX_MEM- DIM_MAX_MEM -1 -: 4];
    assign r_en_ext = instruction_out_full[DIM_INSTR-1-DIM_ADDR_STACK-DIM_ADDR_STACK-DIM_OFFSET_STACK-2-DIM_MODE-DIM_INPUT_NEURONS-DIM_OUTPUT_NEURONS-DIM_MAX_MEM-DIM_MAX_MEM-1-DIM_OFFSET-DIM_MAX_MEM- DIM_MAX_MEM -1-4 -: 4];
    assign en_port_wr = instruction_out_full[DIM_INSTR-1-DIM_ADDR_STACK-DIM_ADDR_STACK-DIM_OFFSET_STACK-2-DIM_MODE-DIM_INPUT_NEURONS-DIM_OUTPUT_NEURONS-DIM_MAX_MEM-DIM_MAX_MEM-1-DIM_OFFSET-DIM_MAX_MEM- DIM_MAX_MEM -1-4-4 -: 4];
    assign voltage_decay = instruction_out_full[DIM_INSTR-1-DIM_ADDR_STACK-DIM_ADDR_STACK-DIM_OFFSET_STACK-2-DIM_MODE-DIM_INPUT_NEURONS-DIM_OUTPUT_NEURONS-DIM_MAX_MEM-DIM_MAX_MEM-1-DIM_OFFSET-DIM_MAX_MEM- DIM_MAX_MEM -1-4-4-4 -: DIM_VOLT_DECAY_LIF];
    assign threshold     = instruction_out_full[DIM_INSTR-1-DIM_ADDR_STACK-DIM_ADDR_STACK-DIM_OFFSET_STACK-2-DIM_MODE-DIM_INPUT_NEURONS-DIM_OUTPUT_NEURONS-DIM_MAX_MEM-DIM_MAX_MEM-1-DIM_OFFSET-DIM_MAX_MEM- DIM_MAX_MEM -1-4-4-4-DIM_VOLT_DECAY_LIF -: WIDTH_LIF];
    assign load_stack_wentries_en = instruction_out_full[DIM_INSTR-1-DIM_ADDR_STACK-DIM_ADDR_STACK-DIM_OFFSET_STACK-2-DIM_MODE-DIM_INPUT_NEURONS-DIM_OUTPUT_NEURONS-DIM_MAX_MEM-DIM_MAX_MEM-1-DIM_OFFSET-DIM_MAX_MEM- DIM_MAX_MEM -1-4-4-4-DIM_VOLT_DECAY_LIF -WIDTH_LIF -: 1];
    assign en_wr_stack = instruction_out_full[DIM_INSTR-1-DIM_ADDR_STACK-DIM_ADDR_STACK-DIM_OFFSET_STACK-2-DIM_MODE-DIM_INPUT_NEURONS-DIM_OUTPUT_NEURONS-DIM_MAX_MEM-DIM_MAX_MEM-1-DIM_OFFSET-DIM_MAX_MEM- DIM_MAX_MEM -1-4-4-4-DIM_VOLT_DECAY_LIF -WIDTH_LIF -1 -: 1];
// ---------------------- Instruction Mem ----------------------------


    // ---------------------- MMU ----------------------------------
    assign group_in_spikes = r_en_ext[0] ? dout_port4_sm1[3:0] : dout_port4_sm2[3:0];
    wire [DIM_MAX_LOGIC_ADDRESS - 1 : 0] wr_addr_cnt;
    wire o_valid_last_layer_pulse;
    localparam IN_STACK_WBADDR = 3329;
    wire valid_data_op;
    assign valid_op = valid_data_op;
    wire valid_addr_stack_sig_delay;
(* keep_hierarchy *)    mmu #(
    .DIM_ADDR_SPIKE_MEM (DIM_ADDR_SPIKE_MEM),
    .DIM_ADDR_SPRAM     (DIM_ADDR_SPRAM),
    .DIM_MAX_MEM        (DIM_MAX_MEM),
    .DIM_INPUT_NEURONS  (11),
    .DIM_OUTPUT_NEURONS (DIM_OUTPUT_NEURONS),
    .DIM_MAX_LOGIC_ADDRESS(DIM_MAX_LOGIC_ADDRESS),
    .DEPTH_STACK        (DEPTH_STACK),
    .INIT_STACK         (INIT_STACK),
    .DATA_WIDTH         (DATA_WIDTH),
    .V_COMP_K_Q         (V_COMP_K_Q),
    .WIDTH_BRAM         (WIDTH_BRAM),
    .WIDTH_SPRAM        (WIDTH_SPRAM),
    .DIM_MODE           (DIM_MODE),
    .DIM_GROUP_SPIKES   (DIM_GROUP_SPIKES),
    .DIM_SUMS_SPIKES    (DIM_SUMS_SPIKES),
    .NUM_MEMS           (NUM_MEMS),
    .DIM_OFFSET_STACK   (DIM_OFFSET_STACK),
    .DIM_OFFSET         (DIM_OFFSET),
    .DIM_TIMESTEP       (DIM_TIMESTEP),
    .IN_STACK_WBADDR    (IN_STACK_WBADDR),
    .PIPE               (PIPE)
  ) u_mmu (
    .clk                (clk),
    .rst                (rst),
    .clr                (clr),
    .en                 (en),
    .en_pipe            (en_pipe),
    .mode               (mode),
    .num_input_neurons  (num_input_neurons),
    .num_output_neurons (num_output_neurons),
    .r_baddr1           (r_baddr1),
    .r_baddr2           (r_baddr2),
    .wr_baddr1          (wr_baddr1),
    .wr_baddr2          (wr_baddr2),
    .w_en               (en_port_wr),
    .use_v              (use_v),
    .use_stack          (use_stack),
    .addr_offset_ext    (addr_offset_ext),
    .ext_offset_stack   (ext_offset_stack),
    .raddr_sel          (raddr_sel),
    .spike_out          (spike_p_out), 
    .sum_spikes         (data_int_out_sums),
    .data_int           (data_int_out), // This is a signal setted high when tere is a valid result to store
    .v_gen_id           (v_gen_id),
    .k_gen_id           (k_gen_id),
    .stack_wbaddr       (stack_wbaddr),
    .stack_rbaddr       (stack_rbaddr),
    .group_in_spikes    (group_in_spikes),
    .spike_in           (spike_s_out),
    .r_en_ext           (r_en_ext_stack),
    .load_push_stack    (load_push_stack),
    .data_out_intmem1   (data_out_int_mem1),
    .data_out_intmem2   (data_out_int_mem2),
    .load_stack_wentries_en (load_stack_wentries_en),
    .en_wr_stack       (en_wr_stack),
    .end_inference       (end_inference),
    .clr_valid_ll_ext   (i_clr_valid_ll_ext), // Clear the valid when the CPU reads the valid_last_layer signal
    .last_layer         (last_instr),
    .valid_instr     (valid_instr),
    .i_wren_spike_ext (valid_bin),
    .i_spike_ext (spike_bin),
    .i_logic_addr_ext (input_adr),
    .i_load_input_stack_entries (load_input_stack_entries),
    // Collegare i segnali di uscita
    .raddr_spike_mem1   (rd_addr_sm1),
    .raddr_spike_mem2   (rd_addr_sm2),
    .wr_addr_bram1      (wr_addr_sm1),
    .wr_addr_bram2      (wr_addr_sm2),
    .raddr_spram1       (rd_addr_intmem1),
    .raddr_spram2       (rd_addr_intmem2),
    .wr_addr_spram1     (wr_addr_intmem1),
    .wr_addr_spram2     (wr_addr_intmem2),
    .valid_read_op      (valid_op_mmu),
    .valid_read_data    (valid_data_mmu),
    .valid_addr_stack_sig (valid_addr_stack_sig),
    .valid_addr_stack_sig_delay (valid_addr_stack_sig_delay),
    .data_in_bram1      (data_in_sm1),
    .data_in_bram2      (data_in_sm2),
    .data_in_spram1     (data_in_intmem1),
    .data_in_spram2     (data_in_intmem2),
    .wren_bram1         (wr_en_sm1),
    .wren_bram2         (wr_en_sm2),
    .wren_spram1        (wr_en_intmem1),
    .wren_spram2        (wr_en_intmem2),
    .timestep           (timestep),
    .matmul_ss_id       (matmul_ss_id),
    .empty              (empty_stack),
    .wr_addr_cnt (wr_addr_cnt),
    .valid_last_layer_output (o_valid_last_layer),
    .output_last_layer (o_data_last_layer),
    .o_valid_data_op (valid_data_op),
    .en_datapath (en_datapath),
    .block_rd_cnt_lif (block_rd_cnt_lif),
    .rd_en_sm (rd_en_sm),
    .o_valid_last_layer_pulse(o_valid_last_layer_pulse),
    .valid_datapath (valid_datapath)
  );
  // ---------------------- End of MMU ------------------------------


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
