---
title: "Agentic AI, Part 1: From Chatbot to Coworker — A Hands-on Starter Guide"
excerpt: "A chatbot answers. An agent gets it done. What's really inside an AI agent — the loop, tools, memory, MCP — and a working one in about 60 lines of Python, guardrails included."
header:
  image: /images/posts/agentic-ai/hero.jpg
tags: [AI, agents, MCP, LLM]
---
![Agentic AI: the goal, think, act, observe loop around an LLM](/images/posts/agentic-ai/hero.jpg)

Most of my posts are about security. This one is a Friday break, on the topic everyone's talking about: <strong>agentic AI</strong>. A chatbot answers your question. An agent takes your <em>goal</em>, makes a plan, uses tools, checks the results and keeps going until the job is done. That's the gap between "here's how to rename your files" and "I renamed your files — here's what changed".

The good news: under all the hype, an agent is just <strong>a loop around a language model that can call functions</strong>. Once you see the loop, everything else — tools, memory, MCP, multi-agent patterns and the guardrails that separate a demo from something you can trust — falls into place. So let's open the box and build one.

## Chatbot, workflow or agent?
"Agent" is used for everything these days, so first, some vocabulary. The useful question is <strong>who decides the next step</strong>, your code or the model:

<div style="margin:2rem 0;padding:1.25rem;background:var(--bg-elevated);border:1px solid var(--border);border-radius:var(--radius-m);">
<svg viewBox="0 0 640 250" style="width:100%;height:auto;font-family:inherit;" role="img" aria-label="Autonomy spectrum from left to right: chatbot, where the model only answers; workflow, where code decides the steps; agent, where the model decides the steps; multi-agent, where agents delegate to agents. Autonomy, power and risk all grow to the right">
  <defs><marker id="ag-arr1" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto"><path d="M0,0 L8,4 L0,8 z" fill="var(--accent)"/></marker></defs>
  <g style="font-size:12px;">
    <rect x="5" y="20" width="145" height="150" rx="10" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="20" y="44" font-weight="700" fill="var(--text-muted)">LEVEL 0</text>
    <text x="20" y="66" font-weight="700" font-size="15" fill="var(--text)">Chatbot</text>
    <text x="20" y="92" fill="var(--text-muted)">Question in,</text>
    <text x="20" y="110" fill="var(--text-muted)">answer out.</text>
    <text x="20" y="128" fill="var(--text-muted)">No actions.</text>
    <text x="20" y="156" fill="var(--text)">"How do I…?"</text>

    <rect x="165" y="20" width="145" height="150" rx="10" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="180" y="44" font-weight="700" fill="var(--text-muted)">LEVEL 1</text>
    <text x="180" y="66" font-weight="700" font-size="15" fill="var(--text)">Workflow</text>
    <text x="180" y="92" fill="var(--text-muted)">LLM calls in fixed</text>
    <text x="180" y="110" fill="var(--text-muted)">steps. <tspan font-weight="700" fill="var(--text)">Your code</tspan></text>
    <text x="180" y="128" fill="var(--text-muted)">decides the path.</text>
    <text x="180" y="156" fill="var(--text)">"Summarize, then…"</text>

    <rect x="325" y="20" width="145" height="150" rx="10" fill="var(--bg-elevated-2)" stroke="var(--accent)" stroke-width="2"/>
    <text x="340" y="44" font-weight="700" fill="var(--accent)">LEVEL 2</text>
    <text x="340" y="66" font-weight="700" font-size="15" fill="var(--accent)">Agent</text>
    <text x="340" y="92" fill="var(--text-muted)">Loop + tools.</text>
    <text x="340" y="110" fill="var(--text-muted)"><tspan font-weight="700" fill="var(--text)">The model</tspan> decides</text>
    <text x="340" y="128" fill="var(--text-muted)">the next step.</text>
    <text x="340" y="156" fill="var(--text)">"Get it done."</text>

    <rect x="485" y="20" width="150" height="150" rx="10" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="500" y="44" font-weight="700" fill="var(--text-muted)">LEVEL 3</text>
    <text x="500" y="66" font-weight="700" font-size="15" fill="var(--text)">Multi-agent</text>
    <text x="500" y="92" fill="var(--text-muted)">An orchestrator</text>
    <text x="500" y="110" fill="var(--text-muted)">delegates to</text>
    <text x="500" y="128" fill="var(--text-muted)">specialist agents.</text>
    <text x="500" y="156" fill="var(--text)">"Run the project."</text>

    <line x1="10" y1="205" x2="625" y2="205" stroke="var(--accent)" stroke-width="2.5" marker-end="url(#ag-arr1)"/>
    <text x="10" y="232" fill="var(--text-muted)">more autonomy  ·  more capability  ·  more cost  ·  more things that can go wrong</text>
  </g>
</svg>
</div>

The rule I follow: <strong>use the lowest level that solves the problem</strong>. If you can write the steps down in advance, build a workflow. Choose an agent when the path depends on what the model finds along the way, like debugging, research, or cleaning up a messy folder.

## Anatomy of an agent
Every agent, from a 60-line script to a coding assistant, is made of the same five parts:

