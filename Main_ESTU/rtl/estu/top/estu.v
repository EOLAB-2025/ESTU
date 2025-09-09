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
localparam DIM_ADDR_STACK = clogb2(DEPTH_STACK-1); // Address size of the stack

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


// Shifter of enables
wire [PIPE - 1 : 0] en_pipe;

// Datapath
wire [DIM_VOLT_DECAY_LIF - 1 : 0] voltage_decay;
wire [WIDTH_LIF-1 : 0] threshold;
wire valid_datapath;
wire [SPIKE_MEM_WIDTH/2 - 1 : 0] spike_p_out;
wire spike_s_out;
(* keep *)  wire [DATA_WIDTH - 1 : 0] data_int_out;
(* keep *)  wire [DATA_WIDTH*2 - 1 : 0] data_int_out_sums;
// Memories 
(* keep *)  wire [SPIKE_MEM_WIDTH-1 : 0] dout_port4_sm1, dout_port4_sm2, data_in_sm1, data_in_sm2;
(* keep *)  wire [WIDTH_SPRAM-1:0] data_in_intmem1, data_in_intmem2;
(* keep *)  wire [4*SPIKE_MEM_WIDTH-1 : 0] dout_port16_sm1, dout_port16_sm2;
(* keep *)  wire rd_en_sm;
(* keep *)  wire rd_en_intmem;
integer i;


// ---------------------- Memories ----------------------------------
// Spike memories
wire wr_en_sm1, wr_en_sm2, wr_en_intmem1, wr_en_intmem2;
wire [DIM_ADDR_SPRAM -1 : 0] wr_addr_intmem1, wr_addr_intmem2, rd_addr_intmem1, rd_addr_intmem2;
wire [DIM_ADDR_SPIKE_MEM-1 : 0] wr_addr_sm1, wr_addr_sm2, rd_addr_sm1, rd_addr_sm2;
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
    // -------------------------------- End of memories -------------------------------

// ---------------------- Datapath   ------------------------------
wire valid_data_mmu, block_rd_cnt_lif, valid_instr, en_datapath, empty_stack;
wire valid_op_mmu, clr;
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
        .acc_clear_and_go  (valid_data_mmu),
        .block_rd_cnt_lif (block_rd_cnt_lif),
        .clr               (clr|valid_instr),
        .en                (en_datapath),
        .ctrl_sig          (en_pipe),
        .use_v             (use_v),
        .empty             (empty_stack&use_stack),
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
        .valid_datapath    (valid_datapath)
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
reg start_inference;
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
assign o_clr_start_inf = start_inf_dd;
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

