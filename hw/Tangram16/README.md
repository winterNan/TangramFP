# FP32 MAC - Floating Point Multiply-Accumulate Unit

A VHDL implementation of a Tangram 16-bit floating point multiply-accumulate unit optimized for AI accelerator implementation on FPGA.

## Overview

This project implements a pipelined MAC unit that performs:
- 16-bit floating point multiplication 
- 32-bit floating point addition
- Optimized Dadda multiplier for mantissa multiplication
- Leading zero detection for normalization
- Configurable precision and modes

## Key Features

- Single-stage :
  - Multiplication (combinational)
  - Addition (combinational)
  - Output (rising edge)
- Optimized Dadda tree multiplier with:
  - Configurable width and cut parameters
  - Multiple operation modes (FULL, SKIP_BD, AC_ONLY, SKIP)
- Hardware-optimized leading zero counter
- IEEE-754 compliant floating point operations
- Proper handling of special cases (NaN, zero, subnormal)

## Architecture

The main components are:

- `MAC.vhd`: Top level MAC unit
- `kacy_mult.vhd`: Optimized mantissa multiplier
- `DaddaMultiplier.vhd`: Dadda tree implementation
- `CSA4i`: Carry Look Ahead adder 4 inputs for partial products
- `CSA2i`: Carry Look Ahead adder 3 inputs with 1 stage addition for final addition of the partial products 
- `fp_add.vhd`: Floating point adder
- `LZC.vhd`: Leading zero counter
- `tools.vhd`: Utility functions

## Performance Optimizations

1. Custom Dadda multiplier with:
   - Parameterized tree reduction
   - Carry-save adder arrays
   - Optimized final addition stage

2. Efficient LZC implementation:
   - Parallel leading zero detection
   - Optimized for FPGA LUT structure

3. Pipelined architecture:
   - Multiplication result on rising edge
   - Addition result on rising edge
   - single cycle latency per operation
## Implementation Details

### FP16 IEEE-754 Format
- Half precision (16-bit) floating-point format
- Sign bit: 1 bit
- Exponent: 5 bits (bias 15, range -14 to 15)
- Mantissa: 10 bits + 1 hidden bit
- Special cases handling: NaN, Infinity, Subnormal numbers

### FP32 IEEE-754 Format
- Single precision (32-bit) floating-point format
- Sign bit: 1 bit
- Exponent: 8 bits (bias 127, range -126 to 127)
- Mantissa: 23 bits + 1 hidden bit
- Special cases handling: NaN, Infinity, Subnormal numbers

### Mantissa Multiplication Architecture
- Segmented mantissa multiplication (TangramFP approach)
- Split pattern: 1:5:5 (hidden bit : A/C : B/D)
- Multiplication term: 2^(p+q) + (X + Y)*2^(p+q) + A*C*2^(2q) + (A*D + B*C)*2^q + B*D
- Dadda tree optimization for partial products

### Operation Modes
1. **Full Mode**
   - Complete multiplication with all terms
   - Used when exponent difference <= 0

2. **Skip_BD Mode**
   - Skips B*D term
   - Activated when threshold_1 > exponent difference > 0

3. **AC_Only Mode**
   - Only computes A*C term
   - Activated when threshold_1 >= exponent difference < threshold_2

4. **Skip Mode**
   - Bypasses multiplication
   - Used for special cases (NaN, Infinity)
   - Activated when exponent difference >= threshold_2

### Special Cases Handling
1. **Subnormal Numbers**
   - Input normalization to lowest normal number
   - Zero exponent replaced with 1
   - Mantissa rounded to zero

2. **NaN and Infinity**
   - Detected through all-ones exponent
   - Direct output propagation
   - Multiplication/addition bypass

3. **Overflow**
   - Exponent > 254 handled as infinity
   - Skip mode activation
   - Direct infinity output
## Usage

```vhdl
entity MAC is
    Port ( 
        a, b    : in  STD_LOGIC_VECTOR(16 downto 0);  -- Multiplicands
        c       : in  STD_LOGIC_VECTOR(16 downto 0);  -- Accumulator input
        clk     : in  STD_LOGIC;                      -- Clock
        n_rst   : in  STD_LOGIC;                      -- Active low reset
        sumout  : out STD_LOGIC_VECTOR(32 downto 0)   -- Result
    );
end MAC;