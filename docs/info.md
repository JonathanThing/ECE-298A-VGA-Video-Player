<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

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

To be determined

## External hardware

The design will require a custom PCB to handle 8-bit VGA output and also house the external memory