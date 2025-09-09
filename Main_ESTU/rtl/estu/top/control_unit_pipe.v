module control_unit_pipe #(
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
    localparam PIPE = 9;

    // --- Wires dalle uscite “raw” del control_unit ---
    wire                                  clr_w;
    wire [DIM_VOLT_DECAY_LIF-1:0]         voltage_decay_w;
    wire [WIDTH_LIF-1:0]                  threshold_w;
    wire [SPIKE_MEM_WIDTH-1:0]            data_in_sm1_w, data_in_sm2_w;
    wire [WIDTH_SPRAM-1:0]                data_in_intmem1_w, data_in_intmem2_w;
    wire                                  o_valid_last_layer_w;
    wire [PIPE-1:0]              en_pipe_w;
    wire                                  end_inference_w, rd_en_sm_w, valid_data_mmu_w;
    wire                                  wr_en_sm1_w, wr_en_sm2_w, wr_en_intmem1_w, wr_en_intmem2_w;
    wire                                  block_rd_cnt_lif_w, last_instr_w, valid_instr_w, en_datapath_w;
    wire                                  use_v_w, empty_stack_w, use_stack_w, v_gen_id_w;
    wire [DIM_MODE-1:0]                   mode_w;
    wire [3:0]                            r_en_ext_w, en_port_wr_w;
    wire [DIM_ADDR_SPIKE_MEM-1:0]         wr_addr_sm1_w, wr_addr_sm2_w, rd_addr_sm1_w, rd_addr_sm2_w;
    wire [DIM_ADDR_SPRAM-1:0]             wr_addr_intmem1_w, wr_addr_intmem2_w, rd_addr_intmem1_w, rd_addr_intmem2_w;
    wire [12:0]                           o_data_last_layer_w;
    wire                                  valid_op_mmu_w;
    // --- Registri di uscita (pipeline stage) ---
    reg                                   clr_r;
    reg  [DIM_VOLT_DECAY_LIF-1:0]         voltage_decay_r;
    reg  [WIDTH_LIF-1:0]                  threshold_r;
    reg  [SPIKE_MEM_WIDTH-1:0]            data_in_sm1_r, data_in_sm2_r;
    reg  [WIDTH_SPRAM-1:0]                data_in_intmem1_r, data_in_intmem2_r;
    reg                                   o_valid_last_layer_r;
    reg  [PIPE-1:0]              en_pipe_r;
    reg                                   end_inference_r, rd_en_sm_r, valid_data_mmu_r;
    reg                                   wr_en_sm1_r, wr_en_sm2_r, wr_en_intmem1_r, wr_en_intmem2_r;
    reg                                   block_rd_cnt_lif_r, last_instr_r, valid_instr_r, en_datapath_r;
    reg                                   use_v_r, empty_stack_r, use_stack_r, v_gen_id_r;
    reg  [DIM_MODE-1:0]                   mode_r;
    reg  [3:0]                            r_en_ext_r, en_port_wr_r;
    reg  [DIM_ADDR_SPIKE_MEM-1:0]         wr_addr_sm1_r, wr_addr_sm2_r, rd_addr_sm1_r, rd_addr_sm2_r;
    reg  [DIM_ADDR_SPRAM-1:0]             wr_addr_intmem1_r, wr_addr_intmem2_r, rd_addr_intmem1_r, rd_addr_intmem2_r;
    reg  [12:0]                           o_data_last_layer_r;
    reg                                   valid_op_mmu_r;



