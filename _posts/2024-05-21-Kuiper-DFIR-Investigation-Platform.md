---
title: "Kuiper: A Team-Scale Home for Your Forensic Artifacts"
excerpt: "My manager asked me to look into open-source DFIR platforms, and two names kept coming back. This is the hands-on getting-to-know guide for the first one — Kuiper: install it with Docker, feed it triage data, and parse, search, tag and alert across a whole case from one browser tab."
header:
  image: /images/posts/kuiper/hero.svg
tags: [DFIR, Forensics, Incident-Response, Kuiper, parsers, triage]
---
![Kuiper: a team-scale home for your forensic artifacts](/images/posts/kuiper/hero.svg)

Earlier this year my line manager asked me to go away and research the open-source DFIR tooling landscape — what a small team could stand up without a six-figure license. Two names kept surfacing in every comparison I read: **Kuiper** and **Velociraptor**. They solve different halves of the same problem, so I spent real time getting to know each one properly.

This post isn't that comparison. It's the hands-on *getting-to-know* guide I wrote for myself on the first of the two — **Kuiper** — so that next time I open it, I'm not relearning it from scratch. If you've ever finished a triage collection and then stared at a folder of `.zip` files wondering where to actually *look*, this is the tool that answers that.

## What Kuiper actually is

Kuiper is a **digital forensics investigation platform**: a server-side home where collected evidence gets parsed, indexed, searched, tagged, timelined and alerted on — by a whole team, in one place. It's open-source (GPL-3.0), built by Saleh Muhaysin, Muteb Alqahtani and Abdullah Alrasheed.

The mental model that made it click for me: Kuiper is **not** a collector and **not** an agent on the endpoint. It sits *after* collection. Something else grabs the artifacts off a machine (its sibling tool **Hoarder**, or KAPE, or CyLR); Kuiper is where those artifacts go to become *searchable evidence*. Think of it as the Elasticsearch-backed case file that every analyst on the team queries at once, instead of five people each running `EvtxECmd` on their own laptop and emailing CSVs around.

<div style="margin:2rem 0;padding:1.25rem;background:var(--bg-elevated);border:1px solid var(--border);border-radius:var(--radius-m);">
<svg viewBox="0 0 640 300" style="width:100%;height:auto;font-family:inherit;" role="img" aria-label="Kuiper architecture: a browser talks through Nginx to a Flask web app. Flask reads case and machine metadata from MongoDB and queues parsing jobs through Redis. Celery workers (one per CPU core) pick up jobs, run parsers, and write structured records into Elasticsearch, which Flask then searches. An NFS share holds the uploaded evidence files so both Flask and the Celery workers can read them.">
  <defs><marker id="k-a" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto"><path d="M0,0 L8,4 L0,8 z" fill="var(--accent)"/></marker></defs>
  <g style="font-size:12px;">
    <rect x="8" y="120" width="96" height="52" rx="8" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="56" y="143" text-anchor="middle" font-weight="700" fill="var(--text)">Browser</text>
    <text x="56" y="160" text-anchor="middle" fill="var(--text-muted)">analysts</text>
    <rect x="124" y="120" width="70" height="52" rx="8" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="159" y="143" text-anchor="middle" font-weight="700" fill="var(--text)">Nginx</text>
    <text x="159" y="160" text-anchor="middle" fill="var(--text-muted)">proxy</text>
    <rect x="214" y="120" width="84" height="52" rx="8" fill="var(--bg-elevated-2)" stroke="var(--accent)"/>
    <text x="256" y="143" text-anchor="middle" font-weight="700" fill="var(--accent)">Flask</text>
    <text x="256" y="160" text-anchor="middle" fill="var(--text-muted)">web app</text>
    <rect x="214" y="18" width="84" height="46" rx="8" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="256" y="38" text-anchor="middle" font-weight="700" fill="var(--text)">MongoDB</text>
    <text x="256" y="54" text-anchor="middle" fill="var(--text-muted)">case meta</text>
    <rect x="214" y="228" width="84" height="46" rx="8" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="256" y="248" text-anchor="middle" font-weight="700" fill="var(--text)">Redis</text>
    <text x="256" y="264" text-anchor="middle" fill="var(--text-muted)">job queue</text>
    <rect x="330" y="206" width="104" height="68" rx="8" fill="var(--bg-elevated-2)" stroke="var(--accent)"/>
    <text x="382" y="232" text-anchor="middle" font-weight="700" fill="var(--accent)">Celery</text>
    <text x="382" y="250" text-anchor="middle" fill="var(--text-muted)">workers run</text>
    <text x="382" y="265" text-anchor="middle" fill="var(--text-muted)">the parsers</text>
    <rect x="470" y="120" width="104" height="60" rx="8" fill="var(--accent)" fill-opacity="0.10" stroke="var(--accent-strong)"/>
    <text x="522" y="144" text-anchor="middle" font-weight="700" fill="var(--text)">Elasticsearch</text>
    <text x="522" y="162" text-anchor="middle" fill="var(--text-muted)">searchable records</text>
    <rect x="470" y="206" width="104" height="52" rx="8" fill="none" stroke="var(--text-muted)" stroke-dasharray="5 4"/>
    <text x="522" y="228" text-anchor="middle" font-weight="700" fill="var(--text)">NFS share</text>
    <text x="522" y="245" text-anchor="middle" fill="var(--text-muted)">evidence files</text>
    <line x1="104" y1="146" x2="122" y2="146" stroke="var(--accent)" stroke-width="2" marker-end="url(#k-a)"/>
    <line x1="194" y1="146" x2="212" y2="146" stroke="var(--accent)" stroke-width="2" marker-end="url(#k-a)"/>
    <line x1="256" y1="120" x2="256" y2="66" stroke="var(--text-muted)" stroke-width="1.5" marker-end="url(#k-a)"/>
    <line x1="256" y1="172" x2="256" y2="226" stroke="var(--text-muted)" stroke-width="1.5" marker-end="url(#k-a)"/>
    <line x1="298" y1="250" x2="328" y2="245" stroke="var(--accent)" stroke-width="2" marker-end="url(#k-a)"/>
    <line x1="434" y1="232" x2="490" y2="182" stroke="var(--accent)" stroke-width="2" marker-end="url(#k-a)"/>
    <line x1="298" y1="150" x2="468" y2="150" stroke="var(--accent)" stroke-width="2" marker-end="url(#k-a)"/>
    <line x1="434" y1="232" x2="468" y2="232" stroke="var(--text-muted)" stroke-width="1.5" stroke-dasharray="4 3"/>
  </g>
