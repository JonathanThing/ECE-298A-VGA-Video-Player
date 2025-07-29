<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## Rough Timing Diagrams

### Boot sequence timing diagram
<p align="center">
  <img src="https://github.com/JonathanThing/VGA-Video-Player/blob/Verilog-Fixes/docs/imgs/Startup_Sequence.png?raw=true" alt="Diagram 2"/>
</p>

### Regular operation QSPI timing diagram
<p align="center">
  <img src="https://github.com/JonathanThing/VGA-Video-Player/blob/Verilog-Fixes/docs/imgs/Instruction_Reading.png?raw=true" alt="Diagram 1"/>
</p>

## How it works

Outputs a 640x480 VGA video from external memory with Run Length Encoded (RLE) data using QSPI.


RLE works by breaking an image down into strips of consequtive pixels, specifying the length and colour of the strip.

Each instruction is 3 bytes (18 bits of data + 4 bits of padding) and is stored in the form:

|-----------------|-------------------|--------------|
| padding [23:18] | run_length [17:8] | colour [7:0] |
|-----------------|-------------------|--------------|  

The video player uses 8 bit colour (3 bits for Red, 3 bits for Green, 2 bits for Blue)

|-----------|-------------|------------|
| red [7:5] | green [4:2] | blue [1:0] |
|-----------|-------------|------------|


Requirements for RLE Data:
- One pixel run must be at least 3 pixels
- For any given 6 consequtive pxiel runs, the number of pixels must sum up to 36

The chip reads the data stored in the external flash memory using a continous sequential read command, where it expects to be able to continuously clock data sequentailly from 0 to the final memory address. 

It takes the chip 6 clock cycles to read one instruction as it reads 4 bits at a time using QSPI.
Since it runs at 25.175MHz, each clock cycle correlates to one pixel output for the VGA.
Therefore, without a buffer, this would mean that every strip would have to be atleast 6 pixels long to keep up with the VGA.

By using 6 buffers, we loosen the requirement to 36 pixels for every 6 runs, allowing for a few runs smaller than 6 without desyncing the video

The mininum requirement of 3 pixels per run is because of limitations from the implementation.

## How to test

Run the cocotb test script in the `test` folder using `make -B`. The timing test results will be shown in the console log.

cd into the `scripts` folder and do `python vga_converter.py ../resources/output.bin`. Make note of the original image `resources/sample_test.png`. After running the script, you should get a new file
`scripts/output.png`. Compare and verify the two images look the same.

For custom tests, you can put an image in the `test/scripts` folder (ensuring it is a 640x480 PNG image) and then run `python png_to_rle_converter.py`. This should give you a `data.bin` file which you can place in `test/resources`. Now you can cd to `test` and run `make -B`. You should see `output.bin` get created. cd to `scripts` and run `python vga_converter.py ../resources/output.bin`. You can see and compare the output image given in `output.png`. 

The test emulate what would be output on a screen using a VGA port. For example, we log to the file directly the colour of each pixel. Through our `test.py` script we read the `data.bin` file for the RLE data and decode it into each pixel on the screen. The `test.py` script will ignore any of the blanking regions (through a counter separate from the verilog files in the `test.py` file; allowing us to test correct blanking as well) so that we can get raw VGA data for one frame. This allows us to test the correctness of the output visually. 

## External hardware

The design will require a custom PCB to handle 8-bit VGA output and also house the external memory
