#!/usr/bin/env python3
"""
RLE Encoder for VGA Images
Converts PNG images to RLE format with 11-bit run length + 8-bit VGA color (RRRGGGBB)
Format: Each entry is 19 bits total (11 bits length + 8 bits color)
"""

from PIL import Image
import numpy as np
import struct
import sys

def rgb_to_vga_color(r, g, b):
    """
    Convert RGB values to VGA 8-bit color format (RRRGGGBB)
    
    Args:
        r, g, b: RGB values (0-255)
        
    Returns:
        int: 8-bit VGA color value
    """
    # Scale down to VGA bit depths
    r_3bit = int(r * 7 / 255)  # 3 bits for red
    g_3bit = int(g * 7 / 255)  # 3 bits for green  
    b_2bit = int(b * 3 / 255)  # 2 bits for blue
    
    # Combine into RRRGGGBB format
    return (r_3bit << 5) | (g_3bit << 2) | b_2bit

def encode_rle_entry(run_length, color):
    """
    Encode a single RLE entry with 11-bit length + 8-bit color = 19 bits
    
    Args:
        run_length: Length of run (0-2047, 11 bits)
        color: VGA color value (0-255, 8 bits)
        
    Returns:
        int: 19-bit RLE entry
    """
    if run_length > 2047:  # 2^11 - 1
        raise ValueError(f"Run length {run_length} exceeds 11-bit maximum (2047)")
    
    if color > 255:  # 2^8 - 1
        raise ValueError(f"Color value {color} exceeds 8-bit maximum (255)")
    
    # Pack as: [11-bit length][8-bit color]
    return (run_length << 8) | color

def rle_encode_image(image_path, output_path="output.rle"):
    """
    RLE encode a PNG image to VGA format
    
    Args:
        image_path: Path to input PNG image
        output_path: Path to output RLE file
        
    Returns:
        tuple: (compression_ratio, original_size, compressed_size)
    """
    try:
        # Load image
        image = Image.open(image_path)
        if image.mode != 'RGB':
            image = image.convert('RGB')
        
        print(f"Loaded image: {image.size} ({image.mode})")
        
        # Convert to numpy array
        img_array = np.array(image)
        height, width = img_array.shape[:2]
        
        # Flatten image to 1D array (row by row)
        pixels = img_array.reshape(-1, 3)
        
        # Convert RGB to VGA colors
        vga_colors = []
        for r, g, b in pixels:
            vga_color = rgb_to_vga_color(r, g, b)
            vga_colors.append(vga_color)
        
        print(f"Converted {len(vga_colors)} pixels to VGA format")
        
        # RLE encode
        rle_entries = []
        current_color = vga_colors[0]
        run_length = 1
        
        for i in range(1, len(vga_colors)):
            if vga_colors[i] == current_color and run_length < 2047:
                run_length += 1
            else:
                # End current run
                rle_entry = encode_rle_entry(run_length, current_color)
                rle_entries.append(rle_entry)
                
                # Start new run
                current_color = vga_colors[i]
                run_length = 1
        
        # Don't forget the last run
        rle_entry = encode_rle_entry(run_length, current_color)
        rle_entries.append(rle_entry)
        
        print(f"RLE encoded to {len(rle_entries)} entries")
        
        # Write to file
        # Each entry is 19 bits, so we'll pack them efficiently
        bit_stream = []
        for entry in rle_entries:
            # Convert 19-bit entry to binary string
            bit_string = format(entry, '019b')
            bit_stream.append(bit_string)
        
        # Join all bits
        all_bits = ''.join(bit_stream)
        
        # Pad to byte boundary
        while len(all_bits) % 8 != 0:
            all_bits += '0'
        
        # Convert to bytes
        compressed_data = bytearray()
        for i in range(0, len(all_bits), 8):
            byte_bits = all_bits[i:i+8]
            byte_value = int(byte_bits, 2)
            compressed_data.append(byte_value)
        
        # Write header + data
        with open(output_path, 'wb') as f:
            # Header: width (2 bytes), height (2 bytes), num_entries (4 bytes)
            header = struct.pack('<HHII', width, height, len(rle_entries), len(compressed_data))
            f.write(header)
            f.write(compressed_data)
        
        # Calculate compression stats
        original_size = len(vga_colors)  # 1 byte per pixel
        compressed_size = len(compressed_data) + 12  # data + header
        compression_ratio = original_size / compressed_size
        
        print(f"Original size: {original_size} bytes")
        print(f"Compressed size: {compressed_size} bytes (including 12-byte header)")
        print(f"Compression ratio: {compression_ratio:.2f}:1")
        print(f"Space savings: {(1 - compressed_size/original_size)*100:.1f}%")
        
        return compression_ratio, original_size, compressed_size
        
    except Exception as e:
        print(f"Error: {e}")
        return None, None, None

