---
title: "Atomic Red Team: Prove Your Detections Actually Fire"
excerpt: "You bought the EDR, you wrote the rules, you drew the dashboard. But would any of it actually catch an attacker? Atomic Red Team lets you safely run real ATT&CK techniques against your own lab and watch whether your detections light up — here's how to use it the right way."
header:
  image: /images/posts/atomic-red-team/hero.jpg
tags: [Detection, Offensive, detection-engineering, MITRE-ATTACK, purple-team, SOC, adversary-emulation, PowerShell]
---
![Atomic Red Team: prove your detections actually fire](/images/posts/atomic-red-team/hero.jpg)

Every SOC has a comfortable assumption baked into it: *"if that happened, we'd see it."* Someone dumps credentials, someone adds a run key, someone spins up a malicious scheduled task — surely a rule fires, an alert pops, an analyst picks it up. The uncomfortable truth is that most teams have never actually checked. They've tested that the EDR is *installed*, not that it *detects*.

**Atomic Red Team**, from Red Canary, exists to close that gap. It's a free, open-source library of small, precise tests — "atomics" — each one mapped to a MITRE ATT&CK technique. You run a test that mimics a specific attacker behaviour, then you go look at your tooling and answer one honest question: *did it alert?* It's the single fastest way I know to turn "we'd probably catch that" into "we catch that, here's the alert, logged at 14:03."

> **This is a lab exercise, not a party trick.** These tests run real, if benign, attacker behaviours on a machine. Only run them on systems you own or are authorised to test, ideally an isolated VM you can snapshot and revert — the same kind of lab from my [FLARE-VM](/FLARE-VM-Malware-Analysis-Lab/) and [Kali](/Kali-Linux-Hands-On-Start/) posts. Never on production without change approval and your SOC in the loop.

## The idea: one technique, one tiny test

What makes Atomic Red Team click is how small each test is. Instead of a sprawling "emulate APT29 for three days" exercise, an atomic is one behaviour you can run in seconds and reason about completely. The library has well over a thousand of them, organised by ATT&CK technique ID.

Take **T1053.005 — Scheduled Task**. The atomic simply creates a scheduled task the way malware would, so you can confirm your detection sees it. Each test is defined in YAML with everything needed to run and, crucially, to clean up:

```yaml
- name: Scheduled task Local
  auto_generated_guid: 42f52ccd-4b89-4fab-9e9b-6a98f2b4c5b4
  description: Create an atomic scheduled task that runs on a schedule.
  supported_platforms: [windows]
  input_arguments:
    task_name:
      description: Name of the scheduled task
      type: string
      default: AtomicTask
  executor:
    name: command_prompt
    elevation_required: true
    command: |
      schtasks /create /tn "#{task_name}" /tr "cmd /c calc.exe" /sc onlogon /ru System
    cleanup_command: |
      schtasks /delete /tn "#{task_name}" /f
```

Three things to notice, because they're the whole philosophy:

1. **It maps to ATT&CK.** The folder is `T1053.005`, so you always know exactly which adversary behaviour you're exercising and can line it up against your detection coverage.
2. **It's parameterised.** `input_arguments` let you change the task name, path, payload — so one atomic covers many variations.
3. **It cleans up after itself.** Every test has a `cleanup_command`. Running the test and *not* cleaning up is how labs rot; the framework makes undo a first-class step.

## How the pieces fit

Atomic Red Team is two things: the **content** (the YAML atomics) and the **engine** that runs them. The engine most people use is **Invoke-AtomicRedTeam**, a PowerShell module that reads the atomics and handles prerequisites, execution, input arguments and cleanup for you.

