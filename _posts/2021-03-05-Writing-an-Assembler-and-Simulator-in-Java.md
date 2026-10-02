---
title: "Writing an Assembler and Simulator for Our Custom CPU in Java"
excerpt: "Hand-assembling hex for a homemade CPU gets old fast. So I wrote a two-pass assembler and a simulator in Java — here's how labels get resolved, how instructions become bits, and how the same code doubles as a reference CPU."
header:
  image: /images/posts/assembler-simulator/simulator-result.png
tags: [Software, Java, assembler, compilers, CPU]
---
<p align="center">
<img src="/images/posts/assembler-simulator/assembler-input.png" alt="ICS233 Project Assembler" width="532" style="margin-inline:auto;"/>
</p>

Our [pipelined processor](/Building-a-Pipelined-RISC-Processor/) worked — but testing it meant translating every program by hand into 16-bit hex and loading it into instruction memory. One wrong bit, and you spend an hour debugging the CPU when the real bug is in your own arithmetic.

So, as a bonus part of the project, I wrote an <strong>assembler and simulator</strong> in Java with a Swing interface. The ideas are small enough to reuse for any custom instruction set, and the code is on <a href="https://github.com/YousefKJM/Assembler-Simulator-for-Pipelined-Processor" target="_blank" rel="noopener">GitHub</a>.

## How the tool works
Before the code, the big picture:

<div style="margin:2rem 0;padding:1.25rem;background:var(--bg-elevated);border:1px solid var(--border);border-radius:var(--radius-m);">
<svg viewBox="0 0 640 200" style="width:100%;height:auto;font-family:inherit;" role="img" aria-label="Tool flow: assembly source goes through pass one parsing to build a label map and instruction list, pass two encoding to produce hex, which loads into the Logisim CPU; the simulator decodes the same hex and executes it in software">
  <defs><marker id="as-arr" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto"><path d="M0,0 L8,4 L0,8 z" fill="var(--text-muted)"/></marker></defs>
  <g style="font-size:12px;">
    <rect x="5" y="30" width="100" height="56" rx="8" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="18" y="54" font-weight="700" fill="var(--text)">source.s</text><text x="18" y="72" fill="var(--text-muted)">labels, mnemonics</text>
    <rect x="135" y="30" width="125" height="56" rx="8" fill="var(--bg-elevated-2)" stroke="var(--accent)" stroke-width="2"/>
    <text x="148" y="54" font-weight="700" fill="var(--accent)">Pass 1: parse</text><text x="148" y="72" fill="var(--text-muted)">label map + inst list</text>
    <rect x="290" y="30" width="125" height="56" rx="8" fill="var(--bg-elevated-2)" stroke="var(--accent)" stroke-width="2"/>
    <text x="303" y="54" font-weight="700" fill="var(--accent)">Pass 2: encode</text><text x="303" y="72" fill="var(--text-muted)">resolve offsets → bits</text>
    <rect x="445" y="30" width="190" height="56" rx="8" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="458" y="54" font-weight="700" fill="var(--text)">hex image</text><text x="458" y="72" fill="var(--text-muted)">Logisim "v2.0 raw" / listing</text>
    <line x1="105" y1="58" x2="131" y2="58" stroke="var(--text-muted)" stroke-width="2" marker-end="url(#as-arr)"/>
    <line x1="260" y1="58" x2="286" y2="58" stroke="var(--text-muted)" stroke-width="2" marker-end="url(#as-arr)"/>
    <line x1="415" y1="58" x2="441" y2="58" stroke="var(--text-muted)" stroke-width="2" marker-end="url(#as-arr)"/>
    <rect x="290" y="130" width="125" height="56" rx="8" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="303" y="154" font-weight="700" fill="var(--text)">Simulator</text><text x="303" y="172" fill="var(--text-muted)">decode → run</text>
    <rect x="445" y="130" width="190" height="56" rx="8" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="458" y="154" font-weight="700" fill="var(--text)">Logisim CPU</text><text x="458" y="172" fill="var(--text-muted)">compare registers</text>
    <path d="M540,86 L540,126" stroke="var(--text-muted)" stroke-width="2" marker-end="url(#as-arr)" fill="none"/>
    <path d="M500,86 L500,108 L352,108 L352,126" stroke="var(--text-muted)" stroke-width="2" marker-end="url(#as-arr)" fill="none"/>
    <text x="10" y="170" fill="var(--text-muted)">Same hex, two executors —</text>
    <text x="10" y="188" fill="var(--text-muted)">if results differ, the bug is in hardware.</text>
  </g>
