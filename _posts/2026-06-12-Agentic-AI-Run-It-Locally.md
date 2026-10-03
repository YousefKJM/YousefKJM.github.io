---
title: "Agentic AI, Part 2: Build It Locally for Free — and Five Projects to Try"
excerpt: "No API key, no cloud, no cost — run the same agent entirely on your laptop with Ollama. Then five projects to build, from a Downloads organizer to a malware-triage agent that writes its own report."
header:
  image: /images/posts/agentic-ai/agent-run.png
tags: [AI, agents, LLM, Ollama]
---
![A terminal running a local agent: it lists files, requests moves, waits for approval, and prints a summary](/images/posts/agentic-ai/agent-run.png)

In [part 1](/Agentic-AI-Getting-Started/) we opened the box: an agent is just a loop around a language model that can call tools, and we built a working one — with guardrails — against Claude's API. Two questions came back more than any other. *Can I run this without paying for an API?* And *what should I actually build?*

This part answers both. First, you'll run the exact same agent **entirely on your own laptop — zero cost, fully private, no internet required** — using Ollama and an open-weight model. Then five projects to build, ordered from a 40-line warm-up to a proper capstone: a malware-triage agent that runs static and dynamic analysis and writes its own technical report.

The thread running through all of it: the loop never changes. Swap the cloud client for a local one, swap one set of tools for another — the agent skill you learned in part 1 is the same skill here.

## Run it locally, for free

In [part 1](/Agentic-AI-Getting-Started/) we built the agent against Claude's API — the fastest way to get a capable one. But you don't *need* a cloud model, or a credit card, or even an internet connection. A laptop from the last few years can run a capable-enough model entirely on your own hardware — which means **zero cost, full privacy, and it works on a plane.** For a security person especially, "the data never leaves my machine" is sometimes the whole point.

The tool that makes this painless is **Ollama**. It downloads open-weight models, runs them locally, and — importantly for us — speaks native tool calling, so the exact loop you just learned works unchanged.

<div style="margin:2rem 0;padding:1.25rem;background:var(--bg-elevated);border:1px solid var(--border);border-radius:var(--radius-m);">
<svg viewBox="0 0 640 230" style="width:100%;height:auto;font-family:inherit;" role="img" aria-label="Local agent stack: your laptop's CPU, RAM or GPU runs the Ollama runtime, which loads a quantized open-weight model such as Llama 3.1; your same agent loop talks to Ollama on localhost instead of a cloud API. The only thing that changes from the cloud version is the client; the loop, tools and guardrails are identical.">
  <defs><marker id="lo-a" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto"><path d="M0,0 L8,4 L0,8 z" fill="var(--accent)"/></marker></defs>
  <g style="font-size:12px;">
    <rect x="5" y="30" width="150" height="110" rx="10" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="80" y="54" text-anchor="middle" font-weight="700" fill="var(--text)">Your laptop</text>
    <text x="80" y="78" text-anchor="middle" fill="var(--text-muted)">CPU · RAM · GPU</text>
    <text x="80" y="98" text-anchor="middle" fill="var(--text-muted)">(Apple Silicon</text>
    <text x="80" y="114" text-anchor="middle" fill="var(--text-muted)">is great for this)</text>
    <rect x="175" y="30" width="150" height="110" rx="10" fill="var(--bg-elevated-2)" stroke="var(--accent)"/>
    <text x="250" y="54" text-anchor="middle" font-weight="700" fill="var(--accent)">Ollama</text>
    <text x="250" y="78" text-anchor="middle" fill="var(--text-muted)">runs the model,</text>
    <text x="250" y="96" text-anchor="middle" fill="var(--text-muted)">serves it on</text>
    <text x="250" y="114" text-anchor="middle" fill="var(--text-muted)">localhost:11434</text>
    <rect x="345" y="30" width="150" height="110" rx="10" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="420" y="54" text-anchor="middle" font-weight="700" fill="var(--text)">Open model</text>
    <text x="420" y="78" text-anchor="middle" fill="var(--text-muted)">Llama 3.1 / 3.2,</text>
    <text x="420" y="96" text-anchor="middle" fill="var(--text-muted)">Qwen 2.5, Mistral</text>
    <text x="420" y="114" text-anchor="middle" fill="var(--text-muted)">(4-bit quantized)</text>
    <rect x="515" y="30" width="120" height="110" rx="10" fill="var(--accent)" fill-opacity="0.12" stroke="var(--accent)"/>
    <text x="575" y="54" text-anchor="middle" font-weight="700" fill="var(--accent)">Your loop</text>
    <text x="575" y="78" text-anchor="middle" fill="var(--text-muted)">same code,</text>
    <text x="575" y="96" text-anchor="middle" fill="var(--text-muted)">same tools,</text>
    <text x="575" y="114" text-anchor="middle" fill="var(--text-muted)">same guardrails</text>
    <line x1="155" y1="85" x2="173" y2="85" stroke="var(--accent)" stroke-width="2" marker-end="url(#lo-a)"/>
    <line x1="325" y1="85" x2="343" y2="85" stroke="var(--accent)" stroke-width="2" marker-end="url(#lo-a)"/>
    <line x1="513" y1="85" x2="497" y2="85" stroke="var(--accent)" stroke-width="2" marker-end="url(#lo-a)"/>
    <rect x="5" y="165" width="630" height="55" rx="10" fill="none" stroke="var(--text-muted)" stroke-dasharray="5 5"/>
    <text x="320" y="188" text-anchor="middle" font-weight="700" fill="var(--text)">The only thing that changes from the cloud version is the client.</text>
    <text x="320" y="208" text-anchor="middle" fill="var(--text-muted)">The agent loop, the tools, the memory and the guardrails are identical.</text>
  </g>
