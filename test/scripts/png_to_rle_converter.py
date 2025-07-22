import struct
from PIL import Image
import numpy as np

def rgb_to_rrrgggbb(r, g, b):
    """
    Convert 8-bit RGB values to RRRGGGBB format (8 bits total)
    R: 3 bits (0-7)
    G: 3 bits (0-7)
    B: 2 bits (0-3)
    """
    # Scale down from 8-bit to reduced bit depths
    r_3bit = (r >> 5) & 0x07  # Top 3 bits of R
    g_3bit = (g >> 5) & 0x07  # Top 3 bits of G
    b_2bit = (b >> 6) & 0x03  # Top 2 bits of B
    
    # Combine into RRRGGGBB format
    return (r_3bit << 5) | (g_3bit << 2) | b_2bit

def encode_rle(image_path, output_path):
    """
    Convert PNG image to RLE encoding with 3-byte instructions
    
    RLE instruction format (24 bits):
    - Bits 23:18 - Unused (set to 0)
    - Bits 17:8  - Run Length (10 bits, max 1023)
    - Bits 7:0   - RRRGGGBB color value
    """
    # Load image
    img = Image.open(image_path)
    
    # Verify dimensions
    if img.size != (640, 480):
        print(f"Warning: Image size is {img.size}, expected (640, 480)")
    
    # Convert to RGB if necessary
    if img.mode != 'RGB':
        img = img.convert('RGB')
    
    # Get pixel data as numpy array
    pixels = np.array(img)
    
    # Flatten to 1D array of pixels
    height, width = pixels.shape[:2]
    flat_pixels = pixels.reshape(-1, 3)
    
    # RLE encoding
    rle_data = []
    
    i = 0
    while i < len(flat_pixels):
        # Get current pixel color
        r, g, b = flat_pixels[i]
        current_color = rgb_to_rrrgggbb(r, g, b)
        
        # Count consecutive pixels with same color
        run_length = 1
        max_run = min(1023, len(flat_pixels) - i)  # Max 10-bit value
        
        while run_length < max_run and i + run_length < len(flat_pixels):
            next_r, next_g, next_b = flat_pixels[i + run_length]
            next_color = rgb_to_rrrgggbb(next_r, next_g, next_b)
            
            if next_color == current_color:
                run_length += 1
            else:
                break
        
        # Create 3-byte RLE instruction
        # Bits 23:18 unused (0), 17:8 run length, 7:0 color
        rle_instruction = (run_length << 8) | current_color
        
        # Pack as 3 bytes (big-endian)
        rle_bytes = struct.pack('>I', rle_instruction)[1:]  # Take last 3 bytes
        rle_data.append(rle_bytes)
        
        i += run_length
    
    # Add stop message instruction: 0x500
    stop_instruction = 0x500
    stop_bytes = struct.pack('>I', stop_instruction)[1:]
    rle_data.append(stop_bytes)

    # Write RLE data to file
    with open(output_path, 'wb') as f:
        for instruction in rle_data:
            f.write(instruction)
    
    # Print statistics
    original_size = width * height * 3  # 3 bytes per pixel
    compressed_size = len(rle_data) * 3  # 3 bytes per RLE instruction
    compression_ratio = original_size / compressed_size
    
    print(f"Original size: {original_size:,} bytes")
    print(f"Compressed size: {compressed_size:,} bytes")
    print(f"Compression ratio: {compression_ratio:.2f}:1")
    print(f"Number of RLE instructions: {len(rle_data):,}")
    
    return rle_data

def decode_rle(rle_path, output_path, width=640, height=480):
    """
    Decode RLE data back to PNG image
    """
    # Read RLE data
    with open(rle_path, 'rb') as f:
        rle_bytes = f.read()
    
    # Parse RLE instructions (3 bytes each)
    pixels = []
    
    for i in range(0, len(rle_bytes), 3):
        if i + 2 >= len(rle_bytes):
            break
            
        # Read 3 bytes and reconstruct 24-bit value
        instruction = (rle_bytes[i] << 16) | (rle_bytes[i+1] << 8) | rle_bytes[i+2]
        
        # Extract run length and color
        run_length = (instruction >> 8) & 0x3FF  # 10 bits
        color_byte = instruction & 0xFF
        
        # Extract RGB from RRRGGGBB
        r_3bit = (color_byte >> 5) & 0x07
        g_3bit = (color_byte >> 2) & 0x07
        b_2bit = color_byte & 0x03
        
        # Scale back up to 8-bit values
        r = (r_3bit << 5) | (r_3bit << 2) | (r_3bit >> 1)  # Replicate bits
        g = (g_3bit << 5) | (g_3bit << 2) | (g_3bit >> 1)
        b = (b_2bit << 6) | (b_2bit << 4) | (b_2bit << 2) | b_2bit
        
        # Add pixels
        for _ in range(run_length):
            pixels.append((r, g, b))
    
    # Create image from pixels
    if len(pixels) != width * height:
        print(f"Warning: Expected {width*height} pixels, got {len(pixels)}")
    
    # Reshape to 2D array
    pixel_array = np.array(pixels[:width*height], dtype=np.uint8)
    pixel_array = pixel_array.reshape(height, width, 3)
    
    # Create and save image
    img = Image.fromarray(pixel_array)
    img.save(output_path)
    print(f"Decoded image saved to: {output_path}")

# Example usage
if __name__ == "__main__":
    # Encode PNG to RLE
    encode_rle("input.png", "output.rle")
    
    # Decode RLE back to PNG (for verification)
    #decode_rle("output.rle", "decoded.png")
