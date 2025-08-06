def generate_instruction(signals):
    # Concatenare i segnali di controllo nell'ordine specificato
    instruction_bin = ''.join(signals.values())
    num_bits = len(instruction_bin)
    instruction_hex = hex(int(instruction_bin, 2))[2:].upper()
    return num_bits, instruction_bin, instruction_hex

def split_instruction(instruction_bin, chunk_size):
    # Divide la stringa binaria in blocchi di chunk_size, aggiungendo padding di zeri all'ultimo blocco se necessario
    chunks = []
    for i in range(0, len(instruction_bin), chunk_size):
        chunk = instruction_bin[i:i+chunk_size]
        if len(chunk) < chunk_size:
            chunk = chunk.ljust(chunk_size, '0')  # padding a destra
        chunks.append(chunk)
    return chunks

CHUNK_SIZE = 32  # Parametrico: dimensione del frammento in bit


instructions = [
    # Embedding
    #  0 Op. 1.1 dense spike int
    {
        'stack_rbaddr' : '110100000001', # DIM_STACK_BADDR 3329 - Stack 1
        'stack_wbaddr' : '110011100001', # DIM_STACK_BADDR 3297 - Stack 2
        'ext_offset_stack' : '000000', # DIM_OFFSET
        'v_gen_id' : '0', # DIM_VGEN_ID
        'use_v' : '0', # DIM_USE_V
        'mode' : '01010', # DIM_MODE = 5
        'num_input_neurons' : '000000', # DIM_INPUT_NEURONS = 6
        'num_output_neurons' : '0000010000', # DIM_OUTPUT_NEURONS = 10
        'r_baddr1' : '00111110110000', # 4016 Address from SPRAM1
        'r_baddr2' : '00000000000000', # DIM_MAX_MEM
        'use_stack' : '1', # DIM_USESTACK
        'addr_offset_ext' : '0001000', # DIM_OFFSET
        'wr_baddr1' : '00110011010100', # DIM_MAX_MEM
        'wr_baddr2' : '00110011010100', # DIM_MAX_MEM
        'k_gen_id' : '0', # DIM_KGEN_ID
        'raddr_sel' : '0011', # DIM_RADDR_SEL
        'ren' : '1101', # DIM_REN
        'wen' : '0010', # DIM_WEN
        'voltage_decay' : '00100000000000',
        'threshold' : '00000000011000010001',
        'load_stack_wentries_en' : '0',
        'en_wr_stack' : '0'
    },

    # 6 Op. 1.2 dense spike int
    {
        'stack_rbaddr' : '110011100001', # DIM_STACK_BADDR
        'stack_wbaddr' : '110011000000', # DIM_STACK_BADDR
        'ext_offset_stack' : '000000', # DIM_OFFSET
        'v_gen_id' : '0', # DIM_VGEN_ID
        'use_v' : '0', # DIM_USE_V
        'mode' : '01010', # DIM_MODE = 5
        'num_input_neurons' : '000000', # DIM_INPUT_NEURONS = 6
        'num_output_neurons' : '0000010000', # DIM_OUTPUT_NEURONS = 10
        'r_baddr1' : '00110011010100', # DIM_MAX_MEM
        'r_baddr2' : '00001000000000', # DIM_MAX_MEM
        'use_stack' : '1', # DIM_USESTACK
        'addr_offset_ext' : '0010000', # DIM_OFFSET
        'wr_baddr1' : '00110011010100', # DIM_MAX_MEM
        'wr_baddr2' : '00110011010100', # DIM_MAX_MEM
        'k_gen_id' : '0', # DIM_KGEN_ID
        'raddr_sel' : '0011', # DIM_RADDR_SEL
        'ren' : '1110', # DIM_REN
        'wen' : '0001', # DIM_WEN
        'voltage_decay' : '00100000000000',
        'threshold' : '00000000100001110010',
        'load_stack_wentries_en' : '0',
        'en_wr_stack' : '0'
    },

    # 12 Op. 1.2 sum spike spike
    {
        'stack_rbaddr' : '000000000000', # DIM_STACK_BADDR
        'stack_wbaddr' : '000000000000', # DIM_STACK_BADDR
        'ext_offset_stack' : '000000', # DIM_OFFSET
        'v_gen_id' : '0', # DIM_VGEN_ID
        'use_v' : '0', # DIM_USE_V
        'mode' : '00100', # DIM_MODE = 5
        'num_input_neurons' : '010001', # DIM_INPUT_NEURONS = 6
        'num_output_neurons' : '0000100000', # DIM_OUTPUT_NEURONS = 10
        'r_baddr1' : '00110011010100', # DIM_MAX_MEM
        'r_baddr2' : '00110011010100', # DIM_MAX_MEM
        'use_stack' : '0', # DIM_USESTACK
        'addr_offset_ext' : '0000000', # DIM_OFFSET
        'wr_baddr1' : '01101110011000', # 7064
        'wr_baddr2' : '01101110011000', # 7064
        'k_gen_id' : '0', # DIM_KGEN_ID
        'raddr_sel' : '0000', # DIM_RADDR_SEL
        'ren' : '0011', # DIM_REN
        'wen' : '1000', # DIM_WEN
        'voltage_decay' : '00111001100001',
        'threshold' : '00000000000000000110',
        'load_stack_wentries_en' : '0',
        'en_wr_stack' : '0'
    },

    # ------------------------------ Attention Layer ------------------------------
    # 18 Op. 2.1 - Dense int int (Q)
    {
        'stack_rbaddr' : '000000000000', # DIM_STACK_BADDR
        'stack_wbaddr' : '000000000000', # DIM_STACK_BADDR
        'ext_offset_stack' : '000000', # DIM_OFFSET
        'v_gen_id' : '0', # DIM_VGEN_ID
        'use_v' : '0', # DIM_USE_V
        'mode' : '01001', # DIM_MODE = 5
        'num_input_neurons' : '100000', # DIM_INPUT_NEURONS = 6
        'num_output_neurons' : '0000010000', # DIM_OUTPUT_NEURONS = 10
        'r_baddr1' : '01101110011000', # DIM_MAX_MEM
        'r_baddr2' : '01101110011000', # DIM_MAX_MEM 00011000000000
        'use_stack' : '0', # DIM_USESTACK
        'addr_offset_ext' : '0100000', # DIM_OFFSET
        'wr_baddr1' : '00000000000000', # DIM_MAX_MEM
        'wr_baddr2' : '00000000000000', # DIM_MAX_MEM
        'k_gen_id' : '0', # DIM_KGEN_ID
        'raddr_sel' : '1000', # DIM_RADDR_SEL
        'ren' : '1100', # DIM_REN
        'wen' : '0001', # DIM_WEN
        'voltage_decay' : '00100000000000',
        'threshold' : '00000001000010001010',
        'load_stack_wentries_en' : '0',
        'en_wr_stack' : '0'
    },


    # ------------------------------ K Generation ------------------------------
    # 24 Op. 2.21 - Dense int int (K0)
    {
        'stack_rbaddr' : '000000000000', # DIM_STACK_BADDR
        'stack_wbaddr' : '000000000000', # DIM_STACK_BADDR
        'ext_offset_stack' : '000000', # DIM_OFFSET
        'v_gen_id' : '0', # DIM_VGEN_ID
        'use_v' : '0', # DIM_USE_V
        'mode' : '01001', # DIM_MODE = 5
        'num_input_neurons' : '100000', # DIM_INPUT_NEURONS = 6
        'num_output_neurons' : '0000000100', # DIM_OUTPUT_NEURONS = 10
        'r_baddr1' : '01101110011000', # DIM_MAX_MEM
        'r_baddr2' : '10001110011000', # DIM_MAX_MEM 00011000000000
        'use_stack' : '0', # DIM_USESTACK
        'addr_offset_ext' : '0100000', # DIM_OFFSET
        'wr_baddr1' : '00000000000000', # DIM_MAX_MEM
        'wr_baddr2' : '00000000000000', # DIM_MAX_MEM
        'k_gen_id' : '1', # DIM_KGEN_ID
        'raddr_sel' : '1000', # DIM_RADDR_SEL
        'ren' : '1100', # DIM_REN
        'wen' : '0010', # DIM_WEN
        'voltage_decay' : '00100000000000',
        'threshold' : '00000000110010000100',
        'load_stack_wentries_en' : '0',
        'en_wr_stack' : '0'
    },
    # 30 Op. 2.22 - Dense int int (K1)
    {
        'stack_rbaddr' : '000000000000', # DIM_STACK_BADDR
        'stack_wbaddr' : '000000000000', # DIM_STACK_BADDR
        'ext_offset_stack' : '000000', # DIM_OFFSET
        'v_gen_id' : '0', # DIM_VGEN_ID
        'use_v' : '0', # DIM_USE_V
        'mode' : '01001', # DIM_MODE = 5
        'num_input_neurons' : '100000', # DIM_INPUT_NEURONS = 6
        'num_output_neurons' : '0000000100', # DIM_OUTPUT_NEURONS = 10
        'r_baddr1' : '01101110011000', # DIM_MAX_MEM
        'r_baddr2' : '10010110011000', # DIM_MAX_MEM 00011000000000
        'use_stack' : '0', # DIM_USESTACK
        'addr_offset_ext' : '0100000', # DIM_OFFSET
        'wr_baddr1' : '00000000000000', # DIM_MAX_MEM
        'wr_baddr2' : '00001100100000', # DIM_MAX_MEM
        'k_gen_id' : '1', # DIM_KGEN_ID
        'raddr_sel' : '1000', # DIM_RADDR_SEL
        'ren' : '1100', # DIM_REN
        'wen' : '0010', # DIM_WEN
        'voltage_decay' : '00100000000000',
        'threshold' : '00000000110010000100',
        'load_stack_wentries_en' : '0',
        'en_wr_stack' : '0'
    },
    # 36 Op. 2.23 - Dense int int (K2)
    {
        'stack_rbaddr' : '000000000000', # DIM_STACK_BADDR
        'stack_wbaddr' : '000000000000', # DIM_STACK_BADDR
        'ext_offset_stack' : '000000', # DIM_OFFSET
        'v_gen_id' : '0', # DIM_VGEN_ID
        'use_v' : '0', # DIM_USE_V
        'mode' : '01001', # DIM_MODE = 5
        'num_input_neurons' : '100000', # DIM_INPUT_NEURONS = 6
        'num_output_neurons' : '0000000100', # DIM_OUTPUT_NEURONS = 10
        'r_baddr1' : '01101110011000', # DIM_MAX_MEM
        'r_baddr2' : '10011110011000', # DIM_MAX_MEM 00011000000000
        'use_stack' : '0', # DIM_USESTACK
        'addr_offset_ext' : '0100000', # DIM_OFFSET
        'wr_baddr1' : '00000000000000', # DIM_MAX_MEM
        'wr_baddr2' : '00011001000000', # DIM_MAX_MEM
        'k_gen_id' : '1', # DIM_KGEN_ID
        'raddr_sel' : '1000', # DIM_RADDR_SEL
        'ren' : '1100', # DIM_REN
        'wen' : '0010', # DIM_WEN
        'voltage_decay' : '00100000000000',
        'threshold' : '00000000110010000100',
        'load_stack_wentries_en' : '0',
        'en_wr_stack' : '0'
    },
    # 42 Op. 2.24 - Dense int int (K3)
    {
        'stack_rbaddr' : '000000000000', # DIM_STACK_BADDR
        'stack_wbaddr' : '000000000000', # DIM_STACK_BADDR
        'ext_offset_stack' : '000000', # DIM_OFFSET
        'v_gen_id' : '0', # DIM_VGEN_ID
        'use_v' : '0', # DIM_USE_V
        'mode' : '01001', # DIM_MODE = 5
        'num_input_neurons' : '100000', # DIM_INPUT_NEURONS = 6
        'num_output_neurons' : '0000000100', # DIM_OUTPUT_NEURONS = 10
        'r_baddr1' : '01101110011000', # DIM_MAX_MEM
        'r_baddr2' : '10100110011000', # DIM_MAX_MEM 00011000000000
        'use_stack' : '0', # DIM_USESTACK
        'addr_offset_ext' : '0100000', # DIM_OFFSET
        'wr_baddr1' : '00000000000000', # DIM_MAX_MEM
        'wr_baddr2' : '00100101100000', # DIM_MAX_MEM
        'k_gen_id' : '1', # DIM_KGEN_ID
        'raddr_sel' : '1000', # DIM_RADDR_SEL
        'ren' : '1100', # DIM_REN
        'wen' : '0010', # DIM_WEN
        'voltage_decay' : '00100000000000',
        'threshold' : '00000000110010000100',
        'load_stack_wentries_en' : '0',
        'en_wr_stack' : '0'
    },



    # 48 Op. 2.31 - Matmul spike int Q0, K0
    {
        'stack_rbaddr' : '000000000000', # DIM_STACK_BADDR
        'stack_wbaddr' : '000000000000', # DIM_STACK_BADDR
        'ext_offset_stack' : '000000', # DIM_OFFSET
        'v_gen_id' : '0', # DIM_VGEN_ID
        'use_v' : '0', # DIM_USE_V
        'mode' : '00000', # DIM_MODE = 5
        'num_input_neurons' : '000000', # DIM_INPUT_NEURONS = 6
        'num_output_neurons' : '0000000000', # DIM_OUTPUT_NEURONS = 10
        'r_baddr1' : '00000000000000', # DIM_MAX_MEM
        'r_baddr2' : '00000000000000', # DIM_MAX_MEM 00011000000000
        'use_stack' : '0', # DIM_USESTACK
        'addr_offset_ext' : '0000000', # DIM_OFFSET
        'wr_baddr1' : '00011000000000', # DIM_MAX_MEM
        'wr_baddr2' : '00011000000000', # DIM_MAX_MEM
        'k_gen_id' : '0', # DIM_KGEN_ID
        'raddr_sel' : '0001', # DIM_RADDR_SEL
        'ren' : '0011', # DIM_REN
        'wen' : '1100', # DIM_WEN
        'voltage_decay' : '00111001100001',
        'threshold' : '00000000000000000110',
        'load_stack_wentries_en' : '0',
        'en_wr_stack' : '0'
    },
    # 54 Op. 2.32 - Matmul spike int Q1, K1
    {
        'stack_rbaddr' : '000000000000', # DIM_STACK_BADDR
        'stack_wbaddr' : '000000000000', # DIM_STACK_BADDR
        'ext_offset_stack' : '000000', # DIM_OFFSET
        'v_gen_id' : '0', # DIM_VGEN_ID
        'use_v' : '0', # DIM_USE_V
        'mode' : '00000', # DIM_MODE = 5
        'num_input_neurons' : '000000', # DIM_INPUT_NEURONS = 6
        'num_output_neurons' : '0000000000', # DIM_OUTPUT_NEURONS = 10
        'r_baddr1' : '00000000000100', # DIM_MAX_MEM
        'r_baddr2' : '00001100100000', # DIM_MAX_MEM 00011000000000
        'use_stack' : '0', # DIM_USESTACK
        'addr_offset_ext' : '0000000', # DIM_OFFSET
        'wr_baddr1' : '00011000110010', # DIM_MAX_MEM
        'wr_baddr2' : '00011000110010', # DIM_MAX_MEM
        'k_gen_id' : '0', # DIM_KGEN_ID
        'raddr_sel' : '0001', # DIM_RADDR_SEL
        'ren' : '0011', # DIM_REN
        'wen' : '1100', # DIM_WEN
        'voltage_decay' : '00111001100001',
        'threshold' : '00000000000000000110',
        'load_stack_wentries_en' : '0',
        'en_wr_stack' : '0'
    },
    # 60 Op. 2.33 - Matmul spike int Q2, K2
    {
        'stack_rbaddr' : '000000000000', # DIM_STACK_BADDR
        'stack_wbaddr' : '000000000000', # DIM_STACK_BADDR
        'ext_offset_stack' : '000000', # DIM_OFFSET
        'v_gen_id' : '0', # DIM_VGEN_ID
        'use_v' : '0', # DIM_USE_V
        'mode' : '00000', # DIM_MODE = 5
        'num_input_neurons' : '000000', # DIM_INPUT_NEURONS = 6
        'num_output_neurons' : '0000000000', # DIM_OUTPUT_NEURONS = 10
        'r_baddr1' : '00000000001000', # DIM_MAX_MEM
        'r_baddr2' : '00011001000000', # DIM_MAX_MEM 00011000000000
        'use_stack' : '0', # DIM_USESTACK
        'addr_offset_ext' : '0000000', # DIM_OFFSET
        'wr_baddr1' : '00011001100100', # DIM_MAX_MEM
        'wr_baddr2' : '00011001100100', # DIM_MAX_MEM
        'k_gen_id' : '0', # DIM_KGEN_ID
        'raddr_sel' : '0001', # DIM_RADDR_SEL
        'ren' : '0011', # DIM_REN
        'wen' : '1100', # DIM_WEN
        'voltage_decay' : '00111001100001',
        'threshold' : '00000000000000000110',
        'load_stack_wentries_en' : '0',
        'en_wr_stack' : '0'
    },
    # 66 Op. 2.34 - Matmul spike int Q3, K3
    {
        'stack_rbaddr' : '000000000000', # DIM_STACK_BADDR
        'stack_wbaddr' : '000000000000', # DIM_STACK_BADDR
        'ext_offset_stack' : '000000', # DIM_OFFSET
        'v_gen_id' : '0', # DIM_VGEN_ID
        'use_v' : '0', # DIM_USE_V
        'mode' : '00000', # DIM_MODE = 5
        'num_input_neurons' : '000000', # DIM_INPUT_NEURONS = 6
        'num_output_neurons' : '0000000000', # DIM_OUTPUT_NEURONS = 10
        'r_baddr1' : '00000000001100', # DIM_MAX_MEM
        'r_baddr2' : '00100101100000', # DIM_MAX_MEM 00011000000000
        'use_stack' : '0', # DIM_USESTACK
        'addr_offset_ext' : '0000000', # DIM_OFFSET
        'wr_baddr1' : '00011010010110', # DIM_MAX_MEM
        'wr_baddr2' : '00011010010110', # DIM_MAX_MEM
        'k_gen_id' : '0', # DIM_KGEN_ID
        'raddr_sel' : '0001', # DIM_RADDR_SEL
        'ren' : '0011', # DIM_REN
        'wen' : '1100', # DIM_WEN
        'voltage_decay' : '00111001100001',
        'threshold' : '00000000000000000110',
        'load_stack_wentries_en' : '0',
        'en_wr_stack' : '0'
    },




    # --------------------------- V Generation ---------------------------
    # 72 Op. 2.41 - Dense int int (V0)
    {
        'stack_rbaddr' : '000000000000', # DIM_STACK_BADDR
        'stack_wbaddr' : '000000000000', # DIM_STACK_BADDR
        'ext_offset_stack' : '110011', # DIM_OFFSET
        'v_gen_id' : '1', # DIM_VGEN_ID
        'use_v' : '0', # DIM_USE_V
        'mode' : '01001', # DIM_MODE = 5
        'num_input_neurons' : '100000', # DIM_INPUT_NEURONS = 6
        'num_output_neurons' : '0000010000', # It is now a shift amount
        'r_baddr1' : '01101110011000', # DIM_MAX_MEM
        'r_baddr2' : '10101110011000', # DIM_MAX_MEM 00011000000000
        'use_stack' : '0', # DIM_USESTACK
        'addr_offset_ext' : '0100000', # DIM_OFFSET
        'wr_baddr1' : '00000000010000', # DIM_MAX_MEM
        'wr_baddr2' : '00000000000000', # DIM_MAX_MEM
        'k_gen_id' : '0', # DIM_KGEN_ID
        'raddr_sel' : '1000', # DIM_RADDR_SEL
        'ren' : '1101', # DIM_REN
        'wen' : '0001', # DIM_WEN
        'voltage_decay' : '00100000000000',
        'threshold' : '00000000110110011000',
        'load_stack_wentries_en' : '1',
        'en_wr_stack' : '0'
    },
    # 78 Op. 2.42 - Dense int int (V1)
    {
        'stack_rbaddr' : '000000000000', # DIM_STACK_BADDR
        'stack_wbaddr' : '001100110000', # DIM_STACK_BADDR
        'ext_offset_stack' : '110011', # DIM_OFFSET
        'v_gen_id' : '1', # DIM_VGEN_ID
        'use_v' : '0', # DIM_USE_V
        'mode' : '01001', # DIM_MODE = 5
        'num_input_neurons' : '100000', # DIM_INPUT_NEURONS = 6
        'num_output_neurons' : '0000010000', # It is now a shift amount
        'r_baddr1' : '01101110011000', # DIM_MAX_MEM
        'r_baddr2' : '10110110011000', # DIM_MAX_MEM 
        'use_stack' : '0', # DIM_USESTACK
        'addr_offset_ext' : '0100000', # DIM_OFFSET
        'wr_baddr1' : '00001100110000', # DIM_MAX_MEM
        'wr_baddr2' : '00000000000000', # DIM_MAX_MEM
        'k_gen_id' : '0', # DIM_KGEN_ID
        'raddr_sel' : '1000', # DIM_RADDR_SEL
        'ren' : '1101', # DIM_REN
        'wen' : '0001', # DIM_WEN
        'voltage_decay' : '00100000000000',
        'threshold' : '00000000110110011000',
        'load_stack_wentries_en' : '1',
        'en_wr_stack' : '0'
    },
    # 84 Op. 2.43 - Dense int int (V2)
    {
        'stack_rbaddr' : '000000000000', # DIM_STACK_BADDR
        'stack_wbaddr' : '011001100000', # DIM_STACK_BADDR
        'ext_offset_stack' : '110011', # DIM_OFFSET
        'v_gen_id' : '1', # DIM_VGEN_ID
        'use_v' : '0', # DIM_USE_V
        'mode' : '01001', # DIM_MODE = 5
        'num_input_neurons' : '100000', # DIM_INPUT_NEURONS = 6
        'num_output_neurons' : '0000010000', # It is now a shift amount
        'r_baddr1' : '01101110011000', # DIM_MAX_MEM
        'r_baddr2' : '10111110011000', # DIM_MAX_MEM 00011000000000
        'use_stack' : '0', # DIM_USESTACK
        'addr_offset_ext' : '0100000', # DIM_OFFSET
        'wr_baddr1' : '00011001010000', # DIM_MAX_MEM
        'wr_baddr2' : '00000000000000', # DIM_MAX_MEM
        'k_gen_id' : '0', # DIM_KGEN_ID
        'raddr_sel' : '1000', # DIM_RADDR_SEL
        'ren' : '1101', # DIM_REN
        'wen' : '0001', # DIM_WEN
        'voltage_decay' : '00100000000000',
        'threshold' : '00000000110110011000',
        'load_stack_wentries_en' : '1',
        'en_wr_stack' : '0'
    },
    # 90 Op. 2.44 - Dense int int (V3)
    {
        'stack_rbaddr' : '000000000000', # DIM_STACK_BADDR
        'stack_wbaddr' : '100110010000', # DIM_STACK_BADDR
        'ext_offset_stack' : '110011', # DIM_OFFSET
        'v_gen_id' : '1', # DIM_VGEN_ID
        'use_v' : '0', # DIM_USE_V
        'mode' : '01001', # DIM_MODE = 5
        'num_input_neurons' : '100000', # DIM_INPUT_NEURONS = 6
        'num_output_neurons' : '0000010000', # It is now a shift amount
        'r_baddr1' : '01101110011000', # DIM_MAX_MEM
        'r_baddr2' : '11000110011000', # DIM_MAX_MEM 00011000000000
        'use_stack' : '0', # DIM_USESTACK
        'addr_offset_ext' : '0100000', # DIM_OFFSET
        'wr_baddr1' : '00100101110000', # DIM_MAX_MEM
        'wr_baddr2' : '00000000000000', # DIM_MAX_MEM
        'k_gen_id' : '0', # DIM_KGEN_ID
        'raddr_sel' : '1000', # DIM_RADDR_SEL
        'ren' : '1101', # DIM_REN
        'wen' : '0001', # DIM_WEN
        'voltage_decay' : '00100000000000',
        'threshold' : '00000000110110011000',
        'load_stack_wentries_en' : '1',
        'en_wr_stack' : '0'
    },


    # --------------------------- Matmul spike int ---------------------------
    # 96 Matmul spike int Q0K0*V0
    {
        'stack_rbaddr' : '000000000000', # DIM_STACK_BADDR
        'stack_wbaddr' : '110011000000', # DIM_STACK_BADDR
        'ext_offset_stack' : '110011', # DIM_OFFSET
        'v_gen_id' : '0', # DIM_VGEN_ID
        'use_v' : '1', # DIM_USE_V
        'mode' : '01010', # DIM_MODE = 5
        'num_input_neurons' : '100000', # Not used
        'num_output_neurons' : '0000000100', # It is now a shift amount
        'r_baddr1' : '00000000010000', # 16 - Spikes of V0
        'r_baddr2' : '00011000000000', # DIM_MAX_MEM 00011000000000
        'use_stack' : '1', # DIM_USESTACK
        'addr_offset_ext' : '1001110', # DIM_OFFSET
        'wr_baddr1' : '00000000000000', # DIM_MAX_MEM
        'wr_baddr2' : '00110010000000', # DIM_MAX_MEM
        'k_gen_id' : '0', # DIM_KGEN_ID
        'raddr_sel' : '0001', # DIM_RADDR_SEL
        'ren' : '1101', # DIM_REN
        'wen' : '0010', # DIM_WEN
        'voltage_decay' : '00100000000000',
        'threshold' : '00000000000001000000',
        'load_stack_wentries_en' : '0',
        'en_wr_stack' : '0'
    },

    # 102 Matmul spike int Q1K1*V1
    {
        'stack_rbaddr' : '001100110000', # DIM_STACK_BADDR
        'stack_wbaddr' : '110011000000', # DIM_STACK_BADDR
        'ext_offset_stack' : '110011', # DIM_OFFSET
        'v_gen_id' : '0', # DIM_VGEN_ID
        'use_v' : '1', # DIM_USE_V
        'mode' : '01010', # DIM_MODE = 5
        'num_input_neurons' : '100000', # Not used
        'num_output_neurons' : '0000000100', # It is now a shift amount
        'r_baddr1' : '00001100110000', # 16 - Spikes of V0
        'r_baddr2' : '00011000110010', # 1586
        'use_stack' : '1', # DIM_USESTACK
        'addr_offset_ext' : '1001110', # DIM_OFFSET
        'wr_baddr1' : '00000000000000', # DIM_MAX_MEM
        'wr_baddr2' : '00110010000000', # DIM_MAX_MEM
        'k_gen_id' : '0', # DIM_KGEN_ID
        'raddr_sel' : '0001', # DIM_RADDR_SEL
        'ren' : '1101', # DIM_REN
        'wen' : '0010', # DIM_WEN
        'voltage_decay' : '00100000000000',
        'threshold' : '00000000000001000000',
        'load_stack_wentries_en' : '1',
        'en_wr_stack' : '0'
    },

    # 108 Matmul spike int Q2K2*V2
    {
        'stack_rbaddr' : '011001100000', # DIM_STACK_BADDR
        'stack_wbaddr' : '110011000000', # DIM_STACK_BADDR
        'ext_offset_stack' : '110011', # DIM_OFFSET
        'v_gen_id' : '0', # DIM_VGEN_ID
        'use_v' : '1', # DIM_USE_V
        'mode' : '01010', # DIM_MODE = 5
        'num_input_neurons' : '100000', # Not used
        'num_output_neurons' : '0000000100', # It is now a shift amount
        'r_baddr1' : '00011001010000', # 16 - Spikes of V0
        'r_baddr2' : '00011001100100', # DIM_MAX_MEM 00011000000000
        'use_stack' : '1', # DIM_USESTACK
        'addr_offset_ext' : '1001110', # DIM_OFFSET
        'wr_baddr1' : '00000000000000', # DIM_MAX_MEM
        'wr_baddr2' : '00110010000000', # DIM_MAX_MEM
        'k_gen_id' : '0', # DIM_KGEN_ID
        'raddr_sel' : '0001', # DIM_RADDR_SEL
        'ren' : '1101', # DIM_REN
        'wen' : '0010', # DIM_WEN
        'voltage_decay' : '00100000000000',
        'threshold' : '00000000000001000000',
        'load_stack_wentries_en' : '1',
        'en_wr_stack' : '0'
    },

    # 114 Matmul spike int Q3K3*V3
    {
        'stack_rbaddr' : '100110010000', # DIM_STACK_BADDR
        'stack_wbaddr' : '110011000000', # DIM_STACK_BADDR
        'ext_offset_stack' : '110011', # DIM_OFFSET
        'v_gen_id' : '0', # DIM_VGEN_ID
        'use_v' : '1', # DIM_USE_V
        'mode' : '01010', # DIM_MODE = 5
        'num_input_neurons' : '100000', # Not used
        'num_output_neurons' : '0000000100', # It is now a shift amount
        'r_baddr1' : '00100101110000', # 16 - Spikes of V0
        'r_baddr2' : '00011010010110', # DIM_MAX_MEM 00011000000000
        'use_stack' : '1', # DIM_USESTACK
        'addr_offset_ext' : '1001110', # DIM_OFFSET
        'wr_baddr1' : '00000000000000', # DIM_MAX_MEM
        'wr_baddr2' : '00110010000000', # DIM_MAX_MEM
        'k_gen_id' : '0', # DIM_KGEN_ID
        'raddr_sel' : '0001', # DIM_RADDR_SEL
        'ren' : '1101', # DIM_REN
        'wen' : '0010', # DIM_WEN
        'voltage_decay' : '00100000000000',
        'threshold' : '00000000000001000000',
        'load_stack_wentries_en' : '1',
        'en_wr_stack' : '0'
    },

    # 120 Dense spike int 
    {
        'stack_rbaddr' : '110011000000', # 3264 - Stack 1
        'stack_wbaddr' : '110011100000', # 3297 - Stack 2
        'ext_offset_stack' : '000000', # DIM_OFFSET
        'v_gen_id' : '0', # DIM_VGEN_ID
        'use_v' : '0', # DIM_USE_V
        'mode' : '01010', # DIM_MODE = 5
        'num_input_neurons' : '000000', # DIM_INPUT_NEURONS = 6
        'num_output_neurons' : '0000010000', # 16 Neurons because we have 64 spikes into 4 neurons
        'r_baddr1' : '00110010000000', # 3200 - spikes from spike mem 2
        'r_baddr2' : '00011011001000', # 1763 - Weights
        'use_stack' : '1', # DIM_USESTACK
        'addr_offset_ext' : '0010000', # DIM_OFFSET
        'wr_baddr1' : '00110010010000', # 3216 - Spike mem1
        'wr_baddr2' : '00110010010000', # DIM_MAX_MEM
        'k_gen_id' : '0', # DIM_KGEN_ID
        'raddr_sel' : '0011', # DIM_RADDR_SEL
        'ren' : '1110', # DIM_REN
        'wen' : '0001', # DIM_WEN
        'voltage_decay' : '00100000000000',
        'threshold' : '00000000111011101100',
        'load_stack_wentries_en' : '0',
        'en_wr_stack' : '0'
    },
    # 126 Sum spike int
    {
        'stack_rbaddr' : '000000000000', # DIM_STACK_BADDR
        'stack_wbaddr' : '000000000000', # DIM_STACK_BADDR
        'ext_offset_stack' : '000000', # DIM_OFFSET
        'v_gen_id' : '0', # DIM_VGEN_ID
        'use_v' : '0', # DIM_USE_V
        'mode' : '10100', # Sum spike int
        'num_input_neurons' : '100000', # 32
        'num_output_neurons' : '0000100000', # DIM_OUTPUT_NEURONS = 10
        'r_baddr1' : '01101110011000', # 7064 int mem 2 
        'r_baddr2' : '00110010010000', # 3216 - spike mem1 
        'use_stack' : '0', # DIM_USESTACK
        'addr_offset_ext' : '0000000', # DIM_OFFSET
        'wr_baddr1' : '11001110011000', # 13208
        'wr_baddr2' : '11001110011000', # 13208
        'k_gen_id' : '0', # DIM_KGEN_ID
        'raddr_sel' : '1100', # DIM_RADDR_SEL
        'ren' : '1001', # DIM_REN
        'wen' : '0100', # DIM_WEN
        'voltage_decay' : '00111001100001',
        'threshold' : '00000000000000000110',
        'load_stack_wentries_en' : '0',
        'en_wr_stack' : '0'
    },

    # Feedforward stage
    # 132 Dense int int 
    {
        'stack_rbaddr' : '000000000000', # DIM_STACK_BADDR
        'stack_wbaddr' : '110011000000', # DIM_STACK_BADDR
        'ext_offset_stack' : '000000', # DIM_OFFSET
        'v_gen_id' : '0', # DIM_VGEN_ID
        'use_v' : '0', # DIM_USE_V
        'mode' : '01001', # DIM_MODE = 5
        'num_input_neurons' : '100000', # DIM_INPUT_NEURONS = 6
        'num_output_neurons' : '0000100000', # It is now a shift amount
        'r_baddr1' : '11001110011000', # 7096 
        'r_baddr2' : '01101110111000', # 13208
        'use_stack' : '0', # DIM_USESTACK
        'addr_offset_ext' : '0100000', # DIM_OFFSET
        'wr_baddr1' : '00110010100000', # DIM_MAX_MEM
        'wr_baddr2' : '00110010100000', # DIM_MAX_MEM
        'k_gen_id' : '0', # DIM_KGEN_ID
        'raddr_sel' : '0100', # DIM_RADDR_SEL
        'ren' : '1100', # DIM_REN
        'wen' : '0010', # DIM_WEN
        'voltage_decay' : '00100000000000',
        'threshold' : '00000001001000000010',
        'load_stack_wentries_en' : '0',
        'en_wr_stack' : '1'
    },
    # 138 Dense spike int FF 1
    {
        'stack_rbaddr' : '110011000000', # 3264 - Stack 1
        'stack_wbaddr' : '110011100000', # 3297 - Stack 2
        'ext_offset_stack' : '000000', # DIM_OFFSET
        'v_gen_id' : '0', # DIM_VGEN_ID
        'use_v' : '0', # DIM_USE_V
        'mode' : '01010', # DIM_MODE = 5
        'num_input_neurons' : '000000', # DIM_INPUT_NEURONS = 6
        'num_output_neurons' : '0000010000', 
        'r_baddr1' : '00110010100000', # 3232 from spike mem 2
        'r_baddr2' : '00101011001000', # 1763 - Weights
        'use_stack' : '1', # DIM_USESTACK
        'addr_offset_ext' : '0100000', # DIM_OFFSET
        'wr_baddr1' : '00110010110000', # 3216 - Spike mem1
        'wr_baddr2' : '00110010110000', # DIM_MAX_MEM
        'k_gen_id' : '0', # DIM_KGEN_ID
        'raddr_sel' : '0011', # DIM_RADDR_SEL
        'ren' : '1110', # DIM_REN
        'wen' : '0001', # DIM_WEN
        'voltage_decay' : '00100000000000',
        'threshold' : '00000000011100110100',
        'load_stack_wentries_en' : '0',
        'en_wr_stack' : '0' # Abilita la scrittura nello stack
    },
    # 144 Sum spike int 1
    {
        'stack_rbaddr' : '000000000000', # DIM_STACK_BADDR
        'stack_wbaddr' : '000000000000', # DIM_STACK_BADDR
        'ext_offset_stack' : '000000', # DIM_OFFSET
        'v_gen_id' : '0', # DIM_VGEN_ID
        'use_v' : '0', # DIM_USE_V
        'mode' : '10100', # Sum spike int
        'num_input_neurons' : '100000', # 32
        'num_output_neurons' : '0000100000', # DIM_OUTPUT_NEURONS = 10
        'r_baddr1' : '11001110011000', # 13208 SPRAM1 
        'r_baddr2' : '00110010110000', # 3216 - spike mem1 
        'use_stack' : '0', # DIM_USESTACK
        'addr_offset_ext' : '0000000', # DIM_OFFSET
        'wr_baddr1' : '10101110111000', # 11192 spram2
        'wr_baddr2' : '10101110111000', # 11192 spram2
        'k_gen_id' : '0', # DIM_KGEN_ID
        'raddr_sel' : '1100', # DIM_RADDR_SEL
        'ren' : '0101', # DIM_REN
        'wen' : '1000', # DIM_WEN
        'voltage_decay' : '00111001100001',
        'threshold' : '00000000000000000110',
        'load_stack_wentries_en' : '0',
        'en_wr_stack' : '0'
    },
        # 150 Dense int int Final
    {
        'stack_rbaddr' : '000000000000', # 3264 - Stack 1
        'stack_wbaddr' : '110011000000', # 3297 - Stack 2
        'ext_offset_stack' : '000000', # DIM_OFFSET
        'v_gen_id' : '0', # DIM_VGEN_ID
        'use_v' : '0', # DIM_USE_V
        'mode' : '01001', # DIM_MODE = 5
        'num_input_neurons' : '100000', # DIM_INPUT_NEURONS = 6
        'num_output_neurons' : '0000001101', 
        'r_baddr1' : '10101110111000', # 11192 sum spike int
        'r_baddr2' : '11001110111000', # 13240 weights
        'use_stack' : '0', # DIM_USESTACK
        'addr_offset_ext' : '0100000', # DIM_OFFSET
        'wr_baddr1' : '00110011000000', # 3216 - Spike mem1
        'wr_baddr2' : '00110011000000', # DIM_MAX_MEM
        'k_gen_id' : '0', # DIM_KGEN_ID
        'raddr_sel' : '1000', # DIM_RADDR_SEL
        'ren' : '1100', # DIM_REN
        'wen' : '0000', # DIM_WEN
        'voltage_decay' : '00100000000000',
        'threshold' : '00000000010001000101',
        'load_stack_wentries_en' : '0',
        'en_wr_stack' : '0' # Abilita la scrittura nello stack
    }
]


