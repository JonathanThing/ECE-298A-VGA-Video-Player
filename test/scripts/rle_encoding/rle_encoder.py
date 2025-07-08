from PIL import Image

img = Image.open("input.png")

width, height = img.size

if (width, height) != (640, 480):
    print(f"Size is {width}x{height}, expected 640x480")

img = img.convert('RGB')

run = 0
colour = (-1, -1, -1) 

# Data format 24 bits
# [5 bit unused][10 bits run][3 bits red][3 bits green][3 bits blue]
def write_rle_instruction(f, run_length, r, g, b):

    if run_length < 5:
        # Warn, may change if capabilities change
        print(f"Run of {run} pixels at ({x}, {y}) with colour {colour} is too short")

    r_3bit = (r >> 5) & 0x7
    g_3bit = (g >> 5) & 0x7  
    b_3bit = (g >> 5) & 0x7  

    instruction = (run_length & 0x3FF) << 9 | (r_3bit << 6) | (g_3bit << 3) | (b_3bit)
    print(f"Writing 0x{instruction:06X} for run {run_length} ({run_length:010b}) with colour {r_3bit} ({r_3bit:03b}), {g_3bit} ({g_3bit:03b}), {b_3bit} ({b_3bit:03b})")

    f.write(instruction.to_bytes(3, byteorder='big'))

with open("output.bin", "wb") as f:
    for y in range(height):
        for x in range(width):
            r, g, b = img.getpixel((x, y))
            if colour == (-1, -1, -1):
                colour = (r, g, b)
                run = 1
            elif colour == (r, g, b):
                run += 1
            else:
                write_rle_instruction(f, run, r, g, b)

                run = 1
                colour = (r, g, b)
                # endif
            #end if
        #end for
        
        write_rle_instruction(f, run, r, g, b)
        run = 0
        colour = (-1, -1, -1)