</svg>
</div>

That's seven containers — Nginx, Flask, MongoDB, Redis, Celery, Elasticsearch and an NFS share — but you don't manage them by hand. Docker Compose brings the whole thing up as one unit.

## Step 1 — stand it up with Docker

Kuiper ships as a Docker Compose stack, so the install is mostly "have Docker, then `up`". Give it room: Elasticsearch is the hungry one.

> **Spec it honestly:** 64-bit Ubuntu 18.04+, Docker 20.10+ and Compose, 4+ CPU cores (Kuiper spawns one parsing worker per core), 25 GB+ disk, and as much RAM as you can spare — 4 GB is the floor, 64 GB is what Elasticsearch actually wants for a busy case.

```bash
# Elasticsearch refuses to start without this — set it first, every boot
sudo sysctl -w vm.max_map_count=262144

# Pull and run the whole stack
git clone https://github.com/DFIRKuiper/Kuiper.git
cd Kuiper
docker-compose pull
docker-compose up -d
```

Then confirm all seven services came up, and tail logs if one didn't:

```bash
docker-compose ps -a                         # every service should read "Up"
docker-compose logs -f --tail=100 kuiper_flask   # if Flask failed to mount NFS, just re-run `up -d`
```

The web UI comes up over HTTPS on port 443. Log in, and you've got an empty investigation platform waiting for its first case.

## Step 2 — the workflow: case → machines → parsed evidence

Here's the loop that every investigation in Kuiper follows. Collection happens *outside* Kuiper; everything after the upload happens *inside* it.