<div style="margin:2rem 0;padding:1.25rem;background:var(--bg-elevated);border:1px solid var(--border);border-radius:var(--radius-m);">
<svg viewBox="0 0 640 300" style="width:100%;height:auto;font-family:inherit;" role="img" aria-label="Agent anatomy: the model in the center, connected to instructions, tools, memory and the loop, all wrapped inside a guardrails boundary">
  <g style="font-size:12px;">
    <rect x="5" y="5" width="630" height="290" rx="14" fill="none" stroke="var(--text-muted)" stroke-dasharray="6 6"/>
    <text x="20" y="28" font-weight="700" fill="var(--text-muted)">5 · GUARDRAILS  — permissions · approvals · step limits · budgets · logs</text>
    <line x1="320" y1="150" x2="140" y2="85" stroke="var(--border)" stroke-width="2"/>
    <line x1="320" y1="150" x2="500" y2="85" stroke="var(--border)" stroke-width="2"/>
    <line x1="320" y1="150" x2="140" y2="225" stroke="var(--border)" stroke-width="2"/>
    <line x1="320" y1="150" x2="500" y2="225" stroke="var(--border)" stroke-width="2"/>
    <circle cx="320" cy="150" r="58" fill="var(--accent)"/>
    <text x="320" y="146" text-anchor="middle" font-weight="700" font-size="16" fill="var(--accent-contrast)">MODEL</text>
    <text x="320" y="166" text-anchor="middle" fill="var(--accent-contrast)">reasons &amp; decides</text>

    <rect x="30" y="52" width="210" height="64" rx="10" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="44" y="76" font-weight="700" fill="var(--text)">1 · Instructions</text>
    <text x="44" y="96" fill="var(--text-muted)">system prompt: role, rules, goal</text>
    <rect x="400" y="52" width="210" height="64" rx="10" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="414" y="76" font-weight="700" fill="var(--text)">2 · Tools</text>
    <text x="414" y="96" fill="var(--text-muted)">functions it may call (its hands)</text>
    <rect x="30" y="192" width="210" height="64" rx="10" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="44" y="216" font-weight="700" fill="var(--text)">3 · Memory</text>
    <text x="44" y="236" fill="var(--text-muted)">conversation + files / notes</text>
    <rect x="400" y="192" width="210" height="64" rx="10" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="414" y="216" font-weight="700" fill="var(--text)">4 · The loop</text>
    <text x="414" y="236" fill="var(--text-muted)">think → act → observe → repeat</text>
  </g>
</svg>
</div>

| Part | What it is | In our example below |
|---|---|---|
| **Model** | The LLM that reads everything and decides what to do next | `claude-opus-5-5` |
| **Instructions** | The system prompt: role, rules, definition of "done" | "Careful file organizer. Look before you act." |
| **Tools** | Functions the model can ask you to run, each with a name, a description and a JSON schema | `list_files`, `move_file` |
| **Memory** | What it remembers: the message history (short-term) and files or notes (long-term) | The `messages` list |
| **Loop** | Your code that runs the requested tools and sends the results back | A `for` loop with a step limit |
| **Guardrails** | Everything that limits damage | Folder jail, approval prompt, `max_steps` |

> **Key insight:** The model never runs anything itself. It only <em>asks</em> for a tool call, with arguments, and <strong>your code</strong> decides whether to run it. That is the most important thing to understand about agents, and it is where all your control lives.

## The agent loop, step by step
Here's what actually travels between your code and the model. On every turn your code sends the whole conversation, the model replies, and the reply's `stop_reason` tells you what to do next:

<div style="margin:2rem 0;padding:1.25rem;background:var(--bg-elevated);border:1px solid var(--border);border-radius:var(--radius-m);">
<svg viewBox="0 0 640 330" style="width:100%;height:auto;font-family:inherit;" role="img" aria-label="Sequence: your code sends goal and tool definitions to the model; the model replies with a tool_use request; your code runs the function and sends back a tool_result; this repeats until the model replies with stop_reason end_turn and a final answer">
  <defs><marker id="ag-arr2" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto"><path d="M0,0 L8,4 L0,8 z" fill="var(--text-muted)"/></marker></defs>
  <g style="font-size:12px;">
    <rect x="20" y="10" width="170" height="40" rx="8" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="105" y="35" text-anchor="middle" font-weight="700" fill="var(--text)">Your code (the loop)</text>
    <rect x="450" y="10" width="170" height="40" rx="8" fill="var(--accent)"/>
    <text x="535" y="35" text-anchor="middle" font-weight="700" fill="var(--accent-contrast)">Model (API)</text>
    <line x1="105" y1="50" x2="105" y2="320" stroke="var(--border)" stroke-width="2" stroke-dasharray="4 4"/>
    <line x1="535" y1="50" x2="535" y2="320" stroke="var(--border)" stroke-width="2" stroke-dasharray="4 4"/>

    <line x1="110" y1="80" x2="528" y2="80" stroke="var(--text-muted)" stroke-width="2" marker-end="url(#ag-arr2)"/>
    <text x="125" y="72" fill="var(--text)">① goal + system prompt + tool definitions</text>
    <line x1="530" y1="125" x2="112" y2="125" stroke="var(--accent)" stroke-width="2" marker-end="url(#ag-arr2)"/>
    <text x="210" y="117" fill="var(--accent)">② stop_reason: "tool_use" → list_files({})</text>
    <rect x="30" y="140" width="150" height="34" rx="6" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="105" y="162" text-anchor="middle" fill="var(--text)">③ run list_files()</text>
    <line x1="110" y1="200" x2="528" y2="200" stroke="var(--text-muted)" stroke-width="2" marker-end="url(#ag-arr2)"/>
    <text x="125" y="192" fill="var(--text)">④ tool_result: ["IMG_2041.jpg", "invoice…pdf", …]</text>
    <text x="320" y="232" text-anchor="middle" fill="var(--text-muted)">… repeat ②–④ as many times as the task needs …</text>
    <line x1="530" y1="275" x2="112" y2="275" stroke="var(--accent-strong)" stroke-width="2" marker-end="url(#ag-arr2)"/>
    <text x="180" y="267" fill="var(--accent-strong)">⑤ stop_reason: "end_turn" → final answer, loop ends</text>
    <text x="320" y="310" text-anchor="middle" fill="var(--text-muted)">The model is stateless: every request carries the full history (that is the short-term memory)</text>
  </g>