<div style="margin:2rem 0;padding:1.25rem;background:var(--bg-elevated);border:1px solid var(--border);border-radius:var(--radius-m);">
<svg viewBox="0 0 640 260" style="width:100%;height:auto;font-family:inherit;" role="img" aria-label="Atomic Red Team workflow: the atomics library of YAML tests mapped to ATT&CK feeds the Invoke-AtomicRedTeam PowerShell engine, which checks prerequisites, runs the test on the lab endpoint, then runs cleanup; meanwhile the endpoint's EDR and logs flow to the SIEM where the analyst checks whether an alert fired, and tunes the detection if it did not">
  <defs><marker id="at-a" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto"><path d="M0,0 L8,4 L0,8 z" fill="var(--accent)"/></marker></defs>
  <g style="font-size:11.5px;">
    <rect x="5" y="30" width="140" height="90" rx="10" fill="var(--bg-elevated-2)" stroke="var(--accent)"/>
    <text x="75" y="54" text-anchor="middle" font-weight="700" fill="var(--accent)">Atomics library</text>
    <text x="75" y="76" text-anchor="middle" fill="var(--text-muted)">YAML tests,</text>
    <text x="75" y="94" text-anchor="middle" fill="var(--text-muted)">one per ATT&amp;CK</text>
    <text x="75" y="110" text-anchor="middle" fill="var(--text-muted)">technique</text>
    <rect x="175" y="30" width="150" height="90" rx="10" fill="var(--bg-elevated-2)" stroke="var(--accent)"/>
    <text x="250" y="54" text-anchor="middle" font-weight="700" fill="var(--accent)">Invoke-</text>
    <text x="250" y="70" text-anchor="middle" font-weight="700" fill="var(--accent)">AtomicRedTeam</text>
    <text x="250" y="90" text-anchor="middle" fill="var(--text-muted)">prereqs → run →</text>
    <text x="250" y="108" text-anchor="middle" fill="var(--text-muted)">cleanup</text>
    <rect x="355" y="30" width="140" height="90" rx="10" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="425" y="54" text-anchor="middle" font-weight="700" fill="var(--text)">Lab endpoint</text>
    <text x="425" y="76" text-anchor="middle" fill="var(--text-muted)">behaviour runs,</text>
    <text x="425" y="94" text-anchor="middle" fill="var(--text-muted)">EDR + logs</text>
    <text x="425" y="110" text-anchor="middle" fill="var(--text-muted)">record it</text>
    <rect x="505" y="30" width="130" height="90" rx="10" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="570" y="54" text-anchor="middle" font-weight="700" fill="var(--text)">SIEM / EDR</text>
    <text x="570" y="76" text-anchor="middle" fill="var(--text-muted)">did an alert</text>
    <text x="570" y="94" text-anchor="middle" fill="var(--text-muted)">fire?</text>
    <line x1="145" y1="75" x2="173" y2="75" stroke="var(--accent)" stroke-width="2" marker-end="url(#at-a)"/>
    <line x1="325" y1="75" x2="353" y2="75" stroke="var(--accent)" stroke-width="2" marker-end="url(#at-a)"/>
    <line x1="495" y1="75" x2="503" y2="75" stroke="var(--accent)" stroke-width="2" marker-end="url(#at-a)"/>
    <rect x="175" y="165" width="320" height="70" rx="10" fill="var(--accent)" fill-opacity="0.12" stroke="var(--accent)"/>
    <text x="335" y="190" text-anchor="middle" font-weight="700" fill="var(--accent)">The purple-team loop</text>
    <text x="335" y="212" text-anchor="middle" fill="var(--text-muted)">no alert → write/tune the detection → run the atomic again</text>
    <text x="335" y="228" text-anchor="middle" fill="var(--text-muted)">until the technique reliably fires. Then move to the next.</text>
    <path d="M570 120 C 570 150, 420 150, 400 163" fill="none" stroke="var(--text-muted)" stroke-width="2" stroke-dasharray="5 4" marker-end="url(#at-a)"/>
  </g>
</svg>
</div>

## Install the framework (in your lab)

On a Windows lab VM, open an **elevated PowerShell** and install both the module and the atomics content:

```powershell
# Allow the install in this session
Set-ExecutionPolicy Bypass -Scope Process -Force

# Install the Invoke-AtomicRedTeam module and the atomics folder
IEX (IWR 'https://raw.githubusercontent.com/redcanaryco/invoke-atomicredteam/master/install-atomicredteam.ps1' -UseBasicParsing)
Install-AtomicRedTeam -getAtomics

# Load it for use
Import-Module "C:\AtomicRedTeam\invoke-atomicredteam\Invoke-AtomicRedTeam.psd1" -Force
```

