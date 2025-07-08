from PIL import Image
import random

width, height = 640, 480
block_size = 40

blocks_x = width // block_size 
blocks_y = height // block_size 
total_blocks = blocks_x * blocks_y 

def map_3bit_to_8bit(val):
    return int((val / 7) * 255)

def map_8bit_to_3bit(val):
    return int((val / 255) * 7)

# Common colours
common_colors = [
    (255, 0, 0),   # Red
    (0, 255, 0),   # Green
    (0, 0, 255),   # Blue
    (255, 255, 0), # Yellow
    (255, 165, 0), # Orange
    (128, 0, 128), # Purple
    (0, 255, 255), # Cyan
    (192, 192, 192), # Silver
    (0, 0, 0),     # Black
    (255, 255, 255) # White
]

# Generate all possible 3 bit RGB colours
colors_3bit = [(r, g, b) for r in range(8) for g in range(8) for b in range(8)]

# Generate 8 bit values of colours
colors_8bit = [(map_3bit_to_8bit(r), map_3bit_to_8bit(g), map_3bit_to_8bit(b)) for r, g, b in colors_3bit]

# Select random sample of colours
random_colors = random.sample(colors_8bit, total_blocks - len(common_colors))

# Add the common colors to start of the list
random_colors = common_colors + random_colors

img = Image.new("RGB", (width, height))

index = 0
for by in range(blocks_y):
    for bx in range(blocks_x):
        color = random_colors[index]
        index += 1

        for y in range(by * block_size, (by + 1) * block_size):
            for x in range(bx * block_size, (bx + 1) * block_size):
                img.putpixel((x, y), color)

img.save("random_mixed_checkered.bmp")
print("Image saved as random_mixed_checkered_rgb.bmp")