</svg>
</div>

That's the whole trick. Time to build one.

## Build your first agent: a Downloads tidy-up assistant
Everyone's Downloads folder is a mess, so it makes a good first task. It is open-ended (the agent has to look before it decides), easy to check, and a little bit dangerous, which is perfect for learning guardrails. We will give the agent two tools, one to look and one to act, and ask for approval before every move.

<strong>Step 1 — Install the SDK and set your API key</strong>

```bash
python -m venv venv && source venv/bin/activate
pip install anthropic
export ANTHROPIC_API_KEY="sk-ant-..."      # from console.anthropic.com
```

<strong>Step 2 — Write the tools as plain Python functions</strong>

Notice the two guardrails built in from the beginning. Every path is resolved and checked so it stays inside `~/Downloads`, and every move asks for a human "y":

```python
import json, shutil
from pathlib import Path
import anthropic

client = anthropic.Anthropic()          # reads ANTHROPIC_API_KEY
ROOT = Path("~/Downloads").expanduser()  # the only folder the agent may touch

def list_files(folder: str = ".") -> str:
    path = (ROOT / folder).resolve()
    if not path.is_relative_to(ROOT):
        return "Error: outside the allowed folder"
    return json.dumps([f.name + ("/" if f.is_dir() else "") for f in sorted(path.iterdir())])

def move_file(name: str, dest_folder: str) -> str:
    src, dest = (ROOT / name).resolve(), (ROOT / dest_folder).resolve()
    if not (src.is_relative_to(ROOT) and dest.is_relative_to(ROOT)):
        return "Error: outside the allowed folder"
    if input(f"  approve move {name} -> {dest_folder}/ ? [y/N] ").lower() != "y":
        return "The user declined this move."           # human in the loop
    dest.mkdir(exist_ok=True)
    shutil.move(src, dest / src.name)
    return f"Moved {name} to {dest_folder}/"

TOOLS = {"list_files": list_files, "move_file": move_file}
```

<strong>Step 3 — Describe the tools to the model</strong>

The model never sees your Python code. It only sees the <strong>name, description and JSON schema</strong>, so write the descriptions like you are explaining the tool to a new colleague:

```python
tool_specs = [
    {"name": "list_files",
     "description": "List files and folders inside the Downloads folder.",
     "input_schema": {"type": "object",
                      "properties": {"folder": {"type": "string", "description": "Sub-folder, default '.'"}}}},
    {"name": "move_file",
     "description": "Move one file into a sub-folder (created if missing). The user must approve each move.",
     "input_schema": {"type": "object",
                      "properties": {"name": {"type": "string"}, "dest_folder": {"type": "string"}},
                      "required": ["name", "dest_folder"]}},
]
```

<strong>Step 4 — The loop</strong>

This is the agent. Call the model, print what it says, run the tools it asks for, send the results back, and stop when it is done or when the step limit is reached:

```python
def run(goal: str, max_steps: int = 15):
    messages = [{"role": "user", "content": goal}]
    for step in range(1, max_steps + 1):
        response = client.messages.create(
            model="claude-opus-5-5",
            max_tokens=16000,
            system="You are a careful file-organizing assistant. Look before you act.",
            tools=tool_specs,
            messages=messages,
        )
        messages.append({"role": "assistant", "content": response.content})

        for block in response.content:
            if block.type == "text" and block.text.strip():
                print(f"[{step}] 🤖 {block.text}")

        if response.stop_reason != "tool_use":       # no more actions -> done
            return

        results = []
        for block in response.content:
            if block.type == "tool_use":
                print(f"[{step}] 🔧 {block.name}({json.dumps(block.input)})")
                output = TOOLS[block.name](**block.input)
                results.append({"type": "tool_result", "tool_use_id": block.id, "content": output})
        messages.append({"role": "user", "content": results})  # observe

    print("Stopped: step limit reached")

if __name__ == "__main__":
    run("Tidy up my Downloads folder: group files into sensible sub-folders.")
```

<strong>Step 5 — Run it</strong>

