---
title: "When the Case Freezes You: A Field Kit for DFIR Paralysis"
excerpt: "A 4 TB image with no context. A lawyer asking about a report you wrote two years ago. Three hours deep in one artifact. Every responder freezes eventually — here's a structured way back to moving, built on Brett Shavers' idea that context is the story."
header:
  image: /images/posts/dfir-paralysis/hero.jpg
tags: [DFIR, mindset, methodology, SOC]
---
![When the case freezes you: a field kit for getting unstuck](/images/posts/dfir-paralysis/hero.jpg)

Picture it. A drive lands on your desk — four terabytes, a one-line ticket ("possible data theft, please check"), and a manager who wants an answer by Thursday. You mount the image, open your favourite tool, and… nothing. Not a technical problem. A human one. There are a million places to start and none of them looks like the right one.

Brett Shavers gave this moment a name in his article <a href="https://www.linkedin.com/pulse/dfir-paralysis-what-do-when-you-dont-know-brett-shavers-jvzyc" target="_blank" rel="noopener">DF/IR Paralysis: What to Do When You Don't Know What to Do</a>, and I've been thinking about it ever since. His core point is simple and freeing: the freeze isn't a sign you're bad at this. It's a signal to stop improvising and fall back on structure. He also makes two arguments every analyst should tattoo somewhere visible — the people receiving your work care about <strong>outcomes, not process</strong>, and an artifact without context means very little, because <strong>context is the story</strong>.

This post is my attempt to turn that mindset into a practical kit: something you can actually reach for at 4 p.m. on a Wednesday when the case has frozen you.

## Three kinds of freeze

Not every freeze is the same, and the fix depends on which one you're in. Naming it takes thirty seconds and already breaks the loop.

<div style="margin:2rem 0;padding:1.25rem;background:var(--bg-elevated);border:1px solid var(--border);border-radius:var(--radius-m);">
<svg viewBox="0 0 640 230" style="width:100%;height:auto;font-family:inherit;" role="img" aria-label="Three kinds of DFIR freeze: the volume freeze with too much data and no starting point, fixed by writing the question; the pressure freeze under scrutiny or deadline, fixed by switching to a script you trust; the rabbit-hole freeze deep inside one artifact, fixed by a timebox and a step back to the question">
  <g style="font-size:12px;">
    <rect x="5" y="10" width="200" height="210" rx="12" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="20" y="40" font-size="26">🗄️</text>
    <text x="20" y="70" font-weight="700" font-size="15" fill="var(--text)">Volume freeze</text>
    <text x="20" y="94" fill="var(--text-muted)">Too much data,</text>
    <text x="20" y="112" fill="var(--text-muted)">no starting point.</text>
    <text x="20" y="130" fill="var(--text-muted)">"Where do I even begin?"</text>
    <rect x="15" y="160" width="180" height="46" rx="8" fill="var(--accent)" fill-opacity="0.15" stroke="var(--accent)"/>
    <text x="27" y="180" font-weight="700" fill="var(--accent)">First move</text>
    <text x="27" y="197" fill="var(--text)">write the question</text>

    <rect x="220" y="10" width="200" height="210" rx="12" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="235" y="40" font-size="26">🎤</text>
    <text x="235" y="70" font-weight="700" font-size="15" fill="var(--text)">Pressure freeze</text>
    <text x="235" y="94" fill="var(--text-muted)">Deadline, executives,</text>
    <text x="235" y="112" fill="var(--text-muted)">cross-examination.</text>
    <text x="235" y="130" fill="var(--text-muted)">"What if I'm wrong?"</text>
    <rect x="230" y="160" width="180" height="46" rx="8" fill="var(--accent)" fill-opacity="0.15" stroke="var(--accent)"/>
    <text x="242" y="180" font-weight="700" fill="var(--accent)">First move</text>
    <text x="242" y="197" fill="var(--text)">run a script you trust</text>

    <rect x="435" y="10" width="200" height="210" rx="12" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="450" y="40" font-size="26">🕳️</text>
    <text x="450" y="70" font-weight="700" font-size="15" fill="var(--text)">Rabbit-hole freeze</text>
    <text x="450" y="94" fill="var(--text-muted)">Three hours inside</text>
    <text x="450" y="112" fill="var(--text-muted)">one artifact.</text>
    <text x="450" y="130" fill="var(--text-muted)">"Why did I open this?"</text>
    <rect x="445" y="160" width="180" height="46" rx="8" fill="var(--accent)" fill-opacity="0.15" stroke="var(--accent)"/>
    <text x="457" y="180" font-weight="700" fill="var(--accent)">First move</text>
    <text x="457" y="197" fill="var(--text)">timebox, then step back</text>
  </g>
