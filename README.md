![](../../workflows/gds/badge.svg) ![](../../workflows/docs/badge.svg) ![](../../workflows/test/badge.svg)

# Tiny Tapeout VGA Video Player

- [Read the documentation for project](docs/info.md)

## Overview: VGA Video and Audio Player

This project is a VGA video and audio player designed in verilog and to be fabricated into an ASIC design for TinyTapeout SKY 25a. The player reads video and audio data from an external flash memory, buffers it, and outputs the corresponding video/audio signal.

## Key Features:
- 640x480p 60Hz VGA video output
- 8-bit colour (3-bit Red, 3-bit Green, 2-bit Blue)
- 8-bit PWM audio at ~31.5kHz sample rate

## Block Diagram
<p align="center">
  <img src="https://github.com/JonathanThing/VGA-Video-Player/blob/main/docs/imgs/Block_Diagram.png?raw=true" alt="Diagram 1"/>
</p>
