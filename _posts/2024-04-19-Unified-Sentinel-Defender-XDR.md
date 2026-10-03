---
title: "One Portal to Rule Them All? Sentinel Meets Defender XDR"
excerpt: "Microsoft folded Sentinel and Defender XDR into a single security.microsoft.com experience — one incident queue, one hunting bar, one copilot. Here's what genuinely changes day to day for an analyst, what to watch out for before you onboard, and whether the hype holds up."
header:
  image: /images/posts/sentinel-xdr/hero.jpg
tags: [Detection, Cloud, Sentinel, Defender-XDR, SIEM, KQL, SOC]
---
![Sentinel meets Defender XDR in one portal](/images/posts/sentinel-xdr/hero.jpg)

For years, working a Microsoft SOC meant living in two browser tabs. Defender XDR (security.microsoft.com) for endpoint, identity, email and cloud-app alerts; Azure Sentinel (in the Azure portal) for the SIEM — your custom logs, your analytics rules, your long-term hunting. Same incident, two windows, two query experiences, and a lot of alt-tabbing to stitch a story together. Microsoft has now merged the two into a **single unified portal** at security.microsoft.com, and a sharp walkthrough by <a href="https://medium.com/@junaidmumtaz438/a-closer-look-at-the-unified-microsoft-sentinel-defender-xdr-portal-%EF%B8%8F-64751f9fb767" target="_blank" rel="noopener">Junaid Mumtaz</a> got me thinking about what it actually means for the people doing the work.

The short version: it's less a new product than the removal of a seam that never should have been there. But seams have a way of hiding assumptions, so it's worth looking at what moves, what doesn't, and what to check before you flip the switch.

## The before and after, in one picture

The change is structural. Instead of two consoles each owning part of an incident, one console owns the whole thing and Sentinel becomes a workspace *inside* it.

<div style="margin:2rem 0;padding:1.25rem;background:var(--bg-elevated);border:1px solid var(--border);border-radius:var(--radius-m);">
<svg viewBox="0 0 640 270" style="width:100%;height:auto;font-family:inherit;" role="img" aria-label="Before: an analyst split between the Azure portal for Sentinel SIEM and security.microsoft.com for Defender XDR, correlating incidents manually across two tabs. After: a single security.microsoft.com portal with one incident queue, one advanced hunting bar over both data sets, and Security Copilot, with the Sentinel workspace living inside it">
  <defs><marker id="sx-a" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto"><path d="M0,0 L8,4 L0,8 z" fill="var(--text-muted)"/></marker></defs>
  <g style="font-size:11.5px;">
    <text x="160" y="20" text-anchor="middle" font-weight="700" fill="var(--text-muted)">BEFORE</text>
    <rect x="15" y="34" width="135" height="80" rx="10" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="82" y="58" text-anchor="middle" font-weight="700" fill="var(--text)">Azure portal</text>
    <text x="82" y="78" text-anchor="middle" fill="var(--text-muted)">Sentinel (SIEM)</text>
    <text x="82" y="96" text-anchor="middle" fill="var(--text-muted)">custom logs, rules</text>
    <rect x="170" y="34" width="135" height="80" rx="10" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="237" y="58" text-anchor="middle" font-weight="700" fill="var(--text)">security.ms.com</text>
    <text x="237" y="78" text-anchor="middle" fill="var(--text-muted)">Defender XDR</text>
    <text x="237" y="96" text-anchor="middle" fill="var(--text-muted)">endpoint, email, ID</text>
    <path d="M150 74 L168 74" stroke="var(--text-muted)" stroke-width="2" stroke-dasharray="3 3" marker-end="url(#sx-a)"/>
    <path d="M168 86 L152 86" stroke="var(--text-muted)" stroke-width="2" stroke-dasharray="3 3" marker-end="url(#sx-a)"/>
    <text x="160" y="134" text-anchor="middle" fill="var(--text-muted)">analyst correlates by hand, two tabs</text>

    <text x="490" y="20" text-anchor="middle" font-weight="700" fill="var(--accent)">AFTER</text>
    <rect x="355" y="34" width="270" height="100" rx="12" fill="var(--accent)" fill-opacity="0.12" stroke="var(--accent)" stroke-width="2"/>
    <text x="490" y="56" text-anchor="middle" font-weight="700" fill="var(--accent)">security.microsoft.com</text>
    <text x="490" y="78" text-anchor="middle" fill="var(--text)">one incident queue</text>
    <text x="490" y="96" text-anchor="middle" fill="var(--text)">one Advanced Hunting bar</text>
    <text x="490" y="114" text-anchor="middle" fill="var(--text-muted)">Sentinel workspace lives inside · + Copilot</text>

    <rect x="15" y="170" width="610" height="80" rx="10" fill="none" stroke="var(--text-muted)" stroke-dasharray="5 5"/>
    <text x="30" y="194" font-weight="700" fill="var(--text)">What merges</text>
    <text x="30" y="216" fill="var(--text-muted)">Incidents (XDR + Sentinel analytics) · Advanced Hunting (device/email tables + custom Log Analytics tables)</text>
    <text x="30" y="236" fill="var(--text-muted)">Entities, watchlists, automation, and Security Copilot — all in one place</text>
  </g>
