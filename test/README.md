# Testbench for RLE Video PLayer

Note: It is recommended to test only on small inputs (Only a few frames) to avoid long simulation times and large output files (such as `output.bin` and `tb.vcd`)

## Test Procedure

Before running the simulation, make sure there is a valid `data.bin` file in the resources folder, this is the RLE video data that the testbench will use.

RLE files can be generated with this tool:
https://github.com/JonathanThing/ECE298A-RLE-Tool

Once the test has been successfully completed, an `output.bin` file will be created in the resources folder that logs every pixel outputted by the player. The `vga_converter.py` script can be used to convert the output data so that it can be visually checked.

## How to run

```sh
make -B
```

## How to view the VCD file

```sh
gtkwave tb.vcd tb.gtkw
```
