# Simulates the output of the QSPI flash memory 

index = 0
clocks = 0

with open("resources/data.bin", "rb") as f:
    data = f.read()

def get_half_byte():
    global index
    if index >= len(data):
        return 15
    if ((clocks % 2) == 0): # Upper Nibble
        output = (data[index] >> 4) & 0x0F
    else: # Lower Nibble
        output = data[index] & 0x0F
        index += 1 # Byte is done
    return output

def clock_data():
    output = get_half_byte()
    global clocks
    clocks += 1
    return output
    