</svg>
</div>

## What actually changes for the analyst

Four things genuinely improve the day-to-day. The rest is mostly the same engine with the walls knocked down.

**1. One incident queue.** This is the headline. Previously a phishing case might raise a Defender email alert *and* a Sentinel analytics-rule alert from your firewall logs, and you'd manually realise they were the same event. In the unified portal, correlation happens across both worlds, so a single incident can carry XDR alerts and Sentinel alerts together, with one combined entity graph. Less swivel-chair, fewer "wait, is this the same thing?" moments.

**2. One hunting bar over both data sets.** Advanced Hunting now queries Defender's schema (`DeviceProcessEvents`, `EmailEvents`, `IdentityLogonEvents`…) *and* your Sentinel/Log Analytics custom tables from the same KQL prompt. A hunt that used to mean running one query in Defender, exporting, and re-running something similar in Sentinel becomes a single join:

```sql
// One query spanning Defender XDR tables and a custom Sentinel table
DeviceProcessEvents
| where Timestamp > ago(24h)
| where FileName =~ "powershell.exe" and ProcessCommandLine has_any ("-enc", "downloadstring")
| join kind=inner (
    FirewallLogs_CL                       // a custom table that lives in Sentinel
    | where TimeGenerated > ago(24h)
) on $left.DeviceName == $right.HostName_s
| project Timestamp, DeviceName, ProcessCommandLine, DestinationIP_s
```

**3. Security Copilot in the console.** The natural-language assistant sits in the same portal — summarise an incident, explain a script, draft a KQL query, generate a hunting lead. Microsoft cites meaningful speed-ups for analysts using it; treat the exact numbers as vendor figures, but the direction (faster triage on routine incidents) matches what people report. Just remember that an assistant which reads attacker-influenced content (alerts, emails, logs) is itself part of the attack surface — prompt injection is a real concern the moment you let a model act on untrusted input.

**4. One place to learn.** For a junior analyst, "where do I go?" finally has one answer. That alone lowers the onboarding cliff that a two-portal SOC quietly imposed.

## What doesn't change (and why that's fine)

Under the hood, it's the same machinery:

- **Sentinel is still Sentinel.** Your Log Analytics workspace, your data connectors, your analytics rules, your retention and your cost model are unchanged. The portal is a new front door, not a new house.
- **KQL is still KQL.** Nothing to relearn — if anything, you now use it in *more* places.
- **Billing is the same.** Ingestion and retention still bill against the Log Analytics workspace. Merging the portal doesn't merge the invoice, and it won't magically reduce your SIEM spend (for that, see the real levers: table tiering, DCR filtering, archive).

## Before you onboard: the checklist

It's a smooth switch, but it's still a change to your primary investigation surface. Walk in with eyes open.

