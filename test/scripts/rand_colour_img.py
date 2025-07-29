from PIL import Image
import random

width, height = 640, 480
block_heights = 1
block_widths = [640]  # alternating widths

# Color mapping functions
def map_3bit_to_8bit(val):
    return int((val / 7) * 255)

# Common RGB colors
common_colors = [
    (255, 0, 0), (0, 255, 0), (0, 0, 255),
    (255, 255, 0), (255, 165, 0), (128, 0, 128),
    (0, 255, 255), (192, 192, 192), (0, 0, 0), (255, 255, 255)
]

# Generate all possible 3-bit RGB colors
colors_3bit = [(r, g, b) for r in range(8) for g in range(8) for b in range(8)]
colors_8bit = [(map_3bit_to_8bit(r), map_3bit_to_8bit(g), map_3bit_to_8bit(b)) for r, g, b in colors_3bit]

# Initialize image
img = Image.new("RGB", (width, height))

# Track used colors
used_colors = common_colors.copy()
color_index = 0

# Fill the image row by row with horizontally alternating block widths
y = 0
while y < height:
    x = 0
    toggle = 0
    while x < width:
        block_width = block_widths[toggle % len(block_widths)]
        toggle += 1

        # Pick color
        if color_index < len(used_colors):
            color = used_colors[color_index]
        else:
            color = random.choice(colors_8bit)
            used_colors.append(color)
        color_index += 1

        # Paint block
        for by in range(y, min(y + block_heights, height)):
            for bx in range(x, min(x + block_width, width)):
                img.putpixel((bx, by), color)

        x += block_width
    y += block_heights

img.save("input.png")
print("Image saved as input.png")
