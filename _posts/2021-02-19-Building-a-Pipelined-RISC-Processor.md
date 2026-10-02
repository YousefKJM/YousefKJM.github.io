---
title: "Building a 5-Stage Pipelined RISC Processor in Logisim, Gate by Gate"
excerpt: "A walkthrough of the 32-bit CPU my team designed at KFUPM: a 16-bit instruction set with four formats, a ROM-driven control unit, then the jump to a five-stage pipeline with three-way forwarding, a load-use stall, and branch flushing. Encodings, control tables, and the hazards that bite."
---

In ICS 233 (Computer Architecture & Assembly Language) at KFUPM, my team of three built a CPU from scratch in **Logisim** — first single-cycle, then pipelined. I owned the next-PC logic, the main control unit, and most of the pipelined datapath integration. The full design is on [GitHub](https://github.com/YousefKJM/Pipelined-Processor-Design). Here's how it fits together, and what I'd tell anyone attempting the same.

## The spec in one glance

| Property | Value |
|---|---|
| Data width | 32-bit |
| Registers | 8 general-purpose: `R0`–`R7` (so register fields are **3 bits**) |
| Instruction width | **16-bit** — 5-bit opcode, up to 32 opcodes |
| Memory | Word-addressed (next PC = `PC + 1`, not `+4`) |
| Special registers by convention | `R7` = return address (`JAL`), `R0` = target of `SET`/`SSET` |

16-bit instructions with 32-bit data is the interesting constraint. It forces small immediates and a trick for building large constants (more on `SET`/`SSET` below).

## Four instruction formats

<div style="margin:2rem 0;padding:1.25rem;background:var(--bg-elevated);border:1px solid var(--border);border-radius:var(--radius-m);">
<svg viewBox="0 0 640 260" style="width:100%;height:auto;font-family:inherit;" role="img" aria-label="Instruction formats, 16 bits each. R-type: opcode 5, rs 3, rt 3, rd 3, function 2. I-type: opcode 5, rs 3, rt 3, immediate 5. B-type: opcode 5, rs 3, immediate 8. J-type: opcode 5, immediate 11.">
  <g style="font-size:12px;">
    <text x="10" y="20" fill="var(--text-muted)">bit 15</text>
    <text x="580" y="20" fill="var(--text-muted)">bit 0</text>
    <!-- scale: 32px per bit, start x=100 -> 16 bits = 512 -->
    <text x="10" y="58" font-weight="700" fill="var(--text)">R-type</text>
    <rect x="100" y="36" width="160" height="34" fill="var(--accent)" fill-opacity="0.8" stroke="var(--bg)"/>
    <rect x="260" y="36" width="96" height="34" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <rect x="356" y="36" width="96" height="34" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <rect x="452" y="36" width="96" height="34" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <rect x="548" y="36" width="64" height="34" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="150" y="58" fill="var(--accent-contrast)" font-weight="700">op (5)</text>
    <text x="285" y="58" fill="var(--text)">rs (3)</text>
    <text x="381" y="58" fill="var(--text)">rt (3)</text>
    <text x="477" y="58" fill="var(--text)">rd (3)</text>
    <text x="558" y="58" fill="var(--text)">f (2)</text>

    <text x="10" y="114" font-weight="700" fill="var(--text)">I-type</text>
    <rect x="100" y="92" width="160" height="34" fill="var(--accent)" fill-opacity="0.8" stroke="var(--bg)"/>
    <rect x="260" y="92" width="96" height="34" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <rect x="356" y="92" width="96" height="34" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <rect x="452" y="92" width="160" height="34" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="150" y="114" fill="var(--accent-contrast)" font-weight="700">op (5)</text>
    <text x="285" y="114" fill="var(--text)">rs (3)</text>
    <text x="381" y="114" fill="var(--text)">rt (3)</text>
    <text x="500" y="114" fill="var(--text)">imm5</text>

    <text x="10" y="170" font-weight="700" fill="var(--text)">B-type</text>
    <rect x="100" y="148" width="160" height="34" fill="var(--accent)" fill-opacity="0.8" stroke="var(--bg)"/>
    <rect x="260" y="148" width="96" height="34" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <rect x="356" y="148" width="256" height="34" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="150" y="170" fill="var(--accent-contrast)" font-weight="700">op (5)</text>
    <text x="285" y="170" fill="var(--text)">rs (3)</text>
    <text x="440" y="170" fill="var(--text)">imm8 (PC-relative)</text>

    <text x="10" y="226" font-weight="700" fill="var(--text)">J-type</text>
    <rect x="100" y="204" width="160" height="34" fill="var(--accent)" fill-opacity="0.8" stroke="var(--bg)"/>
    <rect x="260" y="204" width="352" height="34" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="150" y="226" fill="var(--accent-contrast)" font-weight="700">op (5)</text>
    <text x="380" y="226" fill="var(--text)">imm11</text>
  </g>
</svg>
</div>

| Format | Opcodes | Instructions |
|---|---|---|
| R | 0 (`f`=0–3), 1 (`f`=0–3) | `AND CAND OR XOR` · `ADD NADD SLT SLTU` |
| I | 4–17 | `ANDI CANDI ORI XORI ADDI NADDI SLTI SLTUI` · `SLL SRL SRA ROR` · `LW SW` |
| B | 20–27 | `BEQZ BNEZ BLTZ BGEZ BGTZ BLEZ` · `JR JALR` |
| J | 28–31 | `SET SSET` · `J JAL` |

Two non-MIPS instructions worth knowing:

- **`CAND rd, rs, rt`** → `rd = ~rs & rt` (complement-AND — bit clearing in one instruction)
- **`NADD rd, rs, rt`** → `rd = rt − rs` (negate-add — subtraction without a separate `SUB` opcode)

### Building a 32-bit constant from 11-bit pieces

With only 11 bits of immediate, how do you load a full 32-bit value? Two instructions:

```
set  imm11      ; R0 = imm11
sset imm11      ; R0 = (R0 << 11) | imm11   — shift in the next 11 bits
```

Three `SET`/`SSET` steps cover 33 bits. It's the same idea as MIPS `lui`+`ori`, adapted to a narrower instruction.

## Stage 1: the single-cycle datapath

Build and **fully verify** this before touching a pipeline. Every bug you leave here gets harder to find once five instructions are in flight at once.

<div style="margin:2rem 0;padding:1.25rem;background:var(--bg-elevated);border:1px solid var(--border);border-radius:var(--radius-m);">
<svg viewBox="0 0 640 150" style="width:100%;height:auto;font-family:inherit;" role="img" aria-label="Single-cycle datapath: PC feeds instruction memory, then register file and control, then ALU, then data memory, then write-back mux back to the register file">
  <defs><marker id="cpu-arr" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto"><path d="M0,0 L8,4 L0,8 z" fill="var(--text-muted)"/></marker></defs>
  <g style="font-size:12px;">
    <rect x="5" y="45" width="60" height="50" rx="6" fill="var(--bg-elevated-2)" stroke="var(--border)"/><text x="24" y="75" font-weight="700" fill="var(--text)">PC</text>
    <rect x="90" y="45" width="90" height="50" rx="6" fill="var(--bg-elevated-2)" stroke="var(--border)"/><text x="102" y="68" font-weight="700" fill="var(--text)">Instr.</text><text x="102" y="84" fill="var(--text-muted)">memory</text>
    <rect x="205" y="45" width="100" height="50" rx="6" fill="var(--bg-elevated-2)" stroke="var(--accent)" stroke-width="2"/><text x="217" y="68" font-weight="700" fill="var(--accent)">Reg file</text><text x="217" y="84" fill="var(--text-muted)">+ control ROM</text>
    <rect x="330" y="45" width="80" height="50" rx="6" fill="var(--bg-elevated-2)" stroke="var(--border)"/><text x="355" y="75" font-weight="700" fill="var(--text)">ALU</text>
    <rect x="435" y="45" width="90" height="50" rx="6" fill="var(--bg-elevated-2)" stroke="var(--border)"/><text x="447" y="68" font-weight="700" fill="var(--text)">Data</text><text x="447" y="84" fill="var(--text-muted)">memory</text>
    <rect x="550" y="45" width="85" height="50" rx="6" fill="var(--bg-elevated-2)" stroke="var(--border)"/><text x="562" y="68" font-weight="700" fill="var(--text)">WB mux</text><text x="562" y="84" fill="var(--text-muted)">4 sources</text>
    <line x1="65" y1="70" x2="86" y2="70" stroke="var(--text-muted)" stroke-width="2" marker-end="url(#cpu-arr)"/>
    <line x1="180" y1="70" x2="201" y2="70" stroke="var(--text-muted)" stroke-width="2" marker-end="url(#cpu-arr)"/>
    <line x1="305" y1="70" x2="326" y2="70" stroke="var(--text-muted)" stroke-width="2" marker-end="url(#cpu-arr)"/>
    <line x1="410" y1="70" x2="431" y2="70" stroke="var(--text-muted)" stroke-width="2" marker-end="url(#cpu-arr)"/>
    <line x1="525" y1="70" x2="546" y2="70" stroke="var(--text-muted)" stroke-width="2" marker-end="url(#cpu-arr)"/>
    <path d="M592,95 L592,130 L255,130 L255,99" fill="none" stroke="var(--accent)" stroke-width="2" marker-end="url(#cpu-arr)"/>
    <text x="360" y="124" fill="var(--accent)">write-back to register file</text>
  </g>
</svg>
</div>

### The control unit as a ROM

Instead of deriving a logic equation for every control signal, we fed the opcode through a **decoder into a ROM** whose words *are* the control signals. Adding an instruction becomes editing one ROM row rather than re-deriving boolean equations.

| Signal | 0 | 1 | 2 | 3 |
|---|---|---|---|---|
| `RegDst` | Rt | Rd | R7 (for `JAL`) | R0 (for `SET`) |
| `ExtOp` | zero-extend | sign-extend | – | – |
| `ALUSrc` | BusB (Rt) | ext. imm5 | ext. imm11 | ext. imm11 |
| `MemRd` / `MemWr` | off | on | – | – |
| `WBdata` | ALU result | memory out | PC + 1 (return addr) | ext. imm11 |

The 4-way `RegDst` and `WBdata` muxes are what this ISA needs beyond textbook MIPS — `JAL` writes `PC+1` into `R7`, and `SET` writes an immediate straight into `R0`.

The ALU itself was one 16-input mux selected by a 4-bit `ALUOp`, with each operation (`AND`, `CAND`, `OR`, `XOR`, `ADD`, `NADD`, `SLT`, `SLTU`, shifts) computed in parallel and the mux picking the result.

## Stage 2: pipelining it

Split the datapath with four pipeline registers into five stages:

<div style="margin:2rem 0;padding:1.25rem;background:var(--bg-elevated);border:1px solid var(--border);border-radius:var(--radius-m);">
<svg viewBox="0 0 640 230" style="width:100%;height:auto;font-family:inherit;" role="img" aria-label="Pipeline timing diagram: four instructions overlap across IF, ID, EX, MEM, WB stages, one stage apart each clock cycle">
  <g style="font-size:12px;">
    <text x="10" y="20" fill="var(--text-muted)">cycle →</text>
    <g fill="var(--text-muted)"><text x="132" y="20">1</text><text x="192" y="20">2</text><text x="252" y="20">3</text><text x="312" y="20">4</text><text x="372" y="20">5</text><text x="432" y="20">6</text><text x="492" y="20">7</text><text x="552" y="20">8</text></g>
    <text x="10" y="55" fill="var(--text)">add $1,$2,$3</text>
    <text x="10" y="100" fill="var(--text)">add $4,$1,$5</text>
    <text x="10" y="145" fill="var(--text)">or  $6,$1,$7</text>
    <text x="10" y="190" fill="var(--text)">xor $2,$1,$4</text>
    <g font-weight="700">
      <rect x="115" y="36" width="56" height="30" rx="4" fill="var(--bg-elevated-2)" stroke="var(--border)"/><text x="133" y="56" fill="var(--text)">IF</text>
      <rect x="175" y="36" width="56" height="30" rx="4" fill="var(--bg-elevated-2)" stroke="var(--border)"/><text x="193" y="56" fill="var(--text)">ID</text>
      <rect x="235" y="36" width="56" height="30" rx="4" fill="var(--accent)" fill-opacity="0.8"/><text x="253" y="56" fill="var(--accent-contrast)">EX</text>
      <rect x="295" y="36" width="56" height="30" rx="4" fill="var(--bg-elevated-2)" stroke="var(--border)"/><text x="306" y="56" fill="var(--text)">MEM</text>
      <rect x="355" y="36" width="56" height="30" rx="4" fill="var(--bg-elevated-2)" stroke="var(--border)"/><text x="371" y="56" fill="var(--text)">WB</text>

      <rect x="175" y="81" width="56" height="30" rx="4" fill="var(--bg-elevated-2)" stroke="var(--border)"/><text x="193" y="101" fill="var(--text)">IF</text>
      <rect x="235" y="81" width="56" height="30" rx="4" fill="var(--bg-elevated-2)" stroke="var(--border)"/><text x="253" y="101" fill="var(--text)">ID</text>
      <rect x="295" y="81" width="56" height="30" rx="4" fill="var(--accent)" fill-opacity="0.8"/><text x="313" y="101" fill="var(--accent-contrast)">EX</text>
      <rect x="355" y="81" width="56" height="30" rx="4" fill="var(--bg-elevated-2)" stroke="var(--border)"/><text x="366" y="101" fill="var(--text)">MEM</text>
      <rect x="415" y="81" width="56" height="30" rx="4" fill="var(--bg-elevated-2)" stroke="var(--border)"/><text x="431" y="101" fill="var(--text)">WB</text>

      <rect x="235" y="126" width="56" height="30" rx="4" fill="var(--bg-elevated-2)" stroke="var(--border)"/><text x="253" y="146" fill="var(--text)">IF</text>
      <rect x="295" y="126" width="56" height="30" rx="4" fill="var(--bg-elevated-2)" stroke="var(--border)"/><text x="313" y="146" fill="var(--text)">ID</text>
      <rect x="355" y="126" width="56" height="30" rx="4" fill="var(--accent)" fill-opacity="0.8"/><text x="373" y="146" fill="var(--accent-contrast)">EX</text>
      <rect x="415" y="126" width="56" height="30" rx="4" fill="var(--bg-elevated-2)" stroke="var(--border)"/><text x="426" y="146" fill="var(--text)">MEM</text>
      <rect x="475" y="126" width="56" height="30" rx="4" fill="var(--bg-elevated-2)" stroke="var(--border)"/><text x="491" y="146" fill="var(--text)">WB</text>

      <rect x="295" y="171" width="56" height="30" rx="4" fill="var(--bg-elevated-2)" stroke="var(--border)"/><text x="313" y="191" fill="var(--text)">IF</text>
      <rect x="355" y="171" width="56" height="30" rx="4" fill="var(--bg-elevated-2)" stroke="var(--border)"/><text x="373" y="191" fill="var(--text)">ID</text>
      <rect x="415" y="171" width="56" height="30" rx="4" fill="var(--accent)" fill-opacity="0.8"/><text x="433" y="191" fill="var(--accent-contrast)">EX</text>
      <rect x="475" y="171" width="56" height="30" rx="4" fill="var(--bg-elevated-2)" stroke="var(--border)"/><text x="486" y="191" fill="var(--text)">MEM</text>
      <rect x="535" y="171" width="56" height="30" rx="4" fill="var(--bg-elevated-2)" stroke="var(--border)"/><text x="551" y="191" fill="var(--text)">WB</text>
    </g>
    <text x="115" y="222" fill="var(--text-muted)">Every later instruction reads $1 before the first one has written it back → forwarding needed.</text>
  </g>
</svg>
</div>

Throughput approaches one instruction per cycle. The price: **hazards**.

## The three hazards, and how we solved each

### 1. Data hazards → a three-way forwarding unit

Our hazard unit watches the destination registers of the **three** instructions ahead of the one in EX, and a 4-input mux in front of each ALU operand picks the freshest value:

| `ForwardA` / `ForwardB` | ALU operand comes from |
|---|---|
| 0 | Register file (no hazard) |
| 1 | Previous instruction — result sitting in EX/MEM |
| 2 | 2nd previous instruction — in MEM/WB |
| 3 | 3rd previous instruction — the value being written back this cycle |

**Priority matters:** if two older instructions both write the same register, forward from the **most recent** one. Getting this order wrong passes simple tests and fails on loops.

### 2. Load-use hazard → stall exactly one cycle

```
lw  $7, 0($2)      ; value only exists after MEM
naddi $2, $7, 15   ; needs $7 in EX — one cycle too early
```

Forwarding can't fix this: the data doesn't exist yet when the dependent instruction reaches EX. Our design stalls for exactly one cycle. The standard way to build that: detect "instruction in EX is a load AND its `rt` matches a source of the instruction in ID," then:

1. Freezes the PC and the IF/ID register (hold the same instructions one more cycle)
2. Injects a bubble (all control signals zero) into ID/EX
3. Next cycle, forwarding from MEM/WB delivers the loaded value

### 3. Control hazards → kill signals

By the time a branch resolves, the wrong-path instructions are already in the pipe. The PC control unit generates `PCSrc` (which next-PC to take) and two signals, **`kill1`** and **`kill2`**, that zero out the control bits of the wrong-path instructions in the pipeline registers — turning them into no-ops instead of letting them write registers or memory.

## How we tested it

Each test program targeted one failure mode, and each one is in the repo:

| Program | Exercises |
|---|---|
| Sequence of all instructions | Every opcode, single-cycle correctness |
| Bubble sort | Loops, branches, `LW`/`SW`, real data dependency chains |
| Count the 1-bits in a register | Shifts, branches, a tight loop |
| Independent instructions | Pipeline fill/drain with no hazards |
| Dependent instructions (> 5 in a chain) | Every forwarding path |
| Dependent instructions after `LW` | The load-use stall |
| Branching logic | `kill1`/`kill2` flushing |

The bubble sort, in our ISA:

```
          set 4                ; numOfComparisons = arraySize - 1
whileLoop: beqz $0, EndWhile
          xor  $1, $1, $1      ; i = 0
ForLoop:  nadd $5, $0, $1      ; $5 = $1 - $0  → zero when i == numOfComparisons
          beqz $5, EndForLoop
          addi $2, $1, 0
          lw   $3, 0($2)       ; array[i]
          lw   $4, 1($2)       ; array[i+1]   (word-addressed: +1)
          slt  $6, $4, $3
          beqz $6, Endif
          sw   $4, 0($2)       ; swap
          sw   $3, 1($2)
Endif:    addi $1, $1, 1
          j ForLoop
EndForLoop: addi $0, $0, -1
          j whileLoop
EndWhile: addi $7, $7, 1
```

Notice `lw $3` immediately followed by `lw $4` then `slt` using both — that's a load-use stall *and* a two-deep forwarding case in four lines. Real programs find bugs synthetic tests miss.

## If you're building one: the order that works

1. **Register file** alone — test simultaneous read-two/write-one.
2. **ALU** alone — test every op with edge values (0, -1, max int, overflow).
3. **Control ROM** — write the truth table in a spreadsheet first, then burn it.
4. **Single-cycle CPU** — run the all-instructions program, check every register after every step.
5. **Insert the four pipeline registers** — with no hazard logic, run only independent instructions.
6. **Add forwarding** — run the dependent-chain test.
7. **Add the load-use stall** — run the `LW` test.
8. **Add branch flushing** — run the branch test, then bubble sort as the final exam.

Each step adds one mechanism and one test. Skipping ahead means debugging three mechanisms at once.

Writing those test programs by hand in hex got old fast — which is why I wrote an [assembler and simulator](/Writing-an-Assembler-and-Simulator-in-Java/) for this ISA. That's the next post.
