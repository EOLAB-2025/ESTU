#include <stdint.h>
// RISC-V CSR definitions and access classes
#include "riscv-csr.h"
#include "riscv-interrupts.h"
#include "timer.h"
#include "peripherals.h"
#include "constants.h"



#define DEV_WRITE(addr, val)    (*((volatile uint32_t *)(addr)) = val)
#define DEV_READ(addr)          (*((volatile uint32_t *)(addr)))



// ============================ Function Prototypes ===========================
inline static void uart_send(uint32_t data);
static uint32_t uart_recv(void);
static void read_spi(uint32_t spi_addr, uint32_t mem_addr, uint32_t spi_read_size);
static void irq_entry(void) __attribute__((naked));
static int16_t exec_inference();


// ============================ Global Variables ===========================
volatile uint32_t input_buf_adr = 0;
volatile int16_t inference_data = 0;


// ============================ Main Function ===========================
int main(void) {
    // wait for uButton to be pressed on iCEBreaker board
	DEV_WRITE(SERVANT_GPIO_ADDR,0xaaaaaaaa);
	while(DEV_READ(SERVANT_GPIO_ADDR) & 0xf0000000);
	DEV_WRITE(SERVANT_GPIO_ADDR,0x55555555);

    DEV_WRITE(UART_HP, 1); 
    
    // Disable interrupts of RISC-V core    
    clear_csr(mstatus, MSTATUS_MIE_BIT_MASK);
    write_csr(mie, 0);
    write_csr(mtvec, ((uint_xlen_t) irq_entry));

    // Int Mems initialization from SPI
    DEV_WRITE(ESTU_WREN, 1);               
    read_spi(INT_MEM_1_ADDR, INT_MEM1_ID, WEIGHTS_SIZE_1);   
    DEV_WRITE(ESTU_WREN, 2);    
    read_spi(INT_MEM_2_ADDR, INT_MEM2_ID, WEIGHTS_SIZE_2);   
        

    
    // Initialize Encoding Slot and Accelerator
    DEV_WRITE(ESTU_WREN, 0); // Disable CPU writing to the accelerator weight memories
    input_buf_adr = INPUT_BUFFER_ADDR; // Initialize input buffer address
    DEV_WRITE(ESTU_ENCODING_BYPASS, 0); // Disable encoding bypass 
    DEV_WRITE(ESTU_NUM_INSTRUCTIONS, NUM_INSTRUCTIONS);     // Set the number of instructions to execute
    
    // First inference
    DEV_WRITE(ESTU_START_INFERENCE, 1); 
    read_spi(input_buf_adr, INPUT_BUFFER_ID, INPUT_CHANNELS);
    input_buf_adr += OFFSET_CHANNELS; // Increment input buffer address by the size of the input channels
    inference_data = exec_inference();
    uart_send(inference_data); // Send the inference data via UART

    // Setup timer at every sample time 
	mtimer_set_raw_time_cmp(TIME);
    // Enable MIE.MTI
    set_csr(mie, MIE_MTI_BIT_MASK);
    // Global interrupt enable 
    set_csr(mstatus, MSTATUS_MIE_BIT_MASK);

    while(1);

    return 0;
}

// ============================ Function Definitions ===========================
inline static void uart_send(uint32_t data) {
	DEV_WRITE(UART_DATA_ADDR, data);
    DEV_WRITE(UART_SEND_ADDR, 1);
    while(!DEV_READ(UART_READY_ADDR));
}

static uint32_t uart_recv(void) {
    while ((DEV_READ(UART_RXVALID_ADDR) & 1U) == 0) ;
    return (uint32_t)(DEV_READ(UART_RXDATA_ADDR));
}

static void read_spi(uint32_t spi_addr, uint32_t mem_addr, uint32_t spi_read_size) {
    DEV_WRITE(SPI_ADDR, spi_addr); // Flash address to read from
    DEV_WRITE(SPI_SEL_MEM_OUT, mem_addr); // Output memory selection
    DEV_WRITE(SPI_READ_SIZE_ADDR, spi_read_size); // Number of bytes to read from SPI
    DEV_WRITE(SPI_START_ADDR, 1);
    while(DEV_READ(SPI_VALID_ADDR) == 0);
}

static int16_t exec_inference() {
    uint32_t data;
    do {
        data = DEV_READ(ESTU_DATA);
    } while ((data & 0x01) == 0);  
    return (data >> 1) & 0x1FFF;   
}

static void irq_entry(void)  {	
    DEV_WRITE(ESTU_START_INFERENCE, 1); 
    read_spi(input_buf_adr, INPUT_BUFFER_ID, INPUT_CHANNELS);
    input_buf_adr += OFFSET_CHANNELS;// Increment input buffer address by the size of the input channels
    inference_data = exec_inference(); // Execute inference and get the data
    uart_send(inference_data); // Send the inference data via UART
    DEV_WRITE(CLOCK_GATE_CTRL, 1);
    asm volatile("wfi"); 
}