<div style="margin:2rem 0;padding:1.25rem;background:var(--bg-elevated);border:1px solid var(--border);border-radius:var(--radius-m);">
<svg viewBox="0 0 640 150" style="width:100%;height:auto;font-family:inherit;" role="img" aria-label="Kuiper workflow: collect artifacts from an endpoint with Hoarder, KAPE or CyLR into a zip; create a case in Kuiper; upload the machine's zip; Celery workers parse it into Elasticsearch; then you investigate by searching, tagging, timelining and writing rules.">
  <defs><marker id="k-w" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto"><path d="M0,0 L8,4 L0,8 z" fill="var(--accent)"/></marker></defs>
  <g style="font-size:11px;">
    <rect x="4" y="40" width="112" height="70" rx="9" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="60" y="64" text-anchor="middle" font-size="18">📦</text>
    <text x="60" y="86" text-anchor="middle" font-weight="700" fill="var(--text)">1 · Collect</text>
    <text x="60" y="102" text-anchor="middle" fill="var(--text-muted)">Hoarder/KAPE → zip</text>
    <rect x="136" y="40" width="112" height="70" rx="9" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="192" y="64" text-anchor="middle" font-size="18">🗂️</text>
    <text x="192" y="86" text-anchor="middle" font-weight="700" fill="var(--text)">2 · Case</text>
    <text x="192" y="102" text-anchor="middle" fill="var(--text-muted)">create + scope</text>
    <rect x="268" y="40" width="112" height="70" rx="9" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="324" y="64" text-anchor="middle" font-size="18">⬆️</text>
    <text x="324" y="86" text-anchor="middle" font-weight="700" fill="var(--text)">3 · Upload</text>
    <text x="324" y="102" text-anchor="middle" fill="var(--text-muted)">one zip per machine</text>
    <rect x="400" y="40" width="112" height="70" rx="9" fill="var(--bg-elevated-2)" stroke="var(--accent)"/>
    <text x="456" y="64" text-anchor="middle" font-size="18">⚙️</text>
    <text x="456" y="86" text-anchor="middle" font-weight="700" fill="var(--accent)">4 · Parse</text>
    <text x="456" y="102" text-anchor="middle" fill="var(--text-muted)">Celery → ES</text>
    <rect x="532" y="40" width="104" height="70" rx="9" fill="var(--accent)" fill-opacity="0.10" stroke="var(--accent-strong)"/>
    <text x="584" y="64" text-anchor="middle" font-size="18">🔎</text>
    <text x="584" y="86" text-anchor="middle" font-weight="700" fill="var(--text)">5 · Investigate</text>
    <text x="584" y="102" text-anchor="middle" fill="var(--text-muted)">search·tag·rules</text>
    <line x1="116" y1="75" x2="134" y2="75" stroke="var(--accent)" stroke-width="2" marker-end="url(#k-w)"/>
    <line x1="248" y1="75" x2="266" y2="75" stroke="var(--accent)" stroke-width="2" marker-end="url(#k-w)"/>
    <line x1="380" y1="75" x2="398" y2="75" stroke="var(--accent)" stroke-width="2" marker-end="url(#k-w)"/>
    <line x1="512" y1="75" x2="530" y2="75" stroke="var(--accent)" stroke-width="2" marker-end="url(#k-w)"/>
  </g>
</svg>
</div>

1. **Collect.** On the endpoint, run a triage collector. The team behind Kuiper also makes **Hoarder** for exactly this, but KAPE or CyLR output works too — the point is you end up with a `.zip` of that machine's artifacts (registry hives, event logs, `$MFT`, prefetch, browser history, and so on).
2. **Create a case** in the UI and scope the machines that belong to it.
3. **Upload** each machine's `.zip`. Kuiper stores it on the shared NFS volume so the workers can reach it.
4. **Parse.** This is where Kuiper earns its keep: Celery fans the work out across your CPU cores — roughly one machine per core — running the right parser for each artifact type and streaming structured records into Elasticsearch. You watch progress per machine in the UI.
5. **Investigate.** Now every parsed field, from every machine in the case, is searchable from one bar.

## Parsers: how a raw hive becomes a searchable row

A **parser** in Kuiper is a small program that takes one artifact type and emits structured records. Out of the box it ships parsers for the usual suspects — Windows registry, EVTX event logs, `$MFT`, prefetch, browser history, scheduled tasks, and more — each living in its own folder under `kuiper/parsers/`. Every parser's output lands in Elasticsearch with a consistent envelope (which machine, which parser, a timestamp, and the parsed fields), which is the whole trick behind searching across wildly different artifact types in one query.

> **Why this matters:** once a `4688` process-creation event and a `Run`-key registry value and a prefetch execution record are all just *documents with fields* in the same index, "show me everything that touched `temp\svchost.exe` on any machine" becomes a single search instead of three tools.

### Writing a custom parser

