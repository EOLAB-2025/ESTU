with open("flash_raw.txt", "r") as fin:
    lines = [line.strip() for line in fin if line.strip()]

with open("flash_input.txt", "w") as fout:
    fout.write("signed char flash[] = {")
    fout.write(", ".join(f"0x{line}" for line in lines))
    fout.write("};\n")

print("Created flash_input.txt.")