#define SERVANT_GPIO_ADDR       (0xC0000000) // Most significant nibble is 0b1100

// UART peripheral addresses
#define UART_DATA_ADDR          (0x20000000) // Used to write data to the UART
#define UART_SEND_ADDR          (0x20010000) // Used to send data through the UART
#define UART_READY_ADDR         (0x20020000)
#define UART_HP     		    (0x20030000)
// UART RX
#define UART_RXDATA_ADDR        (0x20040000)
#define UART_RXVALID_ADDR       (0x20050000)

// ESTU 
#define ESTU_START_INFERENCE    (0x40000000)
#define ESTU_NUM_INSTRUCTIONS   (0x40010000)
#define ESTU_WREN               (0x40020000)
#define ESTU_SAMPLE_MEM         (0x40030000) 
#define ESTU_ENCODING_BYPASS    (0x40040000) 
#define ESTU_DATA               (0x40050000) 
// EXTERNAL Memory
#define EXTERNAL_MEM_ADDR       (0x60000000) // Used for testing purposes


// ============================ SPI peripheral addresses ===========================
#define SPI_ADDR                (0xA0000000) // Used to store the SPI address to read from
/*
SPI_SEL_MEM_OUT is used to select the memory to write to.
    0 -  Write to INT MEM 1
    1 -  Write to INT MEM 2
    2 -  Write to INPUT BUFFER
    3 -  Write to debug register (to remove)
*/
#define SPI_SEL_MEM_OUT         (0xA0010000) 
#define SPI_READ_SIZE_ADDR      (0xA0020000) // Number of bytes to read from SPI
#define SPI_START_ADDR          (0xA0030000) // Start address for SPI operations
#define SPI_VALID_ADDR          (0xA0040000) // Valid address for SPI operations
#define SPI_DEBUG_ADDR          (0xA0050000) // Debug address for SPI operations

// ============================ Clock Management =================
#define CLOCK_GATE_CTRL         (0xE0000000)