When you have an artifact Kuiper doesn't know yet — a bespoke application log, an EDR export — you add a parser folder. Each one pairs the program that does the parsing with a configuration that tells Kuiper when to run it and how to label its output. The shape looks like this (the exact field names are documented in the project's [Add Custom Parser](https://github.com/DFIRKuiper/Kuiper/wiki/Add-Custom-Parser) wiki page — follow it rather than my sketch for the real schema):

```yaml
# kuiper/parsers/mytool/configuration.yaml  (illustrative shape)
parser_name: mytool
description: Parse MyTool's JSON export into Kuiper records
# which uploaded files this parser should be handed
files:  ['*mytool*.json']
# how to run it — Kuiper pipes the artifact in and reads records out
interpreter: python3
command: 'mytool_parser.py'
```

```python
# mytool_parser.py — read the artifact, print one JSON record per line
import sys, json
for line in open(sys.argv[1]):
    row = json.loads(line)
    print(json.dumps({
        "timestamp": row["ts"],          # Kuiper timelines on this
        "user":      row.get("user"),
        "action":    row.get("action"),
        "raw":       row,                 # keep the original for context
    }))
```

Drop the folder in, and your artifact is now first-class: searchable, taggable and timeline-able like everything else.

## Searching across the whole case

Because the backend is Elasticsearch, search is field-aware and fast. You query by the fields the parsers produced — pick a machine or search them all at once, filter by parser, and pivot on values:

```text
# representative queries — the available fields depend on the parser
EventID:4624 AND LogonType:10            # interactive RDP logons
parser:"windows.registry" AND KeyPath:*\\Run\\*
message:*powershell* AND message:*-enc*  # encoded PowerShell anywhere
```

The win isn't any single query — it's that you're querying **every machine in the case at once**, from one box, without re-running tooling per host.

## Tagging and the timeline

Searching finds candidates; **tagging** is how you turn candidates into a story. When a record looks relevant, tag it. Tagged records flow into the **timeline** view, so instead of a flat 50,000-row dump you get the handful of events that matter, in order. You can also drop **manual timeline entries** — a firewall hit, a proxy log line, a note from the reporter — as timestamped context without importing the whole source. By the end of a case, the timeline *is* your narrative.

## Rules: promote a good query to an alarm

The feature that changes how you work: save a search as a **rule**. A rule is a query that Kuiper evaluates against the case's data — past, present *and* future — and flags matches automatically. Write it once ("binary executed from a temp directory", "encoded PowerShell", "new service install via `7045`") and every machine you upload afterwards gets checked against it the moment it finishes parsing. It's detection-engineering thinking applied to dead-box evidence: your hard-won knowledge from the last case becomes an automatic check on the next one.

## Automating it: the API

For anything repetitive, Kuiper exposes a REST API (see the companion [DFIRKuiperAPI](https://github.com/DFIRKuiper/DFIRKuiperAPI) project). The two endpoints I'd reach for first:

- **`UploadMachines`** — push a machine's `.zip` into a case programmatically, so your collection pipeline can hand off to Kuiper with no clicks.
- **`GetFieldsScript`** — pull parsed data back out, for a report or to feed another tool.

That turns Kuiper from a place you *visit* into a step in an automated triage pipeline: collector drops a zip, a script uploads it, parsing kicks off, rules fire — and an analyst only steps in once there's something to look at.

## Five ways I'd actually use it

1. **Team case file.** Five analysts, one case, zero emailed CSVs — everyone searches the same parsed evidence and sees each other's tags.
2. **A rules library that compounds.** Every case ends with a few new rules. Six months in, a fresh upload is auto-triaged against everything you've ever learned.
3. **Collector + API = hands-off intake.** Wire Hoarder (or KAPE) output straight into `UploadMachines` so triage data parses itself on arrival.
4. **Cross-host hunting.** "Did this IOC touch *any* machine in scope?" is one query, not one-per-host.
5. **A teaching sandbox.** Spin up the stack, drop in a sample triage image, and let a junior analyst learn to pivot through real artifacts without touching a live endpoint.

## Where this leaves you

Kuiper is the **after-collection** half of a DFIR workflow: the shared, searchable, rule-driven home where artifacts become evidence a team can actually work. It doesn't reach out and grab data from endpoints — and that's exactly the gap the other tool from my manager's research fills. That one's an agent on the endpoint, and it's next.

Worth reading next: the [Kuiper repository](https://github.com/DFIRKuiper/Kuiper) and its [wiki](https://github.com/DFIRKuiper/Kuiper/wiki) (start with *Add Custom Parser*), the companion collector [Hoarder](https://github.com/DFIRKuiper/Hoarder), and the [DFIRKuiperAPI](https://github.com/DFIRKuiper/DFIRKuiperAPI) for automation.
