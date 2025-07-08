from PIL import Image

img = Image.open("input.bmp")

width, height = img.size

if (width, height) != (640, 480):
    print(f"Size is {width}x{height}, expected 640x480")

img = img.convert('RGB')

run = 0
colour = (-1, -1, -1) 

with open("output.bin", "wb") as f:
    for y in range(1):
        for x in range(width):
            r, g, b = img.getpixel((x, y))
            if colour == (-1, -1, -1):
                colour = (r, g, b)
                run = 1
            elif colour == (r, g, b):
                run += 1
            else:
                if run < 5:
                    # Warn
                    print(f"Run of {run} pixels at ({x}, {y}) with colour {colour} is too short")
                
                # Data format 20 bits
                # [1 bit unused leave 0][10 bits run][3 bits red][3 bits green][3 bits blue]
                f.write(bytes([(run & 0x3FF) | 0x80, (r & 0x07) << 5 | (g & 0x07) << 2 | (b & 0x07)]))
                print(f"Run of {run} pixels at ({x}, {y}) with colour {colour}")

                run = 1
                colour = (r, g, b)
