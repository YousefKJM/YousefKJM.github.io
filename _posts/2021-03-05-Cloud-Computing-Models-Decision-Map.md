---
title: "IaaS, PaaS, SaaS, Serverless: The One-Diagram Decision Map"
excerpt: "Who manages what in each cloud service model, the shared responsibility line that actually matters for security, and a five-question flowchart for picking the right model — distilled from AZ-900 prep into something you'll actually reuse."
---

I wrote this while preparing for **AZ-900 (Azure Fundamentals)**. The exam material sprawls; the core idea doesn't. It's one question: **how much of the stack do you want to own?**

## The stack, and who owns each layer

<div style="margin:2rem 0;padding:1.25rem;background:var(--bg-elevated);border:1px solid var(--border);border-radius:var(--radius-m);">
<svg viewBox="0 0 640 380" style="width:100%;height:auto;font-family:inherit;" role="img" aria-label="Responsibility matrix: on-premises you manage all layers; IaaS provider manages up to virtualization; PaaS provider also manages OS and runtime; SaaS provider manages everything except data and access">
  <g style="font-size:12px;">
    <text x="10" y="22" font-weight="700" fill="var(--text-muted)">LAYER</text>
    <text x="150" y="22" font-weight="700" fill="var(--text)">On-prem</text>
    <text x="270" y="22" font-weight="700" fill="var(--text)">IaaS</text>
    <text x="390" y="22" font-weight="700" fill="var(--text)">PaaS</text>
    <text x="510" y="22" font-weight="700" fill="var(--text)">SaaS</text>
    <g id="rows">
      <text x="10" y="54" fill="var(--text)">Data &amp; access</text>
      <text x="10" y="90" fill="var(--text)">Application</text>
      <text x="10" y="126" fill="var(--text)">Runtime</text>
      <text x="10" y="162" fill="var(--text)">Middleware</text>
      <text x="10" y="198" fill="var(--text)">Operating system</text>
      <text x="10" y="234" fill="var(--text)">Virtualization</text>
      <text x="10" y="270" fill="var(--text)">Servers &amp; storage</text>
      <text x="10" y="306" fill="var(--text)">Networking</text>
      <text x="10" y="342" fill="var(--text)">Physical datacenter</text>
    </g>
    <!-- On-prem: all you -->
    <rect x="140" y="36" width="100" height="320" rx="4" fill="var(--accent)" fill-opacity="0.85"/>
    <!-- IaaS: you top 4 rows (data, app, runtime, middleware, OS) = 5 rows -->
    <rect x="260" y="36" width="100" height="176" rx="4" fill="var(--accent)" fill-opacity="0.85"/>
    <rect x="260" y="216" width="100" height="140" rx="4" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <!-- PaaS: you data + app = 2 rows -->
    <rect x="380" y="36" width="100" height="68" rx="4" fill="var(--accent)" fill-opacity="0.85"/>
    <rect x="380" y="108" width="100" height="248" rx="4" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <!-- SaaS: you data only -->
    <rect x="500" y="36" width="100" height="32" rx="4" fill="var(--accent)" fill-opacity="0.85"/>
    <rect x="500" y="72" width="100" height="284" rx="4" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <rect x="150" y="364" width="14" height="10" fill="var(--accent)"/>
    <text x="170" y="373" fill="var(--text)">you manage</text>
    <rect x="270" y="364" width="14" height="10" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="290" y="373" fill="var(--text)">provider manages</text>
  </g>
</svg>
</div>

**Read the top row first.** In every model — even SaaS — **data and access are yours.** Most cloud breaches aren't the provider failing; they're a misconfigured storage container, an over-permissioned account, or a missing MFA policy on the customer's side of the line.

## Same app, four ways

Hosting a web app, mapped to real Azure services:

| Model | Azure service | You do | Azure does |
|---|---|---|---|
| **IaaS** | Virtual Machines | Patch the OS, install the runtime, configure IIS/nginx, back it up | Hardware, hypervisor, network fabric |
| **PaaS** | App Service | Deploy code, set config | OS, patching, runtime, load balancing, scaling |
| **Serverless** | Azure Functions | Write functions | Everything else, including scaling to zero |
| **SaaS** | Microsoft 365 | Configure users, policies, data | The entire application |

## Five questions to pick a model

