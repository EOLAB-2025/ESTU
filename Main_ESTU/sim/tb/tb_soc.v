`timescale 1ns / 1ps

module tb_soc;

  // Clock & Reset
  reg         clk = 0;
  reg         rst = 1;
  always #10 clk = ~clk;         // 12 MHz

  // DUT ports
  reg         rxd = 1;
  wire [3:0]  led;
  wire        txd;
  reg [2:0]   buttons = 3'b000; // No buttons pressed

  // SPI signals
  wire o_flash_sck, o_flash_ss, o_flash_mosi;
  wire i_flash_miso;

  // Instantiate Device Under Test
  soc dut (
    .i_clk         (clk),
    .i_rst         (rst),
    .i_rxd         (rxd),
    .buttons       (buttons),
    .led           (led),
    .o_txd         (txd),
    .i_flash_miso  (i_flash_miso),
    .o_flash_sck   (o_flash_sck),
    .o_flash_ss    (o_flash_ss),
    .o_flash_mosi  (o_flash_mosi)
  );

    uart_decoder #(
    .BAUD_RATE(3000000)      
    ) uart_mon (
    .rx(txd)                   
    );
  // SPI Flash simulation
  spiflash spi_flash (
    .csb(o_flash_ss),
    .clk(o_flash_sck),
    .io0(o_flash_mosi), // MOSI
    .io1(i_flash_miso), // MISO
    .io2(),             // non usati
    .io3()
  );

  initial begin
    // dump waves
    $dumpfile("tb_soc.vcd");
    $dumpvars(0, tb_soc);

    // hold reset
    #200;
    rst = 0;

  end

`ifdef VERIFICATION 
// ===============================================================
//  VERIFICATION BLOCK – ESTU golden-model checker (versione dettagliata)
// ===============================================================
parameter MAX_TRANSACTIONS = 141400;

/* ---------- segnale clock-domain dall'acceleratore ------------- */
wire        wr_en_sm1     = dut.servant.inst_servant_estu.inst_estu.wr_en_sm1;
wire        wr_en_sm2     = dut.servant.inst_servant_estu.inst_estu.wr_en_sm2;
wire        wr_en_intmem1 = dut.servant.inst_servant_estu.inst_estu.wr_en_intmem1;
wire        wr_en_intmem2 = dut.servant.inst_servant_estu.inst_estu.wr_en_intmem2;
wire wb_clk = dut.servant.wb_clk; 
wire [3:0]  data_in_sm1     = dut.servant.inst_servant_estu.inst_estu.data_in_sm1;
wire [3:0]  data_in_sm2     = dut.servant.inst_servant_estu.inst_estu.data_in_sm2;
wire [15:0] data_in_intmem1 = dut.servant.inst_servant_estu.inst_estu.data_in_intmem1;
wire [15:0] data_in_intmem2 = dut.servant.inst_servant_estu.inst_estu.data_in_intmem2;
wire [7:0]  pc_dut          = dut.servant.inst_servant_estu.inst_estu.pc;
wire [7:0]  dut_timestep    = dut.servant.inst_servant_estu.inst_estu.timestep;
wire        o_valid_last_layer = dut.servant.inst_servant_estu.valid_last_layer;
wire [12:0] o_data_last_layer  = dut.servant.inst_servant_estu.data_last_layer;

/* -------------- pulse detector per o_valid_last_layer ---------- */
reg  o_valid_last_layer_d;
wire o_valid_last_layer_pulse = o_valid_last_layer & ~o_valid_last_layer_d;
always @(posedge clk) begin
    if (rst) o_valid_last_layer_d <= 0;
    else     o_valid_last_layer_d <= o_valid_last_layer;
end

/* --------------------- golden-model arrays --------------------- */
reg  [7:0]  golden_ts   [0:MAX_TRANSACTIONS-1];
reg  [4:0]  golden_opid [0:MAX_TRANSACTIONS-1];
reg  [3:0]  golden_mem  [0:MAX_TRANSACTIONS-1];
reg  [32:0] golden_data [0:MAX_TRANSACTIONS-1];

