---
title: "Building a Pipelined RISC Processor in Logisim"
excerpt: "In this article I would like to present how my team designed a 32-bit RISC processor from scratch in Logisim — first as a single-cycle CPU, then as a five-stage pipeline with forwarding, stalling and branch flushing — using the real circuits from our project."
header:
  image: /images/posts/pipelined-cpu/single-cycle-datapath.png
---

<p align="center">
<img src="/images/posts/pipelined-cpu/single-cycle-datapath.png" alt="Single cycle processor in Logisim" style="margin-inline:auto;"/>
</p>

<h3><strong>Short introduction</strong></h3>
Every software engineer uses a processor all day, but very few of us build one. In the ICS 233 course (Computer Architecture &amp; Assembly Language) at KFUPM, my team of three did exactly that: we designed a <strong>32-bit RISC processor</strong> gate by gate in <a href="http://www.cburch.com/logisim/" target="_blank" rel="noopener">Logisim</a>, first as a single-cycle CPU and then as a <strong>five-stage pipelined</strong> CPU. On the pipelined design I worked on the next-PC logic, the main control unit and most of the processor integration. In this article I would like to walk you through the design step by step, using the actual circuits from our project report. The full project is available on <a href="https://github.com/YousefKJM/Pipelined-Processor-Design" target="_blank" rel="noopener">GitHub</a>.

&nbsp;
<h3><strong>The instruction set</strong></h3>
Before drawing a single wire we had to agree on the instruction set. Here are the main properties of our processor:

| Property | Value |
|---|---|
| Data width | 32-bit |
| Registers | 8 general-purpose registers `R0`–`R7` (so each register field is 3 bits) |
| Instruction width | **16-bit**, with a 5-bit opcode |
| Memory | Word-addressed, so the next instruction is `PC + 1` |
| Special registers | `R7` holds the return address for `JAL`, `R0` is the target of `SET`/`SSET` |

All instructions fit in one of four formats:

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
| R | 0 and 1 (function 0–3) | `AND CAND OR XOR` · `ADD NADD SLT SLTU` |
| I | 4–17 | `ANDI CANDI ORI XORI ADDI NADDI SLTI SLTUI` · `SLL SRL SRA ROR` · `LW SW` |
| B | 20–27 | `BEQZ BNEZ BLTZ BGEZ BGTZ BLEZ` · `JR JALR` |
| J | 28–31 | `SET SSET` · `J JAL` |

Two instructions are not the usual MIPS ones:

- **`CAND rd, rs, rt`** means `rd = ~rs & rt` (complement then AND)
- **`NADD rd, rs, rt`** means `rd = rt − rs`, so we get subtraction without a separate `SUB` opcode

> **_NOTE:_**  With only 11 bits of immediate, a 32-bit constant is built in steps: `set imm11` loads `R0 = imm11`, then every `sset imm11` does `R0 = (R0 << 11) | imm11`. It is the same idea as `lui` + `ori` in MIPS.

&nbsp;
<h3><strong>Single cycle design</strong></h3>
Lets start from the single-cycle processor. My advice here: build it and test it completely before you even think about the pipeline. Any bug you leave in this stage becomes much harder to find when five instructions are running at the same time.

<strong>Register file</strong>

The register file reads two registers and writes one register in the same cycle. Writing is done with a demultiplexer that enables only the selected register, and reading is done with two 8-to-1 multiplexers, one for each output (`Read Data 1` and `Read Data 2`):

<img src="/images/posts/pipelined-cpu/register-file.png" alt="Register file circuit" style="margin-inline:auto;" />

<strong>Arithmetic and Logic Unit (ALU)</strong>

The ALU is built from logic gates, shifters, comparators and multiplexers. All operations (`AND`, `CAND`, `OR`, `XOR`, `ADD`, `NADD`, `SLT`, `SLTU` and the shifts) are calculated in parallel, and a multiplexer controlled by the 4-bit `ALUOp` signal selects the result we need:

<img src="/images/posts/pipelined-cpu/alu.png" alt="ALU circuit" style="margin-inline:auto;" />

