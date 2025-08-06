import json

input_json = "data/golden_txns.json"
output_hex = "data/golden_txns.hex"

with open(input_json) as f:
    txns = json.load(f)

with open(output_hex, "w") as out:
    for t in txns:
        out.write(f"{t['ts']} {t['op_id']} {t['mem']} {t['data']}\n")

print(f"File {output_hex} generato con successo.")
 