
import serial
import os

SERIAL_PORT = '/dev/ttyUSB1'
BAUDRATE    = 3000000
TIMEOUT     = 60  # seconds
OUTPUT_FILE = 'output/serial_dump.txt'

def main():

    os.makedirs(os.path.dirname(OUTPUT_FILE), exist_ok=True)

    with serial.Serial(SERIAL_PORT, BAUDRATE, timeout=TIMEOUT) as ser:
        resp = ser.read(1600)

        if resp:
            print(f"Ricevuti {len(resp)} byte. Scrivo su {OUTPUT_FILE}")
            with open(OUTPUT_FILE, 'w') as f:
                for b in resp:
                    f.write(f"{b:02X}\n")
        else:
            print("Nessuna risposta dalla porta seriale.")

if __name__ == "__main__":
    main()