<strong>Main control unit</strong>

Instead of writing a logic equation for every control signal, we decoded the opcode and used a <strong>ROM</strong>, where every word is the set of control signals for one instruction. Adding or fixing an instruction means changing one row in the ROM instead of redesigning gates:

<img src="/images/posts/pipelined-cpu/main-control-unit.png" alt="Main control unit with decoder and ROM" style="margin-inline:auto;" />

These are the control signals it generates:

| Signal | 0 | 1 | 2 | 3 |
|---|---|---|---|---|
| `RegDst` | Rt | Rd | R7 (for `JAL`) | R0 (for `SET`) |
| `ExtOp` | zero-extend | sign-extend | – | – |
| `ALUSrc` | BusB (Rt) | extended imm5 | extended imm11 | extended imm11 |
| `MemRd` / `MemWr` | off | on | – | – |
| `WBdata` | ALU result | memory output | PC + 1 (return address) | extended imm11 |

Once all components are connected, we get the complete single-cycle processor shown at the top of this article: instruction fetch, instruction splitter, register file, ALU, data memory, next PC logic and the control unit.

&nbsp;
<h3><strong>Pipelined design</strong></h3>
In the pipelined version we split the datapath into five stages with pipeline registers between them: <strong>IF</strong> (instruction fetch), <strong>ID</strong> (instruction decode), <strong>EX</strong> (execute), <strong>MEM</strong> (memory access) and <strong>WB</strong> (write back). Now a new instruction can start every cycle:

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

As you can see above, every instruction after the first one needs `$1` before it has been written back. This is called a <strong>data hazard</strong>, and solving hazards is the real work in a pipelined design. Lets go through the stages one by one.

<strong>IF — Instruction Fetch</strong>

The PC selects the next address from four options (`PC+1`, `JUMP`, `BRANCH`, `JUMPR`) using the `PCSrc` signal. Notice two important signals here: `Stall` disables writing the PC and the instruction register, and `Kill1` replaces the fetched instruction with `0000` (a no-op):

<img src="/images/posts/pipelined-cpu/pipeline-if-stage.png" alt="Instruction fetch stage" style="margin-inline:auto;" />

<strong>ID — Instruction Decode</strong>

Here the instruction is split into its fields, registers are read, and the control unit generates the signals. This is also where the <strong>forwarding multiplexers</strong> sit: `ForwardA` and `ForwardB` decide whether each ALU operand comes from the register file or from one of the three instructions ahead (`FW1`, `FW2`, `FW3`):

<img src="/images/posts/pipelined-cpu/pipeline-id-stage.png" alt="Instruction decode stage with hazard unit" style="margin-inline:auto;" />

<strong>EX, MEM and WB</strong>

The ALU runs in EX, data memory is accessed in MEM, and the result is written back in WB. At the bottom you can see how control signals travel with the instruction through the pipeline registers. If `Kill2` or `Stall` is active, the multiplexer sends zeros instead, which turns the instruction into a bubble:

<img src="/images/posts/pipelined-cpu/pipeline-ex-mem-wb.png" alt="Execute, memory and write back stages" style="margin-inline:auto;" />

&nbsp;
<h3><strong>Hazard detection unit</strong></h3>
The hazard unit compares the source registers of the current instruction (`s`, `t`) with the destination registers of the three previous instructions (`d2`, `d3`, `d4`) and checks if those instructions really write a register (`RegWr`):

<img src="/images/posts/pipelined-cpu/hazard-unit.png" alt="Hazard detection and forwarding unit" style="margin-inline:auto;" />

The forwarding signals mean:

| `ForwardA` / `ForwardB` | ALU operand comes from |
|---|---|
| 0 | Register file (no hazard) |
| 1 | Previous instruction (EX stage) |
| 2 | Second previous instruction (MEM stage) |
| 3 | Third previous instruction (WB stage) |

Look at the chain of three multiplexers on the right side of the circuit. The comparison for the <strong>most recent</strong> instruction (`EC1`) is connected last, so it always wins. This order is very important: if two older instructions write the same register, we must take the newest value. A wrong order passes simple tests and fails on loops.

