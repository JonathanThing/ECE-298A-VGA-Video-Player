## Design Documents
Additional design documentation can be found at the end of the document
## Duties and Contributions
|Task| Contributions |
|--|--|
| QSPI Controller |Jonathan: FSM structure and rewrite, Timing fixes, Integration<br>Isaac: Original structure, Boot Sequence structure, bug fixes<br>Commits:https://github.com/JonathanThing/ECE-298A-VGA-Video-Player/commit/edb0e5f37a2747d81cffc11871099e1879bb5264<br>https://github.com/JonathanThing/ECE-298A-VGA-Video-Player/commit/7d859bcaf0b9361f265d4a335508b185661d5f0f|
|Data Buffer|Jonathan: Entire thing<br>Commits:https://github.com/JonathanThing/ECE-298A-VGA-Video-Player/commit/4f3cd7a50c2eb82ecfd387aba78bc2b590faa9d1#diff-bf0068ea937132f55ed8b254574c9fc2d5098d80feb32b6c8a04860c70154cbd|
|Instruction Decoder|Jonathan: Bug fixes and integration<br>Isaac: Primary structure, bug fixes<br>Commits:https://github.com/JonathanThing/ECE-298A-VGA-Video-Player/commit/c1f5f28e3e54028cecfcea6ec3a2a1e7be0e1e69<br>https://github.com/JonathanThing/ECE-298A-VGA-Video-Player/commit/7d859bcaf0b9361f265d4a335508b185661d5f0f|
|VGA Module|Jonathan: Timing and Restructure/Rewrite<br>Isaac: Integration structure and original version, bug fixes<br>Commits:https://github.com/JonathanThing/ECE-298A-VGA-Video-Player/commit/c1f5f28e3e54028cecfcea6ec3a2a1e7be0e1e69<br>https://github.com/JonathanThing/ECE-298A-VGA-Video-Player/commit/7d859bcaf0b9361f265d4a335508b185661d5f0f|
|Python Tests|Jonathan: cocotb timing tests, Test Image Generator<br>Isaac: RLE conversion, VGA to Image, cocotb VGA logging<br>Commits:https://github.com/JonathanThing/ECE-298A-VGA-Video-Player/commit/12f6ca9941e3e32062dc05faf3eb738f4b95e620<br>https://github.com/JonathanThing/ECE-298A-VGA-Video-Player/commit/a9b5c3827cee77e0953461bcd3df90078bb888ba|


  

## Test Plan
### Verilog Code/Hardware Tests
 - [ ] **Main Test:** Test QSPI Boot Sequence
	 - [ ] **Sub Test:** Correctly set mode (6Bh) of flash memory on boot
		 - [ ] Should take exactly 8 cycles
		 - [ ] Pass 6Bh 1 bit at a time (0110 1011) on the DI line
		 - [ ] **Validation:** Await 1 cycle each time, verify the bits received
	 - [ ] **Sub Test:** Wait 32 dummy cycles
		 - [ ] **Validation:** Await 32 cycles, check FSM state at the end
 - [ ] **Main Test:** Test QSPI Data Transfer Timing and Buffer Timing
	 - [ ] **Sub Test:** Test filling buffer from empty/startup state
		 - [ ] Should take 12 cycles to fill the last buffer once data transmission starts
		 - [ ] Data should not be shifted out unless requested
		 - [ ] **Validation:** After we begin data transmission, check if buffer is filled after 12 cycles
		 - [ ] **Validation:** Each preceding buffer should be filled every 6 cycles thereafter while there is space
	 - [ ] **Sub Test:** Test buffer timing and shifting during normal operation
		 - [ ] Should still take 6 cycles to fill a buffer
		 - [ ] Data should stop being sent if all buffers full (turn off SPI Clock)
		 - [ ] Data should only be shifted out once it has been consumed by Instruction Decoder Module
		 - [ ] **Validation:** Check if buffer gets filled every 6 cycles when a buffer is empty
		 - [ ] **Validation:** Check if data is passed through empty buffers 
		 - [ ] **Validation:** Check if SPI Clock is turned off (held low) when all buffers are full
		 - [ ] **Validation:** Check consumption (shift out) of last buffer (Buffer 6) when Instruction Decoder consumes data
 - [ ] **Main Test:** Test Instruction Decoder
	 - [ ] **Sub Test:** Ensure decoder properly separates data
		 - [ ] [23:18] Discarded
		 - [ ] [17:8] Run Length
		 - [ ] [7:5] Red
		 - [ ] [4:2] Green
		 - [ ] [1:0] Blue
		 - [ ] **Validation:** Check internal counter value after decoding an instruction for correct run length
		 - [ ] **Validation:** Check value of red, green and blue registers after VGA requests pixel for correctness of RGB values
 - [ ] **Main Test:** Test VGA Timing and Image Correctness
	 - [ ] **Sub Test:** Test blanking region timing
		 - [ ] Start in blanking state, count number of cycles, should be 35319 blank cycles after QSPI startup is complete
		 - [ ] **Validation:** Check if VGA module is ready to accept pixel data after 35319 cycles
	 - [ ] **Sub Test:** Image Correctness and Normal Operation timing
		 - [ ] Pixels should be requested for 640 clock cycles, then blank for 160 cycles each row
		 - [ ] After 480 rows, blank for 45 rows
		 - [ ] **Validation:** Check pixel request value at each blanking region (should be deasserted)
		 - [ ] **Validation:** Log to file the VGA output, use Python script to compare and generate image with a known sample image 


