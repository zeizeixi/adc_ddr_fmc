# fmc_sdram_port: 10 MHz oversampled FMC endpoint

This specification binds to the existing interface, not a new clock domain.

## Contract

- `clk`: 100 MHz FPGA UI clock. `rst`: synchronous active-high logical reset; output DQ is also disabled combinationally while reset is high.
- `enabled`: high in FMC_CONTROL=1 mode. Disabled mode holds DQ high impedance.
- STM32 SDCLK: nominal 1 to 10 MHz; nominal minimum period 100 ns, high/low phases at least 45 ns.
- Commands, CKE, address, bank, masks and write DQ must be stable at least 30 ns before the external rising edge.
- Input SDCLK stays on L21 as an oversampled asynchronous input. No BUFG or MMCM is driven by SDCLK.
- Address geometry: four banks, 13 row bits, eight column bits, 16-bit data; BL1, CL3, mode register 0x0230.
- All internal request/reply signals remain in `clk`; no ports or instantiation connections change.
- `bus_read`/`bus_write`: one UI-clock pulse. Register responses or two-cycle block-reader RAM responses must be received before the next decoded SDCLK rising edge.
- Read output is launched on the decoded C3 edge. MCU must use RPIPE=2 HCLK, disable read burst and use SDCLK=HCLK/3.
- Register-to-DQ datapath must meet 10 ns maximum delay in the integrated routed FPGA design. That is a physical requirement, not proof supplied by behavioral simulation.

## Small changes

1. The sampled-edge guard changes from edge_age<19 to edge_age<8. An N-cycle sampled edge gap has edge_age=N-1; nine-cycle gaps are accepted to tolerate one cycle of sampling quantization around a nominal ten-cycle period. This guard is a gross overspeed detector, not an exact frequency meter.
2. `clock_fall_seen` qualifies `edge_seen`. A partial high phase captured after reset/enable does not become a reference full period; the next full rising edge establishes the reference.
3. The output XDC budget changes from 20 ns to 10 ns to preserve margin for the shorter RPIPE interval.

## Timing diagram

The reply must be stored before decoded C1. DQ becomes valid after the decoded C3 edge, delayed about 30 to 40 ns by the existing synchronizer/edge detector, plus physical output routing. RPIPE=2 at HCLK=30 MHz allows about 66.7 ns from the external C3 edge to the modeled MCU observation.

```json
{"signal":[{"name":"external_sdclk","wave":"p....."},{"name":"command","wave":"=.....","data":["READ C0"]},{"name":"reply_ready","wave":"01...."},{"name":"cas_stage","wave":"====..","data":["C0","C1","C2","C3"]},{"name":"DQ_valid","wave":"0...10"}],"head":{"text":"CL3; output follows decoded C3; RPIPE2 observation later in the same interval"}}
```

## Verification and risks

- Original 5 MHz RTL rejects the 10 MHz test during initialization.
- Candidate tests use the actual ram256x16_8k XPM, all 4096 read halfwords, command rejection, write/read masks, row changes, bank isolation, invalid mode, RAM timeout, reset, disabled ownership, stopped-clock high impedance and 20 MHz overspeed detection.
- Phase sweep uses 0 through 9 ns start phases, 45/55, 50/50 and 55/45 duty cycles, 30 ns input setup, 7 ns post-edge command hold, and zero/two extra response cycles.
- No full MIG simulation, full-top placement/routing or board verification is implied. Input setup and output-delay requirements need actual integrated timing/measurement.
- Runtime interface layout and command definitions are unchanged.