</svg>
</div>

The volume freeze is about <em>direction</em>. The pressure freeze is about <em>fear</em>. The rabbit-hole freeze is about <em>focus</em>. Same symptom — you stop making progress — but three different cures.

## The ten-minute unfreeze

When I notice I'm stuck, I don't try to "push through". I run the same short loop every time, on paper if I have to. It takes about ten minutes, and it works precisely because it's boring:

<div style="margin:2rem 0;padding:1.25rem;background:var(--bg-elevated);border:1px solid var(--border);border-radius:var(--radius-m);">
<svg viewBox="0 0 640 300" style="width:100%;height:auto;font-family:inherit;" role="img" aria-label="The unfreeze loop: write one question, list what would prove or disprove it, pick the smallest dataset that can answer it, timebox the work, keep known, assumed and unknown lists, then return to the question with the result">
  <defs><marker id="dp-a1" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto"><path d="M0,0 L8,4 L0,8 z" fill="var(--accent)"/></marker></defs>
  <g style="font-size:12px;">
    <circle cx="320" cy="150" r="62" fill="var(--accent)"/>
    <text x="320" y="146" text-anchor="middle" font-weight="700" font-size="14" fill="var(--accent-contrast)">THE</text>
    <text x="320" y="164" text-anchor="middle" font-weight="700" font-size="14" fill="var(--accent-contrast)">QUESTION</text>
    <g fill="var(--text)">
      <rect x="235" y="8" width="170" height="48" rx="8" fill="var(--bg-elevated-2)" stroke="var(--accent)"/>
      <text x="320" y="28" text-anchor="middle" font-weight="700">① Write it down</text>
      <text x="320" y="46" text-anchor="middle" fill="var(--text-muted)">one sentence, testable</text>
      <rect x="455" y="80" width="180" height="48" rx="8" fill="var(--bg-elevated-2)" stroke="var(--accent)"/>
      <text x="545" y="100" text-anchor="middle" font-weight="700">② Prove / disprove</text>
      <text x="545" y="118" text-anchor="middle" fill="var(--text-muted)">what would I expect to see?</text>
      <rect x="455" y="178" width="180" height="48" rx="8" fill="var(--bg-elevated-2)" stroke="var(--accent)"/>
      <text x="545" y="198" text-anchor="middle" font-weight="700">③ Smallest dataset</text>
      <text x="545" y="216" text-anchor="middle" fill="var(--text-muted)">3 artifacts, 1 host, 1 window</text>
      <rect x="235" y="244" width="170" height="48" rx="8" fill="var(--bg-elevated-2)" stroke="var(--accent)"/>
      <text x="320" y="264" text-anchor="middle" font-weight="700">④ Timebox</text>
      <text x="320" y="282" text-anchor="middle" fill="var(--text-muted)">a real timer, 45 min</text>
      <rect x="5" y="130" width="180" height="48" rx="8" fill="var(--bg-elevated-2)" stroke="var(--accent)"/>
      <text x="95" y="150" text-anchor="middle" font-weight="700">⑤ Known / assumed /</text>
      <text x="95" y="168" text-anchor="middle" font-weight="700">unknown</text>
    </g>
    <path d="M405 40 Q 470 45 500 78" fill="none" stroke="var(--accent)" stroke-width="2" marker-end="url(#dp-a1)"/>
    <path d="M545 128 L 545 175" fill="none" stroke="var(--accent)" stroke-width="2" marker-end="url(#dp-a1)"/>
    <path d="M500 226 Q 470 262 408 266" fill="none" stroke="var(--accent)" stroke-width="2" marker-end="url(#dp-a1)"/>
    <path d="M235 266 Q 120 262 100 181" fill="none" stroke="var(--accent)" stroke-width="2" marker-end="url(#dp-a1)"/>
    <path d="M100 128 Q 120 40 232 33" fill="none" stroke="var(--accent)" stroke-width="2" marker-end="url(#dp-a1)"/>
  </g>
