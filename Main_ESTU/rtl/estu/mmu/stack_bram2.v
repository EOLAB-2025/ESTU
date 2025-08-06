`timescale 1ns / 1ps

module stack_bram2
#(
    parameter DATA_WIDTH = 10,   
    // 3200 entries for the 4 heads of V and 128 for each stack frame used (e.g. used in Dense(spike,int) layers)  
    // Each frame has a location used to store the number of active entries in the frame (in the first frame address)
    parameter DEPTH      = 3468,
    parameter INIT_STACK = "", // Specify name/location of RAM initialization file if using one (leave blank if not)
    parameter DIM_OFFSET_STACK = 6
)
(
    input clk, rst, load_instr,
    input [DATA_WIDTH-1:0] din,    
    input r_en_ext, // From the FSM
    input load_push_stack, // From the FSM
    input wr_en, 
    input clr,      
    input stream_out, 
    input valid_read_op, // Flag to indicate that the read operation is terminated
    input valid_data,
    input [clogb2(DEPTH-1)-1:0] stack_wbaddr, // From IM. Base address of the stack frame used in write stage
    input [clogb2(DEPTH-1)-1:0] stack_rbaddr, // From IM. Base address of the stack frame used in read stage
    input [DIM_OFFSET_STACK-1:0] ext_offset_stack, // From IM.
    input use_v, // From IM. Flag to indicate that the stack is used in the matmul(spike,int)
    input v_gen_id, // From IM. Flag to indicate that the stack is used in the V-generation stage
    input first_timestep,
    input load_stack_wentries_en,
    input offset_mm_si,
    input valid_data_ext, // Valid data signal from the external module
    // Outputs
    output [DATA_WIDTH-1:0] dout,  
    output done,  
    output empty,
    output valid_addr     
);
    // Internal signals
    // Push
    wire sel_push;
    wire [clogb2(DEPTH)-1:0] offset_p_baddr;
    wire [DATA_WIDTH-1:0] curr_wentries_nxt; 
    wire [DATA_WIDTH-1:0] init_value_pop_cnt; 
    reg [DATA_WIDTH-1:0] curr_wentries;
    reg load_push_stack_d;
    reg wr_en_d;
    // Pop
    wire r_en;
    wire load;
    reg [clogb2(DEPTH)-1:0] stream_cnt;
    wire [clogb2(DEPTH)-1:0] stream_cnt_nxt;
    wire valid_addr_stack;
    // Offset V
    reg [clogb2(DEPTH-1)-1:0] offset_v;
    reg [clogb2(DEPTH-1):0] offset_v_mm;
    wire en_offset_v;
    wire and_done_usev, and_vgenid_validdata;
    // Others
    reg valid_addr_stack_d;
    reg valid_data_d;
    reg valid_data_dd;
    reg valid_data_ddd;

    // ----------------------------- Ctrl Stack --------------------------------
    always @(posedge clk) begin 
        if (rst | clr) begin
            valid_data_d <= 0;
            valid_data_dd <= 0;
            valid_data_ddd <= 0;
        end
        else begin
            valid_data_d <= valid_data;
            valid_data_dd <= valid_data_d;
            valid_data_ddd <= valid_data_dd;
        end
    end
    // ----------------------------- Ctrl Stack --------------------------------


    // ----------------------------- Stack Memory --------------------------------
    wire [DATA_WIDTH-1:0] bram_dout;
    wire [clogb2(DEPTH-1)-1:0] bram_addrb;
    wire [clogb2(DEPTH-1)-1:0] bram_addra;
    wire [DATA_WIDTH-1:0] bram_dina;
    wire bram_wea;
    wire enb;
    wire load_stack_wentries_pulse;
    // test
    reg load_stack_wentries_d;
    always @(posedge clk) begin
        if (rst | clr)
            load_stack_wentries_d <= 1'b0;
        else
            load_stack_wentries_d <= load_stack_wentries_en;
    end

    reg load_stack_wentries_pulse_d;
    reg load_stack_wentries_pulse_dd;
    always @(posedge clk) begin
        if (rst | clr) begin
            load_stack_wentries_pulse_d <= 1'b0;
            load_stack_wentries_pulse_dd <= 1'b0;
        end
        else begin
            load_stack_wentries_pulse_d <= load_stack_wentries_pulse;
            load_stack_wentries_pulse_dd <= load_stack_wentries_pulse_d;
        end
    end

    assign load_stack_wentries_pulse = load_stack_wentries_en & ~load_stack_wentries_d;

    reg pulse_usev_renext_latched;

    always @(posedge clk) begin
        if (rst | clr) begin
            pulse_usev_renext_latched <= 1'b0;
        end else if (use_v & r_en_ext & ~pulse_usev_renext_latched) begin
            pulse_usev_renext_latched <= 1'b1;
        end 
    end

    // Stack signal assignments
    assign bram_addrb = r_en_ext&~pulse_usev_renext_latched ? ((v_gen_id|load_stack_wentries_pulse_d) ? offset_p_baddr : (offset_v+stack_rbaddr)) : ((v_gen_id&valid_data_dd) ? offset_p_baddr : (stream_cnt + offset_v));
    assign enb = r_en | r_en_ext;
    assign bram_addra = sel_push ? offset_p_baddr : (offset_p_baddr + curr_wentries + (((use_v&(~load_stack_wentries_en))|v_gen_id) ? 1'b0 : 1'b1));
    // assign bram_dina = sel_push ? curr_wentries : din;
    assign bram_dina = sel_push ? ((use_v&(~load_stack_wentries_en)) ? ((curr_wentries==1) ? 1'b0 : (curr_wentries-1)): curr_wentries) : din;
    // assign bram_dina = sel_push ? ((use_v&(curr_wentries==1)) ? 1'b0: curr_wentries) : din;
    assign bram_wea = (v_gen_id&valid_data_d) | valid_read_op | wr_en;

    BRAM_singlePort_readFirst
    #(
    .RAM_WIDTH(DATA_WIDTH), // Specify RAM data width
    .RAM_DEPTH(DEPTH), // Specify RAM depth (number of entries)
    .RAM_PERFORMANCE("LOW_LATENCY"), // Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
    .INIT_FILE(INIT_STACK) // Specify name/location of RAM initialization file if using one (leave blank if not)
    )
    bram_stack
    (
        .addra(bram_addra), // write address
        .addrb(bram_addrb), // read address
        .dina(bram_dina),  // write data
        .clk(clk),
        .wea(bram_wea), // write enable
        .ena(1'b1), // enable of the write port
        .enb(enb), // enable of the read port
        .rst(rst),
        .regceb(1'b1), 
        .doutb(bram_dout)
    ); 
    // ----------------------------- End Stack Memory --------------------------------



    // ----------------------------- Push stack --------------------------------
    always @(posedge clk) begin
        if (rst | clr) begin
            load_push_stack_d <= 0;
        end
        else begin
            load_push_stack_d <= load_push_stack;
        end
    end
    
    always @(posedge clk) begin
        if (rst | clr) begin
            wr_en_d <= 0;
        end
        else begin
            wr_en_d <= wr_en;
        end
    end

    always @(posedge clk) begin
        if (rst | clr | load_instr) begin
            curr_wentries <= (use_v|v_gen_id) ? 1'b1 : 1'b0;
            //curr_wentries <= 1;
        end
        else if (v_gen_id & valid_data_ddd) 
            curr_wentries <= curr_wentries_nxt;
        else if (v_gen_id & wr_en)
            curr_wentries <= curr_wentries_nxt;
        else if (v_gen_id & load_stack_wentries_pulse_dd)
            curr_wentries <= curr_wentries_nxt;
        else if (wr_en&use_v)
            curr_wentries <= curr_wentries_nxt;
        else if (wr_en&~v_gen_id&~use_v  | load_stack_wentries_pulse_dd&use_v) begin
            curr_wentries <= curr_wentries_nxt;
        end
    end
    assign offset_p_baddr = stack_wbaddr + (v_gen_id ?  offset_v: 0);
    assign sel_push = valid_read_op | (valid_data_d & v_gen_id);
    assign init_value_pop_cnt = first_timestep ? 1 : (bram_dout); // If first timestep, initialize the number of active entries to 1, otherwise use the value read from the stack memory plus the offset_mm_si
    assign curr_wentries_nxt = (load_push_stack_d&~use_v&~v_gen_id | load_stack_wentries_pulse_dd&use_v | (valid_data_ddd | load_stack_wentries_pulse_dd)&v_gen_id) ? init_value_pop_cnt : curr_wentries+1;
    // ----------------------------- End Push stack --------------------------------



    // ----------------------------- Pop stack --------------------------------

    stack_fsm_pop stack_fsm_pop_inst (
        .clk(clk),
        .rst(rst),
        .stream_out(load_stack_wentries_en ? load_stack_wentries_pulse_d : stream_out),
        .done(done),
        .last_op(valid_read_op),
        .use_v(use_v),
        .valid_data(valid_data_ext),
        .r_en(r_en),
        .load(load),
        .valid_addr_stack(valid_addr_stack)
    );

    // Load signal is used to load the number of active entries to read into the rd_active_entries register
    reg signed [DATA_WIDTH:0] rd_active_entries;

    // Load of the number of active entries to read into the rd_active_entries register
    always @(posedge clk) begin
        if (rst | clr) begin
            rd_active_entries <= 0;
        end
        else if (load) begin
            rd_active_entries <= bram_dout;
        end
    end

    // stream_cnt set the logical read address of the stack
    always @(posedge clk) begin
        if (rst | clr | stream_out) begin
            stream_cnt <= stack_rbaddr;
        end
        else if (done) // if not using v the logic rd address starts from the base address of the stack frame plus 1 (skip the active entries reading phase)
            stream_cnt <= stack_rbaddr + (use_v ? 0 : 1);
        else if (r_en)  // Increment logic stack read address
            stream_cnt <= stream_cnt_nxt;
    end
    assign stream_cnt_nxt = stream_cnt + 1'b1; // Increment logic stack read address
    
    reg load_d;
    always @(posedge clk) begin
        if (rst | clr) begin
            load_d <= 0;
        end
        else begin
            load_d <= load;
        end
    end
    assign done = ( ((use_v) ?(rd_active_entries == 1) : (rd_active_entries == 0)) || (rd_active_entries+stack_rbaddr == stream_cnt)) && (use_v ? valid_addr_stack : (valid_addr_stack_d | load_d | valid_addr_stack));
    //assign done = (( (use_v|v_gen_id) ?(rd_active_entries == 1) : (rd_active_entries == 0)&(load_d)) || (rd_active_entries+stack_rbaddr - (offset_mm_si ? 1 : 0) == stream_cnt)) && (use_v ? valid_addr_stack : valid_addr_stack_d);
    // ----------------------------- End Pop stack --------------------------------


    // ----------------------------- Offset V --------------------------------
    // Offset used both in the push and pop stack stages. It is used to increment the read address of the stack
    // in the V-generation stage.
    assign and_done_usev = done & use_v;
    assign and_vgenid_validdata = valid_data_d & v_gen_id;
    assign en_offset_v = and_done_usev | and_vgenid_validdata;

    always @(posedge clk) begin
        if (rst | clr | stream_out) begin
            offset_v <= 0;
        end
        else if (en_offset_v) begin
            offset_v <= offset_v + ext_offset_stack;
        end
    end
    // ----------------------------- End Offset V --------------------------------
    
    always @(posedge clk) begin
        if (rst | clr) begin
            valid_addr_stack_d <= 0;
        end
        else begin
            valid_addr_stack_d <= valid_addr_stack;
        end
    end

    assign empty = (((use_v&(~load_stack_wentries_en)) |v_gen_id) ? (rd_active_entries == 1) : (rd_active_entries == 0));
    //assign empty = (rd_active_entries == 0);
    assign valid_addr = use_v ? valid_addr_stack : (valid_addr_stack | valid_addr_stack_d);
    assign dout = valid_addr ? bram_dout : 0;
    

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