`timescale 1ns / 1ps

module estu #(
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
    input i_start_inference, // Signal that starts the inference
    input [DIM_NUM_INSTR-1 : 0] num_instr, // Number of instructions to execute
    input i_clr_valid_ll_ext, 
    // Int mem1
    input [WIDTH_SPRAM-1:0] i_int_mem1,
    input [DIM_ADDR_SPRAM-1 : 0] i_int_mem1_wr_addr,
    input i_wr_en_intmem1, 
    // Int mem2
    input [WIDTH_SPRAM-1:0] i_int_mem2,
    input [DIM_ADDR_SPRAM-1 : 0] i_int_mem2_wr_addr,
    input i_wr_en_intmem2,
    input [1:0] i_external_wren, // External write enable for the int memory
    //  Outputs
    output [12:0] o_data_last_layer, // Output data of the last layer 
    output end_inference, // Signal that indicates the end of the inference over all the timesteps
    output o_valid_last_layer, // Signal that indicates the valid data of the last layer output (single timestep)
    // Encoding Slot
    input i_clk_enc,
    output wire [15:0] o_sample_mem_dat,	
	input wire [7:0] i_sample_mem_adr,
	input wire       i_sample_mem_rd_en,	 
	input wire        i_sample_mem_wr_en,
	input wire [15:0] i_sample_mem_dat,
    input wire [15:0] i_sample_mem_spi,
    input wire i_en_encoding_slot,
    input wire i_encoding_bypass,
    output wire o_clr_start_inf
);

localparam INPUT_BASE_ADDR = 4016;
localparam PIPE = 9;
localparam PIPE_VALID_DATA = 6; 
localparam DIM_ADDR_STACK = clogb2(DEPTH_STACK-1); // Address size of the stack
// Internal signals
// Instruction Mem
localparam DEPTH_PC = clogb2(INSTR_MEM_DEPTH-1);
wire [DEPTH_PC-1:0] pc;
wire valid_instr;
wire [DIM_INSTR-1:0] instruction_out_full;
// Instruction signals
wire [DIM_ADDR_STACK-1:0] stack_rbaddr, stack_wbaddr;
wire signed [DIM_OFFSET-1 : 0] addr_offset_ext; 
wire [DIM_OFFSET_STACK - 1 : 0] ext_offset_stack;
wire v_gen_id, k_gen_id, use_v, use_stack;
wire [DIM_MODE-1 : 0] mode;
wire [DIM_INPUT_NEURONS-1 : 0] num_input_neurons;
wire [DIM_OUTPUT_NEURONS-1 : 0] num_output_neurons;
wire [DIM_MAX_MEM-1 : 0] r_baddr1, r_baddr2, wr_baddr1, wr_baddr2;
wire [3:0] raddr_sel, r_en_ext, en_port_wr;
wire last_instr;
wire load_stack_wentries_en;
wire en_wr_stack;
// FSM and control
wire en, clr, fetch_instr, r_en_ext_stack, load_push_stack, valid_inference, clr_pc;
wire valid_op;
reg valid_data;
reg en_toggle, en_toggle2;
wire en_datapath;
reg en_rd_addr_gen;
wire matmul_ss_id;
reg pipe_valid_addr_stack_d0;
reg pipe_valid_addr_stack_d1;
// Shifter of enables
reg [PIPE - 1 : 0] en_pipe;
reg [PIPE_VALID_DATA : 0] pipe_valid_data;
reg valid_result_d, valid_result_dd;
// MMU
(* keep *)  wire wr_en_sm1, wr_en_sm2, wr_en_intmem1, wr_en_intmem2, valid_op_mmu, valid_data_mmu, stream_out, valid_addr_stack_sig, first_timestep;
(* keep *)  wire [DIM_ADDR_SPIKE_MEM-1 : 0] wr_addr_sm1, wr_addr_sm2, rd_addr_sm1, rd_addr_sm2;
(* keep *)  wire [DIM_ADDR_SPRAM -1 : 0] wr_addr_intmem1, wr_addr_intmem2, rd_addr_intmem1, rd_addr_intmem2;
(* keep *)  wire [DIM_OUTPUT_NEURONS-1 : 0] num_output_neurons_mux;
(* keep *)  wire [DIM_TIMESTEP - 1 : 0] timestep;
(* keep *) wire valid_result;
(* keep *) wire wren_wr_addr_gen_ext;
(* keep *)  wire [3:0] group_in_spikes;
(* keep *)  reg stream_out_d;
(* keep *)  wire empty_stack, empty_stack_to_dp;
// Datapath
wire [DIM_VOLT_DECAY_LIF - 1 : 0] voltage_decay;
wire [WIDTH_LIF-1 : 0] threshold;
wire valid_datapath;
wire [SPIKE_MEM_WIDTH/2 - 1 : 0] spike_p_out;
wire spike_s_out;
(* keep *)  wire [DATA_WIDTH - 1 : 0] data_int_out;
(* keep *)  wire [DATA_WIDTH*2 - 1 : 0] data_int_out_sums;
(* keep *)  wire valid_int_neuron;
// Memories 
(* keep *)  wire [SPIKE_MEM_WIDTH-1 : 0] dout_port4_sm1, dout_port4_sm2, data_in_sm1, data_in_sm2;
(* keep *)  wire [WIDTH_SPRAM-1:0] data_in_intmem1, data_in_intmem2;
(* keep *)  wire [4*SPIKE_MEM_WIDTH-1 : 0] dout_port16_sm1, dout_port16_sm2;
(* keep *)  wire rd_en_sm;
(* keep *)  wire rd_en_intmem;
integer i;
// ----------------------- FSM and general Control ----------------------------
assign last_instr = (pc == num_instr);
reg start_inference;
fsm_estu u_fsm_estu (
    .clk(clk),
    .rst(rst),
    .start_inference(start_inf_dd),
    .use_v(use_v),
    .valid_instr(valid_instr),
    .valid_op(valid_op),
    .last_instr(last_instr),
    .v_gen_id(v_gen_id),
    .valid_data(valid_data),
    .en(en),
    .clr(clr),
    .fetch_instr(fetch_instr),
    .r_en_ext_stack(r_en_ext_stack),
    .load_push_stack(load_push_stack),
    .valid_inference(valid_inference),
    .clr_pc(clr_pc)
);
    always @(posedge clk) begin
        if (rst || clr) begin
            pipe_valid_addr_stack_d0 <= 1'b0;
            pipe_valid_addr_stack_d1<= 1'b0;
        end 
        else begin
            pipe_valid_addr_stack_d0 <= valid_addr_stack_sig;
            pipe_valid_addr_stack_d1<= pipe_valid_addr_stack_d0;
        end
    end
    
    localparam PIPE_EMPTY = 3;
    reg pipe_empty [PIPE_EMPTY - 1 : 0];
    always @(posedge clk) begin
        if (rst || clr) begin
            for (i = 0; i < PIPE_EMPTY; i=i+1) begin
                pipe_empty[i] <= 1'b0;
            end
        end 
        else begin
            pipe_empty[0] <= empty_stack;
            for (i = 1; i < PIPE_EMPTY; i=i+1) begin
                pipe_empty[i] <= pipe_empty[i-1];
            end
        end
    end
    `ifdef SIMULATION
    wire [PIPE_EMPTY-1:0] pipe_empty_sim;
    generate
        genvar j;
        for (j = 0; j < PIPE_EMPTY; j=j+1) begin : gen_pipe_empty_sim
            assign pipe_empty_sim[j] = pipe_empty[j];
        end
    endgenerate
    `endif

    always @(*) begin
        if (mode[2]) begin // sum(spike,spike)
            valid_data = en & en_pipe[3] & ~valid_op;
        end 
        else if (matmul_ss_id) begin // matmul(spike,spike)
            valid_data = en & en_pipe[2] & ~valid_op;
        end 
        else if (use_stack) begin  // Dense spike int
            valid_data = pipe_valid_data[6];
        end
        else begin
            valid_data = pipe_valid_data[5];
        end
    end
    

    always @(posedge clk) begin
        if (rst || clr) begin
            stream_out_d <= 1'b0;
        end 
        else begin
            stream_out_d <= valid_instr;
        end
    end


    always @(posedge clk) begin
        if (rst || clr  || use_v&valid_data) begin
            en_pipe <= 0;
        end 
        else begin
            en_pipe[0] <= en;
            for (i = 1; i < PIPE; i=i+1) begin
                en_pipe[i] <= en_pipe[i-1];
            end
        end
    end


    always @(posedge clk) begin
        if (rst || clr) begin
            valid_result_d <= 1'b0;
            valid_result_dd <= 1'b0;
        end 
        else begin
            valid_result_d <= valid_result;
            valid_result_dd <= valid_result_d;
        end
    end


    // Toggle enable
    always @(posedge clk) begin
        if (rst)
            en_toggle <= 1'b0;
        else if (valid_instr) begin
            en_toggle <= 1'b1;
            en_toggle2 <= 1'b0;
        end 
        else if (en) begin
            en_toggle <= ~en_toggle;
            en_toggle2 <= ~en_toggle2;
        end
    end

    
    always @(posedge clk) begin
        if (rst || clr || use_v&valid_data) begin
            pipe_valid_data <= 0;
        end 
        else begin
            pipe_valid_data[0] <= valid_data_mmu;
            for (i = 1; i <= PIPE_VALID_DATA; i=i+1) begin
                pipe_valid_data[i] <= pipe_valid_data[i-1];
            end
        end
    end

    assign en_datapath = 
        (mode[2] & en & ~mode[4])                         ? en_toggle :
        (mode[4] & en)                                    ? (en_toggle & en_pipe[1]) :
        (use_stack & ~use_v)                              ? (en & en_pipe[3]) :
        (use_stack & use_v)                               ? (pipe_valid_addr_stack_d1 
                                                            | en_pipe[2] 
                                                            | en_pipe[3] 
                                                            | en_pipe[4]) :
        (mode[3] & ~use_stack)                            ? (en & en_pipe[1]) :
        (matmul_ss_id)                                    ? (en & en_pipe[1]) :
                                                        1'b0;

    always @(*) begin 
        if (en&mode[2]&~mode[4])
            en_rd_addr_gen = en_toggle2;
        else 
            en_rd_addr_gen = en;
    end
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

// ---------------------- Memories ----------------------------------
// Spike memories
    assign rd_en_sm = mode[3] ? valid_addr_stack_sig : en;
(* keep_hierarchy *)    spike_mem #(
        .RAM_WIDTH(SPIKE_MEM_WIDTH),
        .RAM_DEPTH(SPIKE_MEM_DEPTH),
        .RAM_PERFORMANCE(RAM_PERFORMANCE),
        .INIT_FILE1(INIT_FILE_SM1),
        .INIT_FILE2(INIT_FILE_SM2),
        .INIT_FILE3(INIT_FILE_SM3),
        .INIT_FILE4(INIT_FILE_SM4),
        .NUM_MEMS(NUM_MEMS_SPIKE_MEM),
        .ADDR_WIDTH(DIM_ADDR_SPIKE_MEM)
    ) spike_mem1_inst (
        .clk        (clk),
        .rst        (rst),
        .en_port_wr (en_port_wr[0] | valid_bin),
        .wr_en_ext  (wr_en_sm1 | valid_bin),
        .en_port_rd (r_en_ext[0]),
        .rd_en      (rd_en_sm),
        .wr_addr    (valid_bin ? (INPUT_BASE_ADDR + input_adr) : wr_addr_sm1),
        .rd_addr    (rd_addr_sm1),
        .data_in    (valid_bin ? spike_bin : data_in_sm1),
        .dout_port4 (dout_port4_sm1),
        .dout_port16(dout_port16_sm1)
    );

(* keep_hierarchy *)    spike_mem #(
        .RAM_WIDTH(SPIKE_MEM_WIDTH),
        .RAM_DEPTH(SPIKE_MEM_DEPTH),
        .RAM_PERFORMANCE(RAM_PERFORMANCE),
        .INIT_FILE1(),
        .INIT_FILE2(),
        .INIT_FILE3(),
        .INIT_FILE4(),
        .NUM_MEMS(NUM_MEMS_SPIKE_MEM),
        .ADDR_WIDTH(DIM_ADDR_SPIKE_MEM)
    ) spike_mem2_inst (
        .clk        (clk),
        .rst        (rst),
        .en_port_wr (en_port_wr[1]),
        .wr_en_ext  (wr_en_sm2),
        .en_port_rd (r_en_ext[1]),
        .rd_en      (rd_en_sm),
        .wr_addr    (wr_addr_sm2),
        .rd_addr    (rd_addr_sm2),
        .data_in    (data_in_sm2),
        .dout_port4 (dout_port4_sm2),
        .dout_port16(dout_port16_sm2)
    );

    // BRAM (will be an SPRAM) generation for WEIGHTS and some results
    wire [WIDTH_SPRAM-1:0] data_out_int_mem1_stage1;
    reg [WIDTH_SPRAM-1 : 0] data_out_int_mem1;
    always @(posedge clk) begin
    	if (rst)
		data_out_int_mem1 <= 0;
	else
		data_out_int_mem1 <= data_out_int_mem1_stage1;
    end

    wire [WIDTH_SPRAM-1:0] data_out_int_mem2_stage1;
	reg [WIDTH_SPRAM-1 : 0] data_out_int_mem2;
	always @(posedge clk) begin
		if(rst)
			data_out_int_mem2 <= 0;
		else
			data_out_int_mem2 <= data_out_int_mem2_stage1;
	end
    
    // `ifdef SIMULATION

    // SB_SPRAM256KA_sim  #(
    //     .INIT_FILE()
    // ) INT_MEM1 (
    //     .ADDRESS    (i_external_wren[0] ? i_int_mem1_wr_addr : (wr_en_intmem1 ? wr_addr_intmem1 : rd_addr_intmem1)),
    //     .DATAIN     (i_external_wren[0] ? i_int_mem1 : data_in_intmem1),
    //     .MASKWREN   ((wr_en_intmem1|i_external_wren[0]) ? 4'b1111 : 4'b0000),
    //     .WREN       (i_external_wren[0] ? i_wr_en_intmem1 : wr_en_intmem1),
    //     .CHIPSELECT (en_port_wr[2] | r_en_ext[2] | i_external_wren[0]),
    //     .CLOCK      (clk),
    //     .STANDBY    (1'b0),
    //     .SLEEP      (1'b0),
    //     .POWEROFF   (1'b1),
    //     .DATAOUT    (data_out_int_mem1_stage1)
    // );

    // SB_SPRAM256KA_sim  #(
    //     .INIT_FILE()
    // ) INT_MEM2 (
    //     .ADDRESS    (i_external_wren[1] ? i_int_mem2_wr_addr : (wr_en_intmem2 ? wr_addr_intmem2 : rd_addr_intmem2)),
    //     .DATAIN     (i_external_wren[1] ? i_int_mem2 : data_in_intmem2),
    //     .MASKWREN   ((wr_en_intmem2|i_external_wren[1])  ? 4'b1111 : 4'b0000),
    //     .WREN       (i_external_wren[1] ? i_wr_en_intmem2 : wr_en_intmem2),
    //     .CHIPSELECT (en_port_wr[3] | r_en_ext[3] | i_external_wren[1]),
    //     .CLOCK      (clk),
    //     .STANDBY    (1'b0),
    //     .SLEEP      (1'b0),
    //     .POWEROFF   (1'b1),
    //     .DATAOUT    (data_out_int_mem2_stage1)
    // );

    // `else

    SB_SPRAM256KA INT_MEM1 (
        .ADDRESS    (i_external_wren[0] ? i_int_mem1_wr_addr : (wr_en_intmem1 ? wr_addr_intmem1 : rd_addr_intmem1)),
        .DATAIN     (i_external_wren[0] ? i_int_mem1 : data_in_intmem1),
        .MASKWREN   ((wr_en_intmem1|i_external_wren[0]) ? 4'b1111 : 4'b0000),
        .WREN       (i_external_wren[0] ? i_wr_en_intmem1 : wr_en_intmem1),
        .CHIPSELECT (en_port_wr[2] | r_en_ext[2] | i_external_wren[0]),
        .CLOCK      (clk),
        .STANDBY    (1'b0),
        .SLEEP      (1'b0),
        .POWEROFF   (1'b1),
        .DATAOUT    (data_out_int_mem1_stage1)
    );

    SB_SPRAM256KA INT_MEM2 (
        .ADDRESS    (i_external_wren[1] ? i_int_mem2_wr_addr : (wr_en_intmem2 ? wr_addr_intmem2 : rd_addr_intmem2)),
        .DATAIN     (i_external_wren[1] ? i_int_mem2 : data_in_intmem2),
        .MASKWREN   ((wr_en_intmem2|i_external_wren[1])  ? 4'b1111 : 4'b0000),
        .WREN       (i_external_wren[1] ? i_wr_en_intmem2 : wr_en_intmem2),
        .CHIPSELECT (en_port_wr[3] | r_en_ext[3] | i_external_wren[1]),
        .CLOCK      (clk),
        .STANDBY    (1'b0),
        .SLEEP      (1'b0),
        .POWEROFF   (1'b1),
        .DATAOUT    (data_out_int_mem2_stage1)
    );

    // `endif

    // -------------------------------- End of memories -------------------------------



    // ---------------------- MMU ----------------------------------
    assign stream_out = use_v ? stream_out_d : valid_instr;
    assign group_in_spikes = r_en_ext[0] ? dout_port4_sm1[3:0] : dout_port4_sm2[3:0];
    assign first_timestep = (timestep == 0);
    //assign num_output_neurons_mux = (use_v) ? ((timestep+1)<<num_output_neurons) : num_output_neurons;
    assign num_output_neurons_mux = num_output_neurons;
    wire [DIM_MAX_LOGIC_ADDRESS - 1 : 0] wr_addr_cnt;
    wire block_rd_cnt_lif;
    reg [DIM_MAX_LOGIC_ADDRESS - 1 : 0] ctrl_acc_clr_and_go;
    always @(posedge clk) begin
        if (rst || clr) begin
            ctrl_acc_clr_and_go <= 0;
        end 
        else if (valid_data&block_rd_cnt_lif) begin
            ctrl_acc_clr_and_go <= ctrl_acc_clr_and_go + 1;
        end
    end
    
    assign block_rd_cnt_lif = ~( ctrl_acc_clr_and_go == ((num_output_neurons_mux)<<2) );
    localparam IN_STACK_WBADDR = 3329;
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
    .IN_STACK_WBADDR    (IN_STACK_WBADDR)
  ) u_mmu (
    // Collegare i segnali di ingresso
    //.ext_ctrl           (ext_ctrl),
    //.ext_addr_spram     (ext_addr_spram),
    //.ext_datain_spram   (ext_datain_spram),
    //.ext_addr_bram      (ext_addr_bram),
    //.ext_datain_bram    (ext_datain_bram),
    .clk                (clk),
    .rst                (rst),
    .clr                (clr),
    .en                 (en),
    .en_rd_addr_gen     (en_rd_addr_gen),
    .mode               (mode),
    .num_input_neurons  (num_input_neurons),
    .num_output_neurons (num_output_neurons_mux),
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
    .data_int           (data_int_out),
    .valid_result       (valid_result), // This is a signal setted high when tere is a valid result to store
    .v_gen_id           (v_gen_id),
    .k_gen_id           (k_gen_id),
    .stack_wbaddr       (stack_wbaddr),
    .stack_rbaddr       (stack_rbaddr),
    .group_in_spikes    (group_in_spikes),
    .spike_in           (spike_s_out),
    .r_en_ext           (r_en_ext_stack),
    .load_push_stack    (load_push_stack),
    .stream_out         (stream_out),
    .first_timestep     (first_timestep),
    .valid_op_datapath  (valid_op),
    .data_out_intmem1   (data_out_int_mem1),
    .data_out_intmem2   (data_out_int_mem2),
    .load_stack_wentries_en (load_stack_wentries_en),
    .en_wr_stack       (en_wr_stack),
    .valid_data_ext     (valid_data),
    .end_inference       (end_inference),
    .clr_valid_ll_ext   (i_clr_valid_ll_ext), // Clear the valid when the CPU reads the valid_last_layer signal
    .last_layer         (last_instr),
    .valid_instr     (valid_instr),
    .i_wren_spike_ext (valid_bin),
    .i_spike_ext (spike_bin),
    .i_logic_addr_ext (input_adr),
    .i_load_input_stack_entries (load_input_stack_entries2),
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
    .output_last_layer (o_data_last_layer)
  );
  // ---------------------- End of MMU ------------------------------

// ---------------------- Datapath   ------------------------------
(* keep_hierarchy *)    datapath #(
        .DIM_MODE            (DIM_MODE),
        .DIM_GROUP_SPIKE4    (DIM_GROUP_SPIKE4),
        .DIM_GROUP_16        (DIM_GROUP_16),
        .DATA_WIDTH          (DATA_WIDTH),
        .NUM_MEMS            (NUM_MEMS),
        .DIM_CURRENT         (DIM_CURRENT),
        .DIM_CTRL            (PIPE),
        .NEURON              (NEURON),
        .DIM_CURR_DECAY_LIF  (DIM_CURR_DECAY_LIF),
        .DIM_VOLT_DECAY_LIF  (DIM_VOLT_DECAY_LIF),
        .WIDTH_LIF           (WIDTH_LIF)
    ) datapath_inst (
        .clk               (clk),
        .rst               (rst),
        .valid_inference   (end_inference),
        .acc_clear_and_go  (valid_data),
        .block_rd_cnt_lif (block_rd_cnt_lif),
        .clr               (clr|valid_instr),
        .en                (en_datapath),
        .ctrl_sig          (en_pipe),
        .use_v             (use_v),
        .empty             (pipe_empty[2]&use_stack),
        .mode              (mode),
        .spikes_in_1       (dout_port4_sm1),
        .spikes_in_2       (dout_port4_sm2),
        .spikes_in16_1     (dout_port16_sm1),
        .spikes_in16_2     (dout_port16_sm2),
        .data_int1         (data_out_int_mem1),
        .data_int2         (data_out_int_mem2),
        .r_en_mems         (r_en_ext),
        .voltage_decay     (voltage_decay),
        .threshold         (threshold),
        .use_stack         (use_stack),
        .v_gen_id          (v_gen_id),
        .valid_op_mmu      (valid_op_mmu),
        .last_layer        (last_instr),
        // Outputs 
        .spike_s_out       (spike_s_out),
        .spike_p_out       (spike_p_out),
        .data_int_out      (data_int_out),
        .data_int_out_sums (data_int_out_sums),
        .valid_datapath    (valid_datapath),
        .valid_int_neuron  (valid_int_neuron)
    );
    // ---------------------- End of Datapath -------------------------




/////////////////////////////////////////////////////////////////////////// 
//  _____ _   _  ____ ___  ____ ___ _   _  ____   ____  _     ___ _____  //
// | ____| \ | |/ ___/ _ \|  _ \_ _| \ | |/ ___| / ___|| |   / _ \_   _| //
// |  _| |  \| | |  | | | | | | | ||  \| | |  _  \___ \| |  | | | || |   //
// | |___| |\  | |__| |_| | |_| | || |\  | |_| |  ___) | |__| |_| || |   //
// |_____|_| \_|\____\___/|____/___|_| \_|\____| |____/|_____\___/ |_|   //
//                                                                       //                                    
///////////////////////////////////////////////////////////////////////////
    
wire [3:0] spike_bin;
wire valid_bin;
wire active_group_out_bin;
reg [clogb2(CHANNELS/2)-1:0] input_adr;
wire [clogb2(CHANNELS/2):0] input_adr_nxt;
wire input_loaded;
reg start_inf_d, start_inf_dd;
reg load_input_stack_entries1, load_input_stack_entries2;

always @(posedge clk) begin
    if (rst || o_valid_last_layer) begin
        input_adr <= 0;
    end 
    else if (valid_bin) begin
        input_adr <= input_adr_nxt;
    end
end

always @(posedge clk) begin
    if (rst || o_valid_last_layer) begin
        start_inference <= 0;
    end 
    else if (input_loaded&i_start_inference&valid_bin) begin
        start_inference <= 1'b1;
    end
    else
        start_inference <= 1'b0;
end

always @(posedge clk) begin
    if (rst || o_valid_last_layer) begin
        start_inf_d <= 1'b0;
        start_inf_dd <= 1'b0;
    end 
    else begin
        start_inf_d <= start_inference;
        start_inf_dd <= start_inf_d;
    end
end

assign input_loaded = (input_adr == CHANNELS/2 - 1);
assign input_adr_nxt = input_adr + 1'b1;

always @(posedge clk) begin
    if (rst || o_valid_last_layer) begin
        load_input_stack_entries1 <= 1'b0;
        load_input_stack_entries2 <= 1'b0;
    end 
    else begin
        load_input_stack_entries1 <= (valid_bin & input_loaded);
        load_input_stack_entries2 <= load_input_stack_entries1;
    end 
end

encoding_slot #(
	.BYPASS(0),    
	.CHANNELS(CHANNELS),
    .ORDER(2),
    .WINDOW(8192),
    .REF_PERIOD(16),
    .DW(8),
    .INIT_INPUT_BUFFER("")
)
encoding_slot_i
(   
    .clk(clk),
    .rst(rst),
    .en(i_en_encoding_slot),
    .data_in(i_sample_mem_spi),
    .detect(1'b1),
    .spike_bin(spike_bin),
    .valid_bin(valid_bin),
    .active_group_out_bin(active_group_out_bin),
    .inference_done(0),
    .o_sample_mem_dat(o_sample_mem_dat),
    .i_sample_mem_adr(i_sample_mem_adr),
    .i_sample_mem_rd_en(i_sample_mem_rd_en),
    .i_sample_mem_wr_en(i_sample_mem_wr_en),
    .i_sample_mem_dat(i_sample_mem_dat),
    .bypass(i_encoding_bypass)
    );   



// ---------------------- Output assignments ------------------------
// assign valid_data = mode[2] ? en&en_pipe[3]&~valid_op : (matmul_ss_id ? en&en_pipe[2]&~valid_op : (use_stack ? (pipe_valid_data[6]) : (pipe_valid_data[5])));
reg o_valid_last_layer_d;
wire o_valid_last_layer_pulse;

always @(posedge clk) begin
    if (rst)
        o_valid_last_layer_d <= 1'b0;
    else
        o_valid_last_layer_d <= o_valid_last_layer;
end

assign o_valid_last_layer_pulse = o_valid_last_layer & ~o_valid_last_layer_d;

assign valid_op = matmul_ss_id ? pipe_valid_data[3] : (valid_op_mmu|o_valid_last_layer_pulse);
assign valid_result = (mode[2]|matmul_ss_id) ? valid_data : valid_datapath;
assign end_inference = o_valid_last_layer & (timestep == 200);
assign o_clr_start_inf = start_inf_dd;
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
