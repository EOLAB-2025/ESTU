# modules/init_mem.py

import os
import numpy as np

def four_spikes_to_spikemem(spikes, folder='.', mode="init"):
    """
    Writes spike vector into 4 separate BRAM init files (spike mem).
    4 spikes = 1 nibble, distributed round-robin to 4 files.
    """
    assert mode in ("init", "append")
    array_size = len(spikes)
    assert array_size % 4 == 0

    num_groups = array_size // 4
    brams = [[] for _ in range(4)]

    for group in range(num_groups):
        start = group * 4
        end = start + 4
        bram_idx = group % 4
        brams[bram_idx].append(spikes[start:end])

    for i, bram in enumerate(brams):
        filename = os.path.join(folder, f'INIT_FILE_SM{i+1}.txt')
        file_mode = 'w' if mode == "init" else 'a'
        with open(filename, file_mode) as f:
            for group in bram:
                bin_str = ''.join(str(bit) for bit in group)
                hex_str = f"{int(bin_str, 2):X}"
                f.write(hex_str + '\n')


def matrix_to_parallel_intmem(path_spram1, path_spram2, matrix, mode="init", transpose=True, base_address=0):
    """
    Writes a matrix of int8 to two parallel 16-bit SPRAM files (2 bytes per row).
    """
    arr = np.array(matrix, dtype=np.int8)
    if transpose:
        arr = arr.T

    flat = arr.flatten()
    assert len(flat) % 4 == 0

    spram1_lines = []
    spram2_lines = []
    for i in range(0, len(flat), 4):
        group = flat[i:i+4]
        hex1 = ''.join(f"{(int(x) & 0xFF):02X}" for x in group[:2])
        hex2 = ''.join(f"{(int(x) & 0xFF):02X}" for x in group[2:])
        spram1_lines.append(hex1)
        spram2_lines.append(hex2)

    _write_memory_file(path_spram1, spram1_lines, mode, base_address)
    _write_memory_file(path_spram2, spram2_lines, mode, base_address)


def matrix_to_single_intmem(path_intmem, matrix, mode="init", transpose=True, base_address=0):
    """
    Writes a matrix of int8 to a single 16-bit INTMEM file (2 bytes per row).
    """
    arr = np.array(matrix, dtype=np.int8)
    if transpose:
        arr = arr.T

    flat = arr.flatten()
    assert len(flat) % 2 == 0

    lines = []
    for i in range(0, len(flat), 2):
        group = flat[i:i+2]
        hex_line = ''.join(f"{(int(x) & 0xFF):02X}" for x in group)
        lines.append(hex_line)

    _write_memory_file(path_intmem, lines, mode, base_address)


def _write_memory_file(path, new_lines, mode, base_address):
    """
    Writes or appends lines to a memory file with optional base address offset.
    """
    if mode == "init":
        with open(path, 'w') as f:
            for line in new_lines:
                f.write(line + '\n')
    else:
        if os.path.exists(path):
            with open(path, 'r') as f:
                existing = [x.strip() for x in f]
        else:
            existing = []

        final_len = max(len(existing), base_address + len(new_lines))
        if len(existing) < final_len:
            existing += ["0000"] * (final_len - len(existing))

        for i, line in enumerate(new_lines):
            existing[base_address + i] = line

        with open(path, 'w') as f:
            for line in existing:
                f.write(line + '\n')
