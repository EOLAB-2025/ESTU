#!/bin/bash

ADDRESS_FILE="address.txt"

# Check if address file exists
if [ ! -f "$ADDRESS_FILE" ]; then
    echo "Error: address file '$ADDRESS_FILE' not found."
    exit 1
fi

# Read ADDRESS into an array
mapfile -t ADDRESS < "$ADDRESS_FILE"

# Ensure ADDRESS are loaded
if [ "${#ADDRESS[@]}" -lt 1 ]; then
    echo "Error: Not enough ADDRESS in '$ADDRESS_FILE'."
    exit 1
fi

# Bulk erase flash
sudo iceprog -b

# Generate binary file
gcc bin_gen.c -o bin_gen
sudo ./bin_gen

# Write weights_1.bin to flash
sudo iceprog -o "${ADDRESS[0]}" -n to_flash/flash_bin.bin

# Optional: read back
rm -f from_flash/*
mkdir -p from_flash
sudo iceprog -o "${ADDRESS[0]}" -R 8192 read.flash
xxd read.flash > from_flash/read_1.txt
rm read.flash

echo "Flash e lettura completate. Controlla from_flash/read_1.txt per verifica."
