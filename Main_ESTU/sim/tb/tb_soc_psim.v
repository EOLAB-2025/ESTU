`timescale 1ns/1ps
module tb_soc_psim;

reg clk = 0;
reg rst = 1;
always #41.67 clk = ~clk;   // 12 MHz

reg         rxd = 1;      
wire        txd;             
wire [3:0]  led;             
reg  [2:0]  buttons = 3'b000;

/* SPI Flash */
wire o_flash_sck, o_flash_ss, o_flash_mosi;
wire i_flash_miso;

soc dut (
    .i_clk        (clk),
    .i_rst        (rst),
    .i_rxd        (rxd),
    .buttons      (buttons),
    .led          (led),
    .o_txd        (txd),
    .i_flash_miso (i_flash_miso),
    .o_flash_sck  (o_flash_sck),
    .o_flash_ss   (o_flash_ss),
    .o_flash_mosi (o_flash_mosi)
);

spiflash spi_flash (
    .csb (o_flash_ss),
    .clk (o_flash_sck),
    .io0 (o_flash_mosi),   // MOSI
    .io1 (i_flash_miso),   // MISO
    .io2 (), .io3 ()
);

uart_decoder #(
    .BAUD_RATE(3000000)      
    ) uart_mon (
    .rx(txd)                   
    );

initial begin
    $display("[%0t] Inizio TB", $time);
    $dumpfile("tb_soc_psim.vcd");
    // $dumpvars(0, tb_soc_psim);

    #200;
    $display("[%0t] Deassert reset", $time);
    rst = 0;

    #1_000_000_000;
    $display("[%0t] Fine timeout", $time);
    $finish;
end

endmodule