</svg>
</div>

The assembler reads the source program in two passes and produces a hex image that can be loaded directly into the Logisim CPU. The simulator then decodes the same hex and runs it in software. That last part is the most useful one: the simulator is a <strong>reference</strong>. If you run the same program in Logisim and in the simulator and a register is different, you know the bug is in the hardware.

## Using the assembler
The screenshot at the top of this article shows the main window with a small program loaded. It counts how many bits are set to 1 in the value stored at memory address 0:

```
        xor  $2, $2, $2 ;     $2 = counter = 0
        lw   $1, 0($0) ;      $1 = memory[0]
Next:   andi $3, $1, 1 ;      take the lowest bit
        add  $2, $2, $3 ;     add it to the counter
        srl  $1, $1, 1 ;      shift right
        bnez $1, Next ;       repeat until $1 is zero
```

The syntax is strict on purpose, because it keeps the parser simple:

1. The first column is reserved for a label. If there is no label, the line starts with a tab or spaces.
2. Every instruction ends with a semicolon `;`. Anything after it is a comment.

You can type the program or click "Load an Assembly File". Once you click "Assemble", the tool assembles the code, writes the output file and runs it in the simulator. A second window opens with the result:

<img src="/images/posts/assembler-simulator/simulator-result.png" alt="Simulator result window" width="551" style="margin-inline:auto;" />

The first box shows the generated machine code in Logisim's memory image format (`v2.0 raw`), ready to load into the instruction memory. The table shows the registers after the program finished. The tool preloads `memory[0] = 5`, which is `101` in binary, so the expected result is two 1-bits — and as you can see, `Regfile[2] = 2`.

## Pass 1: parse and record labels
Why two passes? Look at the branch `bnez $1, Next`. In this example `Next` is above the branch, but a forward branch like `beqz $5, EndLoop` refers to a label we haven't seen yet. So the first pass walks through the whole file and records <strong>where every label is</strong>. Then the second pass can resolve any reference:

```java
int lineNo = 0, stepNo = 0;   // lineNo: source line (for errors), stepNo: instruction address
while (scanner.hasNext()) {
    lineNo++;
    String line = scanner.nextLine();
    String code = line.split(";", 2)[0];            // remove the comment
    if (code.trim().isEmpty()) continue;            // empty or comment-only line

    String[] parts = code.split("[\t ]+", 3);       // [label:] mnemonic args
    String label = parts[0].trim();
    if (label.endsWith(":")) {
        labelMap.put(label.substring(0, label.length() - 1), stepNo);
    } else if (!label.isEmpty()) {
        throw new SyntaxException("Label must be followed by ':'", lineNo);
    }

    if (parts.length == 3) {                        // the line has an instruction
        Instruction inst = Instruction.createInstruction(
            Instruction.getInstByMnemonic(parts[1].trim()), lineNo, stepNo);
        inst.parseArgs(parts[2].trim().split(",[\t ]*"));
        instList.add(inst);
        stepNo++;                                   // only real instructions move the address
    }
}
```

Notice the <strong>two counters</strong>. `lineNo` counts every source line, so error messages point to the correct line in the editor. `stepNo` counts only instructions, because that is the address a label really refers to.

## Pass 2: instructions become bits
Every instruction is an enum entry that knows its opcode (and function code for R-type). Encoding is just joining fixed-width binary fields:

```java
String bits = toBinary(opcode, 5);
switch (format) {
    case R: bits += toBinary(rs, 3) + toBinary(rt, 3) + toBinary(rd, 3) + toBinary(funct, 2); break;
    case I: bits += toBinary(rs, 3) + toBinary(rt, 3) + toBinary(imm5, 5);                    break;
    case B: bits += toBinary(rs, 3) + toBinary(labelMap.get(target) - stepNo, 8);              break;
    case J: bits +=                   toBinary(labelMap.get(target) - stepNo, 11);             break;
}
```

