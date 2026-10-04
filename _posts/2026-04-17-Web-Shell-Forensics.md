---
title: "Chasing a Web Shell: A Windows Forensics Walkthrough"
excerpt: "One uploaded file — a few kilobytes of PHP — becomes a remote doorway into the whole network. This is how you investigate it end to end: why web-shell detection is a process-lineage problem, how to read the web-server logs, and how the MFT, USN journal and Prefetch rebuild the timeline the attacker tried to erase."
header:
  image: /images/posts/web-shell/hero.jpg
tags: [DFIR, Forensics, Incident-Response, web-shell, IIS, Windows, timeline, timestomping, threat-hunting]
---
![Chasing a web shell: a Windows forensics walkthrough](/images/posts/web-shell/hero.jpg)

A web shell is one of the highest-leverage things an attacker can plant. It's a server-side script — often a few kilobytes of PHP, ASPX or JSP — that turns an HTTP request into command execution on your server. No VPN, no RDP, no stolen domain credentials. Just one file reachable over the web, and suddenly someone has a remote terminal inside your perimeter. From there it's reconnaissance, new admin accounts, lateral movement, and often ransomware.

I've been reading Muhap Yahia's excellent two-part *DFIR Mindset: Web Shell Forensics* series (<a href="https://muhapyahia.medium.com/dfir-mindset-web-shell-forensics-investigation-windows-part-1-9c4b7e1f0a2a" target="_blank" rel="noopener">Part 1</a> and <a href="https://muhapyahia.medium.com/dfir-mindset-web-shell-forensics-investigation-windows-part-2-b3dd8afc6c6c" target="_blank" rel="noopener">Part 2</a>), which walks a web-shell case on Windows from the first alert to a full timeline. This is my own take on that investigation — the mental model and the artifact mechanics, so you could run the same case yourself in a lab.

> **Lab note:** the commands below target a lab image (the walkthrough uses DVWA on XAMPP). Run forensic tooling against evidence you're authorised to examine, on copies, read-only.

## The misconception that trips up junior analysts

Ask someone new how they'd detect a web shell and the answer is almost always: *"a web shell is a file, so I'll monitor file creation."* It sounds right. It points you at Sysmon Event ID 11 (FileCreate), the MFT, the USN journal.

And in a tiny lab it works. In production it collapses. An internet-facing web server writes files constantly — uploads, caches, deployments, temp files — so alerting on every file creation is a noise explosion that no SOC can triage. The signal drowns.

The shift in thinking that makes web-shell detection tractable:

<div style="margin:2rem 0;padding:1.25rem;background:var(--bg-elevated);border:1px solid var(--border);border-radius:var(--radius-m);">
<svg viewBox="0 0 640 210" style="width:100%;height:auto;font-family:inherit;" role="img" aria-label="Web shell detection is a process-lineage problem, not a file-creation problem. Monitoring every file write produces too much noise in production. Instead, watch for the web server process spawning command interpreters: httpd.exe or w3wp.exe as the parent of cmd.exe or powershell.exe running reconnaissance commands like whoami.">
  <defs><marker id="ws-a" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto"><path d="M0,0 L8,4 L0,8 z" fill="var(--accent)"/></marker></defs>
  <g style="font-size:12px;">
    <rect x="5" y="20" width="285" height="170" rx="12" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="22" y="44" font-weight="700" fill="var(--text-muted)">❌ File-creation thinking</text>
    <text x="22" y="70" fill="var(--text)">"a web shell is a file,</text>
    <text x="22" y="88" fill="var(--text)">so watch file writes"</text>
    <text x="22" y="116" fill="var(--text-muted)">Sysmon 11 · MFT · USN</text>
    <text x="22" y="144" fill="var(--text-muted)">In production: millions of</text>
    <text x="22" y="162" fill="var(--text-muted)">legitimate writes = noise</text>
    <text x="22" y="180" fill="var(--text-muted)">→ doesn't scale</text>

    <rect x="350" y="20" width="285" height="170" rx="12" fill="var(--accent)" fill-opacity="0.12" stroke="var(--accent)" stroke-width="2"/>
    <text x="367" y="44" font-weight="700" fill="var(--accent)">✅ Process-lineage thinking</text>
    <text x="367" y="70" fill="var(--text)">"watch what the web</text>
    <text x="367" y="88" fill="var(--text)">server process spawns"</text>
    <rect x="367" y="104" width="120" height="26" rx="5" fill="var(--bg-elevated-2)" stroke="var(--border)"/><text x="427" y="121" text-anchor="middle" font-family="var(--font-mono)" fill="var(--text)">w3wp / httpd</text>
    <rect x="367" y="150" width="120" height="26" rx="5" fill="var(--bg-elevated-2)" stroke="var(--border)"/><text x="427" y="167" text-anchor="middle" font-family="var(--font-mono)" fill="var(--text)">cmd / powershell</text>
    <line x1="427" y1="130" x2="427" y2="148" stroke="var(--accent)" stroke-width="2" marker-end="url(#ws-a)"/>
    <text x="500" y="128" fill="var(--text-muted)">parent</text>
    <text x="500" y="167" fill="var(--text-muted)">child +</text>
    <text x="500" y="182" fill="var(--text-muted)">whoami</text>
  </g>
