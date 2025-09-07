
## Extras

<p align="center">
  <img src="https://github.com/JonathanThing/VGA-Video-Player/blob/main/docs/imgs/Block_Diagram.png?raw=true" alt="Diagram 1"/>
</p>

Because of the lack of space available on the chip, the player cannot use a frame buffer for the video output and must instead "race the beam" of the VGA scanline. As the player runs at the same clock frequency as the VGA pixel clock (25.175MHz), it outputs a new pixel at every clock cycle when in the display window of the VGA protocol.

The design utilizes Quad Serial Peripheral Interface (QSPI) to read data from the external memory, allowing 4-bits of data to be read at every clock cycle. With every RLE instruction being 24 bits, this means that it will take the player 6 clock cycles to read a single instruction. This means that without any buffering, each strip must be at least 6 pixels long to keep up with the scanline.

To allow for more flexibility, the data is buffered through 6 registers before being consumed by the player. This allows for pixel runs shorter than 6 pixels as long as the buffer is still filled with longer strips.  To prevent the buffer from emptying, every 6 consecutive pixel runs on the same row must add up to at least 36 pixels. This is because the 6 buffers will each require at least 6 clock cycles to be filled, requiring a total of at least 36 pixels to guarantee that the buffer doesn't become empty.