</svg>
</div>

**Step 1 — install Ollama and pull a model.** One install, one download:

```bash
# macOS/Linux (Windows has an installer at ollama.com)
curl -fsSL https://ollama.com/install.sh | sh

# Pull a tool-capable model. Start small; size up only if you need to.
ollama pull llama3.1           # 8B — the sweet spot for local agents
# ollama pull llama3.2:3b      # 3B — snappy, runs on almost anything
ollama run llama3.1 "hello"    # quick sanity check
```

**Step 2 — match the model to your hardware.** Ollama ships 4-bit quantized models, so they're far smaller than the raw parameter count suggests. Rough guide:

| Model | ~Memory | Runs comfortably on | Feel |
|---|---|---|---|
| 1–3B (`llama3.2:3b`, `qwen2.5:3b`) | 3–6 GB | any modern laptop, CPU-only | snappy; fine for simple tool loops |
| 7–8B (`llama3.1`, `qwen2.5:7b`) | 6–10 GB | 16 GB RAM, or any GPU ≥ 8 GB | the local-agent sweet spot |
| 13–14B | 12–20 GB | 32 GB RAM / 12–16 GB GPU | stronger reasoning, slower on CPU |
| 30B+ | 24 GB+ | workstation GPU / Apple Silicon with lots of unified memory | diminishing returns on a laptop |

**Step 3 — point your agent at it.** Here's the Downloads tidy-up agent from [part 1](/Agentic-AI-Getting-Started/), rewritten for Ollama. Notice the tools, the loop and the approval guardrail are *exactly the same* — only the model call changed:

```python
import json, shutil
from pathlib import Path
import ollama

ROOT = Path("~/Downloads").expanduser()

def list_files(folder: str = ".") -> str:
    """List files and folders inside the Downloads folder.

    Args:
        folder: Sub-folder to list, default '.'.
    """
    path = (ROOT / folder).resolve()
    if not path.is_relative_to(ROOT):
        return "Error: outside the allowed folder"
    return json.dumps([f.name + ("/" if f.is_dir() else "") for f in sorted(path.iterdir())])

def move_file(name: str, dest_folder: str) -> str:
    """Move one file into a sub-folder (created if missing). The user must approve each move.

    Args:
        name: File name inside Downloads.
        dest_folder: Target sub-folder, e.g. 'Documents'.
    """
    src, dest = (ROOT / name).resolve(), (ROOT / dest_folder).resolve()
    if not (src.is_relative_to(ROOT) and dest.is_relative_to(ROOT)):
        return "Error: outside the allowed folder"
    if input(f"  approve move {name} -> {dest_folder}/ ? [y/N] ").lower() != "y":
        return "The user declined this move."
    dest.mkdir(exist_ok=True)
    shutil.move(src, dest / src.name)
    return f"Moved {name} to {dest_folder}/"

TOOLS = {"list_files": list_files, "move_file": move_file}

def run(goal: str, model: str = "llama3.1", max_steps: int = 15):
    messages = [
        {"role": "system", "content": "You are a careful file-organizing assistant. Look before you act."},
        {"role": "user", "content": goal},
    ]
    for _ in range(max_steps):
        res = ollama.chat(model=model, messages=messages, tools=[list_files, move_file])
        msg = res.message
        messages.append(msg)                        # keep the assistant turn (it may hold tool_calls)
        if not msg.tool_calls:                       # no tool wanted -> the model is done
            print("🤖", msg.content)
            return
        for call in msg.tool_calls:
            name = call.function.name
            args = call.function.arguments           # Ollama hands you a dict already
            print("🔧", name, args)
            output = TOOLS[name](**args)
            messages.append({"role": "tool", "tool_name": name, "content": output})
    print("Stopped: step limit reached")

if __name__ == "__main__":
    run("Tidy up my Downloads folder: group files into sensible sub-folders.")
```