/* ----------------- load transactions once at t=0 -------------- */
integer golden_file, status, count = 0;
initial begin
    golden_file = $fopen("scripts/Python/data/golden_txns.hex","r");
    if (!golden_file) begin
        $fatal(1,"❌ Impossibile aprire golden_txns.hex");
    end
    while (!$feof(golden_file) && count < MAX_TRANSACTIONS) begin
        status = $fscanf(golden_file,"%d %d %h %h\n",
                         golden_ts[count],
                         golden_opid[count],
                         golden_mem[count],
                         golden_data[count]);
        if (status==4) count++;
    end
    $fclose(golden_file);
    $display("✅ Golden-model caricato: %0d transazioni",count);
end

/* ------------------ monitor con debug dettagliato -------------- */
integer index_transaction = 0;
reg     no_error = 1;
wire    global_wren = wr_en_sm1 | wr_en_sm2 | wr_en_intmem1 | wr_en_intmem2;

always @(posedge wb_clk or posedge o_valid_last_layer_pulse) begin
        if (no_error && (index_transaction < MAX_TRANSACTIONS)) begin
            if (global_wren | o_valid_last_layer_pulse) begin
                // 1) Controllo PC
                if (pc_dut != (golden_opid[index_transaction] * 6)) begin
                    $display("Error at transaction %0d and timestep %0d: expected PC %h but got %h",
                             index_transaction, dut_timestep,
                             (golden_opid[index_transaction] * 6), pc_dut);
                    $display("Expected data: %b", golden_data[index_transaction]);
                    $display("[DEBUG] TS %0d | PC DUT %h | op_id golden %d | Expected PC %h",
                             dut_timestep,
                             pc_dut,
                             golden_opid[index_transaction],
                             golden_opid[index_transaction] * 6);
                    no_error = 0;
                    $finish;
                end


                // 2) Verifica scrittura sulla memoria corretta e dato
                case (golden_mem[index_transaction])
                    4'b0001: begin // to spike mem 1
                        if ({wr_en_intmem2, wr_en_intmem1, wr_en_sm2, wr_en_sm1} != golden_mem[index_transaction]) begin
                            $display("Error at transaction %0d and timestep %0d, op_id %d: expected write to spike mem 1 but mem code = %b",
                                     index_transaction, dut_timestep, golden_opid[index_transaction],
                                     {wr_en_intmem2, wr_en_intmem1, wr_en_sm2, wr_en_sm1});
                            no_error = 0;
                        end
                        if (golden_data[index_transaction] != data_in_sm1) begin
                            $display("Error at transaction %0d and timestep %0d, op_id %d: expected data %h but got %h",
                                     index_transaction, dut_timestep, golden_opid[index_transaction],
                                     golden_data[index_transaction], data_in_sm1);
                            no_error = 0;
                        end
                    end

                    4'b0010: begin // to spike mem 2
                        if ({wr_en_intmem2, wr_en_intmem1, wr_en_sm2, wr_en_sm1} != golden_mem[index_transaction]) begin
                            $display("Error at transaction %0d and timestep %0d, op_id %d: expected write to spike mem 2 but mem code = %b",
                                     index_transaction, dut_timestep, golden_opid[index_transaction],
                                     {wr_en_intmem2, wr_en_intmem1, wr_en_sm2, wr_en_sm1});
                            no_error = 0;
                        end
                        if (golden_data[index_transaction] != data_in_sm2) begin
                            $display("Error at transaction %0d and timestep %0d, op_id %d: expected data %h but got %h",
                                     index_transaction, dut_timestep, golden_opid[index_transaction],
                                     golden_data[index_transaction], data_in_sm2);
                            no_error = 0;
                        end
                    end

                    4'b0100: begin // to int mem 1
                        if ({wr_en_intmem2, wr_en_intmem1, wr_en_sm2, wr_en_sm1} != golden_mem[index_transaction]) begin
                            $display("Error at transaction %0d and timestep %0d, op_id %d: expected write to int mem 1 but mem code = %b",
                                     index_transaction, dut_timestep, golden_opid[index_transaction],
                                     {wr_en_intmem2, wr_en_intmem1, wr_en_sm2, wr_en_sm1});
                            no_error = 0;
                        end
                        if (golden_data[index_transaction] != data_in_intmem1) begin
                            $display("Error at transaction %0d and timestep %0d, op_id %d: expected data %h but got %h",
                                     index_transaction, dut_timestep, golden_opid[index_transaction],
                                     golden_data[index_transaction], data_in_intmem1);
                            no_error = 0;
                        end
                    end

                    4'b1000: begin // to int mem 2
                        if ({wr_en_intmem2, wr_en_intmem1, wr_en_sm2, wr_en_sm1} != golden_mem[index_transaction]) begin
                            $display("Error at transaction %0d and timestep %0d, op_id %d: expected write to int mem 2 but mem code = %b",
                                     index_transaction, dut_timestep, golden_opid[index_transaction],
                                     {wr_en_intmem2, wr_en_intmem1, wr_en_sm2, wr_en_sm1});
                            no_error = 0;
                        end
                        if (golden_data[index_transaction] != data_in_intmem2) begin
                            $display("Error at transaction %0d and timestep %0d, op_id %d: expected data %h but got %h",
                                     index_transaction, dut_timestep, golden_opid[index_transaction],
                                     golden_data[index_transaction], data_in_intmem2);
                            no_error = 0;
                        end
                    end

                    4'b1100: begin // to both int mems
                        if ({wr_en_intmem2, wr_en_intmem1, wr_en_sm2, wr_en_sm1} != golden_mem[index_transaction]) begin
                            $display("Error at transaction %0d and timestep %0d, op_id %d: expected write to both int mems but mem code = %b",
                                     index_transaction, dut_timestep, golden_opid[index_transaction],
                                     {wr_en_intmem2, wr_en_intmem1, wr_en_sm2, wr_en_sm1});
                            no_error = 0;
                        end
                        if (golden_data[index_transaction] != {data_in_intmem1, data_in_intmem2}) begin
                            $display("Error at transaction %0d and timestep %0d, op_id %d: expected data %h but got %h",
                                     index_transaction, dut_timestep, golden_opid[index_transaction],
                                     golden_data[index_transaction],
                                     {data_in_intmem1, data_in_intmem2});
                            no_error = 0;
                        end
                    end
                    4'b1111: begin
                        if (golden_data[index_transaction] != {3'b0, o_data_last_layer }) begin
                            $display("Error at transaction %0d ... expected last-layer data %h but got %h",
                                    index_transaction, golden_data[index_transaction], o_data_last_layer);
                            no_error = 0;
                        end
                    end
                    

                    default: begin
                        // Se appare un valore di golden_mem non riconosciuto,
                        // lo consideriamo errore.
                        $display("Error at transaction %0d: golden_mem non valido = %b", index_transaction, golden_mem[index_transaction]);
                        no_error = 0;
                    end
                endcase

                // Passa alla transazione successiva
                index_transaction = index_transaction + 1;
            end
        end

        if (no_error && (index_transaction == MAX_TRANSACTIONS)) begin 
            $display("✅ Verifica completata: nessun errore trovato. Index transazioni: %0d", index_transaction);
            #100;
            $finish;
        end
        
        if (!no_error) begin
          $display("❌ Verifica fallita alla transazione %0d. Index transazioni: %0d", index_transaction, index_transaction);
            $finish;
        end
        
    end
/* ------------------ timeout simulazione ----------------- */
initial begin
    #1_500_000_000;
    if (no_error)
        $display("✅ Verifica completata (timeout): nessun errore. Transazioni = %0d", index_transaction);
    else
        $display("❌ Verifica fallita entro il timeout.");
    $finish;
end
`else

initial begin
    #100_000_000; 
    $finish;
end
`endif // VERIFICATION



endmodule