def decode_rle_file(rle_path, output_path="decoded.png"):
    """
    Decode an RLE file back to PNG (for verification)
    
    Args:
        rle_path: Path to RLE file
        output_path: Path to output PNG
    """
    try:
        with open(rle_path, 'rb') as f:
            # Read header
            header_data = f.read(12)
            width, height, num_entries, data_size = struct.unpack('<HHII', header_data)
            
            print(f"Decoding: {width}x{height}, {num_entries} RLE entries")
            
            # Read compressed data
            compressed_data = f.read(data_size)
            
            # Convert bytes back to bit stream
            bit_stream = ''
            for byte in compressed_data:
                bit_stream += format(byte, '08b')
            
            # Extract RLE entries
            rle_entries = []
            for i in range(num_entries):
                start_bit = i * 19
                if start_bit + 19 <= len(bit_stream):
                    entry_bits = bit_stream[start_bit:start_bit + 19]
                    entry_value = int(entry_bits, 2)
                    
                    # Extract length and color
                    run_length = entry_value >> 8  # Top 11 bits
                    color = entry_value & 0xFF     # Bottom 8 bits
                    
                    rle_entries.append((run_length, color))
            
            # Decode to pixel array
            pixels = []
            for run_length, vga_color in rle_entries:
                # Convert VGA color back to RGB
                r_3bit = (vga_color >> 5) & 0x07
                g_3bit = (vga_color >> 2) & 0x07
                b_2bit = vga_color & 0x03
                
                r = int(r_3bit * 255 / 7)
                g = int(g_3bit * 255 / 7)
                b = int(b_2bit * 255 / 3)
                
                for _ in range(run_length):
                    pixels.append([r, g, b])
            
            # Create image
            img_array = np.array(pixels, dtype=np.uint8).reshape(height, width, 3)
            image = Image.fromarray(img_array, 'RGB')
            image.save(output_path)
            
            print(f"Decoded image saved as: {output_path}")
            return True
            
    except Exception as e:
        print(f"Decode error: {e}")
        return False

def main():
    if len(sys.argv) < 2:
        print("Usage: python rle_encoder_8bit.py <input_png> [output.rle]")
        print("   or: python rle_encoder_8bit.py --decode <input.rle> [output.png]")
        print("\nExample:")
        print("  python rle_encoder_8bit.py test_visible_parsed.png compressed.rle")
        print("  python rle_encoder_8bit.py --decode compressed.rle decoded.png")
        sys.exit(1)
    
    if sys.argv[1] == "--decode":
        if len(sys.argv) < 3:
            print("Error: Please specify RLE file to decode")
            sys.exit(1)
        
        rle_file = sys.argv[2]
        output_file = sys.argv[3] if len(sys.argv) > 3 else "decoded.png"
        
        print(f"Decoding RLE file: {rle_file}")
        success = decode_rle_file(rle_file, output_file)
        if not success:
            sys.exit(1)
    else:
        input_file = sys.argv[1]
        output_file = sys.argv[2] if len(sys.argv) > 2 else "compressed.rle"
        
        print(f"Encoding PNG to RLE: {input_file}")
        ratio, orig, comp = rle_encode_image(input_file, output_file)
        
        if ratio is None:
            sys.exit(1)
        
        print(f"\nRLE file created: {output_file}")
        print("Use --decode option to verify the compression worked correctly")

if __name__ == "__main__":
    main()