</svg>
</div>

The pivot is **process lineage and execution context**, not the file. A web shell executes *as the web server process*, so anything the attacker runs through it shows that server process as its parent:

| Web server | Process the shell runs under |
|---|---|
| IIS (Windows) | `w3wp.exe` |
| Apache (Windows / XAMPP) | `httpd.exe` |
| Apache (Linux) | `apache2` / `httpd` |
| Nginx (Linux) | `nginx` |
| PHP-FPM | `php-fpm` |
| Tomcat | `java` / `java.exe` |

So the detection that actually fires isn't "file created." It's **`cmd.exe` spawned by `httpd.exe` running `whoami`** — a command interpreter, with a web-server parent, executing non-interactive reconnaissance. That's the alert that starts the case.

## The first alert, and the triage questions

In the walkthrough, the case opens exactly there: an alert that `whoami` ran on a server. Pull the full process details and the story is immediate:

```text
process.name            = cmd.exe
process.args            = cmd.exe /s /c "whoami"
process.executable      = C:\Windows\System32\cmd.exe
process.parent.name     = httpd.exe
process.parent.executable = C:\xampp\apache\bin\httpd.exe
```

`cmd.exe` with a parent of `httpd.exe` is the tell. Why care about the parent and not `cmd.exe` itself? Because **the parent is how you track the attacker.** They won't keep using `cmd.exe` — they might pull a reflective DLL that runs in memory, drop a driver, or exploit a vulnerable one. But at the start, almost everything still runs under the web-server process. So you hunt the parent (`httpd.exe` / `w3wp.exe`), not the child. Filter on that parent and you see the attacker fan out — discovery commands, then creating admin users for persistence.

Before touching anything, the triage questions that decide your next move:

1. Is this a critical production/value-chain server, or can I isolate it without business impact?
2. Is this the only affected server, or just the only one that *alerted*?
3. What's the root cause — which web application let them in?
4. Do I have the SIEM/endpoint visibility to answer #3?

> **Containment vs investigation:** containment comes first because the attacker may still be active — block their IPs, disable the exposed endpoint, restrict external access. But think before you isolate: if the actor already has footholds elsewhere, yanking one server can tip them off and trigger them to start encrypting the others. On a non-critical box you can isolate freely; on the crown jewels, weigh it.

There's also a hard production reality worth internalising: EDR *could* just block `w3wp.exe → cmd.exe`, but on a busy server that worker process also runs legitimate business logic, so blanket-blocking its children can take down the application. In banking and other high-availability shops, blocking policies are deliberately conservative — which means the investigation often falls back on **SIEM-first** evidence: web-server logs, endpoint command logging, proxy/WAF telemetry.

