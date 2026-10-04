---
title: "Velociraptor: Hunting Across Every Endpoint at Once"
excerpt: "The second tool from my manager's DFIR research. Velociraptor puts a VQL engine on every endpoint, so one query — from one browser tab — can sweep a thousand machines in seconds. A hands-on tour: Instant Velociraptor, VQL, artifacts, hunts, notebooks, live monitoring and offline collectors."
header:
  image: /images/posts/velociraptor/hero.svg
tags: [DFIR, Incident-Response, Velociraptor, VQL, endpoint, forensics]
---
![Velociraptor: hunt across every endpoint at once](/images/posts/velociraptor/hero.svg)

In the [Kuiper post](/Kuiper-DFIR-Investigation-Platform/) I mentioned my manager had asked me to research open-source DFIR tooling, and that two names kept coming up. Kuiper was the first — the place artifacts go *after* you collect them. **Velociraptor** is the other half of that sentence: the thing that reaches out and *does the collecting*, live, across your whole fleet.

This is the getting-to-know guide, not the comparison. Velociraptor is deep enough that the first time I opened it I under-used it badly, so this is the tour I wish I'd had: what it is, how its one big idea works, and every major feature with commands you can run.

## What Velociraptor actually is

Velociraptor is an open-source **endpoint visibility, DFIR and live-response platform**, built by Mike Cohen and the Velocidex team (now part of Rapid7). You run a **server**; you deploy lightweight **clients** (agents) to your endpoints; the server tasks those clients and collects the results through a web GUI.

Here's the one idea that makes everything else fall into place: **a Velociraptor client is just a VQL engine.** Every task you send — list processes, grab a registry key, hunt a hash across 5,000 machines — is a **VQL query** the client executes and streams back. Learn VQL and you haven't learned "a feature"; you've learned the whole tool.

<div style="margin:2rem 0;padding:1.25rem;background:var(--bg-elevated);border:1px solid var(--border);border-radius:var(--radius-m);">
<svg viewBox="0 0 640 260" style="width:100%;height:auto;font-family:inherit;" role="img" aria-label="Velociraptor architecture: analysts use a web GUI on the server. The server sends VQL queries down to client agents installed on Windows, Linux and macOS endpoints. Each client is a VQL engine that runs the query and streams results back to the server, which stores and displays them. A hunt is simply the same query sent to every client at once.">
  <defs><marker id="v-a" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto"><path d="M0,0 L8,4 L0,8 z" fill="var(--accent)"/></marker></defs>
  <g style="font-size:12px;">
    <rect x="8" y="104" width="96" height="54" rx="8" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="56" y="127" text-anchor="middle" font-weight="700" fill="var(--text)">Web GUI</text>
    <text x="56" y="145" text-anchor="middle" fill="var(--text-muted)">analysts</text>
    <rect x="150" y="98" width="110" height="66" rx="8" fill="var(--bg-elevated-2)" stroke="var(--accent)"/>
    <text x="205" y="124" text-anchor="middle" font-weight="700" fill="var(--accent)">Server</text>
    <text x="205" y="142" text-anchor="middle" fill="var(--text-muted)">tasks &amp; stores</text>
    <text x="205" y="157" text-anchor="middle" fill="var(--text-muted)">results</text>
    <line x1="104" y1="131" x2="148" y2="131" stroke="var(--accent)" stroke-width="2" marker-end="url(#v-a)"/>
    <text x="340" y="22" text-anchor="middle" fill="var(--text-muted)">one VQL query out &mdash; results stream back</text>
    <g fill="var(--bg-elevated-2)" stroke="var(--border)">
      <rect x="470" y="34" width="160" height="46" rx="8"/><rect x="470" y="107" width="160" height="46" rx="8"/><rect x="470" y="180" width="160" height="46" rx="8"/>
    </g>
    <text x="550" y="54" text-anchor="middle" font-weight="700" fill="var(--text)">Windows client</text>
    <text x="550" y="70" text-anchor="middle" fill="var(--text-muted)">VQL engine</text>
    <text x="550" y="127" text-anchor="middle" font-weight="700" fill="var(--text)">Linux client</text>
    <text x="550" y="143" text-anchor="middle" fill="var(--text-muted)">VQL engine</text>
    <text x="550" y="200" text-anchor="middle" font-weight="700" fill="var(--text)">macOS client</text>
    <text x="550" y="216" text-anchor="middle" fill="var(--text-muted)">VQL engine</text>
    <line x1="260" y1="120" x2="468" y2="57" stroke="var(--accent)" stroke-width="1.8" marker-end="url(#v-a)"/>
    <line x1="260" y1="131" x2="468" y2="130" stroke="var(--accent)" stroke-width="1.8" marker-end="url(#v-a)"/>
    <line x1="260" y1="142" x2="468" y2="203" stroke="var(--accent)" stroke-width="1.8" marker-end="url(#v-a)"/>
  </g>