That drops the atomics under `C:\AtomicRedTeam\atomics\`, one folder per technique. There's a Linux/macOS path too (the module runs under PowerShell Core), but Windows is where most detection testing starts.

> **Expect your EDR to fight you.** Atomic Red Team ships things that *look* malicious because that's the point, so antivirus may quarantine the atomics folder mid-install. In a sealed lab you exclude the folder or disable real-time protection for the exercise — never on a machine doing real work.

## The core workflow, command by command

Everything runs through four verbs: **show details, check prerequisites, run, clean up.** Let's walk the scheduled-task technique end to end.

**1. Read before you run.** Always look at exactly what a test will do first:

```powershell
Invoke-AtomicTest T1053.005 -ShowDetails
```

This prints every test under the technique, its description, the commands, and the arguments — so there are no surprises. (`-ShowDetailsBrief` gives a one-line summary of each.)

**2. Check and install prerequisites.** Some atomics need a file or tool staged first. The framework fetches them for you:

```powershell
Invoke-AtomicTest T1053.005 -GetPrereqs
```

**3. Run the test.** Now execute it and watch your tooling:

```powershell
Invoke-AtomicTest T1053.005                      # run every test in the technique
Invoke-AtomicTest T1053.005 -TestNumbers 1       # or just test #1
Invoke-AtomicTest T1053.005 -TestNames "Scheduled task Local"
```

**4. Clean up — always.** This reverses what the test did (deletes the task, removes the file, restores the key):

```powershell
Invoke-AtomicTest T1053.005 -Cleanup
```

A tidy habit is to chain prereqs → run → cleanup, with a pause in the middle so you can collect the telemetry:

```powershell
Invoke-AtomicTest T1053.005 -GetPrereqs
Invoke-AtomicTest T1053.005
Start-Sleep -Seconds 60     # give the EDR/SIEM time to ingest, then check your alerts
Invoke-AtomicTest T1053.005 -Cleanup
```

## Turning it into real detection coverage

Running one atomic is a demo. The value comes from doing it systematically and recording the result. The loop I follow:

<div style="margin:2rem 0;padding:1.25rem;background:var(--bg-elevated);border:1px solid var(--border);border-radius:var(--radius-m);">
<svg viewBox="0 0 640 210" style="width:100%;height:auto;font-family:inherit;" role="img" aria-label="Detection coverage loop: pick an ATT&CK technique relevant to your threat model, run the atomic, check whether it was logged and whether it alerted, record the result in a coverage matrix, tune or write the detection where there was a gap, then re-test to confirm">
  <defs><marker id="al-a" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto"><path d="M0,0 L8,4 L0,8 z" fill="var(--accent)"/></marker></defs>
  <g style="font-size:11px;">
    <circle cx="70" cy="70" r="42" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="70" y="62" text-anchor="middle" font-weight="700" fill="var(--text)">1 Pick</text>
    <text x="70" y="80" text-anchor="middle" fill="var(--text-muted)">a technique</text>
    <circle cx="210" cy="70" r="42" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="210" y="62" text-anchor="middle" font-weight="700" fill="var(--text)">2 Run</text>
    <text x="210" y="80" text-anchor="middle" fill="var(--text-muted)">the atomic</text>
    <circle cx="350" cy="70" r="42" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="350" y="56" text-anchor="middle" font-weight="700" fill="var(--text)">3 Check</text>
    <text x="350" y="74" text-anchor="middle" fill="var(--text-muted)">logged?</text>
    <text x="350" y="88" text-anchor="middle" fill="var(--text-muted)">alerted?</text>
    <circle cx="490" cy="70" r="42" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="490" y="62" text-anchor="middle" font-weight="700" fill="var(--text)">4 Record</text>
    <text x="490" y="80" text-anchor="middle" fill="var(--text-muted)">coverage</text>
    <circle cx="570" cy="160" r="42" fill="var(--accent)" fill-opacity="0.9"/>
    <text x="570" y="154" text-anchor="middle" font-weight="700" fill="var(--accent-contrast)">5 Tune</text>
    <text x="570" y="172" text-anchor="middle" font-size="10" fill="var(--accent-contrast)">close the gap</text>
    <line x1="112" y1="70" x2="166" y2="70" stroke="var(--accent)" stroke-width="2" marker-end="url(#al-a)"/>
    <line x1="252" y1="70" x2="306" y2="70" stroke="var(--accent)" stroke-width="2" marker-end="url(#al-a)"/>
    <line x1="392" y1="70" x2="446" y2="70" stroke="var(--accent)" stroke-width="2" marker-end="url(#al-a)"/>
    <line x1="520" y1="100" x2="556" y2="128" stroke="var(--accent)" stroke-width="2" marker-end="url(#al-a)"/>
    <path d="M540 190 C 300 210, 120 200, 80 112" fill="none" stroke="var(--text-muted)" stroke-width="2" stroke-dasharray="5 4" marker-end="url(#al-a)"/>
    <text x="300" y="205" text-anchor="middle" fill="var(--text-muted)">re-test the same atomic to prove the fix</text>
  </g>
</svg>
</div>

The output of this loop is a **coverage matrix** — a simple table of techniques against three columns: *was it logged, did it alert, is the detection good enough.* That table is gold. It turns "how good is our detection?" from a feeling into a number, and it shows you exactly where to spend your next hour.

| Technique | Behaviour | Logged? | Alerted? | Action |
|---|---|---|---|---|
| T1053.005 | Scheduled task | ✅ 4698 | ✅ | — |
| T1547.001 | Run key persistence | ✅ | ❌ | write Sigma rule |
| T1003.001 | LSASS memory dump | ✅ Sysmon 10 | ⚠️ noisy | tune threshold |
| T1059.001 | PowerShell download cradle | ❌ | ❌ | enable script-block logging |

That last row is the pattern that makes this exercise worth it: a technique you *thought* you'd catch, that produced no log at all — because script-block logging was never enabled. You only find those blind spots by testing.

## Where to point it first

Don't try to run all 1,800 tests. Start with the techniques that matter to *your* environment:

- **Map to your threat model.** If you're a Windows shop, start with the ATT&CK techniques most common in the intrusions you actually see — persistence (T1547, T1053), credential access (T1003), execution (T1059), defense evasion (T1562).
- **Pair it with ATT&CK Navigator.** Colour the techniques you've tested green/yellow/red. The heat map is the most honest picture of your detection posture you'll ever draw, and it maps straight onto the artifacts I cover in the [Windows DFIR Field Reference](/Windows-DFIR-Field-Reference/).
- **Automate the regression.** Once a detection works, re-running its atomic on a schedule catches the day someone "temporarily" disables a logging policy and forgets.

## A word on doing it safely

Because these tests are deliberately real, treat them with the same care as anything else in a malware lab:

1. **Isolated, snapshot-backed VM.** Run, observe, revert. Never your daily driver.
2. **Read every atomic before running it.** `-ShowDetails` is not optional. A handful of destructive techniques (disk wipe, defense impairment) exist in the library precisely because real adversaries use them — know what you're launching.
3. **Always clean up**, and verify the cleanup worked.
4. **Tell your SOC** if you ever test outside a closed lab. Nothing burns trust faster than your team opening a Sev-1 on an "intrusion" that was you.

Atomic Red Team turns detection from an act of faith into an experiment you can run before lunch. Pick one technique you *assume* you'd catch, run its atomic in your lab, and go look. Whatever you find — a clean alert or an awkward silence — you'll know something true about your defences that you didn't know this morning.

Everything here is open source and maintained by Red Canary. Start at the <a href="https://github.com/redcanaryco/atomic-red-team" target="_blank" rel="noopener">atomic-red-team</a> repository and the <a href="https://github.com/redcanaryco/invoke-atomicredteam" target="_blank" rel="noopener">Invoke-AtomicRedTeam</a> framework, and browse the tests in a readable form at <a href="https://www.atomicredteam.io/atomic-red-team/" target="_blank" rel="noopener">atomicredteam.io</a>. Pair it with the <a href="https://attack.mitre.org/" target="_blank" rel="noopener">MITRE ATT&CK</a> matrix and you have a complete, free detection-validation program.
