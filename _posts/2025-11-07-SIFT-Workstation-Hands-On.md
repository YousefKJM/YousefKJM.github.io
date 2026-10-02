---
title: "SIFT Workstation: Your Free Forensics Lab, From Boot to First Timeline"
excerpt: "A disk image, a memory dump, and a free Ubuntu VM with 300+ forensic tools already wired up. This is the hands-on SIFT guide I wish I'd had on day one — install it, mount evidence safely, and run every core tool with real commands."
header:
  image: /images/posts/sift/hero.jpg
tags: [DFIR, forensics, SIFT, timeline, memory, tools]
---
![SIFT Workstation: the free forensics lab, from boot to first timeline](/images/posts/sift/hero.jpg)

There's a moment early in every forensics career where you have a disk image, a vague question, and absolutely no idea which of the fifty tools you half-remember is the right one. The SANS **SIFT Workstation** exists for exactly that moment. It's a free Ubuntu virtual machine with more than 300 forensic and incident-response tools already installed, configured and talking to each other, built and maintained by Rob Lee and the SANS DFIR team.

You could assemble all of this yourself. I've tried. You spend a weekend fighting Python versions and `libewf` builds instead of looking at evidence. SIFT hands you the assembled lab so you can skip straight to the part that matters. This post walks the whole thing: getting it running, the one habit that keeps your evidence admissible, and then a proper hands-on tour of each core tool with commands you can paste.

> **Before anything else:** only examine systems and images you're authorised to touch. Everything below assumes a legitimate investigation, a CTF, or your own lab machines.

## What you actually get

SIFT is built on **Ubuntu 20.04 LTS** (the OVA appliance) and installs its toolset through SaltStack, so the same package set can be laid down on a plain Ubuntu box or inside WSL. Under the hood it's organised into the forensic workflow itself:

