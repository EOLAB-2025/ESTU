import os

def group_spikes_max(spikes, group_size=4):
    """
    Groups a binary list into fixed-size chunks and outputs 1 if any element in the group is active.
    Used to detect spike presence per block.
    """
    grouped = []
    for i in range(0, len(spikes), group_size):
        group = spikes[i:i+group_size]
        grouped.append(1 if any(group) else 0)
    return grouped


def bin_groups_to_hex(bin_vector, group_size=4):
    """
    Converts a binary vector into hexadecimal strings, grouping every `group_size` bits.
    Returns a list of hex strings (one per group).
    """
    assert len(bin_vector) % group_size == 0, "Length must be multiple of group_size"
    hex_vector = []
    for i in range(0, len(bin_vector), group_size):
        group = bin_vector[i:i+group_size]
        bin_str = ''.join(str(int(b)) for b in group)
        hex_str = f"{int(bin_str, 2):X}"  # Uppercase, no 0x
        hex_vector.append(hex_str)
    return hex_vector

def write_spikes_to_file(spikes, filepath, base_address=0, mode="w"):
    """
    Scrive gli spikes nel file a partire da base_address.
    Riempie le righe mancanti con zeri.
    """
    assert len(spikes) % 4 == 0, "Spike length must be multiple of 4"

    # 1. Carica il file esistente se c'è (solo se 'a' o 'r+' o altro mode append)
    existing_lines = []
    if os.path.exists(filepath) and mode in ["a", "r+", "w+"]:
        with open(filepath, "r") as f:
            existing_lines = [line.strip() for line in f.readlines()]

    # 2. Costruisci le nuove righe di spike
    new_spike_lines = []
    for i in range(0, len(spikes), 4):
        group = spikes[i:i+4]
        bin_str = ''.join(str(int(b)) for b in group)
        hex_str = f"{int(bin_str, 2):X}"
        new_spike_lines.append(hex_str)

    # 3. Allinea le righe
    total_lines = max(len(existing_lines), base_address + len(new_spike_lines))
    full_lines = []

    for i in range(total_lines):
        if i < len(existing_lines):
            full_lines.append(existing_lines[i])
        elif i < base_address:
            full_lines.append("0")
        elif i - base_address < len(new_spike_lines):
            full_lines.append(new_spike_lines[i - base_address])
        else:
            full_lines.append("0")

    # 4. Scrivi il file aggiornato
    with open(filepath, "w") as f:
        for line in full_lines:
            f.write(line + "\n")

def write_spikes_to_4files(spikes, base_path, base_address=0, width=4):
    assert len(spikes) % width == 0, f"Spike length must be multiple of {width}"

    # Prepara i file paths
    file_paths = [f"{base_path}{i+1}.txt" for i in range(width)]

    # Leggi i contenuti esistenti
    contents = []
    for path in file_paths:
        if os.path.exists(path):
            with open(path, 'r') as f:
                lines = [line.strip() for line in f.readlines()]
        else:
            lines = []
        contents.append(lines)

    # Trova la lunghezza massima tra i file
    max_len = max(len(c) for c in contents)

    # Allunga i file fino al base_address con zeri
    target_len = max(max_len, base_address)
    for i in range(width):
        while len(contents[i]) < target_len:
            contents[i].append('0')

    # Scrivi i nuovi spikes nei file, a rotazione
    for idx, spike in enumerate(spikes):
        file_idx = idx % width
        write_idx = base_address + (idx // width)
        while len(contents[file_idx]) <= write_idx:
            contents[file_idx].append('0')
        contents[file_idx][write_idx] = str(int(spike))

    # Sovrascrivi i file aggiornati
    for i, path in enumerate(file_paths):
        with open(path, 'w') as f:
            for line in contents[i]:
                f.write(line + '\n')

    print(f"Scrittura completata. File aggiornati: {file_paths}")
    
def get_output_path(filename):
    """
    Builds the path to save a file inside the 'outputs' folder.
    """
    output_dir = os.path.join(os.path.dirname(__file__), "..", "..", "outputs")
    os.makedirs(output_dir, exist_ok=True)
    return os.path.join(output_dir, filename)
