---
title: "The Windows DFIR Field Reference: Timestamps, Execution Evidence, and Lateral Movement"
excerpt: "A working cheat sheet for Windows incident response — how $STANDARD_INFORMATION and $FILENAME timestamps actually behave, where to find proof of execution, what a clean process tree looks like, and how the common lateral movement techniques show up on both ends of the wire. Built from the SANS FOR500/FOR508 posters, corrected and extended with what's changed through 2026."
---

I keep coming back to two posters on my wall: SANS FOR500's timestamp/artifact poster and FOR508's "Hunt Evil" poster. Between them they cover most of what you need in the first two hours of a Windows intrusion case — but they're a few years old in places, and a poster can't hold a "here's the gotcha" the way a page can. This is that page: the same core reference, corrected where Windows has moved on, with the 2025–2026 artifacts (Recall, PCA, the ShimCache research) that didn't exist when those posters were printed.

Treat this as a lookup table, not a tutorial. Ctrl+F it during a case.

## 1. Timestamps: $STANDARD_INFORMATION vs. $FILENAME

Every NTFS file has two independent sets of MACB timestamps: one in `$STANDARD_INFORMATION` (what `dir`, PowerShell, and most tools show you) and one in `$FILENAME` (harder to see, harder to fake). They behave differently depending on the operation, and that difference is one of the highest-value things you can pull out of an MFT.

| Operation | $STANDARD_INFORMATION | $FILENAME |
|---|---|---|
| **Creation** | M/A/C/B all = creation time | M/A/C/B all = creation time |
| **Access** (read/open) | Access = access time; rest unchanged | No change (FN never tracks access) |
| **Modification** (content write) | Modified & Metadata = write time; Access/Creation unchanged | No change |
| **Rename** | Metadata = rename time; rest unchanged | Metadata = rename time; rest unchanged |
| **Copy** (new file object) | Modified inherited from source; Access/Metadata/Creation = copy time | **All four reset to copy time** |
| **Local move** (same volume, Explorer or CLI) | **No change at all** | No change at all |
| **Cross-volume move via CLI** (`move`) | Modified & Metadata inherited; Access/Creation = move time | All four = move time |
| **Cross-volume move via Explorer** (cut/paste) | Modified & Metadata inherited; Access = cut/paste time; Creation inherited | All four = cut/paste time |
| **Deletion** | No change (until MFT record is reused) | No change |

Two things worth remembering on every case:

- **A same-volume move is invisible in timestamps.** If a file was dragged from `C:\Users\bob\Downloads` to `C:\ProgramData\` on the same volume, nothing in `$SI` or `$FN` records that it moved. Don't over-interpret a "clean" timestamp set as proof a file has always lived where you found it.
- **Timestomping tells on itself in $FN.** Tools like `SetFileTime` / `timestomp` rewrite `$SI` — the field every GUI shows — but leave `$FN` alone, because `$FN` lives in the index and requires a rename-class operation to touch. If `$SI` creation is *earlier* than `$FN` creation, or `$SI` has second-level precision while everything else on the volume has the usual sub-millisecond NTFS jitter, that's a manipulated timestamp, not a real one. Parse both with `MFTECmd` or `analyzeMFT` — never trust `$SI` alone on a file that matters.

## 2. Evidence of program execution

No single artifact proves execution on its own — they answer slightly different questions, and several of them prove *presence* rather than *execution*. Use two or more together.

| Artifact | Location | What it actually tells you | Caveat |
|---|---|---|---|
| **Prefetch** | `C:\Windows\Prefetch\*.pf` | Last 8 run times (Win8+; 1 on XP/7), run count, files/devices referenced | Disabled by default on server SKUs; capped at 1024 files (128 on XP/7) — will roll over |
| **Amcache.hve** | `C:\Windows\AppCompat\Programs\Amcache.hve` | Full path, file size, compile time, **SHA1 of the binary**, first-seen time | Proves *presence*, not execution — some entries come from install/inventory scans, not runs |
| **ShimCache / AppCompatCache** | `SYSTEM\CurrentControlSet\Control\Session Manager\AppCompatCache` | Path + last-modified time of the binary at time of caching | Order-dependent, wiped on reboot before Win10, and historically didn't prove execution either — see the 2026 note below |
| **UserAssist** | `NTUSER.DAT\...\Explorer\UserAssist\{GUID}\Count` | GUI execution count, last-run time, focus time — ROT13 encoded | GUI launches only; nothing from a shell or scheduled task |
| **BAM / DAM** | `SYSTEM\CurrentControlSet\Services\bam\UserSettings\{SID}` | Full path + **last** execution time per user, Win10+ | Usually only ~1 week of retention |
| **SRUM** | `C:\Windows\System32\SRU\SRUDB.dat` | 30–60 days of app execution, per-user, plus network bytes sent/received per app per hour | ESE database — needs `srum_dump` or Eric Zimmerman's `SrumECmd`, not a registry viewer |
| **Jump Lists** | `%USERPROFILE%\AppData\Roaming\Microsoft\Windows\Recent\AutomaticDestinations` | First/last time an object was opened *by* an application | Doesn't confirm the app itself executed vs. was already running |
| **RecentApps** | `NTUSER.DAT\...\Search\RecentApps` | Last access time + launch count for GUI apps, Win10+ | Same GUI-only limitation as UserAssist |

### 2026 addition: the PCA launch dictionary

Windows 11 quietly added a new execution artifact via the **Program Compatibility Assistant** — a launch dictionary that records user-driven executable launches with timestamps, independent of Prefetch/Amcache/ShimCache. It doesn't replace any of the above, but it's cheap to check, easy to explain in a report, and analysts are still missing it by habit. Worth adding to your standard collection alongside the usual execution artifacts.

### 2026 correction: ShimCache and the "presence, not execution" rule

The long-standing rule of thumb — ShimCache shows presence, not execution — has needed refinement since 2025 research (Kaspersky, and independently confirmed by other DFIR researchers) found that the **last 4 bytes of the ShimCache Data field can indicate actual execution status** on modern builds, and that Amcache's `InventoryApplicationFile` entries are written by the Microsoft Compatibility Appraiser scanning the disk — which means an Amcache entry can exist for a file that was **never run**, only scanned. If you're citing either artifact as proof of execution in a report, corroborate it with Prefetch, SRUM, or an event log rather than resting on ShimCache/Amcache alone.

### 2026 addition: Windows Recall

On Copilot+ PCs (NPU-equipped, broadly rolled out through 2025), **Windows Recall** takes periodic screenshots of the desktop and stores them locally with OCR'd text, effectively building a forensic timeline of everything the user *saw* — not just what they executed. For an investigator this is a goldmine: visual proof of what was on-screen at a given minute, searchable by text. It also means it's now a first-class target for attackers and a first-class disclosure risk for your own org — treat the Recall snapshot store as sensitive as browser history, and expect it to show up in scope discussions on any Copilot+ endpoint. Tooling is still maturing (`RecallTimeline` is the current open-source starting point), so budget extra parsing time versus a mature artifact like Prefetch.

## 3. Know normal before you hunt evil

Baseline the standard Windows process tree so anomalies actually stand out. The parent/child relationship matters more than the process name — malware loves to spawn from or masquerade as these.

| Process | Normal parent | Normal count | Account | Red flag |
|---|---|---|---|---|
| `System` | none | 1 | Local System | — |
| `smss.exe` | System | 1 master + 1 per session (children exit) | Local System | Lingering child instance |
| `wininit.exe` | orphan (smss child that exited) | 1 | Local System | Any parent other than smss/orphan |
| `csrss.exe` | orphan (smss child that exited) | 2+ | Local System | Parent set to anything else |
| `services.exe` | wininit.exe | 1 | Local System | More than one instance |
| `svchost.exe` | services.exe (mostly) | 10–50+ | System / Network Service / Local Service / logged-on user | No `-k` parameter, or parent isn't services.exe |
| `lsass.exe` | wininit.exe | 1 | Local System | Any child process (EFS is the one legitimate exception); more than one instance |
| `lsaiso.exe` | wininit.exe | 0 or 1 | Local System | Running when Credential Guard/VBS is *not* enabled |
| `winlogon.exe` | orphan (smss child that exited) | 1+ | Local System | Unexpected parent |
| `explorer.exe` | orphan (userinit.exe child that exited) | 1+ per interactive user | logged-on user | Running from anywhere other than `%SystemRoot%\explorer.exe` |
| `RuntimeBroker.exe` | svchost.exe | 1 per UWP app | logged-on user | Parent isn't svchost |
| `taskhostw.exe` | svchost.exe | 1+ | logged-on user / service accounts | Unusual command line or parent |

The two checks that catch the most malware fastest: **wrong parent** (svchost.exe not spawned by services.exe, lsass.exe with any child at all) and **wrong path** (explorer.exe or svchost.exe running from a user-writable directory instead of `%SystemRoot%`).

## 4. Lateral movement: what shows up where

Every technique below leaves evidence on the **source** (attacker's foothold) and the **destination** (where they're moving to). Check both — responders who only look at the destination miss the pivot point.

### RDP

- **Source:** `NTUSER.DAT\Software\Microsoft\Terminal Server Client\Servers` (per-user destination history); ShimCache/Amcache/BAM for `mstsc.exe`; Jump List for the RDP AppID; bitmap cache under `AppData\Local\Microsoft\Terminal Server Client\Cache`.
- **Destination:** Security log **4624** (Logon Type 10) and **4778/4779** (session connect/disconnect); `Microsoft-Windows-TerminalServices-RDPClient/Operational` **1024/1102**; `RemoteConnectionManager/Operational` **1149** (a blank username here can indicate Sticky Keys abuse); Prefetch for `rdpclip.exe`/`tstheme.exe`.

### PsExec

- **Source:** `NTUSER.DAT\Software\SysInternals\PsExec\EulaAccepted`; ShimCache/Amcache/BAM for `psexec.exe`.
- **Destination:** Security log **4624** (Type 3, or Type 2 with `-u`), **4648**, **4672**, **5140** (ADMIN$ access); System log **7045** (service install — `PSEXESVC`); the `psexesvc.exe` binary and any pushed payload landing in `ADMIN$` (`\Windows`).

```
psexec.exe \\host -accepteula -d -c c:\temp\evil.exe
```

### Scheduled tasks (`at`/`schtasks`)

- **Source:** ShimCache/Amcache/BAM for `at.exe`/`schtasks.exe`.
- **Destination:** Security log **4698/4699/4700-4702** (task created/deleted/enabled/disabled); `TaskScheduler/Operational` **106/140/141/200/201**; job/XML files in `C:\Windows\Tasks` and `C:\Windows\System32\Tasks` — check the **Author** tag in the XML for source hostname/username.

```
schtasks /CREATE /TN taskname /TR c:\temp\evil.exe /SC once /RU "SYSTEM" /ST 13:00 /S host /U username
```

### Services (`sc.exe`)

- **Source:** ShimCache/Amcache/BAM for `sc.exe`.
- **Destination:** Security log **4697** (service install, if enabled — enable it, it's cheap and gold); System log **7045**; new key under `SYSTEM\CurrentControlSet\Services\`; ShimCache for the dropped service binary.

```
sc \\host create servicename binpath= "c:\temp\evil.exe"
sc \\host start servicename
```

### WMI / WMIC

- **Source:** ShimCache/Amcache/BAM for `wmic.exe`.
- **Destination:** `WMI-Activity/Operational` **5857** (provider DLL load path — watch for a malicious provider DLL); **5860/5861** (temporary/permanent event consumer registration — common persistence mechanism, also usable for remote exec); `wmiprvse.exe` spawning the payload.

```
wmic /node:host process call create "C:\temp\evil.exe"
```

### PowerShell Remoting

- **Source:** ShimCache/Amcache/BAM for `powershell.exe`; `ConsoleHost_history.txt` under `AppData\Roaming\Microsoft\Windows\PowerShell\PSReadline` (last 4096 commands, PSv5+).
- **Destination:** `WinRM/Operational` **6/8/15/16/33/91/169**; `PowerShell/Operational` **4103/4104** (script block logging — enable this if it isn't already); `Windows PowerShell.evtx` **400/403/800**; `wsmprovhost.exe` as the remoting host process.

```
Enter-PSSession -ComputerName host
Invoke-Command -ComputerName host -ScriptBlock {Start-Process c:\temp\evil.exe}
```

### Net use / share mapping

- **Destination:** Security log **4624** (Type 3), **4672**, **5140/5145** (share access — 5145 is noisy, filter it), **4776/4768/4769** depending on auth type; on servers, User Access Logging at `C:\Windows\System32\LogFiles\Sum` retains source IP + first/last access even after other logs roll off.

```
net use z: \\host\c$ /user:domain\username <password>
```

## 5. Logon types and authentication event IDs

| Type | Meaning |
|---|---|
| 2 | Interactive (console) |
| 3 | Network |
| 4 | Batch |
| 5 | Service |
| 7 | Unlock |
| 8 | Network cleartext (credentials sent in the clear) |
| 9 | RunAs / NewCredentials |
| 10 | RemoteInteractive (RDP) |
| 11 | Cached credentials |
| 12 | Cached remote interactive |
| 13 | Cached unlock |

**Core event IDs to alert on, in order of how often they matter:**

- `4624` successful logon / `4625` failed logon / `4634`+`4647` logoff
- `4648` logon with explicit credentials (RunAs, or any tool passing `-u`)
- `4672` logon with superuser rights — pair with 4624 to catch privilege at the moment of logon
- `4768`/`4769`/`4771` Kerberos TGT granted / service ticket requested / pre-auth failed
- `4776` NTLM authentication
- `4720` account created

## Using this in an actual case

None of these artifacts is convincing alone. The workflow that actually works: pull the timestamp pair on the artifact of interest, cross-reference at least two execution artifacts before you write "executed" in a report, confirm the process tree against the baseline above before chasing a process name that just *looks* suspicious, and walk the lateral movement matrix from both ends — source and destination — because the pivot point is usually where the rest of the blast radius reveals itself.

**Sources and further reading:** SANS FOR500 (Windows Forensic Analysis) and FOR508 (Advanced Incident Response, Threat Hunting, and Digital Forensics) posters, Rob Lee / Mike Pilkington and the SANS DFIR faculty; Kaspersky's 2025 Securelist research on Amcache and ShimCache; Andrea Fortuna's write-up on the Windows 11 PCA artifact; the Windows Recall / RecallTimeline research community. If you're building this out further, FOR508 and FOR572 (network forensics) are the natural next step.