<strong>The load-use stall</strong>

Forwarding cannot solve this case:

```
lw    $7, 0($2)    ; the value exists only after MEM
naddi $2, $7, 15   ; but it is needed in EX one cycle earlier
```

That is why the bottom of the hazard unit generates:

```
Stall = (EC1A OR EC1B) AND EX.MemRd
```

In words: if the previous instruction is a load (`MemRd`) and the current instruction needs its destination register, freeze the PC and the instruction register for one cycle and insert a bubble. In the next cycle the value is forwarded normally.

&nbsp;
<h3><strong>PC control unit and branches</strong></h3>
The PC control unit decides the next PC and which wrong instructions must be cancelled. Branch conditions come from the ALU flags (`>0`, `=0`, `<0`), for example `BGEZ` is taken when `EQZ OR GTZ`:

<img src="/images/posts/pipelined-cpu/pc-control-unit.png" alt="PC control unit with branch and kill logic" style="margin-inline:auto;" />

There are two kill signals:

- **`Kill1`** cancels the instruction in IF. It is used for jumps (and branches), because one wrong instruction is already fetched.
- **`Kill2`** cancels the instruction in ID as well. It is used for taken branches, because a branch is resolved later and two wrong instructions are already in the pipeline.

&nbsp;
<h3><strong>Testing</strong></h3>
Each test program was written to test one specific part of the design:

| Program | What it tests |
|---|---|
| Sequence of all instructions | Every opcode in the single-cycle design |
| Bubble sort | Loops, branches, `LW`/`SW` and real dependency chains |
| Count the 1-bits in a register | Shifts, branches and a tight loop |
| Independent instructions | Pipeline fill and drain without hazards |
| Dependent instructions (more than 5 in a chain) | All forwarding paths |
| Dependent instructions after `LW` | The load-use stall |
| Branching logic | `Kill1` / `Kill2` flushing |

This is the bubble sort program in our instruction set:

```
          set 4                ; numOfComparisons = arraySize - 1
whileLoop: beqz $0, EndWhile
          xor  $1, $1, $1      ; i = 0
ForLoop:  nadd $5, $0, $1      ; $5 = $1 - $0, zero when i == numOfComparisons
          beqz $5, EndForLoop
          addi $2, $1, 0
          lw   $3, 0($2)       ; array[i]
          lw   $4, 1($2)       ; array[i+1]
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

Before running the program, the array in data memory is in reverse order:

<img src="/images/posts/pipelined-cpu/bubble-sort-before.png" alt="Data memory before bubble sort" width="520" style="margin-inline:auto;" />

After running it, the array is sorted:

<img src="/images/posts/pipelined-cpu/bubble-sort-after.png" alt="Data memory after bubble sort" width="520" style="margin-inline:auto;" />

> **_NOTE:_**  Notice the two `lw` instructions followed directly by `slt`, which uses both loaded values. In four lines this program tests the load-use stall and two levels of forwarding. Real programs find bugs that simple tests miss.

&nbsp;
<h3><strong>Summary</strong></h3>
Building a processor teaches you things that are hard to learn from a textbook: why the control unit is easier as a ROM, why forwarding priority matters, and why some hazards can only be solved by stalling. If you want to build your own, follow this order and test after each step:

1. Register file alone
2. ALU alone, with edge values (0, -1, overflow)
3. Control ROM (write the truth table in a spreadsheet first)
4. Complete single-cycle CPU
5. Add the pipeline registers and test only independent instructions
6. Add forwarding and test dependent instructions
7. Add the load-use stall
8. Add branch flushing, then run bubble sort as the final test

Writing all those test programs by hand in hex was painful, which is why I also wrote an [assembler and simulator](/Writing-an-Assembler-and-Simulator-in-Java/) for this instruction set. I will explain it in the next article. The full Logisim circuit, test programs and project report are available on <a href="https://github.com/YousefKJM/Pipelined-Processor-Design" target="_blank" rel="noopener">GitHub</a>.