Run `python tidy_agent.py` and you'll get something like this. Here I approved the invoice and the photo, and declined the installer:

![Terminal output of the tidy-up agent: list_files, three move_file requests with approval prompts, and a final summary](/images/posts/agentic-ai/agent-run.png)

Look at what the agent did:

1. **Looked before acting.** Its first move was `list_files`, not a guess.
2. **Batched its actions.** It asked for three moves in one turn. These are called <em>parallel tool calls</em>, and all their results go back together in one message.
3. **Respected the "no".** The declined move came back as a normal tool result, and the agent adapted instead of retrying.
4. **Checked its own work.** It listed the folder again before reporting that it was done.

None of that behaviour is in our loop. The loop only runs tools. The planning, the checking and the adapting come from the model. That is what "agentic" means in practice.

> **Expect variety:** The wording of the agent's messages will be different on every run, because the model decides the steps. That is expected. What should <em>not</em> change are the guardrails: the folder jail and the approval prompt are in your code, so they hold no matter what the model decides.

## The same agent with less code: the Tool Runner
Writing the loop yourself once is the best way to understand it. For real projects, the SDK can run the loop for you. With `@beta_tool`, the JSON schema is generated from the type hints and docstring, so steps 3 and 4 disappear:

```python
from anthropic import beta_tool      # client, ROOT and imports as before

@beta_tool
def list_files(folder: str = ".") -> str:
    """List files and folders inside the Downloads folder.

    Args:
        folder: Sub-folder to list, default '.'.
    """
    ...  # same body as before

@beta_tool
def move_file(name: str, dest_folder: str) -> str:
    """Move one file into a sub-folder (created if missing). The user must approve each move.

    Args:
        name: File name inside Downloads.
        dest_folder: Target sub-folder, e.g. 'Documents'.
    """
    ...  # same body as before

runner = client.beta.messages.tool_runner(
    model="claude-opus-5-5",
    max_tokens=16000,
    system="You are a careful file-organizing assistant. Look before you act.",
    tools=[list_files, move_file],
    messages=[{"role": "user", "content": "Tidy up my Downloads folder."}],
    max_iterations=15,
)
for message in runner:                      # one item per model turn
    for block in message.content:
        if block.type == "text":
            print("🤖", block.text)
        elif block.type == "tool_use":
            print("🔧", block.name, block.input)
```

## Giving agents superpowers with MCP
Writing tools for every project gets old quickly. The <strong>Model Context Protocol (MCP)</strong> is an open standard, introduced by Anthropic in late 2024 and now supported across most AI apps, IDEs and agent frameworks. It lets you wrap a capability <em>once</em> as an "MCP server" and plug it into any MCP-compatible agent. Think of it as USB-C for AI tools:

<div style="margin:2rem 0;padding:1.25rem;background:var(--bg-elevated);border:1px solid var(--border);border-radius:var(--radius-m);">
<svg viewBox="0 0 640 230" style="width:100%;height:auto;font-family:inherit;" role="img" aria-label="MCP architecture: agent hosts such as Claude Code, an IDE or your own app contain an MCP client which connects to many MCP servers such as GitHub, a database, Slack, the filesystem and your own notes server, each exposing tools, resources and prompts">
  <defs><marker id="ag-arr3" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto"><path d="M0,0 L8,4 L0,8 z" fill="var(--text-muted)"/></marker></defs>
  <g style="font-size:12px;">
    <rect x="5" y="40" width="200" height="150" rx="12" fill="var(--bg-elevated-2)" stroke="var(--accent)" stroke-width="2"/>
    <text x="20" y="64" font-weight="700" fill="var(--accent)">HOST (the agent app)</text>
    <text x="20" y="88" fill="var(--text-muted)">Claude Code, Claude Desktop,</text>
    <text x="20" y="106" fill="var(--text-muted)">VS Code, Cursor, your app…</text>
    <rect x="20" y="126" width="170" height="44" rx="8" fill="var(--accent)"/>
    <text x="105" y="153" text-anchor="middle" font-weight="700" fill="var(--accent-contrast)">MCP client</text>

    <line x1="205" y1="148" x2="388" y2="42" stroke="var(--text-muted)" stroke-width="1.5" marker-end="url(#ag-arr3)"/>
    <line x1="205" y1="148" x2="388" y2="82" stroke="var(--text-muted)" stroke-width="1.5" marker-end="url(#ag-arr3)"/>
    <line x1="205" y1="148" x2="388" y2="122" stroke="var(--text-muted)" stroke-width="1.5" marker-end="url(#ag-arr3)"/>
    <line x1="205" y1="148" x2="388" y2="162" stroke="var(--text-muted)" stroke-width="1.5" marker-end="url(#ag-arr3)"/>
    <line x1="205" y1="148" x2="388" y2="202" stroke="var(--text-muted)" stroke-width="1.5" marker-end="url(#ag-arr3)"/>
    <text x="232" y="196" fill="var(--text-muted)">stdio or</text>
    <text x="232" y="212" fill="var(--text-muted)">HTTP</text>

    <rect x="392" y="24" width="243" height="34" rx="7" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="406" y="46" fill="var(--text)"><tspan font-weight="700">GitHub</tspan> — issues, PRs, code search</text>
    <rect x="392" y="64" width="243" height="34" rx="7" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="406" y="86" fill="var(--text)"><tspan font-weight="700">Database</tspan> — run read-only SQL</text>
    <rect x="392" y="104" width="243" height="34" rx="7" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="406" y="126" fill="var(--text)"><tspan font-weight="700">Slack / email</tspan> — read, draft, send</text>
    <rect x="392" y="144" width="243" height="34" rx="7" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="406" y="166" fill="var(--text)"><tspan font-weight="700">Filesystem</tspan> — read and write files</text>
    <rect x="392" y="184" width="243" height="34" rx="7" fill="var(--bg-elevated-2)" stroke="var(--accent)"/>
    <text x="406" y="206" fill="var(--accent)"><tspan font-weight="700">Your notes</tspan> — the server below ✨</text>
    <text x="392" y="14" fill="var(--text-muted)">MCP SERVERS: tools · resources · prompts</text>
  </g>