<div style="margin:2rem 0;padding:1.25rem;background:var(--bg-elevated);border:1px solid var(--border);border-radius:var(--radius-m);">
<svg viewBox="0 0 640 210" style="width:100%;height:auto;font-family:inherit;" role="img" aria-label="Onboarding checklist: confirm prerequisites of one Sentinel workspace plus at least one Defender XDR workload; know that primary workspace selection matters; re-check RBAC because unified roles map differently; update any saved Azure-portal links, bookmarks and runbooks; and retest SOAR automation and API integrations that referenced the old portal">
  <g style="font-size:12px;">
    <rect x="5" y="15" width="200" height="80" rx="10" fill="var(--bg-elevated-2)" stroke="var(--accent)"/>
    <text x="20" y="38" font-weight="700" fill="var(--accent)">Prerequisites</text>
    <text x="20" y="60" fill="var(--text-muted)">1 Sentinel workspace +</text>
    <text x="20" y="78" fill="var(--text-muted)">≥1 Defender XDR workload</text>
    <rect x="220" y="15" width="200" height="80" rx="10" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="235" y="38" font-weight="700" fill="var(--text)">RBAC</text>
    <text x="235" y="60" fill="var(--text-muted)">re-check who can see</text>
    <text x="235" y="78" fill="var(--text-muted)">what — roles map over</text>
    <rect x="435" y="15" width="200" height="80" rx="10" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="450" y="38" font-weight="700" fill="var(--text)">Workspace scope</text>
    <text x="450" y="60" fill="var(--text-muted)">multi-workspace behaves</text>
    <text x="450" y="78" fill="var(--text-muted)">differently — know yours</text>
    <rect x="5" y="110" width="305" height="80" rx="10" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="20" y="133" font-weight="700" fill="var(--text)">Links &amp; bookmarks</text>
    <text x="20" y="155" fill="var(--text-muted)">update saved Azure-portal URLs, workbooks,</text>
    <text x="20" y="173" fill="var(--text-muted)">and docs that point analysts at the old blade</text>
    <rect x="325" y="110" width="310" height="80" rx="10" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="340" y="133" font-weight="700" fill="var(--text)">Automation &amp; APIs</text>
    <text x="340" y="155" fill="var(--text-muted)">retest SOAR playbooks, Logic Apps and any</text>
    <text x="340" y="173" fill="var(--text-muted)">integrations tied to the incident schema</text>
  </g>
</svg>
</div>

A few specifics worth calling out:

- **Prerequisites.** You need a Sentinel workspace and at least one onboarded Defender XDR workload to get the unified experience.
- **Primary workspace.** Multi-workspace environments behave differently from single-workspace ones; know which workspace is primary and how cross-workspace queries resolve in the new view — the same cross-workspace design thinking you apply to any multi-workspace Sentinel deployment.
- **RBAC.** Permissions carry over, but the *surfaces* people reach change. Verify that the right people see the right incidents and nobody accidentally gained or lost visibility.
- **Don't break your automation.** Playbooks, Logic Apps and API callers that assumed the old portal or incident shape should be regression-tested, exactly like any other change to a production system.

## So — game-changer, or marketing?

Honestly, somewhere sensible in between. It is not a new detection engine and it will not improve your coverage on its own — your analytics rules, your log sources and your tuning still decide whether you catch anything (which is exactly why you still have to validate your detections against real techniques, not assume the portal does it for you). What it *does* remove is friction: one queue, one hunting language over everything, one assistant, one place to train people. For a Microsoft-centric SOC, less context-switching is a real, compounding win — analysts are faster and make fewer correlation mistakes when the whole story lives in one view.

My take: onboard it, but treat it as an operational change, not a free upgrade. Pilot it with a couple of analysts, work the checklist above, and keep measuring the thing that actually matters — time to detect and time to respond — rather than the number of portals.

Credit to <a href="https://medium.com/@junaidmumtaz438/a-closer-look-at-the-unified-microsoft-sentinel-defender-xdr-portal-%EF%B8%8F-64751f9fb767" target="_blank" rel="noopener">Junaid Mumtaz's walkthrough</a> for prompting this one. For the official details and onboarding steps, Microsoft's <a href="https://learn.microsoft.com/en-us/unified-secops-platform/overview-unified-security" target="_blank" rel="noopener">unified security operations platform documentation</a> is the place to start.