</svg>
</div>

**① Write the question.** One sentence you could answer yes or no. Not "investigate the laptop", but <em>"Did the user copy files from the finance share to a USB device between 1 and 15 August?"</em> If you can't write it, your next action isn't opening a tool. It's calling the person who asked.

**② Decide what would prove it — and what would disprove it.** If they copied files to USB, I'd expect a new USB device in the registry, LNK files or jump lists pointing at removable volumes, shellbags, maybe file system timestamps on the share. If they didn't, I'd expect none of that, or devices that predate the window. Writing the "disprove" column is what keeps you honest.

**③ Pick the smallest dataset that can answer it.** Not the whole image. A targeted collection of the artifacts from step ②, from one host, for one time window. Everything else waits.

**④ Timebox it.** Set an actual timer. When it rings, you stop and re-read the question, even if you feel close. Rabbit holes feel productive from the inside.

**⑤ Keep three lists.** <em>Known</em> (with the source of each fact), <em>assumed</em> (needs proof), and <em>unknown</em> (and whether it even matters). Anxiety lives in the gap between what you know and what you're assuming without realising it. Writing it down closes the gap.

## Shrink the haystack

Step ③ is where tools help, as long as they serve the question instead of replacing it. A few examples of "smallest dataset" in practice:

Collect only what the question needs, instead of imaging everything first (KAPE):

```powershell
# Targeted triage collection - registry hives, event logs, LNK/jump lists, browser data, etc.
kape.exe --tsource C: --tdest E:\case042\triage --target KapeTriage --vhdx case042
```

Turn hundreds of event logs into one timeline you can actually read (Hayabusa):

```powershell
hayabusa.exe csv-timeline -d E:\case042\triage\C\Windows\System32\winevt\Logs -o E:\case042\evtx-timeline.csv
```

Ask the event log one precise question — for example, "who logged on over RDP during the incident window?":

```powershell
# 4624 = successful logon; LogonType 10 = RemoteInteractive (RDP)
Get-WinEvent -Path .\Security.evtx -FilterXPath "*[System[(EventID=4624)]]" |
    Where-Object { $_.TimeCreated -ge '2025-08-01' -and $_.TimeCreated -lt '2025-08-16' } |
    Where-Object { $_.Properties[8].Value -eq 10 } |
    Select-Object TimeCreated,
        @{n='User';  e={ "$($_.Properties[6].Value)\$($_.Properties[5].Value)" }},
        @{n='Source';e={ $_.Properties[18].Value }}
```

> **Why this helps:** each of these turns "4 TB of maybe" into a few hundred rows that relate to <em>your</em> question. Small, relevant data is easier to reason about, and easier to explain later.

## Context is the story

This is the part of Shavers' article I keep coming back to. An artifact on its own is a fact without a meaning. A Prefetch file tells you a program with that name ran; it doesn't tell you <em>who</em> ran it, <em>why</em>, or whether it was the malicious copy or the legitimate one. Meaning appears only when artifacts line up with each other — and with the human world outside the computer.

I think of it as a ladder. Every rung up makes a finding more defensible:

<div style="margin:2rem 0;padding:1.25rem;background:var(--bg-elevated);border:1px solid var(--border);border-radius:var(--radius-m);">
<svg viewBox="0 0 640 270" style="width:100%;height:auto;font-family:inherit;" role="img" aria-label="Context ladder from bottom to top: a single artifact, corroborated by independent artifacts, placed on a timeline, tied to a person and account, and finally explained by the human story such as access badges, schedules and interviews">
  <g style="font-size:12px;">
    <rect x="20" y="214" width="360" height="44" rx="8" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="34" y="234" font-weight="700" fill="var(--text)">1 · Artifact</text><text x="34" y="250" fill="var(--text-muted)">"setup.exe has a Prefetch file"</text>
    <rect x="60" y="164" width="360" height="44" rx="8" fill="var(--accent)" fill-opacity="0.18" stroke="var(--border)"/>
    <text x="74" y="184" font-weight="700" fill="var(--text)">2 · Corroboration</text><text x="74" y="200" fill="var(--text-muted)">Amcache hash, 4688 / Sysmon, EDR process event</text>
    <rect x="100" y="114" width="360" height="44" rx="8" fill="var(--accent)" fill-opacity="0.35" stroke="var(--border)"/>
    <text x="114" y="134" font-weight="700" fill="var(--text)">3 · Timeline</text><text x="114" y="150" fill="var(--text-muted)">what happened before and after, in UTC</text>
    <rect x="140" y="64" width="360" height="44" rx="8" fill="var(--accent)" fill-opacity="0.6" stroke="var(--border)"/>
    <text x="154" y="84" font-weight="700" fill="var(--text)">4 · Attribution</text><text x="154" y="100" fill="var(--text)">which account, which session, UserAssist, logon events</text>
    <rect x="180" y="14" width="360" height="44" rx="8" fill="var(--accent)"/>
    <text x="194" y="34" font-weight="700" fill="var(--accent-contrast)">5 · Human story</text><text x="194" y="50" fill="var(--accent-contrast)">badge logs, schedules, interviews, business process</text>
    <text x="550" y="140" font-weight="700" fill="var(--text)">more</text>
    <text x="550" y="158" font-weight="700" fill="var(--text)">defensible</text>
    <line x1="628" y1="240" x2="628" y2="30" stroke="var(--accent)" stroke-width="2.5"/>
    <path d="M620 40 L628 24 L636 40 Z" fill="var(--accent)"/>
  </g>
</svg>
</div>

Here is what that looks like for a single question — <em>"Did this user run the tool we found?"</em> — on a Windows 10/11 endpoint:

| Artifact | What it gives you | What it does <strong>not</strong> give you |
|---|---|---|
| **Prefetch** (`C:\Windows\Prefetch`) | A program with that name/path ran, run count, up to 8 recent run times | Who ran it. Also disabled by default on Windows Server |
| **Amcache.hve** | File path, SHA-1, first-seen information | Proof of execution on its own, on modern Windows |
| **ShimCache** (AppCompatCache) | The file existed and was seen by the system | Execution on Windows 10+, or a reliable time of running |
| **UserAssist** (in the user's NTUSER.DAT) | GUI launches by <em>that user</em>, with counts and last run | Command-line executions |
| **Security 4688 / Sysmon 1 / EDR** | Process creation with parent, user and often command line | Anything if auditing or the sensor wasn't enabled |
| **SRUM** | Per-app, per-user resource and network usage, roughly hourly | Exact timestamps |
| **$MFT / $UsnJrnl** | When the file arrived, was renamed or deleted | Whether it ran |

Notice how every row has a blind spot that another row covers. That's the point. One artifact is a rumour; three independent ones agreeing is a finding. And when the digital story contradicts the physical one — the logs say the user was at the keyboard, the badge system says they were on a plane — that contradiction <em>is</em> the most important finding in the case.

> **Easy trap:** don't let a strong artifact stop the investigation. A clean Prefetch hit feels like an answer, and that feeling is exactly when to ask "what else would have to be true?"

## Say it in outcomes

The second idea from Shavers that changed how I write: decision-makers want to know <strong>what you found, whether you can stand behind it, and what it changes</strong>. They don't need the tool list, the hours spent, or the obstacles you beat.

The same finding, written two ways:

| Process-first (what we usually write) | Outcome-first (what they need) |
|---|---|
| "Using KAPE, we collected triage data and parsed it with Registry Explorer and EvtxECmd. After reviewing 1.2M events and several registry hives, we identified a USB device…" | "A personal USB drive was connected to the user's laptop on 7 August at 18:42 UTC. Within six minutes, 214 files from the finance share were opened from that drive's folder path. This supports the data-theft allegation. It does <strong>not</strong> show the files left the building — that needs the badge and DLP records." |
| "Further analysis may be required." | "Confidence: high for the USB connection and file access; unknown for exfiltration beyond the device." |

The process still matters — it belongs in the appendix, where another examiner can reproduce your work. But the first paragraph is for the person who has to make a decision tomorrow morning.

A template I now use for every finding:

```text
FINDING   : <what happened, in one sentence, with time in UTC>
EVIDENCE  : <2-3 independent artifacts, with source and path>
MEANING   : <what it shows>
LIMITS    : <what it does NOT show, and what would be needed to show it>
CONFIDENCE: high / medium / low - and why
```

## Under the spotlight

The pressure freeze is the hardest, because it happens in front of people: an executive briefing, a heated incident call, or a lawyer asking about a report you wrote long ago. A few habits that make it survivable:

1. **Write today for the version of you who'll be cross-examined in two years.** Notes with timestamps, the exact question you were answering, and the reasoning behind every conclusion. Your memory won't be there; your notes will.
2. **"I don't know" is a complete answer.** Followed by "here's what would tell us". Guessing under pressure is how good analysts lose credibility.
3. **Restate the question before answering it.** It buys you a few seconds and catches misunderstandings — half of hard questions are really two questions glued together.
4. **Separate facts from interpretations out loud.** "The log shows X. My interpretation is Y, because Z." Nobody can push you off a fact you haven't stretched.
5. **Go back to the structure.** Question, evidence, meaning, limits. It's the same skeleton whether you're writing, briefing or testifying.

## Build the reflex before you need it

Structure only helps under stress if it's automatic, and nothing becomes automatic by reading about it. Some low-cost ways to practise:

| Drill | How | Builds |
|---|---|---|
| **Question first** | Before opening any new case or alert, write the one-sentence question. Every time, even when it feels obvious | Direction |
| **Disprove it** | For every finding, write one thing that would prove it wrong, then go look for it | Honesty |
| **Explain it to a non-analyst** | Brief a colleague from finance or HR in two minutes, no jargon | Outcomes |
| **Rabbit-hole timer** | 45-minute timer on any deep dive; when it rings, write what you learned and whether it moved the question | Focus |
| **Read your old reports** | Pick one from a year ago. Could you defend every sentence today? | Defensibility |
| **Public practice images** | Work through public DFIR challenges with the loop above, not just the tools | All of it |

## Take the card with you

I condensed everything above into a one-page card: name the freeze, write the question, prove/disprove, smallest dataset, timebox, three lists, outcome sentence. Print it, keep it next to your screen, and use it the next time a case stares back at you.

<a href="/assets/files/dfir-paralysis/unfreeze-card.md" target="_blank" rel="noopener">⬇ Download the Unfreeze Card (Markdown)</a>

## Freezing is normal; staying frozen is optional

Every responder freezes eventually. The difference between the analysts I admire and everyone else isn't that they never get stuck — it's that they have a way back. A question you can write down, a dataset small enough to reason about, artifacts that corroborate each other, a story that fits the human world, and a finding stated as an outcome you can defend. That's not a script that replaces thinking. It's what lets you keep thinking when the pressure is on.

Credit where it's due: this whole post grew out of Brett Shavers' <a href="https://www.linkedin.com/pulse/dfir-paralysis-what-do-when-you-dont-know-brett-shavers-jvzyc" target="_blank" rel="noopener">DF/IR Paralysis</a> article. If the mindset side of DFIR interests you, his book <em>DFIR Investigative Mindset</em> goes much deeper than any checklist can.