</svg>
</div>

Here's a small MCP server that lets any agent search your Markdown notes. This is the complete file:

```python
# notes_server.py   (pip install mcp)
from pathlib import Path
from mcp.server.mcpserver import MCPServer

mcp = MCPServer("notes")
NOTES = Path("~/notes").expanduser()

@mcp.tool()
def search_notes(keyword: str) -> list[str]:
    """Return the names of notes that contain the keyword."""
    return [p.name for p in NOTES.glob("*.md") if keyword.lower() in p.read_text().lower()]

@mcp.tool()
def read_note(name: str) -> str:
    """Return the full text of one note."""
    return (NOTES / Path(name).name).read_text()

if __name__ == "__main__":
    mcp.run()          # stdio transport by default
```

Then register it with any MCP host. For example, in Claude Code:

```bash
claude mcp add notes -- python /path/to/notes_server.py
```

From now on you can just ask "what did I write about agents last month?", and the agent will decide to call `search_notes` and `read_note` by itself.

> **Version gotcha:** This snippet uses version 2 of the official Python `mcp` package, where the server class is `MCPServer`. Many tutorials online still show the version 1 name, `from mcp.server.fastmcp import FastMCP`. The decorators work the same way, but the import is different.

> **Security note:** An MCP server is code that runs with <strong>your</strong> permissions, and its tool descriptions go straight into the model's context. Install servers only from sources you trust, the same way you would treat a browser extension.

## Memory: how agents remember
Models are stateless, so "memory" is always something your system provides:

| Type | How it works | Use it for | Watch out for |
|---|---|---|---|
| **Short-term** | The `messages` list sent on every call | The current task | Grows every turn. Long tasks fill the context window and get expensive |
| **Compaction** | Older turns are summarized into a short recap | Long-running sessions | Details can get lost in the summary |
| **Long-term (files)** | The agent writes notes to files or a memory tool and reads them later | Preferences, project facts, progress logs | Keep it curated: wrong memories are worse than none |
| **Retrieval (RAG)** | Search a document store and put only the relevant chunks in the context | Large knowledge bases | Retrieval quality limits answer quality |

A simple trick that works well: give long-running agents a `PROGRESS.md` file. Ask them to update it after each milestone and read it at the start of every session. It is cheap, easy to inspect, and you can edit it yourself.

## Five patterns worth knowing
Before you reach for a full agent, check if one of these simpler patterns fits. They come from Anthropic's excellent guide <a href="https://www.anthropic.com/engineering/building-effective-agents" target="_blank" rel="noopener">Building effective agents</a>, and most "agentic" products in production are a mix of them:

<div style="margin:2rem 0;padding:1.25rem;background:var(--bg-elevated);border:1px solid var(--border);border-radius:var(--radius-m);">
<svg viewBox="0 0 640 400" style="width:100%;height:auto;font-family:inherit;" role="img" aria-label="Five patterns: prompt chaining runs LLM calls in sequence with a check between them; routing classifies input and sends it to a specialist; parallelization runs several calls at once and merges results; orchestrator-workers lets a lead model split work across workers; evaluator-optimizer loops a generator and a critic until the result is good enough">
  <defs><marker id="ag-arr4" markerWidth="7" markerHeight="7" refX="6" refY="3.5" orient="auto"><path d="M0,0 L7,3.5 L0,7 z" fill="var(--text-muted)"/></marker></defs>
  <g style="font-size:11px;">
    <!-- 1 chaining -->
    <text x="10" y="20" font-weight="700" font-size="13" fill="var(--text)">1 · Prompt chaining</text>
    <text x="10" y="36" fill="var(--text-muted)">fixed steps in sequence, with a check in between</text>
    <rect x="10" y="46" width="60" height="28" rx="6" fill="var(--accent)"/><text x="40" y="64" text-anchor="middle" fill="var(--accent-contrast)">LLM</text>
    <rect x="95" y="46" width="50" height="28" rx="6" fill="var(--bg-elevated-2)" stroke="var(--border)"/><text x="120" y="64" text-anchor="middle" fill="var(--text)">check</text>
    <rect x="170" y="46" width="60" height="28" rx="6" fill="var(--accent)"/><text x="200" y="64" text-anchor="middle" fill="var(--accent-contrast)">LLM</text>
    <rect x="255" y="46" width="50" height="28" rx="6" fill="var(--bg-elevated-2)" stroke="var(--border)"/><text x="280" y="64" text-anchor="middle" fill="var(--text)">out</text>
    <line x1="70" y1="60" x2="92" y2="60" stroke="var(--text-muted)" marker-end="url(#ag-arr4)"/>
    <line x1="145" y1="60" x2="167" y2="60" stroke="var(--text-muted)" marker-end="url(#ag-arr4)"/>
    <line x1="230" y1="60" x2="252" y2="60" stroke="var(--text-muted)" marker-end="url(#ag-arr4)"/>
    <text x="10" y="94" fill="var(--text)">e.g. outline → check → write the post</text>

    <!-- 2 routing -->
    <text x="340" y="20" font-weight="700" font-size="13" fill="var(--text)">2 · Routing</text>
    <text x="340" y="36" fill="var(--text-muted)">classify first, then send to a specialist</text>
    <rect x="340" y="54" width="70" height="28" rx="6" fill="var(--accent)"/><text x="375" y="72" text-anchor="middle" fill="var(--accent-contrast)">router</text>
    <rect x="460" y="42" width="80" height="22" rx="5" fill="var(--bg-elevated-2)" stroke="var(--border)"/><text x="500" y="57" text-anchor="middle" fill="var(--text)">billing</text>
    <rect x="460" y="72" width="80" height="22" rx="5" fill="var(--bg-elevated-2)" stroke="var(--border)"/><text x="500" y="87" text-anchor="middle" fill="var(--text)">tech support</text>
    <line x1="410" y1="68" x2="457" y2="53" stroke="var(--text-muted)" marker-end="url(#ag-arr4)"/>
    <line x1="410" y1="68" x2="457" y2="83" stroke="var(--text-muted)" marker-end="url(#ag-arr4)"/>
    <text x="340" y="112" fill="var(--text)">e.g. cheap model for FAQs, strong one for hard cases</text>

    <!-- 3 parallel -->
    <text x="10" y="150" font-weight="700" font-size="13" fill="var(--text)">3 · Parallelization</text>
    <text x="10" y="166" fill="var(--text-muted)">split or vote: several calls at once, then merge</text>
    <rect x="10" y="190" width="50" height="28" rx="6" fill="var(--bg-elevated-2)" stroke="var(--border)"/><text x="35" y="208" text-anchor="middle" fill="var(--text)">in</text>
    <rect x="100" y="176" width="50" height="18" rx="4" fill="var(--accent)"/>
    <rect x="100" y="198" width="50" height="18" rx="4" fill="var(--accent)"/>
    <rect x="100" y="220" width="50" height="18" rx="4" fill="var(--accent)"/>
    <rect x="190" y="190" width="60" height="28" rx="6" fill="var(--bg-elevated-2)" stroke="var(--border)"/><text x="220" y="208" text-anchor="middle" fill="var(--text)">merge</text>
    <line x1="60" y1="204" x2="97" y2="185" stroke="var(--text-muted)" marker-end="url(#ag-arr4)"/>
    <line x1="60" y1="204" x2="97" y2="207" stroke="var(--text-muted)" marker-end="url(#ag-arr4)"/>
    <line x1="60" y1="204" x2="97" y2="229" stroke="var(--text-muted)" marker-end="url(#ag-arr4)"/>
    <line x1="150" y1="185" x2="187" y2="204" stroke="var(--text-muted)" marker-end="url(#ag-arr4)"/>
    <line x1="150" y1="207" x2="187" y2="204" stroke="var(--text-muted)" marker-end="url(#ag-arr4)"/>
    <line x1="150" y1="229" x2="187" y2="204" stroke="var(--text-muted)" marker-end="url(#ag-arr4)"/>
    <text x="10" y="258" fill="var(--text)">e.g. review a contract for 3 risks at once</text>

    <!-- 4 orchestrator -->
    <text x="340" y="150" font-weight="700" font-size="13" fill="var(--text)">4 · Orchestrator–workers</text>
    <text x="340" y="166" fill="var(--text-muted)">a lead model plans and delegates at runtime</text>
    <rect x="340" y="190" width="80" height="28" rx="6" fill="var(--accent)"/><text x="380" y="208" text-anchor="middle" fill="var(--accent-contrast)">orchestrator</text>
    <rect x="470" y="176" width="70" height="18" rx="4" fill="var(--bg-elevated-2)" stroke="var(--border)"/><text x="505" y="189" text-anchor="middle" fill="var(--text)">worker</text>
    <rect x="470" y="198" width="70" height="18" rx="4" fill="var(--bg-elevated-2)" stroke="var(--border)"/><text x="505" y="211" text-anchor="middle" fill="var(--text)">worker</text>
    <rect x="470" y="220" width="70" height="18" rx="4" fill="var(--bg-elevated-2)" stroke="var(--border)"/><text x="505" y="233" text-anchor="middle" fill="var(--text)">worker</text>
    <line x1="420" y1="204" x2="467" y2="185" stroke="var(--text-muted)" marker-end="url(#ag-arr4)"/>
    <line x1="420" y1="204" x2="467" y2="207" stroke="var(--text-muted)" marker-end="url(#ag-arr4)"/>
    <line x1="420" y1="204" x2="467" y2="229" stroke="var(--text-muted)" marker-end="url(#ag-arr4)"/>
    <text x="340" y="258" fill="var(--text)">e.g. research: one sub-agent per source</text>

    <!-- 5 evaluator -->
    <text x="10" y="300" font-weight="700" font-size="13" fill="var(--text)">5 · Evaluator–optimizer</text>
    <text x="10" y="316" fill="var(--text-muted)">a generator and a critic loop until the result passes a clear bar</text>
    <rect x="10" y="334" width="90" height="30" rx="6" fill="var(--accent)"/><text x="55" y="353" text-anchor="middle" fill="var(--accent-contrast)">generator</text>
    <rect x="200" y="334" width="90" height="30" rx="6" fill="var(--bg-elevated-2)" stroke="var(--accent)"/><text x="245" y="353" text-anchor="middle" fill="var(--accent)">evaluator</text>
    <path d="M100 342 L197 342" stroke="var(--text-muted)" fill="none" marker-end="url(#ag-arr4)"/>
    <path d="M200 358 L103 358" stroke="var(--text-muted)" fill="none" marker-end="url(#ag-arr4)"/>
    <text x="118" y="336" fill="var(--text-muted)">draft</text>
    <text x="114" y="378" fill="var(--text-muted)">feedback</text>
    <rect x="330" y="334" width="60" height="30" rx="6" fill="var(--bg-elevated-2)" stroke="var(--border)"/><text x="360" y="353" text-anchor="middle" fill="var(--text)">✔ done</text>
    <line x1="290" y1="349" x2="327" y2="349" stroke="var(--text-muted)" marker-end="url(#ag-arr4)"/>
    <text x="410" y="345" fill="var(--text)">e.g. code → run tests → fix → repeat</text>
    <text x="410" y="363" fill="var(--text)">until all tests are green</text>
  </g>