</svg>
</div>

## Step 1 — Instant Velociraptor, in two minutes

Velociraptor is a **single Go binary** — no dependencies, no installer. The fastest way to see it is standalone GUI mode, which runs a server and one client (itself) on your own machine, bound to loopback:

```bash
# download the one binary for your OS from the releases page, then:
./velociraptor gui
# Windows:  velociraptor.exe gui
```

That launches a local server, enrols a single client (your machine), creates an `admin` / `password` login, and opens your browser to the GUI. By default it writes to a temp folder — point it somewhere persistent if you want it to survive a reboot:

```bash
./velociraptor gui --datastore ~/velo-datastore
```

Five minutes in, you can already run artifacts against your own box. That's the right way to learn VQL before you deploy anything.

## Step 2 — from laptop to fleet

For real use you generate a config, run the server on a Linux VM, and push clients out.

```bash
# interactively generate matched server + client configs
./velociraptor config generate -i
#   -> writes server.config.yaml and client.config.yaml

# create your admin user
./velociraptor --config server.config.yaml user add admin --role administrator

# run the server (GUI + frontend that clients connect to)
./velociraptor --config server.config.yaml frontend -v
```

Then package the client for your endpoints — a Debian package, an MSI, or a service install — all built from that single binary plus `client.config.yaml`:

```bash
# build a Debian client package
./velociraptor --config server.config.yaml debian client

# or install as a Windows service on an endpoint
velociraptor.exe --config client.config.yaml service install
```

> **Server note:** the client runs anywhere, but the **server is only fully supported on Linux** for production. Treat Instant Velociraptor as the lab, a Linux VM as the real thing.

## VQL: the one idea that runs everything

VQL looks like SQL but is built for forensics. The shape is always `SELECT columns FROM plugin(args) WHERE condition`, where the *plugins* are the forensic capabilities — process lists, file globbing, registry, EVTX parsing, and hundreds more.

```sql
-- processes, with their command lines and parents
SELECT Name, Pid, Ppid, CommandLine, Exe FROM pslist()

-- anything dropped into a Downloads folder
SELECT FullPath, Mtime, Size
FROM glob(globs="C:/Users/*/Downloads/*")
WHERE NOT IsDir

-- call another artifact as a function and filter it
SELECT * FROM Artifact.Windows.System.Pslist()
WHERE CommandLine =~ "-enc"
```

Because every capability is a plugin, you compose them: glob for files, hash each one, look each hash up against a set, and return only the hits — one query, no scripting.

## Artifacts: pre-built investigations you can run

Writing VQL from scratch every time would be exhausting, so Velociraptor wraps reusable queries as **artifacts**: named, parameterised YAML files you run by name. Hundreds ship built in — a few I lean on:

| Artifact | What it gets you |
|---|---|
| `Windows.System.Pslist` | Running processes with hashes |
| `Windows.EventLogs.Evtx` | Parse and query EVTX logs |
| `Windows.Forensics.Prefetch` | Execution evidence from prefetch |
| `Windows.Forensics.SRUM` | App/network usage history |
| `Windows.Registry.NTUser` | Per-user registry keys (Run, RecentDocs…) |
| `Windows.KapeFiles.Targets` | Collect KAPE-style target sets over the wire |
| `Generic.Client.Info` | Baseline host facts |

Run one from the command line against the local box, or (far more often) pick it in the GUI:

```bash
./velociraptor artifacts collect Windows.Forensics.Prefetch
```

And when the built-ins don't cover it, the **Artifact Exchange** is a community library of hundreds more you import with a click — or you write your own artifact (it's just VQL plus a parameter block).

## Collections and the VFS

Tasking one client for one artifact is a **collection** — the result is stored on the server, browsable and downloadable. Alongside it, the **VFS (Virtual File System)** lets you browse that endpoint's actual filesystem through the GUI, lazily, as if it were mounted: walk `C:\Users`, preview a file, download the ones you want for deeper analysis. Live triage without ever RDP-ing in.

## Hunts: the whole fleet in seconds

This is the feature that sells it. A **hunt** is simply "run this artifact on *every* client (or every client matching a label)". You pick the artifact, set parameters, launch — and results stream back from thousands of endpoints and aggregate into one table you can sort and filter.