<div style="margin:2rem 0;padding:1.25rem;background:var(--bg-elevated);border:1px solid var(--border);border-radius:var(--radius-m);">
<svg viewBox="0 0 640 300" style="width:100%;height:auto;font-family:inherit;" role="img" aria-label="SIFT maps to the DFIR workflow in six stages: acquire with ewfacquire and dcfldd, mount read-only with ewfmount and dislocker, examine the file system with Sleuth Kit and carve with foremost and bulk_extractor, build a super timeline with Plaso and the Zimmerman tools, analyse memory with Volatility 3, and parse artifacts with RegRipper and dedicated parsers, then report">
  <defs><marker id="sf-a" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto"><path d="M0,0 L8,4 L0,8 z" fill="var(--accent)"/></marker></defs>
  <g style="font-size:12px;">
    <rect x="5" y="20" width="96" height="120" rx="10" fill="var(--bg-elevated-2)" stroke="var(--accent)"/>
    <text x="53" y="42" text-anchor="middle" font-weight="700" fill="var(--accent)">1 Acquire</text>
    <text x="53" y="66" text-anchor="middle" fill="var(--text-muted)">ewfacquire</text>
    <text x="53" y="84" text-anchor="middle" fill="var(--text-muted)">dcfldd</text>
    <text x="53" y="102" text-anchor="middle" fill="var(--text-muted)">dc3dd</text>
    <text x="53" y="124" text-anchor="middle" fill="var(--text-muted)">guymager</text>
    <rect x="111" y="20" width="96" height="120" rx="10" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="159" y="42" text-anchor="middle" font-weight="700" fill="var(--text)">2 Mount</text>
    <text x="159" y="66" text-anchor="middle" fill="var(--text-muted)">ewfmount</text>
    <text x="159" y="84" text-anchor="middle" fill="var(--text-muted)">dislocker</text>
    <text x="159" y="102" text-anchor="middle" fill="var(--text-muted)">vshadowmount</text>
    <text x="159" y="124" text-anchor="middle" fill="var(--text-muted)">mmls</text>
    <rect x="217" y="20" width="96" height="120" rx="10" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="265" y="42" text-anchor="middle" font-weight="700" fill="var(--text)">3 Carve / FS</text>
    <text x="265" y="66" text-anchor="middle" fill="var(--text-muted)">Sleuth Kit</text>
    <text x="265" y="84" text-anchor="middle" fill="var(--text-muted)">foremost</text>
    <text x="265" y="102" text-anchor="middle" fill="var(--text-muted)">bulk_extractor</text>
    <text x="265" y="124" text-anchor="middle" fill="var(--text-muted)">scalpel</text>
    <rect x="323" y="20" width="96" height="120" rx="10" fill="var(--bg-elevated-2)" stroke="var(--accent)"/>
    <text x="371" y="42" text-anchor="middle" font-weight="700" fill="var(--accent)">4 Timeline</text>
    <text x="371" y="66" text-anchor="middle" fill="var(--text-muted)">Plaso</text>
    <text x="371" y="84" text-anchor="middle" fill="var(--text-muted)">MFTECmd</text>
    <text x="371" y="102" text-anchor="middle" fill="var(--text-muted)">EvtxECmd</text>
    <text x="371" y="124" text-anchor="middle" fill="var(--text-muted)">mactime</text>
    <rect x="429" y="20" width="96" height="120" rx="10" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="477" y="42" text-anchor="middle" font-weight="700" fill="var(--text)">5 Memory</text>
    <text x="477" y="66" text-anchor="middle" fill="var(--text-muted)">Volatility 3</text>
    <text x="477" y="84" text-anchor="middle" fill="var(--text-muted)">bulk_extractor</text>
    <text x="477" y="102" text-anchor="middle" fill="var(--text-muted)">strings</text>
    <text x="477" y="124" text-anchor="middle" fill="var(--text-muted)">yara</text>
    <rect x="535" y="20" width="100" height="120" rx="10" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="585" y="42" text-anchor="middle" font-weight="700" fill="var(--text)">6 Artifacts</text>
    <text x="585" y="66" text-anchor="middle" fill="var(--text-muted)">RegRipper</text>
    <text x="585" y="84" text-anchor="middle" fill="var(--text-muted)">hindsight</text>
    <text x="585" y="102" text-anchor="middle" fill="var(--text-muted)">prefetch</text>
    <text x="585" y="124" text-anchor="middle" fill="var(--text-muted)">analyzeMFT</text>
    <line x1="101" y1="80" x2="109" y2="80" stroke="var(--accent)" stroke-width="2" marker-end="url(#sf-a)"/>
    <line x1="207" y1="80" x2="215" y2="80" stroke="var(--accent)" stroke-width="2" marker-end="url(#sf-a)"/>
    <line x1="313" y1="80" x2="321" y2="80" stroke="var(--accent)" stroke-width="2" marker-end="url(#sf-a)"/>
    <line x1="419" y1="80" x2="427" y2="80" stroke="var(--accent)" stroke-width="2" marker-end="url(#sf-a)"/>
    <line x1="525" y1="80" x2="533" y2="80" stroke="var(--accent)" stroke-width="2" marker-end="url(#sf-a)"/>
    <rect x="5" y="160" width="630" height="120" rx="10" fill="none" stroke="var(--text-muted)" stroke-dasharray="5 5"/>
    <text x="20" y="184" font-weight="700" fill="var(--text)">Always running underneath</text>
    <text x="20" y="208" fill="var(--text-muted)">Hashing: sha256sum, hashdeep, ssdeep (fuzzy)  ·  Known-bad: ClamAV, YARA</text>
    <text x="20" y="230" fill="var(--text-muted)">Metadata: exiftool  ·  Documents: pdf-parser, pdfid, oleid  ·  Strings: bulk_extractor, strings, floss</text>
    <text x="20" y="252" fill="var(--text-muted)">Filesystems supported: NTFS, ext2/3/4, HFS+, FAT, exFAT  ·  Formats: E01/EWF, AFF, raw dd, VMDK, VHD</text>
    <text x="20" y="272" fill="var(--text-muted)">Everything is read-only by default — the whole point of a forensic workstation</text>
  </g>
</svg>
</div>

## Getting it running (three ways)

Pick the one that fits how you work.

