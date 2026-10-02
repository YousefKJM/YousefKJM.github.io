---
title: "Kali Linux: A Hands-On Start for Authorized Security Testing"
excerpt: "Kali bundles hundreds of offensive-security tools into one Debian-based distro — which makes it powerful and, used carelessly, a fast way to get yourself in trouble. Here's how to install it, build a safe practice lab, and work through its toolkit the right way: with scope, method and a report."
header:
  image: /images/posts/kali/hero.jpg
tags: [Offensive, pentest, Kali, tools, red-team]
---
![Kali Linux: a hands-on start for authorized security testing](/images/posts/kali/hero.jpg)

Kali Linux is the Swiss Army knife of offensive security: a free, Debian-based distribution with several hundred penetration-testing, forensics and security-auditing tools pre-installed and maintained by Offensive Security. If you've watched anyone do security testing in a film, they were almost certainly staring at Kali.

But Kali is a tool for a *job*, and the job has rules. These tools are designed to find and exploit weaknesses in computer systems — which is exactly why running them against anything you don't own or have **written permission** to test can be a crime, full stop. A scanner pointed at your own lab is education. The same scanner pointed at a company you don't have a contract with is an offence in most of the world. So this guide does two things at once: it gets you productive on Kali, and it keeps every single example inside a lab you build yourself. Learn the craft; stay on the right side of it.

> **The one rule that matters:** only test systems you own or are explicitly authorised in writing to test. Everything below targets a deliberately vulnerable machine *you* run, on an isolated network. No exceptions, no "just a quick scan of" anything else.

## What Kali actually is (and isn't)

Kali is a Linux distribution built for one audience: people doing authorised security work. That focus shapes some things worth knowing before you install it.

- It's **Debian-based**, so if you know Ubuntu, you're mostly home. `apt` installs packages; the shell is the same.
- Since the 2020.1 release it uses a **normal non-root user by default** (`kali` / `kali`), a big safety improvement over the old always-root model. You `sudo` like on any other distro.
- The toolset is organised into **metapackages** so you install only what you need, which keeps the system smaller and easier to reason about.
- It is **not a daily-driver desktop** and not a hardened server. It's a workbench you spin up for testing. Many people run it as a VM they can snapshot and revert.

<div style="margin:2rem 0;padding:1.25rem;background:var(--bg-elevated);border:1px solid var(--border);border-radius:var(--radius-m);">
<svg viewBox="0 0 640 220" style="width:100%;height:auto;font-family:inherit;" role="img" aria-label="Kali metapackages from smallest to largest: kali-linux-headless with no GUI for remote or cloud use, kali-linux-default the standard desktop toolset, kali-linux-large a bigger set, and kali-linux-everything with all tools; plus focused kali-tools categories like information-gathering, web, passwords, wireless and forensics">
  <g style="font-size:12px;">
    <rect x="5" y="20" width="150" height="110" rx="10" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="80" y="44" text-anchor="middle" font-weight="700" fill="var(--text)">headless</text>
    <text x="80" y="66" text-anchor="middle" fill="var(--text-muted)">core tools,</text>
    <text x="80" y="84" text-anchor="middle" fill="var(--text-muted)">no desktop</text>
    <text x="80" y="110" text-anchor="middle" font-size="10" fill="var(--text-muted)">cloud / remote</text>
    <rect x="165" y="20" width="150" height="110" rx="10" fill="var(--bg-elevated-2)" stroke="var(--accent)" stroke-width="2"/>
    <text x="240" y="44" text-anchor="middle" font-weight="700" fill="var(--accent)">default</text>
    <text x="240" y="66" text-anchor="middle" fill="var(--text-muted)">desktop +</text>
    <text x="240" y="84" text-anchor="middle" fill="var(--text-muted)">standard tools</text>
    <text x="240" y="110" text-anchor="middle" font-size="10" fill="var(--text)">start here</text>
    <rect x="325" y="20" width="150" height="110" rx="10" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="400" y="44" text-anchor="middle" font-weight="700" fill="var(--text)">large</text>
    <text x="400" y="66" text-anchor="middle" fill="var(--text-muted)">default +</text>
    <text x="400" y="84" text-anchor="middle" fill="var(--text-muted)">much more</text>
    <text x="400" y="110" text-anchor="middle" font-size="10" fill="var(--text-muted)">big download</text>
    <rect x="485" y="20" width="150" height="110" rx="10" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="560" y="44" text-anchor="middle" font-weight="700" fill="var(--text)">everything</text>
    <text x="560" y="66" text-anchor="middle" fill="var(--text-muted)">all tools,</text>
    <text x="560" y="84" text-anchor="middle" fill="var(--text-muted)">all the time</text>
    <text x="560" y="110" text-anchor="middle" font-size="10" fill="var(--text-muted)">rarely needed</text>
    <rect x="5" y="150" width="630" height="58" rx="10" fill="none" stroke="var(--text-muted)" stroke-dasharray="5 5"/>
    <text x="20" y="173" font-weight="700" fill="var(--text)">Focused sets: kali-tools-*</text>
    <text x="20" y="195" fill="var(--text-muted)">information-gathering · vulnerability · web · passwords · wireless · exploitation · forensics · reporting</text>
  </g>