// Pipeline stage: registra tutti i segnali wire_w nei rispettivi reg_r
    always @(posedge clk) begin
        if (rst) begin
            clr_r <= 0;
            voltage_decay_r <= 0;
            threshold_r <= 0;
            data_in_sm1_r <= 0;
            data_in_sm2_r <= 0;
            data_in_intmem1_r <= 0;
            data_in_intmem2_r <= 0;
            o_valid_last_layer_r <= 0;
            en_pipe_r <= 0;
            end_inference_r <= 0;
            rd_en_sm_r <= 0;
            valid_data_mmu_r <= 0;
            wr_en_sm1_r <= 0;
            wr_en_sm2_r <= 0;
            wr_en_intmem1_r <= 0;
            wr_en_intmem2_r <= 0;
            block_rd_cnt_lif_r <= 0;
            last_instr_r <= 0;
            valid_instr_r <= 0;
            en_datapath_r <= 0;
            use_v_r <= 0;
            empty_stack_r <= 0;
            use_stack_r <= 0;
            v_gen_id_r <= 0;
            mode_r <= 0;
            r_en_ext_r <= 0;
            en_port_wr_r <= 0;
            wr_addr_sm1_r <= 0;
            wr_addr_sm2_r <= 0;
            rd_addr_sm1_r <= 0;
            rd_addr_sm2_r <= 0;
            wr_addr_intmem1_r <= 0;
            wr_addr_intmem2_r <= 0;
            rd_addr_intmem1_r <= 0;
            rd_addr_intmem2_r <= 0;
            o_data_last_layer_r <= 0;
            valid_op_mmu_r <= 0;
        end else begin
            clr_r <= clr_w;
            voltage_decay_r <= voltage_decay_w;
            threshold_r <= threshold_w;
            data_in_sm1_r <= data_in_sm1_w;
            data_in_sm2_r <= data_in_sm2_w;
            data_in_intmem1_r <= data_in_intmem1_w;
            data_in_intmem2_r <= data_in_intmem2_w;
            o_valid_last_layer_r <= o_valid_last_layer_w;
            en_pipe_r <= en_pipe_w;
            end_inference_r <= end_inference_w;
            rd_en_sm_r <= rd_en_sm_w;
            valid_data_mmu_r <= valid_data_mmu_w;
            wr_en_sm1_r <= wr_en_sm1_w;
            wr_en_sm2_r <= wr_en_sm2_w;
            wr_en_intmem1_r <= wr_en_intmem1_w;
            wr_en_intmem2_r <= wr_en_intmem2_w;
            block_rd_cnt_lif_r <= block_rd_cnt_lif_w;
            last_instr_r <= last_instr_w;
            valid_instr_r <= valid_instr_w;
            en_datapath_r <= en_datapath_w;
            use_v_r <= use_v_w;
            empty_stack_r <= empty_stack_w;
            use_stack_r <= use_stack_w;
            v_gen_id_r <= v_gen_id_w;
            mode_r <= mode_w;
            r_en_ext_r <= r_en_ext_w;
            en_port_wr_r <= en_port_wr_w;
            wr_addr_sm1_r <= wr_addr_sm1_w;
            wr_addr_sm2_r <= wr_addr_sm2_w;
            rd_addr_sm1_r <= rd_addr_sm1_w;
            rd_addr_sm2_r <= rd_addr_sm2_w;
            wr_addr_intmem1_r <= wr_addr_intmem1_w;
            wr_addr_intmem2_r <= wr_addr_intmem2_w;
            rd_addr_intmem1_r <= rd_addr_intmem1_w;
            rd_addr_intmem2_r <= rd_addr_intmem2_w;
            o_data_last_layer_r <= o_data_last_layer_w;
            valid_op_mmu_r <= valid_op_mmu_w;
        end
    end



 control_unit  #(
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
        .clr(clr_w),
        .num_instr(num_instr),
        .voltage_decay(voltage_decay_w),
        .threshold(threshold_w),
        .valid_datapath(valid_datapath),
        .spike_p_out(spike_p_out),
        .spike_s_out(spike_s_out),
        .data_int_out(data_int_out),
        .data_int_out_sums(data_int_out_sums),
        .dout_port4_sm1(dout_port4_sm1),
        .dout_port4_sm2(dout_port4_sm2),
        .data_in_sm1(data_in_sm1_w),
        .data_in_sm2(data_in_sm2_w),
        .data_in_intmem1(data_in_intmem1_w),
        .data_in_intmem2(data_in_intmem2_w),
        .o_valid_last_layer(o_valid_last_layer_w),
        .start_inf_dd(start_inf_dd),
        .en_pipe(en_pipe_w),
        .end_inference(end_inference_w),
        .rd_en_sm(rd_en_sm_w),
        .valid_data_mmu(valid_data_mmu_w),
        .wr_en_sm1(wr_en_sm1_w),
        .wr_en_sm2(wr_en_sm2_w),
        .wr_en_intmem1(wr_en_intmem1_w),
        .wr_en_intmem2(wr_en_intmem2_w),
        .block_rd_cnt_lif(block_rd_cnt_lif_w),
        .last_instr(last_instr_w),
        .valid_instr(valid_instr_w),
        .en_datapath(en_datapath_w),
        .use_v(use_v_w),
        .empty_stack(empty_stack_w),
        .use_stack(use_stack_w),
        .v_gen_id(v_gen_id_w),
        .mode(mode_w),
        .r_en_ext(r_en_ext_w),
        .en_port_wr(en_port_wr_w),
        .wr_addr_sm1(wr_addr_sm1_w),
        .wr_addr_sm2(wr_addr_sm2_w),
        .rd_addr_sm1(rd_addr_sm1_w),
        .rd_addr_sm2(rd_addr_sm2_w),
        .wr_addr_intmem1(wr_addr_intmem1_w),
        .wr_addr_intmem2(wr_addr_intmem2_w),
        .rd_addr_intmem1(rd_addr_intmem1_w),
        .rd_addr_intmem2(rd_addr_intmem2_w),
        .i_clr_valid_ll_ext(i_clr_valid_ll_ext),
        .o_data_last_layer(o_data_last_layer_w),
        .valid_op_mmu(valid_op_mmu_w),
        .spike_bin(spike_bin),
        .input_adr(input_adr),
        .load_input_stack_entries(load_input_stack_entries)
    );
    


    // Collegamento delle uscite ai registri pipeline
    assign clr = clr_r;
    assign voltage_decay = voltage_decay_r;
    assign threshold = threshold_r;
    assign data_in_sm1 = data_in_sm1_r;
    assign data_in_sm2 = data_in_sm2_r;
    assign data_in_intmem1 = data_in_intmem1_r;
    assign data_in_intmem2 = data_in_intmem2_r;
    assign o_valid_last_layer = o_valid_last_layer_r;
    assign en_pipe = en_pipe_r;
    assign end_inference = end_inference_r;
    assign rd_en_sm = rd_en_sm_r;
    assign valid_data_mmu = valid_data_mmu_r;
    assign wr_en_sm1 = wr_en_sm1_r;
    assign wr_en_sm2 = wr_en_sm2_r;
    assign wr_en_intmem1 = wr_en_intmem1_r;
    assign wr_en_intmem2 = wr_en_intmem2_r;
    assign block_rd_cnt_lif = block_rd_cnt_lif_r;
    assign last_instr = last_instr_r;
    assign valid_instr = valid_instr_r;
    assign en_datapath = en_datapath_r;
    assign use_v = use_v_r;
    assign empty_stack = empty_stack_r;
    assign use_stack = use_stack_r;
    assign v_gen_id = v_gen_id_r;
    assign mode = mode_r;
    assign r_en_ext = r_en_ext_r;
    assign en_port_wr = en_port_wr_r;
    assign wr_addr_sm1 = wr_addr_sm1_r;
    assign wr_addr_sm2 = wr_addr_sm2_r;
    assign rd_addr_sm1 = rd_addr_sm1_r;
    assign rd_addr_sm2 = rd_addr_sm2_r;
    assign wr_addr_intmem1 = wr_addr_intmem1_r;
    assign wr_addr_intmem2 = wr_addr_intmem2_r;
    assign rd_addr_intmem1 = rd_addr_intmem1_r;
    assign rd_addr_intmem2 = rd_addr_intmem2_r;
    assign o_data_last_layer = o_data_last_layer_r;
    assign valid_op_mmu = valid_op_mmu_r;

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