control_unit #(
    .SPIKE_MEM_WIDTH   (SPIKE_MEM_WIDTH),
    .SPIKE_MEM_DEPTH   (SPIKE_MEM_DEPTH),
    .RAM_PERFORMANCE   (RAM_PERFORMANCE),
    .INIT_FILE_SM1     (INIT_FILE_SM1),
    .INIT_FILE_SM2     (INIT_FILE_SM2),
    .INIT_FILE_SM3     (INIT_FILE_SM3),
    .INIT_FILE_SM4     (INIT_FILE_SM4),
    .NUM_MEMS_SPIKE_MEM(NUM_MEMS_SPIKE_MEM),
    .DEPTH_INT_MEM     (DEPTH_INT_MEM),
    .INIT_FILE_INTMEM1 (INIT_FILE_INTMEM1),
    .INIT_FILE_INTMEM2 (INIT_FILE_INTMEM2),
    .DIM_ADDR_SPIKE_MEM(DIM_ADDR_SPIKE_MEM),
    .DIM_ADDR_SPRAM    (DIM_ADDR_SPRAM),
    .DIM_MAX_MEM       (DIM_MAX_MEM),
    .DIM_INPUT_NEURONS (DIM_INPUT_NEURONS),
    .DIM_OUTPUT_NEURONS(DIM_OUTPUT_NEURONS),
    .DIM_MAX_LOGIC_ADDRESS(DIM_MAX_LOGIC_ADDRESS),
    .DEPTH_STACK       (DEPTH_STACK),
    .INIT_STACK        (INIT_STACK),
    .DATA_WIDTH        (DATA_WIDTH),
    .V_COMP_K_Q        (V_COMP_K_Q),
    .WIDTH_BRAM        (WIDTH_BRAM),
    .WIDTH_SPRAM       (WIDTH_SPRAM),
    .DIM_MODE          (DIM_MODE),
    .DIM_GROUP_SPIKES  (DIM_GROUP_SPIKES),
    .DIM_SUMS_SPIKES   (DIM_SUMS_SPIKES),
    .NUM_MEMS          (NUM_MEMS),
    .DIM_OFFSET        (DIM_OFFSET),
    .DIM_OFFSET_STACK  (DIM_OFFSET_STACK),
    .DIM_TIMESTEP      (DIM_TIMESTEP),
    .DIM_GROUP_SPIKE4  (DIM_GROUP_SPIKE4),
    .DIM_GROUP_16      (DIM_GROUP_16),
    .DIM_CURRENT       (DIM_CURRENT),
    .DIM_CTRL          (DIM_CTRL),
    .NEURON            (NEURON),
    .DIM_CURR_DECAY_LIF(DIM_CURR_DECAY_LIF),
    .DIM_VOLT_DECAY_LIF(DIM_VOLT_DECAY_LIF),
    .WIDTH_LIF         (WIDTH_LIF),
    .INSTR_MEM_WIDTH   (INSTR_MEM_WIDTH),
    .TOT_NUM_INSTR     (TOT_NUM_INSTR),
    .DIM_INSTR         (DIM_INSTR),
    .NUM_INSTR         (NUM_INSTR),
    .DIM_NUM_INSTR     (DIM_NUM_INSTR),
    .INSTR_MEM_DEPTH   (INSTR_MEM_DEPTH),
    .INIT_INSTR_MEM    (INIT_INSTR_MEM),
    .CHANNELS          (CHANNELS) // Number of channels for the encoding slot
) u_control_unit (
    .clk(clk),
    .rst(rst),
    .valid_bin(valid_bin),
    .clr(clr),
    .num_instr(num_instr),
    .voltage_decay(voltage_decay),
    .threshold(threshold),
    .valid_datapath(valid_datapath),
    .spike_p_out(spike_p_out),
    .spike_s_out(spike_s_out),
    .data_int_out(data_int_out),
    .data_int_out_sums(data_int_out_sums),
    .dout_port4_sm1(dout_port4_sm1),
    .dout_port4_sm2(dout_port4_sm2),
    .data_in_sm1(data_in_sm1),
    .data_in_sm2(data_in_sm2),
    .data_in_intmem1(data_in_intmem1),
    .data_in_intmem2(data_in_intmem2),
    .o_valid_last_layer(o_valid_last_layer),
    .start_inf_dd(start_inf_dd),
    .en_pipe(en_pipe),
    .end_inference(end_inference),
    .rd_en_sm(rd_en_sm),
    .valid_data_mmu(valid_data_mmu),
    .wr_en_sm1(wr_en_sm1),
    .wr_en_sm2(wr_en_sm2),
    .wr_en_intmem1(wr_en_intmem1),
    .wr_en_intmem2(wr_en_intmem2),
    .block_rd_cnt_lif(block_rd_cnt_lif),
    .last_instr(last_instr),
    .valid_instr(valid_instr),
    .en_datapath(en_datapath),
    .use_v(use_v),
    .empty_stack(empty_stack),
    .use_stack(use_stack),
    .v_gen_id(v_gen_id),
    .mode(mode),
    .r_en_ext(r_en_ext),
    .en_port_wr(en_port_wr),
    .wr_addr_sm1(wr_addr_sm1),
    .wr_addr_sm2(wr_addr_sm2),
    .rd_addr_sm1(rd_addr_sm1),
    .rd_addr_sm2(rd_addr_sm2),
    .wr_addr_intmem1(wr_addr_intmem1),
    .wr_addr_intmem2(wr_addr_intmem2),
    .rd_addr_intmem1(rd_addr_intmem1),
    .rd_addr_intmem2(rd_addr_intmem2),
    .i_clr_valid_ll_ext(i_clr_valid_ll_ext),
    .o_data_last_layer(o_data_last_layer),
    .valid_op_mmu(valid_op_mmu),
    .spike_bin(spike_bin),
    .input_adr(input_adr),
    .load_input_stack_entries(load_input_stack_entries2)
);
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