The expression `labelMap.get(target) - stepNo` is where labels are resolved. Branches and jumps store a <strong>signed offset from the current instruction</strong>, not an absolute address. We can check this with the real output from the screenshot above:

| Assembly | Fields | Binary | Hex |
|---|---|---|---|
| `xor $2, $2, $2` | op=0 · rs=2 · rt=2 · rd=2 · f=3 | `00000 010 010 010 11` | `024b` |
| `lw $1, 0($0)` | op=16 · rs=0 · rt=1 · imm5=0 | `10000 000 001 00000` | `8020` |
| `bnez $1, Next` | op=21 · rs=1 · imm8=−3 | `10101 001 11111101` | `a9fd` |

`Next` is instruction 2 and `bnez` is instruction 5, so the offset is 2 − 5 = −3, stored in two's complement as `11111101`. Also notice that in assembly the order is `rd, rs, rt`, but in the bits it is `rs, rt, rd` — exactly the kind of detail that is easy to get wrong by hand and impossible to get wrong once the code is correct.

## The simulator
Here is the nice part: each `Instruction` object also knows how to <strong>run itself</strong> on a register file and memory, and returns the next PC:

```java
public int run(int pc, RegisterFile r, Memory m) {
    int next = pc + 1;
    switch (inst) {
        case ADD:  r.set(rd,  r.get(rs) + r.get(rt));  break;
        case NADD: r.set(rd, -r.get(rs) + r.get(rt));  break;   // rt - rs
        case CAND: r.set(rd, ~r.get(rs) & r.get(rt));  break;
        case LW:   r.set(rt, m.read(r.get(rs) + imm5));  break;
        case SW:   m.write(r.get(rs) + imm5, r.get(rt)); break;
        case BNEZ: if (r.get(rs) != 0) next = pc + imm8; break;
        case JAL:  r.set(7, pc + 1); next = pc + imm11;  break;
        case SET:  r.set(0, imm11);                       break;
        case SSET: r.set(0, (r.get(0) << 11) | imm11);    break;
    }
    return next;
}
```

The simulator loop is just fetch, execute, repeat. It runs on its own thread, so the window stays responsive and an endless loop can be killed after a few seconds:

```java
public void run() {
    while (!kill) {
        if (pc == instList.size()) return;           // end of the program
        pc = instList.get(pc).run(pc, regfile, memory);
        Thread.yield();
    }
}
```

> **By design:** The simulator is not cycle-accurate — it doesn't simulate the pipeline. That is on purpose. It shows what the program <em>should</em> compute, which is exactly what you want when you are checking a pipeline that may compute it wrong.

## Error messages
Students (including me) write broken assembly all the time, so good error messages matter more than anything else in a tool like this. Each kind of problem has its own exception with the line number. For example, if I forget an argument in an `add` instruction:

<img src="/images/posts/assembler-simulator/assembler-error.png" alt="Assembler showing a syntax error" width="532" style="margin-inline:auto;" />

The full message is: <em>"Syntax Error: Invalid argument (Too few arguments; 3 arguments are expected, but found 2 arguments) on line 1."</em> These are the exceptions the tool uses:

| Exception | When |
|---|---|
| `SyntaxException` | Missing `:`, missing arguments, a label that looks like a number |
| `InvalidArgumentException` | A register outside `$0`–`$7`, an immediate out of range |
| `LabelNotFoundException` | A jump to a label that was never defined |
| `InvalidInstructionException` | Hex that doesn't decode to any instruction (simulator side) |

## What it comes down to

An assembler sounds like a big project, but for a small instruction set it boils down to a few ideas: one enum entry per instruction, a first pass that records labels, a second pass that joins binary fields, and separate counters for source lines and addresses. Make the instructions executable and you get a simulator almost for free — a reference you can trust when the hardware misbehaves. Start from your instruction table and check your first encodings by hand, like the table above. Source code and sample programs are on <a href="https://github.com/YousefKJM/Assembler-Simulator-for-Pipelined-Processor" target="_blank" rel="noopener">GitHub</a>.