DIM_STACK_BADDR = 12 # dimensione in bit dell'indirizzo dello stack
DIM_OFFSET = 6
DIM_VGEN_ID = 1 
DIM_USE_V = 1
DIM_MODE = 5
DIM_INPUT_NEURONS = 5 # numero di neuroni in ingresso
DIM_OUTPUT_NEURONS = 10 # numero di neuroni in uscita
DIM_MAX_MEM = 14 # numero massimo di neuroni in memoria
DIM_USESTACK = 1 # flag per l'uso dello stack
DIM_KGEN_ID = 1 # flag per l'uso del generatore di indirizzi
DIM_RADDR_SEL = 4
DIM_REN = 4 # flag per l'abilitazione della lettura
DIM_WEN = 4 # flag per l'abilitazione della scrittura



# Automatizza la generazione e la stampa delle istruzioni
for idx, control_signals in enumerate(instructions):
    num_bits, instruction_bin, instruction_hex = generate_instruction(control_signals)
    print(f"Istruzione {idx+1}:")
    print(f"  Numero di bit: {num_bits}")
    print(f"  Istruzione binaria: {instruction_bin}")
    print(f"  Istruzione esadecimale: {instruction_hex}")
    print("-----------------------------------------")

with open(r"./instr_mem.txt", "w") as file:
    for idx, control_signals in enumerate(instructions):
        _, instruction_bin, _ = generate_instruction(control_signals)
        chunks = split_instruction(instruction_bin, CHUNK_SIZE)
        print(f"--- Istruzione {idx+1} frammentata ---")
        for i, chunk in enumerate(chunks):
            hex_str = hex(int(chunk, 2))[2:].upper().zfill(CHUNK_SIZE // 4)  # zfill per padding a sinistra
            print(f" Frammento {i+1}:")
            print(f"   Bin: {chunk}")
            print(f"   Hex: {hex_str}")
            file.write(hex_str + "\n")
        print("-------------------------------")

        