```bash
pip install ollama && python tidy_local.py       # no API key, nothing leaves your machine
```

> **Honest expectations:** a local 8B model is not Claude. It reasons less deeply, follows long instructions less reliably, and will sometimes fumble a tool call. The fixes are practical: pick a model that genuinely supports tool calling (Llama 3.1/3.2, Qwen 2.5, Mistral), keep the toolset small (2–5 tools), write crisp tool descriptions, and lower the temperature for steadier behaviour. For learning the mechanics, for private data, and for simple-to-moderate tasks, local is more than enough — and the skills transfer straight back to the cloud version.

> **Privacy win:** because the model runs on your box, the files, emails and logs your agent reads never touch a third party. That is exactly why local models are worth knowing for sensitive work — the phishing-triage and malware ideas below are built on it.

## Five agents worth building

Reading about agents only gets you so far. Here are five worth building — the first four are an evening each, the last is a proper capstone. All of them are the same loop with different tools; each one below lists the tools you give it and the steps to get there.

<div style="margin:2rem 0;padding:1.25rem;background:var(--bg-elevated);border:1px solid var(--border);border-radius:var(--radius-m);">
<svg viewBox="0 0 640 325" style="width:100%;height:auto;font-family:inherit;" role="img" aria-label="Five agent projects: a Downloads tidy-up agent you have already built; a private phishing-triage agent that reads .eml files and extracts indicators; an overnight log summarizer that greps and counts a log file; a notes assistant that answers from your own Markdown notes; and a capstone malware-triage agent that runs static and dynamic analysis and writes a full technical report with snippets and screenshots.">
  <g style="font-size:12px;">
    <rect x="5" y="15" width="205" height="140" rx="12" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="22" y="40" font-size="22">🗂️</text>
    <text x="22" y="66" font-weight="700" fill="var(--text)">1 · Downloads tidy-up</text>
    <text x="22" y="90" fill="var(--text-muted)">sorts Downloads into</text>
    <text x="22" y="108" fill="var(--text-muted)">sub-folders — you</text>
    <text x="22" y="126" fill="var(--text-muted)">already built this one</text>
    <text x="22" y="148" fill="var(--text)">tools: list · move</text>
    <rect x="218" y="15" width="205" height="140" rx="12" fill="var(--bg-elevated-2)" stroke="var(--accent)"/>
    <text x="235" y="40" font-size="22">📧</text>
    <text x="235" y="66" font-weight="700" fill="var(--text)">2 · Phishing triage</text>
    <text x="235" y="90" fill="var(--text-muted)">reads .eml, extracts</text>
    <text x="235" y="108" fill="var(--text-muted)">IOCs, verdicts —</text>
    <text x="235" y="126" fill="var(--text-muted)">all offline &amp; private</text>
    <text x="235" y="148" fill="var(--text)">tools: read · extract</text>
    <rect x="431" y="15" width="204" height="140" rx="12" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="448" y="40" font-size="22">🌙</text>
    <text x="448" y="66" font-weight="700" fill="var(--text)">3 · Night-shift log</text>
    <text x="448" y="90" fill="var(--text-muted)">greps + counts a log,</text>
    <text x="448" y="108" fill="var(--text-muted)">summarizes the</text>
    <text x="448" y="126" fill="var(--text-muted)">anomalies for you</text>
    <text x="448" y="148" fill="var(--text)">tools: grep · count</text>
    <rect x="5" y="170" width="311" height="140" rx="12" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="22" y="195" font-size="22">📚</text>
    <text x="22" y="221" font-weight="700" fill="var(--text)">4 · Notes assistant</text>
    <text x="22" y="245" fill="var(--text-muted)">answers questions from your own</text>
    <text x="22" y="263" fill="var(--text-muted)">Markdown notes, with citations</text>
    <text x="22" y="301" fill="var(--text)">tools: search · read</text>
    <rect x="324" y="170" width="311" height="140" rx="12" fill="var(--accent)" fill-opacity="0.10" stroke="var(--accent-strong)"/>
    <text x="341" y="195" font-size="22">🔬</text>
    <text x="482" y="193" text-anchor="end" font-size="11" font-weight="700" fill="var(--accent-strong)">★ CAPSTONE</text>
    <text x="341" y="221" font-weight="700" fill="var(--text)">5 · Malware report</text>
    <text x="341" y="245" fill="var(--text-muted)">static + dynamic triage, then a</text>
    <text x="341" y="263" fill="var(--text-muted)">full report with snippets &amp; shots</text>
    <text x="341" y="301" fill="var(--text)">tools: static · detonate · report</text>
  </g>
