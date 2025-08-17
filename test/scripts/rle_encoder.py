import struct
from PIL import Image
import numpy as np

# Converts 8 bit per pixel RGB to RRRGGGBB format (8 bits in total)
def rgb_to_8bit(r, g, b):
    # R: 3 bits, G: 3 bits, B: 2 bits
    r_3bit = (r >> 5) & 0x07  # Top 3 bits of R
    g_3bit = (g >> 5) & 0x07  # Top 3 bits of G
    b_2bit = (b >> 6) & 0x03  # Top 2 bits of B
    
    # Combine into RRRGGGBB format
    return (r_3bit << 5) | (g_3bit << 2) | b_2bit

def write_pixel_instruction(rle_data, run_length, colour):
    rle_instruction = (run_length << 8) | colour
        
    # Pack as 3 bytes (big-endian)
    rle_bytes = struct.pack('>I', rle_instruction)[1:]  # Take last 3 bytes
    rle_data.append(rle_bytes)

def write_audio_instruction(rle_data, audio_sample):
    # Add stop message instruction: 0x30000
    audio_instruction = 0x3FF00 + audio_sample
    audio_bytes = struct.pack('>I', audio_instruction)[1:]
    rle_data.append(audio_bytes)


def encode_rle(image_path, output_path):
    # RLE instruction format (24 bits):
    # Bits 23:18 - Unused (set to 0)
    # Bits 17:8  - Run Length (10 bits, max 1023)
    # Bits 7:0   - RRRGGGBB colour value

    img = Image.open(image_path)
    
    if img.size != (640, 480):
        print(f"Warning: Image size is {img.size}, expected (640, 480)")

    if img.mode != 'RGB':
        img = img.convert('RGB')
    
    pixels = np.array(img)
    height, width = pixels.shape[:2]

    rle_data = []
        
    for i in range(height):
        # Reset variables
        run_length = 0
        previous_colour = -1

        # Write pixel data for the row
        for j in range (width):
            r, g, b = pixels[i][j]
            current_colour = rgb_to_8bit(r, g, b)

            if (previous_colour == -1):
                previous_colour = current_colour
            elif (previous_colour != current_colour):
                write_pixel_instruction(rle_data, run_length, previous_colour)
                previous_colour = current_colour
                run_length = 0

            run_length += 1
        write_pixel_instruction(rle_data, run_length, previous_colour)
        write_audio_instruction(rle_data, (i+1) % 256)

    # Write RLE data to file
    with open(output_path, 'wb') as f:
        for instruction in rle_data:
            f.write(instruction)

    # Print statisticsd
    original_size = width * height * 3  # 3 bytes per pixel
    compressed_size = len(rle_data) * 3  # 3 bytes per RLE instruction
    compression_ratio = original_size / compressed_size
    
    print(f"Original size: {original_size:,} bytes")
    print(f"Compressed size: {compressed_size:,} bytes")
    print(f"Compression ratio: {compression_ratio:.2f}:1")
    print(f"Number of RLE instructions: {len(rle_data):,}")
    
    return rle_data
            
# Example usage
if __name__ == "__main__":
    # Encode PNG to RLE
    encode_rle("input.png", "data.bin")