**Option A — the OVA appliance (easiest).** Download the SIFT OVA (about 8.8 GB) from your free SANS account, then in VMware or VirtualBox use *File → Import Appliance*. Give it at least 4 GB RAM (8+ if you'll do memory forensics) and 2 CPUs. Boot it, and you're done.

**Option B — on top of your own Ubuntu.** If you already run Ubuntu (22.04 or 24.04), install the toolset directly with Cast, the Go-based successor to the old `sift-cli`:

```bash
# Install the cast binary, then lay down the full SIFT toolset
curl -sL https://github.com/ekristen/cast/releases/latest/download/cast-linux-amd64 -o /tmp/cast
sudo install /tmp/cast /usr/local/bin/cast
sudo cast install teamdfir/sift
```

**Option C — inside Windows via WSL.** Handy when your host must stay Windows. Install an Ubuntu WSL distro, then run the server-mode (no desktop) install:

```bash
sudo cast install --mode=server teamdfir/sift-saltstack
```

Whichever route you take, the login on the appliance is **`sansforensics`** / **`forensics`**, and you elevate with `sudo -i`. First thing after boot:

```bash
sudo apt update && sudo apt upgrade -y    # patch the base OS
sudo cast update teamdfir/sift            # refresh the toolset
```

> **One habit that saves cases:** a forensic workstation treats evidence as read-only, but you still have to mean it. Work from a *copy* of the image, verify its hash before and after, and mount everything `ro`. A case that can't prove the evidence was unchanged is a case you can lose.

## The read-only mount: where every examination starts

Before any tool can look inside an image, you have to expose it without altering it. This trips up more beginners than anything else, so here's the full pattern.

An **E01 (EnCase/EWF)** image is a container, not a raw disk, so first turn it into something the kernel can mount:

```bash
mkdir -p /mnt/ewf /mnt/windows
ewfmount evidence.E01 /mnt/ewf        # creates /mnt/ewf/ewf1 (a raw view)
mmls /mnt/ewf/ewf1                     # show the partition table
```

`mmls` prints each partition with its **start sector**. Multiply that by the sector size (almost always 512) to get the byte offset, and mount that partition read-only:

```bash
# If the Windows partition starts at sector 2048:
mount -o ro,loop,offset=$((2048*512)),show_sys_files,streams_interface=windows \
      /mnt/ewf/ewf1 /mnt/windows
ls /mnt/windows                        # you're now inside the evidence, safely
```

A plain **raw/dd** image skips the `ewfmount` step — mount it directly with the same `offset` trick. Two situations you'll hit often:

```bash
# BitLocker-encrypted volume (you need the recovery key or password)
dislocker -r -V /mnt/ewf/ewf1 -p<recovery-key> -- /mnt/bde
mount -o ro,loop /mnt/bde/dislocker-file /mnt/windows

# Volume Shadow Copies — historical states of the disk, a goldmine
vshadowmount /mnt/ewf/ewf1 /mnt/vss
mount -o ro,loop,show_sys_files /mnt/vss/vss1 /mnt/vss_mount
```

That `show_sys_files` flag is what exposes `$MFT`, `$LogFile` and the registry hives you'll want in a minute.

## Acquiring an image yourself

If you're the one pulling the image off a disk, SIFT gives you several acquisition tools. `ewfacquire` is the friendly, guided one; it writes an E01 with hashes baked in:

```bash
sudo ewfacquire /dev/sdb               # interactive: case info, compression, hashing
```

For a raw image with a verifiable hash log, `dcfldd` (a forensic `dd`) is the classic:

```bash
sudo dcfldd if=/dev/sdb of=/cases/disk.dd hash=sha256 hashlog=/cases/disk.hashes bs=4M
sha256sum /cases/disk.dd               # compare against disk.hashes
```

> **Use a write blocker:** software read-only flags protect the *image*. When you touch original hardware, use a hardware write blocker so the source disk is never modified. SIFT handles the image; the write blocker handles the physics.

## Walking the file system with The Sleuth Kit

The Sleuth Kit (TSK) is the engine under a lot of GUI forensics tools, and on SIFT you get it raw and scriptable. The workflow is: list files, find the one you want by its inode, extract it.

```bash
# List every file (including deleted) as a bodyfile, from the partition at sector 2048
fls -r -m / -o 2048 /cases/disk.dd > /cases/bodyfile

# Deleted entries are marked with * — grep for something interesting
grep -i "invoice" /cases/bodyfile

# Pull a specific file out by inode number (shown in fls output)
icat -o 2048 /cases/disk.dd 128-128-1 > /cases/recovered_invoice.xlsx

# Details about one inode: timestamps, allocation status, data runs
istat -o 2048 /cases/disk.dd 128-128-1
```

That `bodyfile` isn't just for browsing — it becomes a timeline in the next step.

## Carving: recovering files with no file system

When the file system is gone — formatted drive, corrupted partition, unallocated space — you carve by file signatures instead. `foremost` and `scalpel` rebuild files from their headers and footers:

```bash
foremost -t jpg,pdf,doc,zip -i /cases/disk.dd -o /cases/carved/
cat /cases/carved/audit.txt            # what was recovered and from where
```

`bulk_extractor` is the one I run on almost every case. It scans the whole image (allocated *and* unallocated, compressed included) and pulls out emails, URLs, credit-card numbers, search terms and more into tidy feature files:

```bash
bulk_extractor -o /cases/bulk/ /cases/disk.dd
head /cases/bulk/email.txt /cases/bulk/url.txt
```

## The super timeline: SIFT's superpower

If you learn one thing from SIFT, make it this. A **super timeline** fuses file system timestamps, event logs, registry keys, browser history and dozens of other artifacts into one chronological CSV. Suddenly "what happened on the 7th of August" has a literal answer. The tool is **Plaso** (the `log2timeline` project).

```bash
# 1. Collect every timestamped artifact into a Plaso storage file
log2timeline.py --storage-file /cases/case.plaso /mnt/windows

# 2. Sort and filter into a readable CSV (here: only August 2025 onward)
psort.py -o l2tcsv -w /cases/timeline.csv /cases/case.plaso "date > '2025-08-01 00:00:00'"
```

On a big disk, step 1 can run for hours — that's normal, it's reading everything. When you need a fast answer, `psteal.py` does collect-and-sort in one shot:

```bash
psteal.py --source /mnt/windows -o l2tcsv -w /cases/quick_timeline.csv
```

For a classic file-system-only timeline from the TSK bodyfile you made earlier, `mactime` is instant:

```bash
mactime -b /cases/bodyfile -d -z UTC 2025-08-01..2025-08-31 > /cases/fs_timeline.csv
```

> **Timeline sanity:** always pin a time zone (`-z UTC`) and keep it consistent across every tool, or your timeline will quietly drift by hours and your story will fall apart under questioning.

## Windows artifacts with the Eric Zimmerman tools

SIFT ships Eric Zimmerman's industry-standard parsers, wrapped so they run from `/usr/local/bin` like native commands (they call .NET underneath). Each one turns a cryptic Windows artifact into clean CSV. The headliners:

```bash
# $MFT — the master file table: every file, four timestamps each, even deleted
MFTECmd -f /mnt/windows/\$MFT --csv /cases/out --csvf mft.csv

# Event logs — parse the whole Logs folder at once
EvtxECmd -d /mnt/windows/Windows/System32/winevt/Logs --csv /cases/out --csvf evtx.csv

# Prefetch — proof a program executed, with run counts and times
PECmd -d /mnt/windows/Windows/Prefetch --csv /cases/out

# Jump Lists & LNK — what files a user opened, and from where (incl. USB/network)
JLECmd -d "/mnt/windows/Users/jsmith/AppData/Roaming/Microsoft/Windows/Recent" --csv /cases/out
LECmd  -d "/mnt/windows/Users/jsmith/AppData/Roaming/Microsoft/Windows/Recent" --csv /cases/out

# Recycle Bin, Amcache (evidence of execution), registry (batch mode)
RBCmd -d /mnt/windows/\$Recycle.Bin --csv /cases/out
AmcacheParser -f /mnt/windows/Windows/AppCompat/Programs/Amcache.hve --csv /cases/out
RECmd --bn BatchExamples/RECmd_Batch_MC.reb -d /mnt/windows/Windows/System32/config --csv /cases/out
```

## Registry analysis with RegRipper

For fast, targeted registry answers, `RegRipper` runs profiles of plugins against a hive and gives you readable output — USB history, autoruns, user accounts, typed URLs, and so on:

```bash
# Point rip.pl at a hive with a matching profile
rip.pl -r /mnt/windows/Windows/System32/config/SYSTEM -f system > /cases/system.txt
rip.pl -r /mnt/windows/Windows/System32/config/SOFTWARE -f software > /cases/software.txt
rip.pl -r "/mnt/windows/Users/jsmith/NTUSER.DAT" -f ntuser > /cases/jsmith_ntuser.txt

# Or run a single plugin, e.g. USB device history
rip.pl -r /mnt/windows/Windows/System32/config/SYSTEM -p usbstor
```

## Memory forensics with Volatility 3

Memory tells you what a disk can't: running processes, network connections, injected code, decrypted data. SIFT installs **Volatility 3** as the `vol` command. The modern version auto-detects the OS, so there's no profile guessing anymore.

```bash
vol -f /cases/mem.raw windows.info        # confirm it's a valid Windows image
vol -f /cases/mem.raw windows.pslist      # processes (from the active list)
vol -f /cases/mem.raw windows.pstree      # parent/child — spot the odd child of winword
vol -f /cases/mem.raw windows.psscan      # scan for processes, incl. hidden/terminated
vol -f /cases/mem.raw windows.netscan     # network connections and listeners
vol -f /cases/mem.raw windows.cmdline     # the command line each process launched with
vol -f /cases/mem.raw windows.malfind     # regions that look like injected code
vol -f /cases/mem.raw windows.dlllist --pid 2104
vol -f /cases/mem.raw windows.dumpfiles --pid 2104 -o /cases/dumped/
```

A reliable triage order I use on an unknown dump: `windows.info` → `pstree` → `netscan` → `malfind` → `cmdline`. Within five commands you usually have a lead.

> **The artifact isn't the answer:** `malfind` flags *suspicious* memory, not *malicious* memory — legitimate packers and JIT compilers trip it too. Every finding here is a lead to confirm with a second artifact, exactly like the context ladder from my [DFIR paralysis post](/DFIR-Paralysis-Field-Kit/).

## Documents, metadata and known-bad

The smaller tools earn their place on phishing and malware cases:

```bash
clamscan -r -i /mnt/windows                 # flag known malware (‑i = only infected)
exiftool /cases/suspicious.docx             # author, creation tool, timestamps
pdfid.py /cases/suspicious.pdf              # does the PDF have JS, OpenActions, launch?
pdf-parser.py --search JavaScript /cases/suspicious.pdf
yara -r /cases/rules/apt.yar /mnt/windows   # hunt with your own signatures
```

## A phase-to-tool cheat sheet

Keep this next to you until the muscle memory sets in:

| Goal | Tool | One-liner to start |
|---|---|---|
| Mount an E01 read-only | ewfmount + mount | `ewfmount x.E01 /mnt/ewf` |
| List the partitions | mmls | `mmls /mnt/ewf/ewf1` |
| Image a disk | ewfacquire / dcfldd | `ewfacquire /dev/sdb` |
| List/extract files | Sleuth Kit | `fls -r -o 2048 disk.dd` |
| Carve deleted files | foremost | `foremost -t all -i disk.dd -o out/` |
| Pull PII/strings | bulk_extractor | `bulk_extractor -o bulk/ disk.dd` |
| Super timeline | Plaso | `log2timeline.py --storage-file c.plaso /mnt/windows` |
| Parse $MFT | MFTECmd | `MFTECmd -f /mnt/windows/\$MFT --csv out` |
| Parse event logs | EvtxECmd | `EvtxECmd -d .../winevt/Logs --csv out` |
| Registry answers | RegRipper | `rip.pl -r SYSTEM -f system` |
| Memory analysis | Volatility 3 | `vol -f mem.raw windows.pstree` |
| Browser history | hindsight | `hindsight -i <Chrome profile> -o history` |
| Hash / fuzzy hash | sha256sum / ssdeep | `ssdeep -r /mnt/windows` |

I've put all of these, with the mounting and timeline recipes, into a one-page cheat sheet:

<a href="/assets/files/sift/sift-cheatsheet.md" target="_blank" rel="noopener">⬇ Download the SIFT cheat sheet (Markdown)</a>

## Where to go next

SIFT isn't just a toolbox — it's the teaching platform behind the SANS FOR500 and FOR508 courses, which means almost every DFIR tutorial, challenge and blog post out there assumes you can follow along on it. Grab a practice image (the many public CTF and DFIR challenge images are perfect), mount it with the recipe above, build a timeline, and go looking for the story. The tools stop being a list and start being reflexes surprisingly fast.

Everything here lives in the official project. Start at the <a href="https://www.sans.org/tools/sift-workstation" target="_blank" rel="noopener">SIFT Workstation page</a>, and the build itself is open source in the <a href="https://github.com/teamdfir/sift-saltstack" target="_blank" rel="noopener">teamdfir/sift-saltstack</a> repository — reading the Salt states is genuinely the best way to learn exactly where each tool is installed and how it's wired up.