</svg>
</div>

### Idea 1 — The Downloads tidy-up agent (your warm-up)

Start here, because you already wrote it — it's the `tidy_local.py` from the section above. Point it at `~/Downloads`, give it `list_files` and `move_file`, and keep the approve-each-move guardrail. It's the ideal first agent: the blast radius is tiny, the feedback is instant, and every core idea (a goal, a couple of tools, a loop, a human gate) is on display in 40 lines.

1. **Run the version you have.** `python tidy_local.py` — watch it list, propose moves, and wait for your `y`.
2. **Add a dry run.** A `plan_only` flag that prints the moves it *would* make without touching anything builds the habit of previewing an agent before you let it act.
3. **Give it better judgement.** Add a `file_info(name)` tool (size, modified date, extension) so it can sort by *age* or *type*, not just by name — more context, better decisions.
4. **Then let go of the wheel.** Once you trust it, drop the per-move prompt for low-risk types (images, archives) while keeping it for anything it's unsure about. That graduation — from confirm-everything to confirm-what-matters — is the whole trust curve in miniature.

### Idea 2 — A private phishing-triage agent

The agent reads a folder of saved `.eml` files, pulls out the indicators, and gives each a verdict — and because it's local, sensitive mail never leaves your laptop.

1. **Set the stage.** Drop suspect emails as `.eml` files into `./inbox/`.
2. **Give it three read-only tools:** `list_emails()`, `read_email(name)` (parse the MIME parts into plain text — the same `email` module trick from my [email-spoofing post](/Email-Spoofing-SPF/)), and `extract_iocs(text)` (regex out URLs, domains and IPs).
3. **Write the brief** in the system prompt: *"You are a SOC triage assistant. For each email: read it, extract indicators, and decide phishing or benign with one line of reasoning. Never open or fetch any link."*
4. **Run the loop** over each email. The agent calls `read_email`, then `extract_iocs`, then writes its verdict.
5. **Keep it read-only.** No tool should click a link or send anything — defang the URLs in output (`hxxp://`). This is the safe, useful version of the automated triage I warned about in the [prompt-injection post](/Prompt-Injection-In-Phishing/): it *assists*, it never *acts*.

### Idea 3 — A "what happened overnight?" log summarizer

Point it at a log file and get a plain-English morning brief of the anomalies, instead of scrolling thousands of lines.

1. **Pick a log** — `auth.log`, a web access log, a firewall export, or a sample.
2. **Give it query tools, not the whole file:** `tail_log(n)`, `grep_log(pattern)`, and `count_by(field)` (e.g. count failed logins by source IP). Returning summaries instead of raw megabytes keeps a small model focused.
3. **Brief it:** *"Summarize unusual activity in the last 12 hours. Call out repeated failures, rare source IPs and off-hours access. End with three things a human should check next."*
4. **Loop.** The agent greps for failures, counts by IP and user, and writes the brief.
5. **Guardrail:** every tool is read-only — it can look, it can't touch. This is a gentle, safe on-ramp to the detection thinking in my [SIFT](/SIFT-Workstation-Hands-On/) and [Windows DFIR](/Windows-DFIR-Field-Reference/) posts.

