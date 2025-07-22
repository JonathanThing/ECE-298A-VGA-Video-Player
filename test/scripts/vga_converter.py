#!/usr/bin/env python3
"""
VGA RRRGGGBB to Image Converter

Converts a VGA output file with 8-bit RRRGGGBB color format to a PNG image.
Color format: RRR GGG BB (3 bits red, 3 bits green, 2 bits blue)
Resolution: 640x480
"""

from PIL import Image
import sys

def rrrgggbb_to_rgb(byte_value):
    """
    Convert 8-bit RRRGGGBB format to 24-bit RGB.
    
    RRRGGGBB format:
    - Bits 7-5: Red (3 bits)
    - Bits 4-2: Green (3 bits) 
    - Bits 1-0: Blue (2 bits)
    """
    # Extract color components using bit masks
    red_3bit = (byte_value & 0b11100000) >> 5    # Extract bits 7-5
    green_3bit = (byte_value & 0b00011100) >> 2  # Extract bits 4-2
    blue_2bit = byte_value & 0b00000011          # Extract bits 1-0
    
    # Scale to 8-bit values
    # For 3-bit values (0-7), scale to 0-255
    red_8bit = (red_3bit * 255) // 7
    green_8bit = (green_3bit * 255) // 7
    
    # For 2-bit values (0-3), scale to 0-255
    blue_8bit = (blue_2bit * 255) // 3
    
    return (red_8bit, green_8bit, blue_8bit)

def convert_vga_to_image(input_filename, output_filename="output.png"):
    """
    Convert VGA file to PNG image.
    
    Args:
        input_filename: Path to the VGA input file
        output_filename: Path for the output PNG file
    """
    width = 640
    height = 480
    expected_size = width * height
    
    try:
        # Read the binary file
        with open(input_filename, 'rb') as f:
            data = f.read()
        
        # Verify file size
        if len(data) != expected_size:
            print(f"Warning: Expected {expected_size} bytes, got {len(data)} bytes")
            if len(data) < expected_size:
                print("File too small - padding with zeros")
                data += b'\x00' * (expected_size - len(data))
            else:
                print("File too large - truncating")
                data = data[:expected_size]
        
        # Create image
        img = Image.new('RGB', (width, height))
        pixels = []
        
        # Convert each byte to RGB
        for i, byte_val in enumerate(data):
            rgb = rrrgggbb_to_rgb(byte_val)
            pixels.append(rgb)
        
        # Set all pixels at once
        img.putdata(pixels)
        
        # Save the image
        img.save(output_filename)
        print(f"Successfully converted {input_filename} to {output_filename}")
        print(f"Image size: {width}x{height}")
        
    except FileNotFoundError:
        print(f"Error: File '{input_filename}' not found")
    except Exception as e:
        print(f"Error: {e}")

def main():
    if len(sys.argv) < 2:
        print("Usage: python vga_converter.py <input_file> [output_file]")
        print("Example: python vga_converter.py video.vga output.png")
        sys.exit(1)
    
    input_file = sys.argv[1]
    output_file = sys.argv[2] if len(sys.argv) > 2 else "output.png"
    
    convert_vga_to_image(input_file, output_file)

if __name__ == "__main__":
    main()