<div style="margin:2rem 0;padding:1.25rem;background:var(--bg-elevated);border:1px solid var(--border);border-radius:var(--radius-m);">
<svg viewBox="0 0 640 330" style="width:100%;height:auto;font-family:inherit;" role="img" aria-label="Decision flow: if an off-the-shelf product solves it choose SaaS; if you need OS-level control choose IaaS; if the workload is event-driven and short choose serverless; if it is long-running choose containers; otherwise choose PaaS">
  <defs><marker id="cm-arr" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto"><path d="M0,0 L8,4 L0,8 z" fill="var(--text-muted)"/></marker></defs>
  <g style="font-size:13px;">
    <rect x="10" y="10" width="380" height="44" rx="8" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="24" y="37" fill="var(--text)">1. Does an existing product already do this?</text>
    <rect x="470" y="10" width="160" height="44" rx="8" fill="none" stroke="var(--accent)" stroke-width="2"/>
    <text x="520" y="37" font-weight="700" fill="var(--accent)">SaaS</text>
    <line x1="390" y1="32" x2="466" y2="32" stroke="var(--text-muted)" stroke-width="2" marker-end="url(#cm-arr)"/>
    <text x="410" y="26" fill="var(--text-muted)">yes</text>

    <rect x="10" y="74" width="380" height="44" rx="8" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="24" y="101" fill="var(--text)">2. Need OS / kernel / custom-agent control?</text>
    <rect x="470" y="74" width="160" height="44" rx="8" fill="none" stroke="var(--accent)" stroke-width="2"/>
    <text x="522" y="101" font-weight="700" fill="var(--accent)">IaaS</text>
    <line x1="390" y1="96" x2="466" y2="96" stroke="var(--text-muted)" stroke-width="2" marker-end="url(#cm-arr)"/>
    <text x="410" y="90" fill="var(--text-muted)">yes</text>

    <rect x="10" y="138" width="380" height="44" rx="8" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="24" y="165" fill="var(--text)">3. Event-driven, short, bursty?</text>
    <rect x="470" y="138" width="160" height="44" rx="8" fill="none" stroke="var(--accent)" stroke-width="2"/>
    <text x="500" y="165" font-weight="700" fill="var(--accent)">Serverless</text>
    <line x1="390" y1="160" x2="466" y2="160" stroke="var(--text-muted)" stroke-width="2" marker-end="url(#cm-arr)"/>
    <text x="410" y="154" fill="var(--text-muted)">yes</text>

    <rect x="10" y="202" width="380" height="44" rx="8" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="24" y="229" fill="var(--text)">4. Many services, portability matters?</text>
    <rect x="470" y="202" width="160" height="44" rx="8" fill="none" stroke="var(--accent)" stroke-width="2"/>
    <text x="490" y="229" font-weight="700" fill="var(--accent)">Containers (AKS)</text>
    <line x1="390" y1="224" x2="466" y2="224" stroke="var(--text-muted)" stroke-width="2" marker-end="url(#cm-arr)"/>
    <text x="410" y="218" fill="var(--text-muted)">yes</text>

    <rect x="10" y="266" width="380" height="44" rx="8" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="24" y="293" fill="var(--text)">5. Otherwise — a standard web app or API</text>
    <rect x="470" y="266" width="160" height="44" rx="8" fill="var(--accent)" fill-opacity="0.15" stroke="var(--accent)" stroke-width="2"/>
    <text x="522" y="293" font-weight="700" fill="var(--accent)">PaaS</text>
    <line x1="390" y1="288" x2="466" y2="288" stroke="var(--text-muted)" stroke-width="2" marker-end="url(#cm-arr)"/>
  </g>
</svg>
</div>

Work top to bottom and stop at the first "yes." The order matters: it pushes you toward the **most managed** option that still fits, which is almost always the cheapest to operate.

## The cloud vocabulary that actually comes up

| Term | One-line meaning |
|---|---|
| **CapEx → OpEx** | Stop buying servers up front; pay monthly for what you use |
| **Elasticity** | Scale out and back in automatically with demand |
| **High availability** | Survive a component failing (Availability Sets/Zones) |
| **Disaster recovery** | Survive a whole region failing (paired regions, geo-replication) |
| **Region pair** | Two regions in the same geography, updated one at a time, recovered in priority order |
| **Availability Zone** | Physically separate datacenter within a region — SLA jumps to 99.99% for zone-redundant VMs |
| **SLA math** | Chained services multiply: 99.95% × 99.99% = **99.94%** — composite SLAs are always lower than the weakest link |

## Deployment models in one line each

- **Public cloud** — shared provider infrastructure, pay-as-you-go.
- **Private cloud** — dedicated infrastructure, yours to run (on-prem or hosted).
- **Hybrid** — both, connected (Azure Arc, ExpressRoute, VPN Gateway). This is where most enterprises really live.

## The takeaway

Choose the model by **what you're willing to patch at 2 a.m.** If the answer is "nothing," go SaaS or serverless. If it's "just my code," go PaaS. If you need the OS, take IaaS — and take the patching that comes with it.