### Idea 4 — An assistant that actually knows your notes

Ask questions and get answers grounded in *your* Markdown notes, with the source file cited — a tiny, private retrieval agent.

1. **Point it at `~/notes`** (or your Obsidian vault).
2. **Reuse two read tools** — `search_notes(keyword)` and `read_note(name)` — the same shape as the MCP notes server in [part 1](/Agentic-AI-Getting-Started/).
3. **Constrain it hard:** *"Answer only from the notes. Cite the filename you used. If the answer isn't in the notes, say 'not in my notes' — do not guess."* That one instruction is what turns a confident liar into a trustworthy assistant.
4. **Ask away.** The agent searches, reads the best matches, and answers with citations.
5. **Level up later:** swap keyword search for *semantic* search by generating embeddings locally (`ollama pull nomic-embed-text`) and matching on meaning instead of exact words — the "lite" version of RAG from the memory section.

### Idea 5 — The capstone: a malware-triage agent that writes the report

This is the ambitious one, and it's squarely in our lane. Point it at a sample inside your isolated lab; it runs the standard static-then-dynamic triage, collects the output, and writes a full technical report — snippets, screenshots and IOCs — in the shape TCM Security's [Practical Malware Analysis & Triage](https://tcm-sec.com/) course teaches (the same structure I walk through in my [PMAT field guide](/Practical-Malware-Analysis-and-Triage-Field-Guide/)). It won't replace an analyst. It *will* do the grind — hashing, strings, IOC collection, formatting — so you spend your time on judgement.

<div style="margin:2rem 0;padding:1.25rem;background:var(--bg-elevated);border:1px solid var(--border);border-radius:var(--radius-m);">
<svg viewBox="0 0 640 215" style="width:100%;height:auto;font-family:inherit;" role="img" aria-label="The malware-triage agent pipeline: it works inside an isolated REMnux or FLARE lab VM that you snapshot first; it runs basic static analysis (hashes, strings, PE headers, imports, capa); then dynamic analysis where a human approves the detonation and it captures IOCs and a packet capture; then it writes a report, rendering Markdown to PDF with code snippets and screenshots. A human approves the detonation, and the sample never touches your host — the agent orchestrates the lab, it does not fight the malware.">
  <defs><marker id="mw-a" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto"><path d="M0,0 L8,4 L0,8 z" fill="var(--accent)"/></marker></defs>
  <g style="font-size:11px;">
    <rect x="3" y="15" width="148" height="110" rx="10" fill="var(--bg-elevated-2)" stroke="var(--text-muted)" stroke-dasharray="5 4"/>
    <text x="77" y="42" text-anchor="middle" font-size="20">🧰</text>
    <text x="77" y="66" text-anchor="middle" font-weight="700" fill="var(--text)">Isolated lab</text>
    <text x="77" y="86" text-anchor="middle" fill="var(--text-muted)">REMnux / FLARE VM</text>
    <text x="77" y="104" text-anchor="middle" fill="var(--text-muted)">snapshot first</text>
    <rect x="166" y="15" width="148" height="110" rx="10" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="240" y="42" text-anchor="middle" font-size="20">🔍</text>
    <text x="240" y="66" text-anchor="middle" font-weight="700" fill="var(--text)">Static</text>
    <text x="240" y="86" text-anchor="middle" fill="var(--text-muted)">hashes · strings</text>
    <text x="240" y="104" text-anchor="middle" fill="var(--text-muted)">PE · imports · capa</text>
    <rect x="329" y="15" width="148" height="110" rx="10" fill="var(--bg-elevated-2)" stroke="var(--accent)"/>
    <text x="403" y="42" text-anchor="middle" font-size="20">💣</text>
    <text x="403" y="66" text-anchor="middle" font-weight="700" fill="var(--accent)">Dynamic</text>
    <text x="403" y="86" text-anchor="middle" fill="var(--text-muted)">detonate (approve)</text>
    <text x="403" y="104" text-anchor="middle" fill="var(--text-muted)">capture IOCs + pcap</text>
    <rect x="492" y="15" width="145" height="110" rx="10" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="564" y="42" text-anchor="middle" font-size="20">📄</text>
    <text x="564" y="66" text-anchor="middle" font-weight="700" fill="var(--text)">Report</text>
    <text x="564" y="86" text-anchor="middle" fill="var(--text-muted)">Markdown → PDF</text>
    <text x="564" y="104" text-anchor="middle" fill="var(--text-muted)">snippets + screenshots</text>
    <line x1="152" y1="70" x2="164" y2="70" stroke="var(--accent)" stroke-width="2" marker-end="url(#mw-a)"/>
    <line x1="315" y1="70" x2="327" y2="70" stroke="var(--accent)" stroke-width="2" marker-end="url(#mw-a)"/>
    <line x1="478" y1="70" x2="490" y2="70" stroke="var(--accent)" stroke-width="2" marker-end="url(#mw-a)"/>
    <rect x="3" y="150" width="634" height="52" rx="10" fill="none" stroke="var(--text-muted)" stroke-dasharray="5 5"/>
    <text x="320" y="173" text-anchor="middle" font-weight="700" fill="var(--text)">A human approves the detonation; the sample never touches your host.</text>
    <text x="320" y="192" text-anchor="middle" fill="var(--text-muted)">The agent orchestrates the lab — it doesn't fight the malware.</text>
  </g>
</svg>
</div>

1. **Stage the sample in the lab — and only the lab.** Drop the sample (zipped, password-protected, defanged) into the analysis folder of an isolated [REMnux](/REMnux-Malware-Analysis-Toolkit/) / [FLARE-VM](/FLARE-VM-Malware-Analysis-Lab/) VM with controlled networking (INetSim or FakeNet), and snapshot it so you can roll back. The agent runs *here*, not on your daily driver.
2. **Give it a grouped tool belt.** Static: `hashes(path)` (MD5/SHA-256, plus a VirusTotal lookup if you allow network), `strings_and_capa(path)` (strings + capability detection), `pe_info(path)` (headers, imports, sections, entropy). Dynamic: `detonate(path)` (runs it in the sandbox — **gated behind your approval**, same pattern as `move_file`), `collect_iocs()` (Noriben/procmon + packet capture → processes, files, registry, network). Reporting: `screenshot(target)` (grab the process tree or network graph) and `write_report(sections)` (render Markdown → PDF).
3. **Brief it with the report template.** *"You are a malware-triage analyst. Work in order: basic static, then basic dynamic, then IOCs and a YARA rule. Produce a report with these sections — Executive summary, Technical summary, Malware composition (hashes), Static analysis, Dynamic analysis, Indicators of compromise, YARA/Sigma, Appendix. Embed tool output as code blocks and screenshots. Never run the sample outside the lab; ask before detonating."*
4. **Run the loop.** It hashes and strings the file, reasons over the imports and capa output, asks your approval, detonates, calls `collect_iocs` and `screenshot`, then assembles `write_report`. The same perceive → reason → act → observe loop — just with heavier tools.
5. **Review before you trust it.** Treat the output as a first draft from a keen junior: verify the IOCs, sanity-check the YARA rule, and never ship a report you haven't read. The win isn't autonomy — it's that the tedious 80% is done and formatted by the time you sit down.

> **One hard guardrail:** this agent *orchestrates* analysis tools inside a sandbox — it does not "use AI to fight malware," and the model never executes the sample itself. Detonation stays human-approved and lab-bound. Keep the local model for this if the sample is sensitive: nothing about the case leaves your network. (A bigger model reasons better over disassembly — a fair trade-off to make per sample.)

> **The pattern underneath:** all five are the identical loop — goal, tools, observe, repeat — with sharp tools, one clear system prompt, and a human gate on anything that acts. Build the first and you've effectively built them all; the agent skill is reusable, and the tools are the only thing that changes from a Downloads sorter to a malware-triage analyst.

## Where this leaves you

Two posts in, you've seen the whole arc: an agent is a loop around a model that can call tools, it runs just as well on a free local model as on a frontier API, and the difference between a demo and something you'd trust is the tools you expose and the gates you put in front of them. Pick one of the five, build it this week, and read the traces — that's how the idea stops being abstract.

Worth reading next: go back to [part 1](/Agentic-AI-Getting-Started/) for the loop, tools, memory and MCP; Anthropic's <a href="https://www.anthropic.com/engineering/building-effective-agents" target="_blank" rel="noopener">Building effective agents</a>; and the <a href="https://ollama.com" target="_blank" rel="noopener">Ollama</a> docs for the local models and tool-calling API used here.