<div style="margin:2rem 0;padding:1.25rem;background:var(--bg-elevated);border:1px solid var(--border);border-radius:var(--radius-m);">
<svg viewBox="0 0 640 140" style="width:100%;height:auto;font-family:inherit;" role="img" aria-label="A Velociraptor hunt: pick an artifact, scope it to all clients or a label, launch; the query runs on every endpoint in parallel and the results aggregate into one table within seconds to minutes.">
  <defs><marker id="v-h" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto"><path d="M0,0 L8,4 L0,8 z" fill="var(--accent)"/></marker></defs>
  <g style="font-size:11px;">
    <rect x="4" y="40" width="120" height="60" rx="9" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="64" y="66" text-anchor="middle" font-weight="700" fill="var(--text)">Pick artifact</text>
    <text x="64" y="84" text-anchor="middle" fill="var(--text-muted)">+ parameters</text>
    <rect x="150" y="40" width="120" height="60" rx="9" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="210" y="66" text-anchor="middle" font-weight="700" fill="var(--text)">Scope</text>
    <text x="210" y="84" text-anchor="middle" fill="var(--text-muted)">all / by label</text>
    <rect x="296" y="40" width="120" height="60" rx="9" fill="var(--accent)" fill-opacity="0.10" stroke="var(--accent-strong)"/>
    <text x="356" y="66" text-anchor="middle" font-weight="700" fill="var(--accent)">Launch</text>
    <text x="356" y="84" text-anchor="middle" fill="var(--text-muted)">runs in parallel</text>
    <rect x="470" y="40" width="166" height="60" rx="9" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="553" y="66" text-anchor="middle" font-weight="700" fill="var(--text)">One result table</text>
    <text x="553" y="84" text-anchor="middle" fill="var(--text-muted)">every endpoint, aggregated</text>
    <line x1="124" y1="70" x2="148" y2="70" stroke="var(--accent)" stroke-width="2" marker-end="url(#v-h)"/>
    <line x1="270" y1="70" x2="294" y2="70" stroke="var(--accent)" stroke-width="2" marker-end="url(#v-h)"/>
    <line x1="416" y1="70" x2="468" y2="70" stroke="var(--accent)" stroke-width="2" marker-end="url(#v-h)"/>
  </g>
</svg>
</div>

"Which machines have this scheduled task / this hash / this registry value?" stops being a week of manual checks and becomes a coffee-length hunt.

## Notebooks: from raw rows to a report

Every collection and hunt has a **notebook** — interleaved Markdown and VQL cells — so you post-process results right where they live. Re-query the collected data, join it, chart it, write your findings around it, and export. It's the "turn evidence into a report" step built into the same tool, so your analysis never leaves the platform.

```sql
-- inside a notebook cell: summarise a hunt's results
SELECT OSPath, Hash, count() AS Seen
FROM source()          -- the hunt's collected rows
GROUP BY Hash
ORDER BY Seen DESC
```

## Live monitoring: client and server events

Beyond point-in-time collections, Velociraptor does **continuous monitoring**. *Client event artifacts* (process creation, DNS, service installs…) run permanently on endpoints and stream events up in real time. *Server monitoring* reacts to those events — raise an alert, kick off a follow-up collection, escalate. That's the bridge from "DFIR tool you open during an incident" to "detection sensor you leave running."

## Offline collectors and dead disk images

Not every endpoint can talk to a server — air-gapped hosts, a single suspicious laptop, a consultant's one-off job. Velociraptor builds a **standalone offline collector**: a self-contained executable (made in the GUI) that someone runs on the target with no server at all, producing a single results `.zip` you analyse later. And you can point Velociraptor at **dead evidence** too — a triage collection or a mounted disk image — and run the very same artifacts you'd run live. One skill set, live or post-mortem.

## Five ways I'd actually use it

1. **Fleet-wide IOC sweep.** New threat report drops at 9 a.m.; by 9:15 a hunt has told you which of your endpoints match.
2. **Remote triage, no RDP.** Pull processes, autoruns, prefetch and event logs from a suspect host through the GUI while it stays isolated.
3. **Leave-behind detection.** Deploy a handful of client-monitoring artifacts and let Velociraptor stream process-creation and service-install events as a lightweight sensor.
4. **The one-laptop case.** Hand a non-technical colleague an offline collector `.exe`; get back a zip you analyse with the same artifacts.
5. **Disk-image triage at speed.** Run `Windows.Forensics.*` artifacts against a mounted image instead of chaining five standalone CLI parsers.

## Where this leaves you

Kuiper and Velociraptor turned out to be the two halves of a cheap, capable DFIR capability: **Velociraptor reaches out and collects live from the fleet; Kuiper is the team-scale home where collected artifacts become searchable evidence.** My manager's research question — "what can a small team stand up for free?" — basically answers itself once you've met both. Start each in its lab mode, run one real query, and the rest opens up fast.

Worth reading next: the [Velociraptor docs](https://docs.velociraptor.app/), the [VQL reference](https://docs.velociraptor.app/vql_reference/), the [Artifact Exchange](https://docs.velociraptor.app/exchange/), and — for the other half — my [Kuiper getting-started guide](/Kuiper-DFIR-Investigation-Platform/).