</svg>
</div>

## Step 1 — Install Kali as a VM

The safest and most flexible way to run Kali is inside a virtual machine you can snapshot. Offensive Security publishes ready-made VM images, which is the fastest path:

1. Download the **pre-built VMware or VirtualBox image** from kali.org (there's also an installer ISO if you prefer a manual install, and WSL and ARM/Raspberry Pi builds).
2. Import it into your hypervisor. Give it 2–4 CPUs, 4 GB+ RAM, and 40 GB+ disk.
3. Boot and log in with the default **`kali`** / **`kali`**, then immediately change the password:

```bash
passwd                     # set your own password straight away
```

4. Update everything before you do anything else — Kali moves fast:

```bash
sudo apt update && sudo apt full-upgrade -y
```

5. **Take a snapshot** called `clean`. When a tool makes a mess, or you just want to start fresh, you revert.

If you installed the bare system and want to add toolsets, the metapackages make it one command each:

```bash
sudo apt install -y kali-linux-default        # the standard toolkit
sudo apt install -y kali-tools-web            # just the web-app tools
sudo apt install -y kali-tools-wireless       # just the wireless tools
```

## Step 2 — Build a target to practise on

This is the step that separates learning from trouble. You need something to point the tools at, and it must be **yours**, **isolated**, and **meant to be broken**. The standard practice setup:

- A second VM running a deliberately vulnerable system. **Metasploitable 2/3**, **OWASP Juice Shop**, or **DVWA** (Damn Vulnerable Web Application) are purpose-built for this.
- Both VMs on a **host-only network** with no route to the internet or your home LAN. The malware-lab isolation diagram from my [FLARE-VM post](/FLARE-VM-Malware-Analysis-Lab/) applies here too: nothing you do should be able to reach anything real.

<div style="margin:2rem 0;padding:1.25rem;background:var(--bg-elevated);border:1px solid var(--border);border-radius:var(--radius-m);">
<svg viewBox="0 0 640 210" style="width:100%;height:auto;font-family:inherit;" role="img" aria-label="Practice lab: a Kali VM and a deliberately vulnerable target VM such as Metasploitable, DVWA or Juice Shop, both on an isolated host-only network with no route to the internet or the home LAN; the host snapshots both VMs">
  <defs><marker id="kl-a" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto"><path d="M0,0 L8,4 L0,8 z" fill="var(--text-muted)"/></marker></defs>
  <g style="font-size:12px;">
    <rect x="40" y="30" width="220" height="110" rx="12" fill="var(--bg-elevated-2)" stroke="var(--accent)" stroke-width="2"/>
    <text x="150" y="58" text-anchor="middle" font-weight="700" font-size="14" fill="var(--accent)">Kali VM</text>
    <text x="150" y="82" text-anchor="middle" fill="var(--text-muted)">your testing box</text>
    <text x="150" y="104" text-anchor="middle" fill="var(--text-muted)">192.168.56.10</text>
    <rect x="380" y="30" width="220" height="110" rx="12" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="490" y="58" text-anchor="middle" font-weight="700" font-size="14" fill="var(--text)">Target VM</text>
    <text x="490" y="82" text-anchor="middle" fill="var(--text-muted)">Metasploitable / DVWA</text>
    <text x="490" y="104" text-anchor="middle" fill="var(--text-muted)">192.168.56.20</text>
    <line x1="260" y1="85" x2="378" y2="85" stroke="var(--text-muted)" stroke-width="2" marker-end="url(#kl-a)"/>
    <text x="320" y="78" text-anchor="middle" fill="var(--text-muted)">host-only</text>
    <rect x="40" y="160" width="560" height="40" rx="10" fill="none" stroke="var(--accent-strong)" stroke-dasharray="5 5"/>
    <text x="320" y="185" text-anchor="middle" font-weight="700" fill="var(--accent-strong)">🚫 isolated — no bridge to the internet or your real network</text>
  </g>
</svg>
</div>

Everything from here points at `192.168.56.20` — a machine that exists only to be tested, by you, on a network only you can reach.

## The methodology matters more than the tools

Newcomers collect tools; professionals follow a method. A real authorised engagement moves through phases, and Kali's tools are organised to match them. Knowing the phase you're in tells you which tool to pick and, more importantly, keeps you from wandering outside your agreed scope.

<div style="margin:2rem 0;padding:1.25rem;background:var(--bg-elevated);border:1px solid var(--border);border-radius:var(--radius-m);">
<svg viewBox="0 0 640 250" style="width:100%;height:auto;font-family:inherit;" role="img" aria-label="Penetration test phases mapped to Kali tools: scope and rules of engagement first, then reconnaissance, scanning and enumeration, vulnerability analysis, exploitation against authorized targets, post-exploitation, and reporting; reporting is highlighted as the deliverable that matters most">
  <defs><marker id="km-a" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto"><path d="M0,0 L8,4 L0,8 z" fill="var(--accent)"/></marker></defs>
  <g style="font-size:11.5px;">
    <rect x="5" y="20" width="120" height="80" rx="10" fill="var(--accent-strong)" fill-opacity="0.9"/>
    <text x="65" y="46" text-anchor="middle" font-weight="700" fill="var(--accent-contrast)">0 · Scope</text>
    <text x="65" y="68" text-anchor="middle" font-size="10" fill="var(--accent-contrast)">written authorization,</text>
    <text x="65" y="84" text-anchor="middle" font-size="10" fill="var(--accent-contrast)">rules of engagement</text>
    <rect x="135" y="20" width="120" height="80" rx="10" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="195" y="46" text-anchor="middle" font-weight="700" fill="var(--text)">1 · Recon</text>
    <text x="195" y="68" text-anchor="middle" font-size="10" fill="var(--text-muted)">whois, dnsenum,</text>
    <text x="195" y="84" text-anchor="middle" font-size="10" fill="var(--text-muted)">theHarvester</text>
    <rect x="265" y="20" width="120" height="80" rx="10" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="325" y="46" text-anchor="middle" font-weight="700" fill="var(--text)">2 · Scan</text>
    <text x="325" y="68" text-anchor="middle" font-size="10" fill="var(--text-muted)">nmap,</text>
    <text x="325" y="84" text-anchor="middle" font-size="10" fill="var(--text-muted)">enum4linux</text>
    <rect x="395" y="20" width="120" height="80" rx="10" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="455" y="46" text-anchor="middle" font-weight="700" fill="var(--text)">3 · Vuln</text>
    <text x="455" y="68" text-anchor="middle" font-size="10" fill="var(--text-muted)">nikto, nmap NSE,</text>
    <text x="455" y="84" text-anchor="middle" font-size="10" fill="var(--text-muted)">searchsploit</text>
    <rect x="525" y="20" width="110" height="80" rx="10" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="580" y="46" text-anchor="middle" font-weight="700" fill="var(--text)">4 · Exploit</text>
    <text x="580" y="68" text-anchor="middle" font-size="10" fill="var(--text-muted)">Metasploit</text>
    <text x="580" y="84" text-anchor="middle" font-size="10" fill="var(--text-muted)">(authorized only)</text>
    <line x1="125" y1="60" x2="133" y2="60" stroke="var(--accent)" stroke-width="2" marker-end="url(#km-a)"/>
    <line x1="255" y1="60" x2="263" y2="60" stroke="var(--accent)" stroke-width="2" marker-end="url(#km-a)"/>
    <line x1="385" y1="60" x2="393" y2="60" stroke="var(--accent)" stroke-width="2" marker-end="url(#km-a)"/>
    <line x1="515" y1="60" x2="523" y2="60" stroke="var(--accent)" stroke-width="2" marker-end="url(#km-a)"/>
    <rect x="135" y="125" width="250" height="70" rx="10" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="260" y="150" text-anchor="middle" font-weight="700" fill="var(--text)">5 · Post-exploitation</text>
    <text x="260" y="172" text-anchor="middle" font-size="10" fill="var(--text-muted)">document access, pivot (in scope),</text>
    <text x="260" y="186" text-anchor="middle" font-size="10" fill="var(--text-muted)">then clean up</text>
    <rect x="405" y="125" width="230" height="70" rx="10" fill="var(--accent)" fill-opacity="0.9"/>
    <text x="520" y="150" text-anchor="middle" font-weight="700" fill="var(--accent-contrast)">6 · Report</text>
    <text x="520" y="172" text-anchor="middle" font-size="10" fill="var(--accent-contrast)">the actual deliverable —</text>
    <text x="520" y="186" text-anchor="middle" font-size="10" fill="var(--accent-contrast)">findings, risk, fixes</text>
    <line x1="455" y1="100" x2="300" y2="123" stroke="var(--accent)" stroke-width="2" marker-end="url(#km-a)"/>
    <line x1="385" y1="160" x2="403" y2="160" stroke="var(--accent)" stroke-width="2" marker-end="url(#km-a)"/>
  </g>
</svg>
</div>

Notice phase 0 and phase 6: the work starts with **permission** and ends with a **report**. The exciting middle is only useful if those two bookend it. A finding nobody can act on, or a test nobody authorised, is worthless at best.

## Phase 1–2: reconnaissance and scanning

The first real tool everyone learns is **nmap** — it maps what's alive and what's listening. Against your lab target:

```bash
# Discover hosts on the isolated lab network
nmap -sn 192.168.56.0/24

# Full TCP port + service/version scan of your target, with default scripts
nmap -sV -sC -p- 192.168.56.20 -oA scans/target_full
```

That `-oA` saves the results in three formats at once — get in the habit, because your notes become your report. The `-sC` runs nmap's safe default scripts; the wider **NSE** script engine can check for specific issues:

```bash
# Example: run the "vuln" category scripts against the lab target
nmap --script vuln 192.168.56.20
```

For network services, enumeration tools dig into what nmap found — `enum4linux-ng` for SMB/Windows shares, `smbclient` to list shares, `dnsenum` for DNS. The goal of this phase is a complete inventory: every open port, every service, every version.

## Phase 3: finding the weaknesses

Now you match what you found against known issues. For web apps, **nikto** is the quick first pass:

```bash
nikto -h http://192.168.56.20            # your lab web server
```

**searchsploit** (the offline Exploit-DB mirror built into Kali) turns a version number into a list of known public exploits — invaluable for understanding *why* an old service is dangerous:

```bash
searchsploit vsftpd 2.3.4                 # look up known issues for a service/version
```

This phase is about turning "here's what's running" into "here's what's weak, and how serious it is". That severity judgement is what a client actually pays for.

## Phase 4–5: exploitation and after — in your lab, within scope

This is where Kali's reputation comes from, and where discipline matters most. The flagship is the **Metasploit Framework**, a structured platform for testing exploits against systems you're authorised to test:

```bash
msfconsole                                # launch the framework
# inside msfconsole, against YOUR lab target only:
#   search <service name>                 -> find a matching module
#   use <module path>                     -> select it
#   set RHOSTS 192.168.56.20              -> point it at the lab machine
#   show options                          -> see what it needs
#   check                                 -> safely verify if the target looks vulnerable
#   run                                   -> execute (lab targets only)
```

I'm deliberately keeping this at the framework level rather than writing a break-in recipe, because the *point* isn't a magic sequence of commands — it's understanding what each module does, confirming it against a machine you own, and being able to explain the risk to whoever has to fix it. Metasploitable and the vulnerable web apps have guided walkthroughs for exactly this learning, which is the right place to practise the full chain.

Post-exploitation, on an authorised engagement, means **documenting** the access you proved and then **cleaning up** anything you changed — not rummaging further than your scope allows. The write-up is the product; the shell is just evidence for it.

## Web and wireless, briefly

Two toolsets you'll meet early:

- **Burp Suite** (Community edition ships with Kali) is the standard web-app testing proxy. It sits between your browser and the app, letting you inspect and modify requests. Point your browser's proxy at Burp, add the CA certificate, and browse your lab's DVWA to watch every request — the best way to *understand* web traffic, not just attack it. **sqlmap** automates detecting and demonstrating SQL injection against your lab app.
- **Wireless tools** (the `aircrack-ng` suite and friends) test Wi-Fi security — but only against your *own* access point. Testing a network you don't own is exactly the line this whole post is about. This needs a wireless adapter that supports monitor mode, which is why many people keep a dedicated USB adapter for lab work.

## Phase 6: the report (where the value is)

Every tool above produces output; none of it helps anyone until it's a report. The habit that makes you useful: as you work, keep structured notes — which target, which finding, the evidence, the severity, and the fix. Kali even ships note-taking and reporting tools (CherryTree, Faraday) for this. A good finding reads like the outcome-first style from my [DFIR paralysis post](/DFIR-Paralysis-Field-Kit/):

```text
FINDING   : <what's wrong, one sentence>
AFFECTED  : <host/app, in scope>
EVIDENCE  : <the command output / screenshot that proves it>
RISK      : <what an attacker could do, and how likely>
FIX       : <the specific remediation>
```

A clean report that a defender can act on is worth more than the flashiest exploit. The whole point of offensive testing is to make the defence better.

## Learn it the legal way

The fastest, safest way to get good at Kali is to practise against things built to be practised on. Beyond your own lab VMs, there are legal, intentional playgrounds: **Hack The Box**, **TryHackMe**, **VulnHub**, and **PortSwigger's Web Security Academy** (free, and excellent for the web side). These give you real targets with none of the legal risk, and most come with guided paths that teach the method, not just the keystrokes.

Kali is maintained in the open by OffSec. Start from the <a href="https://www.kali.org/docs/" target="_blank" rel="noopener">official Kali documentation</a> and the <a href="https://www.kali.org/tools/" target="_blank" rel="noopener">tools listing</a>, which documents every included tool with usage examples. Install it, build a lab, pick a vulnerable target, and work the phases end to end — permission first, report last. Do that a dozen times and the toolbox turns into a craft.
