# Single-Cycle RISC-V (RV32I Base) Microprocessor in Verilog

A synthesisable 32-bit RV32I RISC-V processor core written in Verilog, implemented as an 8-state multi-cycle FSM with a byte-addressable memory interface and a comprehensive self-checking testbench.

---

## Overview

This project implements the complete **RV32I base integer instruction set** as a multi-cycle finite state machine. The FSM splits execution across fetch, decode/execute, and memory-access stages, correctly stalling on `mem_rbusy`/`mem_wbusy` signals so it works safely with any memory model — zero-latency SRAM, registered ROM, or a slow external bus.

---

## Architecture

### FSM States

| State | Phase | Description |
|---|---|---|
| 0 | Fetch — Address | Drive `mem_addr ← PC`, assert `mem_rstrb` |
| 1 | Fetch — Wait | Stall until `mem_rbusy` deasserts |
| 2 | Fetch — Latch | Register `instr ← mem_rdata`, deassert `mem_rstrb` |
| 3 | Execute | Decode opcode, run ALU, update PC / branch |
| 4 | Load — Wait | Stall until `mem_rbusy` deasserts |
| 5 | Load — Writeback | Format and write data to destination register |
| 6 | Store — Wait | Stall until `mem_wbusy` deasserts |
| 7 | Store — Commit | Clear `mem_wmask`, advance PC |

### Supported Instructions

| Category | Instructions |
|---|---|
| Arithmetic | ADD, SUB, ADDI |
| Logical | AND, OR, XOR, ANDI, ORI, XORI |
| Shifts | SLL, SRL, SRA, SLLI, SRLI, SRAI |
| Comparison | SLT, SLTU, SLTI, SLTIU |
| Loads | LB, LH, LW, LBU, LHU |
| Stores | SB, SH, SW |
| Branches | BEQ, BNE, BLT, BGE, BLTU, BGEU |
| Jumps | JAL, JALR |
| Upper Immediates | LUI, AUIPC |

### Memory Interface

| Signal | Direction | Description |
|---|---|---|
| `mem_addr[31:0]` | Output | Byte address (word-aligned for fetches) |
| `mem_rstrb` | Output | Read strobe |
| `mem_rdata[31:0]` | Input | Read data |
| `mem_rbusy` | Input | Memory stall (read) |
| `mem_wdata[31:0]` | Output | Write data |
| `mem_wmask[3:0]` | Output | Byte-enable write mask |
| `mem_wbusy` | Input | Memory stall (write) |

Sub-word loads and stores are handled via byte-lane shifting from the bottom 2 address bits, so the host memory can be word-organised.

---

## Files

| File | Description |
|---|---|
| `riscv.v` | Processor core (`riscv_processor` module) |
| `testbench.v` | Self-checking Verilog testbench |

---

## Testbench

The testbench instantiates the core against a 4 096-word word-organised RAM (16 KB) and runs 10 directed test programs assembled inline as hex immediates:

1. Basic Arithmetic (ADD, SUB, ADDI)
2. Logical Operations (AND, OR, XOR + immediates)
3. Load and Store (LW, SW round-trips)
4. Branches (BEQ, BNE, BLT, BGE, BLTU, BGEU)
5. Jumps (JAL, JALR)
6. Upper Immediates (LUI, AUIPC)
7. Shifts (SLL, SRL, SRA + immediate forms)
8. Simple Loop (loop with counter, branch-back)
9. Byte and Halfword access (LB, LH, LBU, LHU, SB, SH)
10. Set Less Than (SLT, SLTU, SLTI, SLTIU)

Each test loads a short instruction sequence into memory, resets the processor, runs for a bounded number of cycles, and checks the result with `[PASS]` / `[FAIL]` output.

---

## Simulation

Any Verilog-2001 compatible simulator works. With **Icarus Verilog**:

```bash
git clone https://github.com/<your-org>/rv32i-multicycle-processor.git
cd rv32i-multicycle-processor
iverilog -o sim riscv.v testbench.v
vvp sim
```

Expected output ends with a summary such as:

```
========================================
FINAL RESULTS
========================================
Passed: 10 / 10 tests
========================================
```

---

## Parameters

| Parameter | Default | Description |
|---|---|---|
| `RESET_ADDR` | `32'h00000000` | PC value on reset |
| `ADDR_WIDTH` | `32` | Address bus width |

---
