---
title: "IaaS, PaaS, SaaS and Serverless: Choosing the Right Cloud Model"
excerpt: "In this article I would like to explain the cloud service models — IaaS, PaaS, SaaS and serverless — who manages what in each one, and a simple way to choose between them, based on my notes while preparing for the AZ-900 exam."
---

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

<h3><strong>Short introduction</strong></h3>
While working as an Azure App Developer at Microsoft, I prepared for the <strong>AZ-900 (Microsoft Azure Fundamentals)</strong> certification. The exam material covers a lot of topics, but the most important idea is actually simple: when you move to the cloud, <strong>how much of the stack do you still want to manage yourself?</strong> The answer to that question is the difference between IaaS, PaaS, SaaS and serverless. In this article I would like to explain these models with real Azure services, and share a simple flow I use to choose between them.

&nbsp;
<h3><strong>Who manages what</strong></h3>
The diagram at the top of this article shows the full stack, from the physical datacenter up to your data. The highlighted (teal) part is what you manage; the rest is managed by the cloud provider:

- **On-premises** — you manage everything, from the building to the application.
- **IaaS (Infrastructure as a Service)** — the provider gives you virtual machines, storage and network. You still manage the operating system and everything above it.
- **PaaS (Platform as a Service)** — the provider also manages the OS and runtime. You deploy your code and configure it.
- **SaaS (Software as a Service)** — the provider runs the whole application. You only manage your data and who has access to it.

> **_NOTE:_**  Look at the top row again. In <strong>every</strong> model, even SaaS, your data and access are your responsibility. This is the "shared responsibility model", and it explains why most cloud security incidents are not the provider failing — they are a public storage container, an over-permissioned account, or a missing MFA policy on the customer side.

&nbsp;
<h3><strong>The same app, four ways</strong></h3>
To make it concrete, lets take one task — hosting a web application — and see how it looks in each model on Azure:

| Model | Azure service | You do | Azure does |
|---|---|---|---|
| **IaaS** | Virtual Machines | Patch the OS, install the runtime, configure IIS or nginx, back it up | Hardware, hypervisor, network |
| **PaaS** | App Service | Deploy the code, set the configuration | OS, patching, runtime, load balancing, scaling |
| **Serverless** | Azure Functions | Write functions | Everything else, including scaling to zero |
| **SaaS** | Microsoft 365 | Configure users, policies and data | The entire application |

If you followed my [Azure DevOps article](/Microsoft-Azure-DevOps-for-ASP-.NET-Core-Web-apps/), the web app there used the PaaS model: we only deployed code to App Service and never touched a server.

&nbsp;
<h3><strong>How to choose</strong></h3>
In this section I want to share the flow I use. Start at the top, and stop at the first "yes":

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

1. **Does an existing product already do this?** Then use SaaS. Building your own email or CRM is rarely worth it.
2. **Do you need control of the OS** (custom agents, kernel settings, legacy software)? Then use IaaS — and accept the patching that comes with it.
3. **Is the workload event-driven, short and bursty?** Then serverless is usually the cheapest option.
4. **Do you have many services and need portability?** Then containers (for example Azure Kubernetes Service, which I introduced in [this article](/Containers-and-Azure-Kubernetes-Service/)).
5. **Otherwise** — a normal web app or API — PaaS.

The order matters. It always pushes you to the <strong>most managed</strong> option that still fits, which is almost always the cheapest one to operate.

&nbsp;
<h3><strong>Cloud terms you will hear all the time</strong></h3>
These terms come up in AZ-900 and in every cloud discussion afterwards:

| Term | Meaning |
|---|---|
| **CapEx → OpEx** | Stop buying servers upfront; pay monthly for what you use |
| **Elasticity** | Scale out and back in automatically with demand |
| **High availability** | Keep running when one component fails (Availability Sets and Zones) |
| **Disaster recovery** | Keep running when a whole region fails (paired regions, geo-replication) |
| **Region pair** | Two regions in the same geography, updated one at a time and recovered in priority order |
| **Availability Zone** | A physically separate datacenter inside a region |
| **Composite SLA** | Chained services multiply: 99.95% × 99.99% = **99.94%**, always lower than the weakest link |

And the three deployment models, in one line each:

- **Public cloud** — shared provider infrastructure, pay as you go.
- **Private cloud** — dedicated infrastructure, run by you (on-premises or hosted).
- **Hybrid cloud** — both connected together (for example with VPN Gateway, ExpressRoute or Azure Arc). This is where most enterprises really are.

&nbsp;
<h3><strong>Summary</strong></h3>
Choosing a cloud model comes down to one question: what are you willing to patch at 2 a.m.? If the answer is nothing, go with SaaS or serverless. If it is only your code, go with PaaS. If you really need the operating system, take IaaS and the work that comes with it. If you are preparing for AZ-900 too, the official <a href="https://docs.microsoft.com/en-us/learn/certifications/azure-fundamentals/" target="_blank" rel="noopener">Azure Fundamentals page</a> links to free Microsoft Learn paths that cover all of these concepts and is a great place to start.
