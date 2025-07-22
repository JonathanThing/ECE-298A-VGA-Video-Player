#!/usr/bin/env python3
"""
VGA Test File Generator - Creates sample VGA output for testing the parser
Generates both full timing and visible-only test files, plus reference images
"""

import os
import sys
from PIL import Image
import numpy as np

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

def generate_test_pattern(width=640, height=480):
    """
    Generate a colorful test pattern for the visible area
    
    Returns:
        tuple: (bytearray of VGA color data, PIL Image for reference)
    """
    data = bytearray()
    rgb_array = np.zeros((height, width, 3), dtype=np.uint8)
    
    for y in range(height):
        for x in range(width):
            # Create a gradient pattern with some geometric shapes
            
            # Base gradient
            r = int(255 * x / width)
            g = int(255 * y / height)
            b = int(255 * (x + y) / (width + height))
            
            # Add some colored rectangles
            if 50 <= x <= 150 and 50 <= y <= 150:
                # Red square
                r, g, b = 255, 0, 0
            elif 200 <= x <= 300 and 100 <= y <= 200:
                # Green square
                r, g, b = 0, 255, 0
            elif 350 <= x <= 450 and 150 <= y <= 250:
                # Blue square
                r, g, b = 0, 0, 255
            elif 500 <= x <= 600 and 200 <= y <= 300:
                # Yellow square
                r, g, b = 255, 255, 0
            elif 100 <= x <= 200 and 350 <= y <= 450:
                # Magenta square
                r, g, b = 255, 0, 255
            elif 300 <= x <= 400 and 300 <= y <= 400:
                # Cyan square
                r, g, b = 0, 255, 255
            

            
            # Store RGB values for reference image
            rgb_array[y, x] = [r, g, b]
            
            # Convert to VGA format for data file
            vga_color = rgb_to_vga_color(r, g, b)
            data.append(vga_color)
    
    # Create reference image
    reference_image = Image.fromarray(rgb_array, 'RGB')
    
    return data, reference_image

def generate_visible_only_file(filename="test_visible.bin"):
    """Generate test file with only visible pixels (640x480)"""
    print(f"Generating visible-only test file: {filename}")
    
    visible_data, reference_image = generate_test_pattern()
    
    with open(filename, 'wb') as f:
        f.write(visible_data)
    
    # Save reference image
    reference_filename = filename.replace('.bin', '_reference.png')
    reference_image.save(reference_filename)
    
    print(f"Created {filename}: {len(visible_data)} bytes")
    print(f"Created {reference_filename}: Reference image (original quality)")
    return filename

def generate_full_timing_file(filename="test_full_timing.bin", 
                             visible_width=640, visible_height=480,
                             total_width=800, total_height=525):
    """Generate test file with full VGA timing including blanking"""
    print(f"Generating full timing test file: {filename}")
    
    visible_data, reference_image = generate_test_pattern(visible_width, visible_height)
    
    # Create full timing data
    full_data = bytearray()
    visible_index = 0
    
    for y in range(total_height):
        for x in range(total_width):
            if y < visible_height and x < visible_width:
                # Visible pixel
                full_data.append(visible_data[visible_index])
                visible_index += 1
            else:
                # Blanking region - output black (0x00)
                full_data.append(0x00)
    
    with open(filename, 'wb') as f:
        f.write(full_data)
    
    # Save reference image
    reference_filename = filename.replace('.bin', '_reference.png')
    reference_image.save(reference_filename)
    
    print(f"Created {filename}: {len(full_data)} bytes")
    print(f"  Total size: {total_width}x{total_height} = {len(full_data)} bytes")
    print(f"  Visible area: {visible_width}x{visible_height} = {len(visible_data)} bytes")
    print(f"Created {reference_filename}: Reference image (original quality)")
    return filename

def main():
    print("VGA Test File Generator")
    print("=" * 40)
    
    # Generate both test files
    visible_file = generate_visible_only_file()
    full_file = generate_full_timing_file()
    
    print("\nTest files created!")
    print(f"Test with: python vga_parser.py {visible_file}")
    print(f"Test with: python vga_parser.py {full_file}")
    
    print("\nReference images created:")
    print("- test_visible_reference.png (original quality)")
    print("- test_full_timing_reference.png (original quality)")
    
    print("\nThe test pattern includes:")
    print("- Rainbow gradient background")
    print("- Colored squares (red, green, blue, yellow, magenta, cyan)")
    
    print("\nCompare the parser output with the reference images to verify correctness!")
    print("Note: Parser output may have slightly different colors due to VGA format limitations.")

if __name__ == "__main__":
    main()
