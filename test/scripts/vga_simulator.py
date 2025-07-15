#!/usr/bin/env python3
"""
VGA Output Parser - Converts VGA output file to 640x480 image
Handles 8-bit color format: RRRGGGBB
Blanking regions are represented as black pixels (0x00)

NOTE: THIS ASSUMES YOU ALSO OUTPUT TO FILE THE BLANKING REGION PIXELS
"""

from PIL import Image
import numpy as np
import sys

def parse_vga_color(color_byte):
    """
    Parse 8-bit VGA color format RRRGGGBB to RGB tuple
    
    Args:
        color_byte: 8-bit integer representing color in RRRGGGBB format
        
    Returns:
        tuple: (R, G, B) values scaled to 0-255 range
    """
    if color_byte == 0:
        return (0, 0, 0)  # Black for blanking regions
    
    # Extract color components
    red_3bit = (color_byte >> 5) & 0x07    # Top 3 bits
    green_3bit = (color_byte >> 2) & 0x07  # Middle 3 bits  
    blue_2bit = color_byte & 0x03          # Bottom 2 bits
    
    # Scale to 8-bit values
    # 3-bit: 0-7 -> 0-255, so multiply by 255/7 ≈ 36.43
    # 2-bit: 0-3 -> 0-255, so multiply by 255/3 = 85
    red_8bit = int(red_3bit * 255 / 7)
    green_8bit = int(green_3bit * 255 / 7)
    blue_8bit = int(blue_2bit * 255 / 3)
    
    return (red_8bit, green_8bit, blue_8bit)

def parse_vga_file(filename, visible_width=640, visible_height=480, 
                   total_width=800, total_height=525):
    """
    Parse VGA output file and create image
    
    Args:
        filename: Path to VGA output file
        visible_width: Visible image width (default 640)
        visible_height: Visible image height (default 480)
        total_width: Total horizontal pixels including blanking (default 800)
        total_height: Total vertical lines including blanking (default 525)
        
    Returns:
        PIL.Image: Generated image
    """
    try:
        with open(filename, 'rb') as f:
            data = f.read()
    except FileNotFoundError:
        print(f"Error: File '{filename}' not found")
        return None
    except Exception as e:
        print(f"Error reading file: {e}")
        return None
    
    expected_size = total_width * total_height
    visible_size = visible_width * visible_height
    
    print(f"File size: {len(data)} bytes")
    print(f"Expected total size (with blanking): {expected_size} bytes")
    print(f"Visible area: {visible_width}x{visible_height} = {visible_size} pixels")
    
    if len(data) != expected_size:
        print(f"Warning: File size doesn't match expected VGA timing")
        print(f"Trying to parse as sequential visible pixels only...")
        
        # Fall back to treating as visible pixels only
        if len(data) == visible_size:
            return parse_visible_only(data, visible_width, visible_height)
        else:
            print(f"File size doesn't match visible area either")
            return None
    
    # Create RGB array for visible pixels only
    rgb_array = np.zeros((visible_height, visible_width, 3), dtype=np.uint8)
    
    # Extract visible pixels from the full VGA timing data
    for row in range(visible_height):
        for col in range(visible_width):
            # Calculate position in full timing data
            data_index = row * total_width + col
            
            if data_index < len(data):
                byte = data[data_index]
                r, g, b = parse_vga_color(byte)
                rgb_array[row, col] = [r, g, b]
    
    # Create and return PIL Image
    image = Image.fromarray(rgb_array, 'RGB')
    return image

def parse_visible_only(data, width, height):
    """
    Parse data that contains only visible pixels (no blanking)
    
    Args:
        data: Raw pixel data
        width: Image width
        height: Image height
        
    Returns:
        PIL.Image: Generated image
    """
    rgb_array = np.zeros((height, width, 3), dtype=np.uint8)
    
    for i, byte in enumerate(data):
        if i >= width * height:
            break
            
        row = i // width
        col = i % width
        
        r, g, b = parse_vga_color(byte)
        rgb_array[row, col] = [r, g, b]
    
    image = Image.fromarray(rgb_array, 'RGB')
    return image

def main():
    if len(sys.argv) < 2:
        print("Usage: python vga_simulator.py <vga_output_file> [output_image.png]")
        print("Example: python vga_simulator.py vga_output.bin output.png")
        sys.exit(1)
    
    input_file = sys.argv[1]
    output_file = sys.argv[2] if len(sys.argv) > 2 else "vga_output.png"
    
    print(f"Parsing VGA file: {input_file}")
    image = parse_vga_file(input_file)
    
    if image is not None:
        print(f"Saving image as: {output_file}")
        image.save(output_file)
        print(f"Image saved successfully! Size: {image.size}")
        
        # Display some statistics
        pixels = np.array(image)
        unique_colors = len(np.unique(pixels.reshape(-1, pixels.shape[-1]), axis=0))
        print(f"Unique colors in image: {unique_colors}")
    else:
        print("Failed to create image")
        sys.exit(1)

if __name__ == "__main__":
    main()