## cocotb Test Results

### test.py
**Lines 27-77:** QSPI boot sequence and timing tests. Passes the instruction/mode to the simulated flash memory on I/O[3], checks at each step the correctness of the bits (6Bh). Test fails if any of the bits are incorrect. Next, awaits the 32 dummy cycles, counts the number of dummy cycles, fails if incorrect number of dummy cycles.

**Lines 78-142:** QSPI data timing and VGA timing tests. Simulates data being sent from flash memory using a file, where the data is already encoded to our instruction format. This data will later be validated with the `vga_converter.py` file. Also checks VGA timing by counting the number of blanking regions as per the test plan. Uses timeouts to check timing of data arrival, fails if data does not arrive in time. 

`vga_converter.py` will convert the received VGA outputs to proper VGA data and give some logs on what is wrong with the data in the case of errors.

## GDS Logs
No errors or violations until 100C 1.60V. 
At 100C and 1.60V we begin to see Slew violations, in the long term we would like to fix these and we can identify where the source of these errors are by cross-referencing the Pin Names with the NetList file. 

From looking at these errors, it seems most of the errors are from the buffers (those created by data_buffers.v). However, from resources on the TinyTapeout Discord and Slack channels, it seems that slew up to 1.5ns is acceptable, but warnings/errors are thrown at 0.75ns. Our design errors due to the slew being 1.255 ns, which is not ideal, but is still within the limits of the design tools. Similarly, we receive Fanout violations, but the TinyTapeout Discord and Slack channels state that Fanouts as high as 25 are acceptable, but errors are thrown at 10. Our highest fanout is 18, which is also acceptable within the limits of the design tools. 

### Pre vs. Post Logs
In the pre-layout logs for the nominal 25C and 40C levels, we get slew errors as high as 2.2ns, however, in post-layout these errors go away. In both situations we have fanout violations, but as mentioned in the previous paragraph, they are below 25 and can be safely ignored. Up to the 100C level, we get slew violations up to 3.6ns, but the post-layout logs have them at 1.18ns at most. 

### Static Timing Analysis for Nominal TT 25C 1V80
The pre-layout logs indicate many slew and fanout violations, with some fanouts being as high as 67 and the slew being as high as 2.22ns. After analyzing the logs, it seems most of the violations are due to the buffers and their data registers. However, after the layout done by OpenLane, there are no slew issues, but there are still fanout issues, with the highest being at 18. However, as stated previously fanouts as high as 25 are acceptable, so the post-layout fanout is acceptable. However, there are slack violations now, with the highest being at -8. These violations occur on the clkbuf pins, and from the TinyTapeout Slack and Discord channels, it seems it is more acceptable for the clk tree to use a larger fanout. However, it would still be best to reduce the slack, and in order to do this we would need to either look into Verilog optimizations or manually configure OpenLane settings to increase the slack. 

## Additional Design Documentation

### Pinout
|#|Input|Output  | Bidir|
|--|--|--|--|
| 0 |  |R[0]|HSYNC (OUT ONLY)|
|  1|  (DO) |R[1]|VSYNC (OUT ONLY)|
|  2| IO1 |R[2]|nCS (OUT ONLY)|
|  3| IO2 |G[0]|IO0 (DI) (I/O)|
|  4|  |G[1]|SCLK (OUT ONLY)|
|  5|  |G[2]||
|  6|  |B[0]|IO3 (HOLD) (I/O)|
|  7|  |B[1]||

### Design Details
8-bit colour VGA video player

Using RLE instructions which are 24 bit instructions
Supports up to 640 run length, with minimum of 2

|24:18|17:8|7:5|4:2|1:0|
|--|--|--|--|--|
| Discarded | Run Length |Red Channel|Green Channel|Blue Channel|

#### Block Diagram
<p align="center">
  <img src="https://github.com/JonathanThing/VGA-Video-Player/blob/main/docs/imgs/Block_Diagram.png?raw=true" alt="Diagram 1"/>
</p>

#### Timing Diagrams
### Boot sequence timing diagram
<p align="center">
  <img src="https://github.com/JonathanThing/VGA-Video-Player/blob/Verilog-Fixes/docs/imgs/Startup_Sequence.png?raw=true" alt="Timing 1"/>
</p>

### Regular operation QSPI timing diagram
<p align="center">
  <img src="https://github.com/JonathanThing/VGA-Video-Player/blob/Verilog-Fixes/docs/imgs/Instruction_Reading.png?raw=true" alt="Timing 2"/>
</p>

