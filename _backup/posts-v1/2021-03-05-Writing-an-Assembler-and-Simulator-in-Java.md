---
title: "Writing a Two-Pass Assembler and Simulator for a Custom CPU (in Java)"
excerpt: "Hand-translating assembly to hex for a homemade CPU is miserable, so I wrote a tool to do it. How a two-pass assembler resolves labels, how instructions become bits, how the same objects run as a simulator — with worked encodings you can check by hand."
---

After my team built a [pipelined RISC processor](/Building-a-Pipelined-RISC-Processor/) in Logisim, testing it meant translating every program into 16-bit hex by hand. One wrong bit and you're debugging the CPU for a typo in your own arithmetic. So, as a solo bonus project, I wrote an **assembler and simulator** in Java with a JavaFX/Swing UI. The code is on [GitHub](https://github.com/YousefKJM/Assembler-Simulator-for-Pipelined-Processor).

This post is the design, so you can build one for your own ISA.

## The pipeline of the tool itself

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

That last box is the real payoff. The simulator is a **reference implementation**: run a program in both, and any register that disagrees points straight at a hardware bug.

## Source syntax (keep it parseable)

```
<label:>  <TAB>  mnemonic  args  ;  comment
```

```
ForLoop:  nadd $5, $0, $1 ;
          beqz $5, EndForLoop ;
          addi $2, $1, 0 ;
          lw   $3, 0($2) ;
```

Two rules made the parser trivial: **the first column is reserved for a label** (leading whitespace means "no label"), and **every instruction ends with `;`** (anything after it is a comment). A grammar this rigid isn't elegant, but it means one `split` handles every line.

## Pass 1: parse and record labels

Why two passes? A forward branch (`beqz $5, EndForLoop`) references a label you haven't seen yet. Pass 1 walks the file once and records **where every label lives**; pass 2 can then resolve any reference.

```java
int lineNo = 0, stepNo = 0;           // lineNo: source line (for errors); stepNo: instruction address
while (scanner.hasNext()) {
    lineNo++;
    String line = scanner.nextLine();
    String code = line.split(";", 2)[0];            // strip comment
    if (code.trim().isEmpty()) continue;            // blank / comment-only line

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
        stepNo++;                                   // only real instructions advance the address
    }
}
```

The detail that matters: **two counters.** `lineNo` counts source lines so error messages point at the right line in the editor. `stepNo` counts only instructions, because that's the address a label actually resolves to.

## Pass 2: instructions become bits

Every mnemonic is an enum entry carrying its opcode (and function code for R-type). Encoding is concatenating fixed-width binary fields:

```java
String bits = toBinary(opcode, 5);
switch (format) {
    case R: bits += toBinary(rs, 3) + toBinary(rt, 3) + toBinary(rd, 3) + toBinary(funct, 2); break;
    case I: bits += toBinary(rs, 3) + toBinary(rt, 3) + toBinary(imm5, 5);                    break;
    case B: bits += toBinary(rs, 3) + toBinary(labelMap.get(target) - stepNo, 8);              break;
    case J: bits +=                   toBinary(labelMap.get(target) - stepNo, 11);             break;
}
```

`labelMap.get(target) - stepNo` is the label resolution: branches and jumps store a **signed offset relative to the current instruction**, not an absolute address. Backward jumps produce negative offsets, encoded in two's complement within the field.

### Worked encodings — check them by hand

| Assembly | Fields | Binary | Hex |
|---|---|---|---|
| `add $2, $3, $4` | op=1 · rs=3 · rt=4 · rd=2 · f=0 | `00001 011 100 010 00` | `0B88` |
| `addi $2, $3, 5` | op=8 · rs=3 · rt=2 · imm5=5 | `01000 011 010 00101` | `4345` |
| `beqz $5, +4` | op=20 · rs=5 · imm8=4 | `10100 101 00000100` | `A504` |
| `j -3` | op=30 · imm11=−3 | `11110 11111111101` | `F7FD` |

Note the R-type quirk: the assembly order is `rd, rs, rt`, but the bit order is `rs, rt, rd`. That mismatch is exactly the kind of thing that's easy to botch by hand and impossible to botch in code once it's right.

### Range checks belong in the assembler

An `imm5` holds −16…15 signed. A branch `imm8` reaches −128…127 instructions. If a loop body grows past that, the encoding silently wraps. Throw an error instead:

```java
if (offset < -128 || offset > 127)
    throw new SyntaxException("Branch target out of range (" + offset + ")", lineNo);
```

## Output formats

The same instruction list emits two formats:

```
 0 :    0B88; % (00) %        ← listing: address, hex, comment — human-readable
 1 :    4345; % (01) %
 2 :    A504; % (02) %
```

```
v2.0 raw
0B88 4345 A504 ...            ← Logisim memory image: right-click ROM → Load Image
```

Supporting the exact format your hardware tool loads is what turns "an assembler" into "something people actually use."

## The simulator: the same objects, executed

Each `Instruction` object knows how to **run itself** against a register file and memory, returning the next PC:

```java
public int run(int pc, RegisterFile r, Memory m) {
    int next = pc + 1;
    switch (inst) {
        case ADD:  r.set(rd,  r.get(rs) + r.get(rt));  break;
        case NADD: r.set(rd, -r.get(rs) + r.get(rt));  break;   // rt - rs
        case CAND: r.set(rd, ~r.get(rs) & r.get(rt));  break;
        case LW:   r.set(rt, m.read(r.get(rs) + imm5));  break;
        case SW:   m.write(r.get(rs) + imm5, r.get(rt)); break;
        case BEQZ: if (r.get(rs) == 0) next = pc + imm8; break;
        case JAL:  r.set(7, pc + 1); next = pc + imm11;  break;
        case SET:  r.set(0, imm11);                       break;
        case SSET: r.set(0, (r.get(0) << 11) | imm11);    break;
    }
    return next;
}
```

And the simulator loop is just fetch → execute → repeat, on its own thread so the UI stays responsive and a runaway loop can be killed:

```java
public void run() {
    while (!kill) {
        if (pc == instList.size()) return;           // fell off the end: program finished
        pc = instList.get(pc).run(pc, regfile, memory);
        Thread.yield();
    }
}
```

The simulator is **not** cycle-accurate — it doesn't model the pipeline. That's deliberate. It models what the program *should* compute, which is exactly what you want as a reference for a pipeline that might be computing it wrong.

## Error handling is the UX

Students (including me) write broken assembly constantly. Each failure mode got its own exception, carrying the source line number:

| Exception | Triggered by |
|---|---|
| `SyntaxException` | Missing `:`, missing args, label that looks like a number |
| `InvalidArgumentException` | Register out of `$0`–`$7`, immediate out of range |
| `LabelNotFoundException` | Jump to a label that was never defined |
| `InvalidInstructionException` | Hex that doesn't decode to any opcode (simulator side) |

"Line 14: Invalid mnemonic (`addd`)" saves an hour. "Error" saves nothing.

## Build your own: the checklist

1. Write the ISA table first — opcode, format, field widths, semantics. The code is a transcription of it.
2. One enum entry per instruction; opcode and format live there, not in `if` chains.
3. Pass 1 = labels + instruction list. Pass 2 = encode. Don't try to do it in one pass.
4. Track source line and instruction address separately.
5. Range-check every immediate and offset.
6. Emit the exact file format your hardware tool loads.
7. Make instructions executable and you get a simulator almost for free.
8. Test the assembler with hand-verified encodings, like the table above, before trusting it on the CPU.
