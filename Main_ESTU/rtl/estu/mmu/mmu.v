`timescale 1ns / 1ps

/*
This module define the memory management unit (MMU) of the Spikeformer. 
It is responsible for generating the read and write addresses and routing them to the correct memory. 
The generated addresses are physical addresses, the Instruction Memory provide some information to the MMU to generate the addresses.
The MMU is composed by:
- The read address generator
- 4 two way muxes for read address routing
- The write address generator

Note that the read enables signals are embedded in the instructions, so the MMU does not generate them.
*/

module mmu#(
    parameter DIM_ADDR_SPIKE_MEM = 12,
    parameter DIM_ADDR_SPRAM = 14,
    parameter DIM_MAX_MEM = 14,// Maximum number of entries in the memory, is the maximum value between DIM_ADDR_SPIKE_MEM and DIM_ADDR_SPRAM
    parameter DIM_INPUT_NEURONS = 9, // Used for the counter cnt_addr_gen and need to count from 0 to 31.
    parameter DIM_OUTPUT_NEURONS = 10, // Used for the counter cnt_control and need to count from 0 to 799.
    parameter DIM_MAX_LOGIC_ADDRESS = 10, // Size of the stack entries. The stack need to store the logic addresses that is maximum 10 bits
    parameter DEPTH_STACK = 3468, // Maximum number of entries in the stack 3200 for the 4 heads of V and 128 for each stack frame used (e.g. used in Dense(spike,int) layers)
    parameter INIT_STACK = "stack_bram_init.mem", // Specify name/location of stack initialization file if using one 
    parameter DATA_WIDTH = 8, // Size of the entries in the SPRAM
    parameter V_COMP_K_Q = 800, // Refers to the number of entries needed to store a single head of Q and K (supposed to be of equal dimension)
    parameter WIDTH_BRAM = 4,
    parameter WIDTH_SPRAM = 16,
    parameter DIM_MODE = 5,
    parameter DIM_GROUP_SPIKES = 2,
    parameter DIM_SUMS_SPIKES = 16,
    parameter NUM_MEMS = 4,
    parameter DIM_OFFSET_STACK = 6,
    parameter DIM_OFFSET = 7, // The number of offset is usually maximum 50 or 51 
    parameter ADDR_STACK = clogb2(DEPTH_STACK-1),
    parameter DIM_NUM_MEMS = clogb2(NUM_MEMS),
    parameter DIM_TIMESTEP = 8,
    parameter IN_STACK_WBADDR = 3329,
    parameter PIPE = 9
)(
    // External signals
    // input [3:0] ext_ctrl,
    // input [WIDTH_SPRAM-1:0] ext_datain_spram1,
    // input [WIDTH_SPRAM-1:0] ext_datain_spram2,
    // input [WIDTH_BRAM-1:0] ext_datain_bram1,
    // input [WIDTH_BRAM-1:0] ext_datain_bram2,
    // Accelerator signals
    input clk, rst,
    input clr,
    input en,
    output reg [PIPE-1:0] en_pipe,
    input [DIM_MODE-1:0] mode,
    input [DIM_INPUT_NEURONS-1:0] num_input_neurons,    // From the IM
    input [DIM_OUTPUT_NEURONS-1:0] num_output_neurons,  // From the IM
    input [DIM_MAX_MEM-1:0] r_baddr1,                    // From the IM
    input [DIM_MAX_MEM-1:0] r_baddr2,                    // From the IM
    input [DIM_MAX_MEM-1:0] wr_baddr1,                    // From the IM
    input [DIM_MAX_MEM-1:0] wr_baddr2,                    // From the IM
    input [NUM_MEMS-1:0] w_en,                  // From the IM
    input use_v,               // From the IM                      
    input use_stack,                                    // From the IM
    input signed [DIM_OFFSET-1:0] addr_offset_ext,  
    input [DIM_OFFSET_STACK - 1 : 0] ext_offset_stack,         // From the IM
    input [3:0] raddr_sel,
    input [DIM_GROUP_SPIKES-1:0] spike_out, // Output of the LIF neuron of 2 bit
    input [DIM_SUMS_SPIKES-1:0] sum_spikes, // Output of the sum(spike,spike) operation or sum(spike,int) 
    input [DATA_WIDTH-1:0] data_int, // Integer data of 8 bit width. Output of the matmul(spike,spike) operation
   
    input v_gen_id, k_gen_id, // From the IM: setted high when V or K matrixes need to be written
    input [ADDR_STACK-1:0] stack_wbaddr, 
    input [ADDR_STACK-1:0] stack_rbaddr, 
    input [WIDTH_BRAM-1:0] group_in_spikes,
    input spike_in,
    input r_en_ext, load_push_stack,
    input [WIDTH_SPRAM - 1 : 0] data_out_intmem1, data_out_intmem2,
    input load_stack_wentries_en,
    input en_wr_stack,
    output end_inference,
    input clr_valid_ll_ext, // Clear the valid when the CPU reads the valid_last_layer_output
    input last_layer,
    input valid_instr,
    input i_wren_spike_ext,
    input [3:0] i_spike_ext,
    input [DIM_MAX_LOGIC_ADDRESS-1:0] i_logic_addr_ext, // External logic address for the stack
    input i_load_input_stack_entries, // Signal to load the input stack entries
    output [DIM_ADDR_SPIKE_MEM-1:0] raddr_spike_mem1, raddr_spike_mem2, wr_addr_bram1, wr_addr_bram2,
    output [DIM_ADDR_SPRAM-1:0] raddr_spram1, raddr_spram2, wr_addr_spram1, wr_addr_spram2,
    output valid_read_op, 
    output reg valid_read_data, 
    output valid_addr_stack_sig,
    output valid_addr_stack_sig_delay,
    output [WIDTH_BRAM - 1 : 0] data_in_bram1,
    output [WIDTH_BRAM - 1 : 0] data_in_bram2,
    output [WIDTH_SPRAM - 1 : 0] data_in_spram1,
    output [WIDTH_SPRAM - 1 : 0] data_in_spram2,
    output wren_bram1, wren_bram2, wren_spram1, wren_spram2,
    output [DIM_TIMESTEP-1:0] timestep,
    output matmul_ss_id,
    output empty,
    output [DIM_MAX_LOGIC_ADDRESS-1:0] wr_addr_cnt,
    output valid_last_layer_output, // Valid signal for the last layer output
    output [12:0] output_last_layer, // Output of the last layer, used for the last layer output
    output o_valid_data_op,
    output en_datapath,
    output block_rd_cnt_lif,
    output rd_en_sm,
    output o_valid_last_layer_pulse,
    input valid_datapath
);
    localparam NUM_SPRAM = 2;
    localparam P_BRAM = 2;
    localparam P_SPRAM = 2; 

    wire valid_result;

    // Wr. Address Generator
    wire [DIM_MAX_LOGIC_ADDRESS - 1 :0] logic_addr;
    wire [DIM_MAX_LOGIC_ADDRESS - 1 : 0] k_ptr, v_ptr;
    wire [1:0] sel_data_int;
    // Wr. controller
    wire active_group_out;
    // Stack
    wire [DIM_MAX_LOGIC_ADDRESS-1:0] stack_ptr;
    wire                done_stack;
    reg done_stack_reg;
    wire                empty_sig;
    wire wren;
    wire offset_mm_si; 
    // Control signals
    wire [DIM_INPUT_NEURONS - 1 : 0] num_input_neurons_mux_stage1;
    wire [DIM_INPUT_NEURONS - 1 : 0] num_input_neurons_mux_stage2;
  


    // ---------------------------- General Control ----------------------------
    assign num_input_neurons_mux_stage1 = num_input_neurons;
    assign num_input_neurons_mux_stage2 = matmul_ss_id ? timestep+1 : num_input_neurons_mux_stage1;
    // ---------------------------- General Control ----------------------------
    


    // ---------------------------- Read Address Generator ----------------------------
    wire [DIM_MAX_MEM-1:0] out1, out2;
    wire valid_data_rdAddr;
    assign valid_read_op = en&(wr_addr_cnt == num_output_neurons);
    integer i;
    localparam PIPE_VALID_DATA = 6; 
    reg [PIPE_VALID_DATA : 0] pipe_valid_data;
    always @(posedge clk) begin
        if (rst || clr || use_v&valid_read_data) begin
            pipe_valid_data <= 0;
        end 
        else begin
            pipe_valid_data[0] <= valid_data_rdAddr;
            for (i = 1; i <= PIPE_VALID_DATA; i=i+1) begin
                pipe_valid_data[i] <= pipe_valid_data[i-1];
            end
        end
    end
    always @(*) begin
        if (mode[2]) begin // sum(spike,spike)
            valid_read_data = en & en_pipe[3] & ~o_valid_data_op;
        end 
        else if (matmul_ss_id) begin // matmul(spike,spike)
            valid_read_data = en & en_pipe[2] & ~o_valid_data_op;
        end 
        else if (use_stack) begin  // Dense spike int
            valid_read_data = pipe_valid_data[6];
        end
        else begin
            valid_read_data = pipe_valid_data[5];
        end
    end
    assign valid_data_op = pipe_valid_data[3];

    read_addr_gen #(
        .DIM_ADDR(DIM_MAX_MEM),
        .DIM_INPUT_NEURONS(DIM_INPUT_NEURONS),
        .DIM_OUTPUT_NEURONS(DIM_OUTPUT_NEURONS),
        .DIM_MAX_LOGIC_ADDRESS(DIM_MAX_LOGIC_ADDRESS),
        .DIM_MODE(DIM_MODE)
    ) read_addr_gen_inst (
        .clk(clk),
        .rst(rst),
        .clr(clr),
        .mode(mode),
        .en(en_rd_addr_gen),
        .num_input_neurons(num_input_neurons_mux_stage2),
        // .num_input_neurons(num_input_neurons),
        .base_addr1(r_baddr1),
        .base_addr2(r_baddr2),
        .use_stack(use_stack),
        .use_v(use_v),
        .done_stack(use_v ? done_stack : done_stack_reg),
        .stack_ptr(stack_ptr),
        .offset_ext({{(DIM_MAX_LOGIC_ADDRESS-DIM_OFFSET){addr_offset_ext[DIM_OFFSET-1]}}, addr_offset_ext}),
        .matmul_ss_id(matmul_ss_id),
        .out1(out1),
        .out2(out2),
        .valid_data(valid_data_rdAddr)
    );

    // 4 two way muxes for read address routing
    wire [DIM_ADDR_SPIKE_MEM-1:0] raddr_spike_mem1_mux1, raddr_spike_mem2_mux1;
    wire [DIM_ADDR_SPRAM-1:0] raddr_spram1_mux1, raddr_spram2_mux2;

    assign raddr_spike_mem1_mux1 = raddr_sel[0] ? out1[DIM_ADDR_SPIKE_MEM-1 : 0] : out2[DIM_ADDR_SPIKE_MEM-1 : 0];
    assign raddr_spike_mem2_mux1 = raddr_sel[1] ? out1[DIM_ADDR_SPIKE_MEM-1 : 0] : out2[DIM_ADDR_SPIKE_MEM-1 : 0];
    assign raddr_spike_mem1 = v_gen_id ? wr_addr_bram1 : raddr_spike_mem1_mux1;
    assign raddr_spike_mem2 = v_gen_id ? wr_addr_bram2 : raddr_spike_mem2_mux1;

    assign raddr_spram1_mux1 = raddr_sel[2] ? out1 : out2;
    assign raddr_spram2_mux2 = raddr_sel[3] ? out1 : out2;
    assign raddr_spram1 = matmul_ss_id ? wr_addr_spram1 : raddr_spram1_mux1;
    assign raddr_spram2 = matmul_ss_id ? wr_addr_spram2 : raddr_spram2_mux2;
    // ---------------------------- End Read Address Generator ----------------------------

    // ---------------------------- Stack ----------------------------
    wire active_group_out_input;
    assign active_group_out_input = i_spike_ext[0] | i_spike_ext[1] | i_spike_ext[2] | i_spike_ext[3]; 
    stack_bram2 #(
    .DATA_WIDTH(DIM_MAX_LOGIC_ADDRESS),
    .DEPTH(DEPTH_STACK),
    .INIT_STACK(),
    .DIM_OFFSET_STACK(DIM_MAX_LOGIC_ADDRESS)
    ) stack_bram_inst (
        .clk(clk),
        .rst(rst),
        .load_instr(valid_instr), // Load the stack with the instruction
        .din(i_wren_spike_ext ? i_logic_addr_ext : logic_addr),
        .r_en_ext(r_en_ext), // Nuovo segnale per abilitare la lettura esterna
        .load_push_stack(load_push_stack), // Nuovo segnale per caricare lo stack
        .wr_en(i_wren_spike_ext ? active_group_out_input : wren & active_group_out & (use_stack | v_gen_id |en_wr_stack)), 
        .clr(clr),
        .stream_out(stream_out),
        .valid_read_op(o_valid_data_op&(use_stack | v_gen_id |en_wr_stack) | i_load_input_stack_entries), // Used to store the current number of entries in the stack
        .valid_data(valid_result), 
        .stack_wbaddr((i_wren_spike_ext|i_load_input_stack_entries) ? IN_STACK_WBADDR : stack_wbaddr),
        .stack_rbaddr(stack_rbaddr),
        .ext_offset_stack({{(DIM_MAX_LOGIC_ADDRESS-DIM_OFFSET_STACK){1'b0}}, ext_offset_stack}),
        .use_v(use_v),
        .v_gen_id(v_gen_id), // Nuovo segnale per identificare la generazione di V
        .first_timestep(first_timestep), // Nuovo segnale per il primo timestep
        .load_stack_wentries_en(load_stack_wentries_en),
        .offset_mm_si(offset_mm_si), 
        .valid_data_ext(valid_read_data),
        .dout(stack_ptr),
        .done(done_stack),
        .empty(empty_sig),
        .valid_addr(valid_addr_stack_sig) // Nuovo segnale per validare l'indirizzo
    );
    always @(posedge clk) begin
        if (rst) begin
            done_stack_reg <= 1'b0;
        end else begin
            done_stack_reg <= done_stack;
        end
    end
    // ---------------------------- End Stack ----------------------------



    // ---------------------------- Write Controller --------------------------------------
    wire wren_bram1_out, wren_bram2_out, wren_spram1_out, wren_spram2_out;
    // Istanziazione del modulo write_controller
    wr_controller #(
        .DATA_WIDTH(DATA_WIDTH),
        .P_SPRAM(P_SPRAM),
        .P_BRAM(P_BRAM),
        .DIM_MODE(DIM_MODE),
        .WIDTH_BRAM(WIDTH_BRAM),
        .WIDTH_SPRAM(WIDTH_SPRAM),
        .DIM_TIMESTEP(DIM_TIMESTEP)
    ) wr_controller_inst (
        //.ext_ctrl(ext_ctrl),
        //.ext_datain_spram1(ext_datain_spram1),
        //.ext_datain_spram2(ext_datain_spram2),
        //.ext_datain_bram1(ext_datain_bram1),    
        //.ext_datain_bram2(ext_datain_bram2),
        // .ext_ctrl(0),
        // .ext_datain_spram1(0),
        // .ext_datain_spram2(0),
        // .ext_datain_bram1(0),    
        // .ext_datain_bram2(0),
        .clk(clk),
        .rst(rst),
        .clr(clr),
        .en(en),
        .valid_data(valid_result),
        .data_int(data_int),
        .sum_spikes(sum_spikes),
        .spike_out(spike_out),
        .mode(mode),
        .timestep(timestep),
        .group_in_spikes(group_in_spikes),
        .new_spike(spike_in),
        .use_v(use_v),
        .v_gen_id(v_gen_id),
        .sel_data_int(sel_data_int),
        .clr_valid_ll_ext(clr_valid_ll_ext), // Clear the valid when the CPU reads the valid_last_layer_output
        .last_layer(last_layer),
        .valid_instr(valid_instr),
        .wren_bram1(wren_bram1_out),
        .wren_bram2(wren_bram2_out),
        .wren_spram1(wren_spram1_out),
        .wren_spram2(wren_spram2_out),
        .data_in_bram1(data_in_bram1),
        .data_in_bram2(data_in_bram2),
        .data_in_spram1(data_in_spram1),
        .data_in_spram2(data_in_spram2),
        .active_group_out(active_group_out),
        .matmul_ss(matmul_ss_id),
        .valid_last_layer_output(valid_last_layer_output),
        .output_last_layer(output_last_layer)
    );
    assign wren_bram1 = wren_bram1_out & w_en[0];
    assign wren_bram2 = wren_bram2_out & w_en[1];
    assign wren_spram1 = wren_spram1_out & w_en[2];
    assign wren_spram2 = wren_spram2_out & w_en[3];
    assign wren = wren_bram1 | wren_bram2 | wren_spram1 | wren_spram2; // Global write enable
    // ---------------------------- End Write Controller ----------------------------

    // -------------------------- WRITE ADDR. GENERATOR --------------------------
    wr_addr_gen #(
        .DIM_MAX_LOGIC_ADDRESS(DIM_MAX_LOGIC_ADDRESS),
        .DIM_MAX_MEM(DIM_MAX_MEM),
        .VCOMP_K_Q(V_COMP_K_Q),
        .DIM_MODE(DIM_MODE),
        .DIM_BRAM(DIM_ADDR_SPIKE_MEM),
        .DIM_SPRAM(DIM_ADDR_SPRAM),
        .DIM_TIMESTEP(DIM_TIMESTEP),
        .DIM_OFFSET(DIM_OFFSET_STACK)
    ) wr_addr_gen_inst (
        .clk(clk),
        .rst(rst),
        .clr(clr),
        .wr_en(wren),
        .mode(mode),
        .wr_baddr1(wr_baddr1),
        .wr_baddr2(wr_baddr2),
        .v_gen_id(v_gen_id),
        .k_gen_id(k_gen_id),
        .valid_op(o_valid_data_op),
        .offset_v_ext(ext_offset_stack-1'b1),
        .matmul_ss_id(matmul_ss_id),
        .use_v(use_v),
        .end_inference(end_inference),
        .logic_addr(logic_addr),
        .dest_addr_bram1(wr_addr_bram1),
        .dest_addr_bram2(wr_addr_bram2),
        .dest_addr_spram1(wr_addr_spram1),
        .dest_addr_spram2(wr_addr_spram2),
        .timestep(timestep),
        .k_ptr(k_ptr),
        .v_ptr(v_ptr),
        .sel_data_int(sel_data_int),
        .gen_cnt(wr_addr_cnt),
        .offset_mm_si(offset_mm_si)
    );
    // ----------------------------------- END WRITE ADDR ----------------------------------------------

// -------------- Additional control
reg pipe_valid_addr_stack_d0;
reg pipe_valid_addr_stack_d1;
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
assign valid_addr_stack_sig_delay = pipe_valid_addr_stack_d1;



// shift register empty signal: è solo un ritardo di pipe_empty, lo metto dentro MMU e mando in uscita solo pipe_empty[i-1]
    localparam PIPE_EMPTY = 3;
    reg pipe_empty [PIPE_EMPTY - 1 : 0];
    always @(posedge clk) begin
        if (rst || clr) begin
            for (i = 0; i < PIPE_EMPTY; i=i+1) begin
                pipe_empty[i] <= 1'b0;
            end
        end 
        else begin
            pipe_empty[0] <= empty_sig;
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
    assign empty = pipe_empty[2];



        reg en_toggle, en_toggle2;
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

        assign en_datapath = 
        (mode[2] & en & ~mode[4])                         ? en_toggle :
        (mode[4] & en)                                    ? (en_toggle & en_pipe[1]) :
        (use_stack & ~use_v)                              ? (en & en_pipe[3]) :
        (use_stack & use_v)                               ? (valid_addr_stack_sig_delay 
                                                            | en_pipe[2] 
                                                            | en_pipe[3] 
                                                            | en_pipe[4]) :
        (mode[3] & ~use_stack)                            ? (en & en_pipe[1]) :
        (matmul_ss_id)                                    ? (en & en_pipe[1]) :
                                                        1'b0;


    // idem si può spostare dentro MMU
    reg en_rd_addr_gen;
    always @(*) begin 
        if (en&mode[2]&~mode[4])
            en_rd_addr_gen = en_toggle2;
        else 
            en_rd_addr_gen = en;
    end

    wire stream_out;
    assign stream_out = use_v ? stream_out_d : valid_instr;
    reg stream_out_d;
        // si può portare dentro MMU insieme a stream_out
    always @(posedge clk) begin
        if (rst || clr) begin
            stream_out_d <= 1'b0;
        end 
        else begin
            stream_out_d <= valid_instr;
        end
    end

    always @(posedge clk) begin
        if (rst || clr  || use_v&valid_read_data) begin
            en_pipe <= 0;
        end 
        else begin
            en_pipe[0] <= en;
            for (i = 1; i < PIPE; i=i+1) begin
                en_pipe[i] <= en_pipe[i-1];
            end
        end
    end

    wire first_timestep;
    assign first_timestep = (timestep == 0);

    reg [DIM_MAX_LOGIC_ADDRESS - 1 : 0] ctrl_acc_clr_and_go;
    always @(posedge clk) begin
        if (rst || clr) begin
            ctrl_acc_clr_and_go <= 0;
        end 
        else if (valid_read_data&block_rd_cnt_lif) begin
            ctrl_acc_clr_and_go <= ctrl_acc_clr_and_go + 1;
        end
    end
    
    assign block_rd_cnt_lif = ~( ctrl_acc_clr_and_go == ((num_output_neurons)<<2) );

    assign rd_en_sm = mode[3] ? valid_addr_stack_sig : en;

    reg o_valid_last_layer_d;
    always @(posedge clk) begin
        if (rst)
            o_valid_last_layer_d <= 1'b0;
        else
            o_valid_last_layer_d <= valid_last_layer_output;
    end

    assign o_valid_last_layer_pulse = valid_last_layer_output & ~o_valid_last_layer_d;
    assign end_inference = valid_last_layer_output & (timestep == 200);
    assign o_valid_data_op = matmul_ss_id ? valid_data_op : (valid_read_op|o_valid_last_layer_pulse);
    assign valid_result = (mode[2]|matmul_ss_id) ? valid_read_data : valid_datapath;
    
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