</svg>
</div>

## Choosing your tools
The ecosystem moves fast, but the options fall into a few clear groups. Here is how I would choose in 2026:

| You want to… | Reach for | Notes |
|---|---|---|
| Understand agents deeply | **The raw API + your own loop** (like above) | Do this at least once. Every framework is this loop with extras |
| Ship a custom agent with your own tools | **Provider SDK tool runners** — Anthropic `tool_runner`, OpenAI Agents SDK, Google ADK | Thin, close to the API, easy to debug |
| Get a ready-made coding or file agent | **Claude Agent SDK** (the Claude Code engine as a library) | Built-in file, shell and web tools, subagents, hooks |
| Model complex, stateful flows as a graph | **LangGraph** | Explicit states and branches, checkpoints, human-in-the-loop |
| Prototype "a crew" of role-based agents | **CrewAI**, **Microsoft Agent Framework** | Quick multi-agent setups. Watch the token bill |
| Not run any infrastructure | **Managed / hosted agents** from the model providers | The provider runs the loop and the sandbox for you |
| Use agents without writing code | **Claude Code, Cursor, GitHub Copilot agent mode, Claude Cowork** | The fastest way to build intuition for what agents are good at |

> **Opinion:** Frameworks are a convenience, not a requirement. If you can't explain what the framework sends to the model on each step, start with the raw loop first. It makes debugging much easier later.

## Guardrails: before you give an agent real work
An agent is a program that writes its own next line of code at runtime, so treat it that way. This is my checklist:

1. **Least privilege tools.** Give it `read_file`, not `run_shell`, unless it truly needs a shell. Each tool should do <em>one</em> thing with clear limits, like the folder jail in our example.
2. **Approval for anything irreversible.** Deleting, sending, paying, deploying: a human says "y". Read-only actions can be automatic.
3. **Hard limits.** A maximum number of steps, a token or cost budget, and timeouts on every tool. Agents stuck in a loop are a real (and expensive) thing.
4. **Treat tool output as untrusted.** Web pages, emails and files can contain text like "ignore your instructions and…". This is called <strong>prompt injection</strong>. Never let content the agent <em>read</em> decide what the agent is <em>allowed</em> to do. Enforce permissions in code, not in the prompt.
5. **Log every step.** Save the full trace: prompts, tool calls, arguments and results. When something odd happens, the trace is your only witness.
6. **Return errors, don't crash.** A tool that returns `"Error: file not found"` lets the agent recover. A Python exception just kills the run.
7. **Sandbox code execution.** If the agent runs code, run it in a container or VM with no secrets and limited network access, never on your laptop's main profile.
8. **Measure it.** Build a small set of test tasks with known good outcomes, and re-run them whenever you change the prompt, the tools or the model.

## Common mistakes I see
| Mistake | Better |
|---|---|
| Building an agent when a single prompt would do | Start at the lowest level of the spectrum and move up only when needed |
| Vague tool descriptions ("does stuff with files") | Describe each tool like documentation for a new colleague: what, when, and the limits |
| 40 tools on day one | Start with 2–5 focused tools. Too many choices confuse the model |
| Letting the prompt be the only safety control | Put the checks in code: path checks, allow-lists, approval gates |
| Judging the agent by one lucky demo | Run 10–20 real tasks, read the traces, and fix the patterns you see |
| Throwing away failed traces | Failures are the best way to find unclear tool descriptions and missing tools |

