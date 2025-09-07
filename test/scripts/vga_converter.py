#!/usr/bin/env python3
"""
VGA RRRGGGBB to Image Converter

Converts a VGA output file with 8-bit RRRGGGBB colour format to PNG images.
colour format: RRR GGG BB (3 bits red, 3 bits green, 2 bits blue)
Resolution: 640x480
"""

from PIL import Image
import sys
import os

def rrrgggbb_to_rgb(byte_value):
    """
    Convert 8-bit RRRGGGBB format to 24-bit RGB.
    
    RRRGGGBB format:
    - Bits 7-5: Red (3 bits)
    - Bits 4-2: Green (3 bits) 
    - Bits 1-0: Blue (2 bits)
    """
    # Extract colour components using bit masks
    red_3bit = (byte_value & 0b11100000) >> 5    # Extract bits 7-5
    green_3bit = (byte_value & 0b00011100) >> 2  # Extract bits 4-2
    blue_2bit = byte_value & 0b00000011          # Extract bits 1-0
    
    # Scale to 8-bit values
    # For 3-bit values (0-7), scale to 0-255
    red_8bit = (int(red_3bit) * 255) // 7
    green_8bit = (int(green_3bit) * 255) // 7

    # For 2-bit values (0-3), scale to 0-255
    blue_8bit = (int(blue_2bit) * 255) // 3

    return (red_8bit, green_8bit, blue_8bit)

def split_to_frames(input_filename, output_dir="frames"):
    """
    Split a long VGA binary file into individual 640x480 frame images.
    
    Args:
        input_filename: Path to the VGA input file
        output_dir: Directory to save frame images
    """
    width = 640
    height = 480
    frame_size = width * height
    
    # Create output directory
    os.makedirs(output_dir, exist_ok=True)
    
    try:
        # Read the binary file
        with open(input_filename, 'rb') as f:
            data = f.read()
        
        total_bytes = len(data)
        total_frames = total_bytes // frame_size
        remaining_bytes = total_bytes % frame_size
        
        print(f"Total bytes: {total_bytes}")
        print(f"Frame size: {frame_size} bytes")
        print(f"Complete frames: {total_frames}")
        if remaining_bytes > 0:
            print(f"Incomplete frame: {remaining_bytes} bytes remaining")
        
        # Process each complete frame
        for frame_num in range(total_frames):
            start_idx = frame_num * frame_size
            end_idx = start_idx + frame_size
            frame_data = data[start_idx:end_idx]
            
            # Create image for this frame
            img = Image.new('RGB', (width, height))
            pixels = []
            
            # Convert each byte to RGB
            for byte_val in frame_data:
                rgb = rrrgggbb_to_rgb(byte_val)
                pixels.append(rgb)
            
            # Set all pixels at once
            img.putdata(pixels)
            
            # Save the frame
            output_filename = os.path.join(output_dir, f"frame_{frame_num:06d}.png")
            img.save(output_filename)
            
            if frame_num % 100 == 0:  # Progress indicator
                print(f"Processed frame {frame_num}/{total_frames}")
        
        # Handle incomplete frame if exists
        if remaining_bytes > 0:
            print(f"Processing incomplete frame with {remaining_bytes} bytes...")
            start_idx = total_frames * frame_size
            frame_data = data[start_idx:]
            
            # Pad with zeros to complete the frame
            frame_data += b'\x00' * (frame_size - remaining_bytes)
            
            # Create image for incomplete frame
            img = Image.new('RGB', (width, height))
            pixels = []
            
            for byte_val in frame_data:
                rgb = rrrgggbb_to_rgb(byte_val)
                pixels.append(rgb)
            
            img.putdata(pixels)
            
            # Save the incomplete frame
            output_filename = os.path.join(output_dir, f"frame_{total_frames:06d}_incomplete.png")
            img.save(output_filename)
        
        print(f"Successfully split {input_filename} into {total_frames} frames")
        print(f"Frames saved in: {output_dir}/")
        
    except FileNotFoundError:
        print(f"Error: File '{input_filename}' not found")
    except Exception as e:
        print(f"Error: {e}")

def convert_single_frame(input_filename, output_filename="output.png"):
    """
    Convert a single VGA frame file to PNG image.
    
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
                print("File too large - using first frame only")
                data = data[:expected_size]
        
        # Create image
        img = Image.new('RGB', (width, height))
        pixels = []
        
        # Convert each byte to RGB
        for byte_val in data:
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
        print("Usage:")
        print("  Split into frames: python vga_converter.py <input_file> [output_dir]")
        print("  Single frame:      python vga_converter.py <input_file> --single [output_file]")
        print("Examples:")
        print("  python vga_converter.py video.bin frames/")
        print("  python vga_converter.py frame.bin --single output.png")
        sys.exit(1)
    
    input_file = sys.argv[1]
    
    # Check if single frame mode
    if len(sys.argv) > 2 and sys.argv[2] == "--single":
        output_file = sys.argv[3] if len(sys.argv) > 3 else "output.png"
        convert_single_frame(input_file, output_file)
    else:
        # Split into frames mode
        output_dir = sys.argv[2] if len(sys.argv) > 2 else "frames"
        split_to_frames(input_file, output_dir)

if __name__ == "__main__":
    main()