## Part 1: what the web-server logs tell you

Once you have access to the server, the first artifacts are the web-server **access** and **error** logs. They answer two different questions:

- **access.log** — what the attacker *did* (which URLs, which methods, which succeeded).
- **error.log** — what they *tried and failed*, and crucially the **first time** they poked at the app.

```text
Apache / XAMPP:  C:\xampp\apache\logs\access.log
                 C:\xampp\apache\logs\error.log
IIS:             C:\inetpub\logs\LogFiles\W3SVC1\u_ex*.log
```

Convert them to CSV first and work them in a timeline tool (Timeline Explorer or Timesketch), filtering on the `Referer` and `Method` to see where each request came from and what it was. In the case, the earliest attacker interaction is a **directory-traversal** attempt against an endpoint, trying to reach `/etc/passwd` — the recon that precedes the upload. (One gotcha the author flags: if a proxy sits in front, the logged source IP is the proxy's, so you pivot to firewall logs for the real origin.)

Follow the requests forward and you find the two facts that drive Part 2: the attacker uploaded a file named **`webshell.php`**, into **`DVWA/hackable/uploads/`**. Logs are great at *what came over HTTP* — but they can't tell you when the file hit disk, whether it was modified, renamed, or whether it actually executed. For that, you go to the Windows artifacts.

## Part 2: rebuilding the timeline from Windows artifacts

This is where it gets fun, and where the attacker's anti-forensics shows up. Three artifacts carry the story, each answering a different question:

<div style="margin:2rem 0;padding:1.25rem;background:var(--bg-elevated);border:1px solid var(--border);border-radius:var(--radius-m);">
<svg viewBox="0 0 640 170" style="width:100%;height:auto;font-family:inherit;" role="img" aria-label="Three Windows artifacts and the question each answers: the Master File Table shows when a file first appeared and where it lived; the USN change journal shows what happened to files over time including renames and deletes; and Prefetch shows which executables actually ran and how many times.">
  <g style="font-size:12px;">
    <rect x="5" y="20" width="200" height="130" rx="10" fill="var(--bg-elevated-2)" stroke="var(--accent)"/>
    <text x="105" y="46" text-anchor="middle" font-weight="700" fill="var(--accent)">$MFT</text>
    <text x="105" y="72" text-anchor="middle" fill="var(--text-muted)">when a file first</text>
    <text x="105" y="90" text-anchor="middle" fill="var(--text-muted)">appeared, where it</text>
    <text x="105" y="108" text-anchor="middle" fill="var(--text-muted)">lived, its timestamps</text>
    <text x="105" y="134" text-anchor="middle" fill="var(--text)">"does it exist now?"</text>
    <rect x="220" y="20" width="200" height="130" rx="10" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="320" y="46" text-anchor="middle" font-weight="700" fill="var(--text)">USN Journal</text>
    <text x="320" y="72" text-anchor="middle" fill="var(--text-muted)">what happened to</text>
    <text x="320" y="90" text-anchor="middle" fill="var(--text-muted)">files over time:</text>
    <text x="320" y="108" text-anchor="middle" fill="var(--text-muted)">create, rename, delete</text>
    <text x="320" y="134" text-anchor="middle" fill="var(--text)">"what happened to it?"</text>
    <rect x="435" y="20" width="200" height="130" rx="10" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="535" y="46" text-anchor="middle" font-weight="700" fill="var(--text)">Prefetch</text>
    <text x="535" y="72" text-anchor="middle" fill="var(--text-muted)">which executables</text>
    <text x="535" y="90" text-anchor="middle" fill="var(--text-muted)">actually ran, when,</text>
    <text x="535" y="108" text-anchor="middle" fill="var(--text-muted)">and how many times</text>
    <text x="535" y="134" text-anchor="middle" fill="var(--text)">"did it execute?"</text>
  </g>
</svg>
</div>

**Narrow before you parse.** A classic mistake is collecting more than you need. We already know the filename (`webshell.php`) and its folder, so we focus there. Parse the MFT with Eric Zimmerman's **MFTECmd** and open the result in Timeline Explorer:

```text
MFTECmd.exe -f "C:\$MFT" --csv "C:\Output"
```

Then the first twist. Search the MFT for `webshell.php` and… nothing. The file we *proved* was uploaded isn't there. Did they delete it? Rename it? Wrong place? The key insight: **the MFT shows the file system's *current* state, not its full history.** When something happens to a file, NTFS updates the existing record (including the `$FILE_NAME`) rather than keeping every past version. So don't search the filename that can change — search the **parent directory**, which can't:

Filtering the MFT on `DVWA\hackable\uploads\` returns three PHP files: `index.php`, `mosts.php`, `liosmon.php`. Now, which belongs to our timeline? Sort by creation time — and here's the second twist.

## Catching the timestomp

All three files show a **Created** time of `2023-01-10 00:00:00` — but the incident is June 2026. A file "created" three years before the server existed is a red flag, but one indicator isn't proof. The attacker may have **timestomped** them: forged the timestamps to blend in.

This is where NTFS saves you. Every file carries **two** sets of timestamps:

- **`$STANDARD_INFORMATION` ($SI)** — what Explorer and most tools show, and what timestomping tools usually rewrite.
- **`$FILE_NAME` ($FN)** — a second set most timestomping tools *leave untouched*.

<div style="margin:2rem 0;padding:1.25rem;background:var(--bg-elevated);border:1px solid var(--border);border-radius:var(--radius-m);">
<svg viewBox="0 0 640 170" style="width:100%;height:auto;font-family:inherit;" role="img" aria-label="Timestomping detection: the standard information timestamps show a fake 2023 creation date set by the attacker, but the file-name timestamps still show the real June 2026 date. A mismatch between the two, plus zeroed fractional seconds, reveals the tampering.">
  <g style="font-size:12px;">
    <rect x="5" y="20" width="300" height="130" rx="10" fill="var(--bg-elevated-2)" stroke="var(--accent-strong)"/>
    <text x="20" y="44" font-weight="700" fill="var(--text)">$SI  (what tools show)</text>
    <text x="20" y="70" font-family="var(--font-mono)" fill="var(--accent-strong)">Created: 2023-01-10 00:00:00</text>
    <text x="20" y="92" fill="var(--text-muted)">attacker-set · fake · round zeros</text>
    <text x="20" y="124" fill="var(--text)">looks old and innocent…</text>
    <rect x="335" y="20" width="300" height="130" rx="10" fill="var(--bg-elevated-2)" stroke="var(--accent)"/>
    <text x="350" y="44" font-weight="700" fill="var(--text)">$FN  (left untouched)</text>
    <text x="350" y="70" font-family="var(--font-mono)" fill="var(--accent)">Created: 2026-06-29 03:4x</text>
    <text x="350" y="92" fill="var(--text-muted)">the real upload time</text>
    <text x="350" y="124" fill="var(--text)">…the truth the attacker missed</text>
  </g>
</svg>
</div>

Compare `$SI` against `$FN` and the forgery falls apart: `$FN` still holds the real June 2026 creation time. Timeline Explorer even highlights the mismatch automatically, and flags classic tells like **zeroed fractional seconds** (real timestamps rarely land on `.0000000`). So one of those renamed PHP files *is* our web shell, and now we have its true birth time to anchor the timeline.

**Did it actually run?** The MFT and USN tell us the file existed and was renamed; **Prefetch** tells us what executed. A Prefetch entry like `php-cgi.exe-XXXXXXXX.pf` confirms the PHP interpreter ran, with timestamps and run counts, tying execution to our window:

```text
# Parse prefetch with PECmd, then correlate in Timeline Explorer
PECmd.exe -d "C:\Windows\Prefetch" --csv "C:\Output"
```

Stitch it together — USN for the create/rename events, `$FN` for the true timestamps, Prefetch for execution, event logs for the follow-on activity — and you have a defensible timeline: when the shell landed, that it was renamed to hide, when it executed, and what the attacker did next. The same artifact-correlation discipline from my [Windows DFIR Field Reference](/Windows-DFIR-Field-Reference/) applies; this is that reference used on a live story.

## The takeaways

<div style="margin:2rem 0;padding:1.25rem;background:var(--bg-elevated);border:1px solid var(--border);border-radius:var(--radius-m);">
<svg viewBox="0 0 640 160" style="width:100%;height:auto;font-family:inherit;" role="img" aria-label="Five takeaways: detect web shells by process lineage not file creation; hunt the web-server parent process; logs give the HTTP story, disk artifacts give the file story; search the directory not the filename because the MFT shows only current state; and always compare SI and FN timestamps to catch timestomping.">
  <g style="font-size:12.5px;">
    <circle cx="26" cy="30" r="9" fill="var(--accent)"/><text x="26" y="34" text-anchor="middle" font-size="11" font-weight="700" fill="var(--accent-contrast)">1</text>
    <text x="46" y="34" fill="var(--text)">Detect by <tspan font-weight="700">process lineage</tspan>, not file creation — web-server parent spawning a shell.</text>
    <circle cx="26" cy="62" r="9" fill="var(--accent)"/><text x="26" y="66" text-anchor="middle" font-size="11" font-weight="700" fill="var(--accent-contrast)">2</text>
    <text x="46" y="66" fill="var(--text)">Hunt the <tspan font-weight="700">parent process</tspan> (w3wp/httpd) — the attacker changes children, not the parent.</text>
    <circle cx="26" cy="94" r="9" fill="var(--accent)"/><text x="26" y="98" text-anchor="middle" font-size="11" font-weight="700" fill="var(--accent-contrast)">3</text>
    <text x="46" y="98" fill="var(--text)">Logs = the HTTP story; <tspan font-weight="700">disk artifacts</tspan> (MFT/USN/Prefetch) = the file story.</text>
    <circle cx="26" cy="126" r="9" fill="var(--accent)"/><text x="26" y="130" text-anchor="middle" font-size="11" font-weight="700" fill="var(--accent-contrast)">4</text>
    <text x="46" y="126" fill="var(--text)">Search the <tspan font-weight="700">directory, not the filename</tspan> — the MFT shows only current state.</text>
    <circle cx="26" cy="152" r="9" fill="var(--accent-strong)"/><text x="26" y="156" text-anchor="middle" font-size="11" font-weight="700" fill="var(--accent-contrast)">5</text>
    <text x="46" y="156" fill="var(--text)">Always compare <tspan font-weight="700">$SI vs $FN</tspan> timestamps to unmask timestomping.</text>
  </g>
</svg>
</div>

A web shell is never "just a file." It's the front door to everything that came after, and the investigation is a chain: an execution-context alert leads to the web logs, the web logs name the file and folder, and the disk artifacts — read with an eye for the attacker's cover-up — rebuild the true timeline. Find the door, then trace every step through it.

Full credit to Muhap Yahia's two-part series, which is well worth reading in the original for the screenshots and the blow-by-blow: <a href="https://muhapyahia.medium.com/dfir-mindset-web-shell-forensics-investigation-windows-part-1-9c4b7e1f0a2a" target="_blank" rel="noopener">Part 1</a> and <a href="https://muhapyahia.medium.com/dfir-mindset-web-shell-forensics-investigation-windows-part-2-b3dd8afc6c6c" target="_blank" rel="noopener">Part 2</a>. To practise the artifact side, the <a href="https://ericzimmerman.github.io/" target="_blank" rel="noopener">Eric Zimmerman tools</a> (MFTECmd, PECmd, Timeline Explorer) are all free, and they're pre-installed on the [SIFT Workstation](/SIFT-Workstation-Hands-On/).