## Your 7-day getting-started plan
If you want to go from zero to comfortable in a week, this is the path I recommend:

<div style="margin:2rem 0;padding:1.25rem;background:var(--bg-elevated);border:1px solid var(--border);border-radius:var(--radius-m);">
<svg viewBox="0 0 640 400" style="width:100%;height:auto;font-family:inherit;" role="img" aria-label="Seven day plan: day 1 use an agent app, day 2 make your first API and tool call, day 3 write the loop yourself, day 4 add guardrails, day 5 build an MCP server, day 6 try a multi-agent pattern, day 7 evaluate with test tasks and ship something small">
  <line x1="40" y1="25" x2="40" y2="375" stroke="var(--border)" stroke-width="2"/>
  <g style="font-size:13px;">
    <circle cx="40" cy="25" r="11" fill="var(--accent)"/><text x="40" y="29" text-anchor="middle" font-size="11" font-weight="700" fill="var(--accent-contrast)">1</text>
    <text x="66" y="30"><tspan font-weight="700" fill="var(--text)">Use one.</tspan><tspan fill="var(--text-muted)"> Give a real task to Claude Code or a similar agent app and watch every step</tspan></text>
    <circle cx="40" cy="83" r="11" fill="var(--accent)"/><text x="40" y="87" text-anchor="middle" font-size="11" font-weight="700" fill="var(--accent-contrast)">2</text>
    <text x="66" y="88"><tspan font-weight="700" fill="var(--text)">First tool call.</tspan><tspan fill="var(--text-muted)"> Define one tool and read the raw tool_use block it returns</tspan></text>
    <circle cx="40" cy="141" r="11" fill="var(--accent)"/><text x="40" y="145" text-anchor="middle" font-size="11" font-weight="700" fill="var(--accent-contrast)">3</text>
    <text x="66" y="146"><tspan font-weight="700" fill="var(--text)">Write the loop.</tspan><tspan fill="var(--text-muted)"> Build the tidy-up agent from this post, then change the task</tspan></text>
    <circle cx="40" cy="199" r="11" fill="var(--accent)"/><text x="40" y="203" text-anchor="middle" font-size="11" font-weight="700" fill="var(--accent-contrast)">4</text>
    <text x="66" y="204"><tspan font-weight="700" fill="var(--text)">Add guardrails.</tspan><tspan fill="var(--text-muted)"> Step limits, approvals, logging; try to break your own agent</tspan></text>
    <circle cx="40" cy="257" r="11" fill="var(--accent)"/><text x="40" y="261" text-anchor="middle" font-size="11" font-weight="700" fill="var(--accent-contrast)">5</text>
    <text x="66" y="262"><tspan font-weight="700" fill="var(--text)">Build an MCP server.</tspan><tspan fill="var(--text-muted)"> Wrap something you use daily, plug it into your agent app</tspan></text>
    <circle cx="40" cy="315" r="11" fill="var(--accent)"/><text x="40" y="319" text-anchor="middle" font-size="11" font-weight="700" fill="var(--accent-contrast)">6</text>
    <text x="66" y="320"><tspan font-weight="700" fill="var(--text)">Try a pattern.</tspan><tspan fill="var(--text-muted)"> Evaluator–optimizer or orchestrator–workers on a real task</tspan></text>
    <circle cx="40" cy="373" r="11" fill="var(--accent-strong)"/><text x="40" y="377" text-anchor="middle" font-size="11" font-weight="700" fill="var(--accent-contrast)">7</text>
    <text x="66" y="378"><tspan font-weight="700" fill="var(--text)">Evaluate and ship.</tspan><tspan fill="var(--text-muted)"> Write 10 test tasks, measure, then automate one real chore</tspan></text>
  </g>
</svg>
</div>

Some ideas for that first real chore: sorting your receipts into a spreadsheet, a "morning brief" agent that reads your calendar and unread emails and writes a five-line summary, a travel planner that checks weather and opening hours before building the itinerary, or an agent that keeps a project's README in sync with its code.

## Start small, then let it earn trust

An agent is a loop: the model reads the goal and the history, asks for a tool, your code runs it and returns the result, and the cycle repeats until the job is done. Everything else is about making that loop useful and safe — clear tools, memory that fits the task, MCP to plug in new capabilities, the simplest pattern that works, and guardrails enforced in code rather than in the prompt. Start small, read the traces, and widen the agent's freedom only as it earns your trust.

> **Next up:** [Part 2 — build it locally for free](/Agentic-AI-Run-It-Locally/) runs this same agent on your laptop at zero cost, then walks through five projects to build — from a Downloads organizer to a malware-triage agent that writes its own report.

Worth reading next: Anthropic's <a href="https://www.anthropic.com/engineering/building-effective-agents" target="_blank" rel="noopener">Building effective agents</a>, the <a href="https://docs.claude.com/en/docs/agents-and-tools/tool-use/overview" target="_blank" rel="noopener">tool use documentation</a>, and the <a href="https://modelcontextprotocol.io" target="_blank" rel="noopener">Model Context Protocol</a> site.
