---
title: "Microsoft Intune Field Manual: Architecture, Build, SIEM Logging, DFIR and Security Review"
excerpt: "In this article I would like to present Microsoft Intune from every angle I care about as a DFIR specialist: how the service is built and how devices talk to it, the network it needs, every major module, a phased implementation plan, how to get its telemetry into a SIEM step by step, how to investigate a device and the tenant itself, and a security review checklist with ready-to-run scripts."
header:
  image: /images/posts/intune/hero.jpg
---

<p align="center">
<img src="/images/posts/intune/hero.jpg" alt="Microsoft Intune field manual: architecture, build, network, SIEM logging, DFIR and security review" style="margin-inline:auto;"/>
</p>

<h3><strong>Short introduction</strong></h3>
Intune is one of those platforms that everyone in IT touches, but few people see completely. The endpoint team sees profiles and apps, the identity team sees Conditional Access, and the SOC sees… usually nothing, until the day something goes wrong. That gap is dangerous. In March 2026, attackers who got hold of an administrator account used Stryker's own Intune tenant to <strong>remote-wipe a very large number of corporate and personal devices</strong>, without deploying a single piece of malware. Intune is a management plane, and a management plane that can run code as SYSTEM on every laptop is also a weapon.

In this article I would like to present Intune the way I wish someone had explained it to me: from the architecture and the network, through every major module and a practical build plan, to the parts that matter most for security teams — <strong>logging into a SIEM, DFIR on endpoints and on the tenant, and a security review</strong>. Every script in this post is also available to download at the end.

> **_NOTE:_**  Intune changes monthly. Everything here was checked against Microsoft's documentation as of October 2026, including the network endpoint list, the diagnostic log categories and the July 2026 licensing changes. Always re-check the linked official pages before you change a firewall or a production policy.

&nbsp;
<h3><strong>Intune in one picture: the architecture</strong></h3>
Intune is a <strong>cloud-only, multi-tenant SaaS service</strong> running on Azure. There is no server to install: your tenant lives in a regional scale unit (you can see it under <em>Tenant administration → Tenant status → Tenant location</em>, for example "Europe 0202"). Everything else is built around three things: <strong>Microsoft Entra ID</strong> for identity, <strong>push channels</strong> to wake devices up, and <strong>connectors</strong> to the outside world:

<div style="margin:2rem 0;padding:1.25rem;background:var(--bg-elevated);border:1px solid var(--border);border-radius:var(--radius-m);">
<svg viewBox="0 0 640 480" style="width:100%;height:auto;font-family:inherit;" role="img" aria-label="Intune architecture: admins and automation use the admin center and Microsoft Graph; Entra ID provides identity, device objects and Conditional Access; the Intune service in a regional scale unit holds policies, apps and compliance; devices on Windows, macOS, iOS and Android are woken through WNS, APNs and FCM and check in over HTTPS; connectors link to Defender for Endpoint, Apple Business Manager, Managed Google Play, on-premises certificate authorities and Configuration Manager; diagnostic settings export logs to Azure Monitor">
  <defs><marker id="in-a1" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto"><path d="M0,0 L8,4 L0,8 z" fill="var(--text-muted)"/></marker></defs>
  <g style="font-size:11.5px;">
    <!-- admin plane -->
    <rect x="5" y="10" width="190" height="120" rx="10" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="18" y="32" font-weight="700" fill="var(--text)">ADMIN PLANE</text>
    <text x="18" y="54" fill="var(--text-muted)">Intune admin center</text>
    <text x="18" y="72" fill="var(--text-muted)">Microsoft Graph API (beta/v1.0)</text>
    <text x="18" y="90" fill="var(--text-muted)">PowerShell · automation apps</text>
    <text x="18" y="108" fill="var(--text-muted)">Security Copilot agents</text>
    <!-- entra -->
    <rect x="225" y="10" width="190" height="120" rx="10" fill="var(--bg-elevated-2)" stroke="var(--accent)" stroke-width="2"/>
    <text x="238" y="32" font-weight="700" fill="var(--accent)">MICROSOFT ENTRA ID</text>
    <text x="238" y="54" fill="var(--text-muted)">users · groups · admin roles</text>
    <text x="238" y="72" fill="var(--text-muted)">device objects (isCompliant)</text>
    <text x="238" y="90" fill="var(--text-muted)">Conditional Access</text>
    <text x="238" y="108" fill="var(--text-muted)">PIM · sign-in &amp; audit logs</text>
    <!-- logs -->
    <rect x="445" y="10" width="190" height="120" rx="10" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="458" y="32" font-weight="700" fill="var(--text)">TELEMETRY OUT</text>
    <text x="458" y="54" fill="var(--text-muted)">Diagnostic settings →</text>
    <text x="458" y="72" fill="var(--text-muted)">Log Analytics / Sentinel</text>
    <text x="458" y="90" fill="var(--text-muted)">Event Hubs → any SIEM</text>
    <text x="458" y="108" fill="var(--text-muted)">Storage (archive)</text>
    <!-- intune core -->
    <rect x="120" y="160" width="400" height="130" rx="12" fill="var(--accent)" fill-opacity="0.12" stroke="var(--accent)" stroke-width="2"/>
    <text x="320" y="184" text-anchor="middle" font-weight="700" font-size="14" fill="var(--accent)">INTUNE SERVICE  ·  regional scale unit</text>
    <g fill="var(--text)">
      <rect x="135" y="196" width="118" height="26" rx="5" fill="var(--bg-elevated-2)" stroke="var(--border)"/><text x="194" y="213" text-anchor="middle">Enrollment</text>
      <rect x="261" y="196" width="118" height="26" rx="5" fill="var(--bg-elevated-2)" stroke="var(--border)"/><text x="320" y="213" text-anchor="middle">Configuration</text>
      <rect x="387" y="196" width="118" height="26" rx="5" fill="var(--bg-elevated-2)" stroke="var(--border)"/><text x="446" y="213" text-anchor="middle">Compliance</text>
      <rect x="135" y="228" width="118" height="26" rx="5" fill="var(--bg-elevated-2)" stroke="var(--border)"/><text x="194" y="245" text-anchor="middle">Apps &amp; MAM</text>
      <rect x="261" y="228" width="118" height="26" rx="5" fill="var(--bg-elevated-2)" stroke="var(--border)"/><text x="320" y="245" text-anchor="middle">Endpoint security</text>
      <rect x="387" y="228" width="118" height="26" rx="5" fill="var(--bg-elevated-2)" stroke="var(--border)"/><text x="446" y="245" text-anchor="middle">Updates</text>
      <rect x="135" y="260" width="118" height="26" rx="5" fill="var(--bg-elevated-2)" stroke="var(--border)"/><text x="194" y="277" text-anchor="middle">Scripts &amp; remediation</text>
      <rect x="261" y="260" width="118" height="26" rx="5" fill="var(--bg-elevated-2)" stroke="var(--border)"/><text x="320" y="277" text-anchor="middle">Remote actions</text>
      <rect x="387" y="260" width="118" height="26" rx="5" fill="var(--bg-elevated-2)" stroke="var(--border)"/><text x="446" y="277" text-anchor="middle">RBAC · MAA · audit</text>
    </g>
    <line x1="100" y1="130" x2="180" y2="158" stroke="var(--text-muted)" stroke-width="1.5" marker-end="url(#in-a1)"/>
    <line x1="320" y1="130" x2="320" y2="158" stroke="var(--text-muted)" stroke-width="1.5" marker-end="url(#in-a1)"/>
    <line x1="460" y1="160" x2="530" y2="132" stroke="var(--text-muted)" stroke-width="1.5" marker-end="url(#in-a1)"/>
    <!-- push -->
    <rect x="5" y="320" width="300" height="66" rx="10" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="18" y="342" font-weight="700" fill="var(--text)">PUSH CHANNELS (wake-up only)</text>
    <text x="18" y="362" fill="var(--text-muted)">WNS (Windows) · APNs (Apple) · FCM (Android)</text>
    <text x="18" y="378" fill="var(--text-muted)">the device then checks in over HTTPS</text>
    <!-- devices -->
    <rect x="335" y="320" width="300" height="66" rx="10" fill="var(--bg-elevated-2)" stroke="var(--accent)"/>
    <text x="348" y="342" font-weight="700" fill="var(--accent)">MANAGED DEVICES</text>
    <text x="348" y="362" fill="var(--text-muted)">Windows · macOS · iOS/iPadOS · Android · Linux</text>
    <text x="348" y="378" fill="var(--text-muted)">MDM stack + Intune Management Extension</text>
    <line x1="230" y1="290" x2="160" y2="318" stroke="var(--text-muted)" stroke-width="1.5" marker-end="url(#in-a1)"/>
    <line x1="420" y1="318" x2="420" y2="292" stroke="var(--text-muted)" stroke-width="1.5" marker-end="url(#in-a1)"/>
    <line x1="490" y1="292" x2="490" y2="318" stroke="var(--text-muted)" stroke-width="1.5" marker-end="url(#in-a1)"/>
    <text x="500" y="309" fill="var(--text-muted)">policy / status</text>
    <!-- connectors -->
    <rect x="5" y="404" width="630" height="70" rx="10" fill="none" stroke="var(--text-muted)" stroke-dasharray="5 5"/>
    <text x="18" y="425" font-weight="700" fill="var(--text)">CONNECTORS</text>
    <text x="18" y="446" fill="var(--text-muted)">Defender for Endpoint · Apple ABM/ASM (ADE, VPP) + APNs · Managed Google Play · Cert Connector</text>
    <text x="18" y="460" fill="var(--text-muted)">Cloud PKI · ConfigMgr co-management · Microsoft Tunnel · partner MTD · ServiceNow</text>
  </g>
</svg>
</div>

Three facts from this picture are worth remembering:

1. **Push is only a doorbell.** WNS, APNs and FCM never carry policy. They only tell the device "check in now". The device then pulls everything over HTTPS from Intune.
2. **Compliance becomes identity.** Intune writes the device's compliance state to its Entra ID device object, and Conditional Access reads it from there. That is how "only healthy devices can open email" works.
3. **Everything is an API.** The admin center is just a client of Microsoft Graph. Anything an admin can click, a script (or an attacker with a token) can do, which matters a lot later in this article.

&nbsp;
<h3><strong>How a Windows device actually talks to Intune</strong></h3>
Windows has two management agents, and you need to know both for troubleshooting and for forensics:

<div style="margin:2rem 0;padding:1.25rem;background:var(--bg-elevated);border:1px solid var(--border);border-radius:var(--radius-m);">
<svg viewBox="0 0 640 330" style="width:100%;height:auto;font-family:inherit;" role="img" aria-label="Windows device lifecycle: Entra join triggers MDM auto-enrollment and an MDM certificate; the built-in OMA-DM client syncs SyncML over HTTPS on a cadence of every 3 minutes for 15 minutes, every 15 minutes for 2 hours, then about every 8 hours, or immediately after a WNS push; the Intune Management Extension agent is installed when Win32 apps, scripts or remediations are assigned and checks in about every hour, running content through AgentExecutor as SYSTEM">
  <defs><marker id="in-a2" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto"><path d="M0,0 L8,4 L0,8 z" fill="var(--text-muted)"/></marker></defs>
  <g style="font-size:12px;">
    <rect x="5" y="10" width="140" height="58" rx="8" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="18" y="33" font-weight="700" fill="var(--text)">1 · Join</text>
    <text x="18" y="52" fill="var(--text-muted)">Entra join / Autopilot</text>
    <rect x="170" y="10" width="140" height="58" rx="8" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="183" y="33" font-weight="700" fill="var(--text)">2 · Enroll</text>
    <text x="183" y="52" fill="var(--text-muted)">MDM auto-enrollment</text>
    <rect x="335" y="10" width="140" height="58" rx="8" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="348" y="33" font-weight="700" fill="var(--text)">3 · Certificate</text>
    <text x="348" y="52" fill="var(--text-muted)">MDM cert (LM\My)</text>
    <rect x="500" y="10" width="135" height="58" rx="8" fill="var(--accent)"/>
    <text x="513" y="33" font-weight="700" fill="var(--accent-contrast)">4 · Managed</text>
    <text x="513" y="52" fill="var(--accent-contrast)">two agents start</text>
    <line x1="145" y1="39" x2="167" y2="39" stroke="var(--text-muted)" stroke-width="2" marker-end="url(#in-a2)"/>
    <line x1="310" y1="39" x2="332" y2="39" stroke="var(--text-muted)" stroke-width="2" marker-end="url(#in-a2)"/>
    <line x1="475" y1="39" x2="497" y2="39" stroke="var(--text-muted)" stroke-width="2" marker-end="url(#in-a2)"/>

    <rect x="5" y="95" width="305" height="225" rx="10" fill="var(--bg-elevated-2)" stroke="var(--accent)" stroke-width="2"/>
    <text x="20" y="120" font-weight="700" fill="var(--accent)">AGENT A · built-in OMA-DM client</text>
    <text x="20" y="142" fill="var(--text)">Speaks SyncML over HTTPS to *.manage / *.dm</text>
    <text x="20" y="160" fill="var(--text-muted)">Applies CSP policies (settings catalog,</text>
    <text x="20" y="176" fill="var(--text-muted)">compliance, BitLocker, Defender, LAPS…)</text>
    <text x="20" y="200" font-weight="700" fill="var(--text)">Check-in cadence after enrollment</text>
    <text x="20" y="220" fill="var(--text-muted)">every 3 min for the first 15 min</text>
    <text x="20" y="238" fill="var(--text-muted)">every 15 min for the next 2 hours</text>
    <text x="20" y="256" fill="var(--text-muted)">then about every 8 hours</text>
    <text x="20" y="278" fill="var(--text)">+ immediately after a WNS push</text>
    <text x="20" y="300" fill="var(--text-muted)">Task: \Microsoft\Windows\EnterpriseMgmt\{GUID}</text>

    <rect x="330" y="95" width="305" height="225" rx="10" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="345" y="120" font-weight="700" fill="var(--text)">AGENT B · Intune Management Extension</text>
    <text x="345" y="142" fill="var(--text)">Installed automatically when you assign</text>
    <text x="345" y="160" fill="var(--text-muted)">Win32 apps, platform scripts, remediations,</text>
    <text x="345" y="176" fill="var(--text-muted)">custom compliance, EPM, BIOS config</text>
    <text x="345" y="200" font-weight="700" fill="var(--text)">Behaviour</text>
    <text x="345" y="220" fill="var(--text-muted)">checks in about every 60 minutes,</text>
    <text x="345" y="238" fill="var(--text-muted)">at service start and after reboot</text>
    <text x="345" y="256" fill="var(--text-muted)">runs code via AgentExecutor.exe</text>
    <text x="345" y="278" fill="var(--accent-strong)" font-weight="700">as SYSTEM (or as the user)</text>
    <text x="345" y="300" fill="var(--text-muted)">Logs: ProgramData\…\IntuneManagementExtension</text>
  </g>
</svg>
</div>

The practical meaning: <strong>settings</strong> (CSP policies) can take up to eight hours to land, unless the device gets a push or the user clicks <em>Sync</em>. <strong>Apps and scripts</strong> follow the IME's hourly cycle. When a user says "the policy didn't apply", the first question is always "which agent delivers it?".

> **_NOTE:_**  The same split matters for an incident. A malicious <strong>script</strong> pushed from a compromised admin account typically reaches most online Windows devices within about an hour. A malicious <strong>configuration</strong> spreads more slowly, unless the attacker also triggers a sync.

&nbsp;
<h3><strong>Licensing in 2026 (what changed in July)</strong></h3>
Microsoft's December 2025 packaging announcement took effect on <strong>1 July 2026</strong>. Several features that used to be paid Intune Suite add-ons are now part of the Microsoft 365 E3 and E5 plans:

| Capability | Plan 1 (M365 E3/E5, Business Premium, EMS) | Now in M365 E3 | Now in M365 E5 |
|---|---|---|---|
| MDM, MAM, compliance, config, apps, endpoint security, updates | ✅ | ✅ | ✅ |
| Remote Help | add-on before | ✅ | ✅ |
| Advanced Analytics (device query, timeline, battery health…) | add-on before | ✅ | ✅ |
| Microsoft Tunnel for MAM, specialty devices, firmware updates | add-on before | ✅ | ✅ |
| Endpoint Privilege Management (EPM) | add-on before | — | ✅ |
| Enterprise App Management (app catalog, auto-updates) | add-on before | — | ✅ |
| Microsoft Cloud PKI | add-on before | — | ✅ |
| Security Copilot in Intune (agents) | — | — | ✅ |

> **_NOTE:_**  This table summarises the official announcement at a high level. Check your agreement and the Microsoft licensing guide for your exact SKUs before planning a rollout around a feature.

&nbsp;
<h3><strong>The modules, one by one</strong></h3>
In this section I want to go through every major area of Intune, what it is for, and the one thing I always check in it.

| Module | What it does | Key building blocks | What I always check |
|---|---|---|---|
| **Enrollment** | Brings devices under management | Windows Autopilot (and Autopilot device preparation), Apple ADE via ABM/ASM, Android Enterprise (work profile, fully managed, dedicated), AOSP, macOS ADE + Platform SSO | Enrollment restrictions: who can enroll what, and are personal Windows devices blocked? |
| **Device configuration** | Pushes settings | Settings catalog (preferred), templates, administrative templates (ADMX), custom OMA-URI, Group Policy analytics | Conflicts. One setting configured twice gives an error, not a "winner" |
| **Compliance** | Defines "healthy" | Compliance policies, actions for noncompliance (mark, email, retire), custom compliance scripts, device health attestation | "Mark devices with no compliance policy as" = <strong>Not compliant</strong> |
| **Conditional Access** (Entra) | Turns compliance into access decisions | "Require device to be marked as compliant", app protection policy grants, filters for devices | Is the policy really enforced, or still report-only? |
| **Apps** | Deploys and updates software | Win32 (.intunewin), Microsoft Store (winget), LOB, Microsoft 365 Apps, Enterprise App Catalog, Apple VPP, Managed Google Play | Who can create Win32 apps? An app is just code that runs as SYSTEM |
| **App protection (MAM)** | Protects data inside apps, even on unmanaged phones | App protection policies (copy/paste, save-as, PIN, wipe corporate data), app configuration policies | BYOD covered without forcing full enrollment |
| **Endpoint security** | Security workloads, policy by policy | Antivirus, firewall, attack surface reduction (ASR), disk encryption (BitLocker/FileVault), EDR onboarding, account protection, Windows LAPS, security baselines | Tamper protection on, and BitLocker keys escrowed to Entra ID |
| **Windows updates** | Patch management | Update rings, feature updates, quality updates (with expedite), driver updates, hotpatch, Windows Autopatch | A pilot ring that really receives updates first |
| **Scripts & remediations** | Runs code on devices | Platform scripts (once), remediations (detection + fix on a schedule, or on demand), macOS shell scripts | The most powerful and most dangerous feature. Protect it with Multi Admin Approval |
| **Remote actions** | Act on one device or in bulk | Sync, restart, Defender scan, rotate LAPS/BitLocker, collect diagnostics, locate, <strong>retire, wipe, delete</strong> | Who holds wipe rights, and is it protected by MAA? |
| **EPM** | Removes local admin without breaking work | Elevation rules (automatic, user-confirmed, support-approved), elevation reports | Rules by file hash or certificate, not only by file name |
| **Remote Help** | Secure helpdesk screen sharing | Role-based sessions, logged in Intune | Session logs reviewed and RBAC scoped |
| **Advanced Analytics** | Live and historical device data | Device query (KQL on one device, in near real time), multi-device query, timeline, anomalies | Extremely useful for IR, as we will see later |
| **Cloud PKI** | Certificates without an on-premises CA | Root and issuing CAs in the cloud, SCEP profiles | Certificate templates scoped to the right devices |
| **Tenant administration** | Governs the tenant | RBAC roles and scope tags, Multi Admin Approval, diagnostic settings, connectors, audit logs, terms and conditions | Everything in the security review section below |

&nbsp;
<h3><strong>Network topology and connectivity</strong></h3>
Intune needs no inbound ports. Every connection is <strong>outbound from the device</strong>, mostly TCP 443, to Microsoft's edge (Azure Front Door). Most of the work is making sure your proxy, firewall and TLS inspection don't break that path:

<div style="margin:2rem 0;padding:1.25rem;background:var(--bg-elevated);border:1px solid var(--border);border-radius:var(--radius-m);">
<svg viewBox="0 0 640 360" style="width:100%;height:auto;font-family:inherit;" role="img" aria-label="Network topology: corporate LAN and remote devices go out through a proxy or secure web gateway with TLS inspection bypass for Intune endpoints, to Microsoft's edge, Azure Front Door, then the Intune service, Entra ID, the push services and content delivery networks; on-premises there is the Certificate Connector and optionally Microsoft Connected Cache; there are no inbound connections">
  <defs><marker id="in-a3" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto"><path d="M0,0 L8,4 L0,8 z" fill="var(--text-muted)"/></marker></defs>
  <g style="font-size:11.5px;">
    <rect x="5" y="10" width="250" height="250" rx="12" fill="none" stroke="var(--text-muted)" stroke-dasharray="5 5"/>
    <text x="18" y="32" font-weight="700" fill="var(--text)">CORPORATE NETWORK</text>
    <rect x="20" y="46" width="105" height="44" rx="7" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="72" y="66" text-anchor="middle" fill="var(--text)">💻 Laptops</text><text x="72" y="82" text-anchor="middle" fill="var(--text-muted)">DO peering 7680</text>
    <rect x="135" y="46" width="105" height="44" rx="7" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="187" y="66" text-anchor="middle" fill="var(--text)">📦 Connected</text><text x="187" y="82" text-anchor="middle" fill="var(--text-muted)">Cache (optional)</text>
    <rect x="20" y="104" width="220" height="44" rx="7" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="130" y="124" text-anchor="middle" fill="var(--text)">🔐 Intune Certificate Connector</text><text x="130" y="140" text-anchor="middle" fill="var(--text-muted)">next to your CA (outbound only)</text>
    <rect x="20" y="180" width="220" height="64" rx="7" fill="var(--accent)" fill-opacity="0.15" stroke="var(--accent)" stroke-width="2"/>
    <text x="130" y="202" text-anchor="middle" font-weight="700" fill="var(--accent)">Proxy / SWG / firewall</text>
    <text x="130" y="220" text-anchor="middle" fill="var(--text)">TLS inspection BYPASS for</text>
    <text x="130" y="236" text-anchor="middle" fill="var(--text)">*.manage · *.dm · attestation</text>
    <line x1="72" y1="90" x2="100" y2="178" stroke="var(--text-muted)" stroke-width="1.5" marker-end="url(#in-a3)"/>
    <line x1="130" y1="148" x2="130" y2="178" stroke="var(--text-muted)" stroke-width="1.5" marker-end="url(#in-a3)"/>
    <rect x="5" y="278" width="250" height="74" rx="12" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="18" y="300" font-weight="700" fill="var(--text)">REMOTE / HOME DEVICES</text>
    <text x="18" y="320" fill="var(--text-muted)">direct to internet, or via SSE / VPN.</text>
    <text x="18" y="338" fill="var(--text-muted)">Split-tunnel Intune if you use a VPN</text>

    <line x1="240" y1="212" x2="318" y2="182" stroke="var(--accent)" stroke-width="2.5" marker-end="url(#in-a3)"/>
    <line x1="255" y1="315" x2="318" y2="200" stroke="var(--accent)" stroke-width="2.5" marker-end="url(#in-a3)"/>
    <text x="262" y="246" fill="var(--accent)" font-weight="700">TCP 443</text>
    <text x="262" y="262" fill="var(--text-muted)">(80 for some CDN)</text>

    <rect x="320" y="150" width="90" height="80" rx="10" fill="var(--accent)"/>
    <text x="365" y="180" text-anchor="middle" font-weight="700" fill="var(--accent-contrast)">Azure</text>
    <text x="365" y="196" text-anchor="middle" font-weight="700" fill="var(--accent-contrast)">Front</text>
    <text x="365" y="212" text-anchor="middle" font-weight="700" fill="var(--accent-contrast)">Door</text>

    <g fill="var(--text)">
      <rect x="440" y="10" width="195" height="40" rx="7" fill="var(--bg-elevated-2)" stroke="var(--border)"/><text x="452" y="28" font-weight="700">Intune service</text><text x="452" y="43" fill="var(--text-muted)">*.manage / *.dm.microsoft.com</text>
      <rect x="440" y="58" width="195" height="40" rx="7" fill="var(--bg-elevated-2)" stroke="var(--border)"/><text x="452" y="76" font-weight="700">Entra ID</text><text x="452" y="91" fill="var(--text-muted)">login.microsoftonline.com …</text>
      <rect x="440" y="106" width="195" height="40" rx="7" fill="var(--bg-elevated-2)" stroke="var(--border)"/><text x="452" y="124" font-weight="700">IME / Win32 CDN</text><text x="452" y="139" fill="var(--text-muted)">imeswd{a|b|c}-afd-*.manage…</text>
      <rect x="440" y="154" width="195" height="40" rx="7" fill="var(--bg-elevated-2)" stroke="var(--border)"/><text x="452" y="172" font-weight="700">Push</text><text x="452" y="187" fill="var(--text-muted)">*.notify / *.wns.windows.com</text>
      <rect x="440" y="202" width="195" height="40" rx="7" fill="var(--bg-elevated-2)" stroke="var(--border)"/><text x="452" y="220" font-weight="700">Updates &amp; DO</text><text x="452" y="235" fill="var(--text-muted)">*.delivery.mp / *.do.dsp…</text>
      <rect x="440" y="250" width="195" height="40" rx="7" fill="var(--bg-elevated-2)" stroke="var(--border)"/><text x="452" y="268" font-weight="700">Attestation (MAA)</text><text x="452" y="283" fill="var(--text-muted)">intunemaape*.attest.azure.net</text>
      <rect x="440" y="298" width="195" height="40" rx="7" fill="var(--bg-elevated-2)" stroke="var(--border)"/><text x="452" y="316" font-weight="700">Apple / Google</text><text x="452" y="331" fill="var(--text-muted)">APNs 443/5223 · FCM · Play</text>
    </g>
    <g stroke="var(--text-muted)" stroke-width="1.2">
      <line x1="410" y1="190" x2="438" y2="30"/><line x1="410" y1="190" x2="438" y2="78"/><line x1="410" y1="190" x2="438" y2="126"/>
      <line x1="410" y1="190" x2="438" y2="174"/><line x1="410" y1="190" x2="438" y2="222"/><line x1="410" y1="190" x2="438" y2="270"/><line x1="410" y1="190" x2="438" y2="318"/>
    </g>
  </g>
</svg>
</div>

These are the rules I follow, all taken from Microsoft's official endpoint page:

| Requirement | Detail |
|---|---|
| **Core service** | `*.manage.microsoft.com`, `manage.microsoft.com`, `*.dm.microsoft.com`, `EnterpriseEnrollment.manage.microsoft.com` on TCP 80/443. If your firewall can't use FQDNs, allow the Intune and `AzureFrontDoor.MicrosoftSecurity` IP ranges |
| **No TLS inspection** | Inspection is <strong>not supported</strong> for `*.manage.microsoft.com`, `*.dm.microsoft.com`, the attestation endpoints, Defender for Endpoint, EPM and the Store API endpoints. Inspecting them breaks enrollment and check-ins, and makes compliance fail |
| **Unauthenticated proxy** | Some tasks need unauthenticated proxy access to `manage.microsoft.com`, `*.azureedge.net` and `graph.microsoft.com`. Remember that SYSTEM can't answer a proxy login prompt |
| **Win32 apps and scripts** | Region-specific CDNs (for example `imeswdb-afd-primary.manage.microsoft.com` for Europe), and the proxy must allow <strong>HTTP partial responses</strong> (byte ranges) |
| **Windows push** | `*.notify.windows.com`, `*.wns.windows.com` on 443. Without them, remote actions wait for the next scheduled check-in |
| **Health attestation** | Windows 11 uses Microsoft Azure Attestation (`intunemaape*.attest.azure.net`) for your tenant's region. If it's blocked, devices with BitLocker, Secure Boot or Code Integrity compliance rules become noncompliant |
| **Delivery Optimization** | `*.do.dsp.mp.microsoft.com`, `*.dl.delivery.mp.microsoft.com`. Peer-to-peer traffic uses TCP 7680 (and 3544 for Teredo). Microsoft Connected Cache saves WAN bandwidth at large sites |
| **Autopilot** | Windows Update endpoints, `time.windows.com` (UDP 123) and TPM attestation (`ekop.intel.com`, `ftpm.amd.com`, `ekcert.spserv.microsoft.com`) |
| **Apple / Android** | APNs (TCP 443 and 5223 to `17.0.0.0/8`), Firebase Cloud Messaging and the Android Enterprise hosts from Google's own documentation |

Microsoft also publishes a connectivity test script. Run it from a managed device as the user, and again as SYSTEM, because they often go through different proxy paths:

```powershell
# Download Test-IntuneAFDConnectivity.ps1 from the "Network endpoints for Microsoft Intune" page, then:
.\Test-IntuneAFDConnectivity.ps1 -LogLevel Detailed -OutputPath "C:\Logs" -Verbose

# Run it as SYSTEM to test the device-context path (the one the agents use)
.\PsExec.exe -accepteula -i -s powershell.exe
```

> **_NOTE:_**  Microsoft states that the old PowerShell scripts that read Intune endpoints from the Office 365 endpoint web service <strong>no longer return accurate data</strong>. Use the consolidated list on the official page instead.

&nbsp;
<h3><strong>How to build it: a phased implementation</strong></h3>
Lets go through how I would build an Intune tenant from zero, or rebuild one that grew without a plan. The order matters. Most failed rollouts enforce Conditional Access before compliance reporting is trustworthy.

<div style="margin:2rem 0;padding:1.25rem;background:var(--bg-elevated);border:1px solid var(--border);border-radius:var(--radius-m);">
<svg viewBox="0 0 640 420" style="width:100%;height:auto;font-family:inherit;" role="img" aria-label="Six implementation phases: phase 0 foundations, phase 1 pilot enrollment, phase 2 baseline policies, phase 3 apps and updates in rings, phase 4 enforce Conditional Access, phase 5 operate and monitor">
  <line x1="40" y1="25" x2="40" y2="395" stroke="var(--border)" stroke-width="2"/>
  <g style="font-size:12.5px;">
    <circle cx="40" cy="25" r="12" fill="var(--accent)"/><text x="40" y="29" text-anchor="middle" font-size="11" font-weight="700" fill="var(--accent-contrast)">0</text>
    <text x="68" y="22" font-weight="700" fill="var(--text)">Foundations — before the first device</text>
    <text x="68" y="40" fill="var(--text-muted)">RBAC + scope tags · PIM · break-glass · naming · groups &amp; filters · diagnostics ON</text>
    <circle cx="40" cy="95" r="12" fill="var(--accent)"/><text x="40" y="99" text-anchor="middle" font-size="11" font-weight="700" fill="var(--accent-contrast)">1</text>
    <text x="68" y="92" font-weight="700" fill="var(--text)">Pilot enrollment — IT devices only</text>
    <text x="68" y="110" fill="var(--text-muted)">Enrollment restrictions · Autopilot profile · ADE/ABM · Android Enterprise binding · Company Portal</text>
    <circle cx="40" cy="165" r="12" fill="var(--accent)"/><text x="40" y="169" text-anchor="middle" font-size="11" font-weight="700" fill="var(--accent-contrast)">2</text>
    <text x="68" y="162" font-weight="700" fill="var(--text)">Security baseline — report first</text>
    <text x="68" y="180" fill="var(--text-muted)">BitLocker · Defender + tamper · firewall · ASR audit→block · LAPS · compliance (CA report-only)</text>
    <circle cx="40" cy="235" r="12" fill="var(--accent)"/><text x="40" y="239" text-anchor="middle" font-size="11" font-weight="700" fill="var(--accent-contrast)">3</text>
    <text x="68" y="232" font-weight="700" fill="var(--text)">Apps &amp; updates in rings</text>
    <text x="68" y="250" fill="var(--text-muted)">Pilot → early adopters → broad · Win32 standard · update rings / Autopatch · MAM</text>
    <circle cx="40" cy="305" r="12" fill="var(--accent)"/><text x="40" y="309" text-anchor="middle" font-size="11" font-weight="700" fill="var(--accent-contrast)">4</text>
    <text x="68" y="302" font-weight="700" fill="var(--text)">Enforce — when compliance data is trusted</text>
    <text x="68" y="320" fill="var(--text-muted)">CA "require compliant device" per app → all cloud apps · grace periods · exception process</text>
    <circle cx="40" cy="375" r="12" fill="var(--accent-strong)"/><text x="40" y="379" text-anchor="middle" font-size="11" font-weight="700" fill="var(--accent-contrast)">5</text>
    <text x="68" y="372" font-weight="700" fill="var(--text)">Operate &amp; defend</text>
    <text x="68" y="390" fill="var(--text-muted)">SIEM detections · Multi Admin Approval · config backup · monthly review · stale device cleanup</text>
  </g>
</svg>
</div>

<strong>Phase 0 — Foundations.</strong> Decide your <strong>RBAC model</strong> before anyone gets "Intune Administrator". Use built-in Intune roles (Help Desk Operator, Application Manager, Policy and Profile Manager, Read Only Operator, Endpoint Security Manager) or custom roles, and limit each one with <strong>scope tags</strong> by region or business unit. The Entra "Intune Administrator" role should be eligible through PIM only, never permanent. Turn on diagnostic settings on day one. You can't investigate logs that were never exported.

<strong>Phase 1 — Pilot enrollment.</strong> Block personal Windows enrollment and require corporate identifiers if needed. Register devices in Autopilot through your hardware vendor, and connect Apple Business Manager and Managed Google Play. Name groups and policies with a convention that tells you the platform, the purpose and the ring, for example `WIN-SEC-BitLocker-Ring1`.

<strong>Phase 2 — Security baseline.</strong> Build the baseline mostly in the <strong>settings catalog</strong> and <strong>endpoint security</strong> policies, because they are easier to review than templates. Start ASR rules in audit mode and move each one to block after reviewing the hits. Create compliance policies, and point Conditional Access at them in <em>report-only</em> mode.

<strong>Phase 3 — Apps and updates in rings.</strong> Use the same three rings for apps, updates and new policies, so a bad change only hits a small group first. Use <strong>assignment filters</strong> (by OS version, model or ownership) instead of creating hundreds of groups.

<strong>Phase 4 — Enforce.</strong> Look at the report-only results. When the number of "would be blocked" devices is low and explained, turn on enforcement, one app at a time.

<strong>Phase 5 — Operate.</strong> Back up your configuration, monitor the SIEM detections from the next section, and review the tenant monthly with the security review script at the end.

Here is how compliance turns into an access decision. It is the heart of a Zero Trust design with Intune:

<div style="margin:2rem 0;padding:1.25rem;background:var(--bg-elevated);border:1px solid var(--border);border-radius:var(--radius-m);">
<svg viewBox="0 0 640 150" style="width:100%;height:auto;font-family:inherit;" role="img" aria-label="Compliance to access flow: device evaluates compliance policy, reports to Intune, Intune writes isCompliant on the Entra device object, Conditional Access checks it at sign-in, and access is granted or blocked">
  <defs><marker id="in-a4" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto"><path d="M0,0 L8,4 L0,8 z" fill="var(--text-muted)"/></marker></defs>
  <g style="font-size:11.5px;">
    <rect x="5" y="30" width="110" height="64" rx="8" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="60" y="56" text-anchor="middle" font-weight="700" fill="var(--text)">Device</text><text x="60" y="74" text-anchor="middle" fill="var(--text-muted)">evaluates rules</text>
    <rect x="135" y="30" width="110" height="64" rx="8" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="190" y="56" text-anchor="middle" font-weight="700" fill="var(--text)">Intune</text><text x="190" y="74" text-anchor="middle" fill="var(--text-muted)">compliance state</text>
    <rect x="265" y="30" width="110" height="64" rx="8" fill="var(--bg-elevated-2)" stroke="var(--accent)" stroke-width="2"/>
    <text x="320" y="56" text-anchor="middle" font-weight="700" fill="var(--accent)">Entra device</text><text x="320" y="74" text-anchor="middle" fill="var(--text-muted)">isCompliant = true</text>
    <rect x="395" y="30" width="110" height="64" rx="8" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="450" y="56" text-anchor="middle" font-weight="700" fill="var(--text)">Conditional</text><text x="450" y="74" text-anchor="middle" fill="var(--text-muted)">Access at sign-in</text>
    <rect x="525" y="14" width="110" height="40" rx="8" fill="var(--accent)"/><text x="580" y="39" text-anchor="middle" font-weight="700" fill="var(--accent-contrast)">✔ access</text>
    <rect x="525" y="70" width="110" height="40" rx="8" fill="none" stroke="var(--text-muted)"/><text x="580" y="95" text-anchor="middle" fill="var(--text)">✖ block / remediate</text>
    <line x1="115" y1="62" x2="132" y2="62" stroke="var(--text-muted)" stroke-width="2" marker-end="url(#in-a4)"/>
    <line x1="245" y1="62" x2="262" y2="62" stroke="var(--text-muted)" stroke-width="2" marker-end="url(#in-a4)"/>
    <line x1="375" y1="62" x2="392" y2="62" stroke="var(--text-muted)" stroke-width="2" marker-end="url(#in-a4)"/>
    <line x1="505" y1="55" x2="522" y2="36" stroke="var(--text-muted)" stroke-width="2" marker-end="url(#in-a4)"/>
    <line x1="505" y1="70" x2="522" y2="88" stroke="var(--text-muted)" stroke-width="2" marker-end="url(#in-a4)"/>
    <text x="5" y="136" fill="var(--text-muted)">A compliance setting nobody enforces in CA is only a report. A CA policy without trusted compliance data is only an outage.</text>
  </g>
</svg>
</div>

A useful habit from day one is a configuration backup, so you can diff policies after an incident. This snippet exports the main policy types as JSON with Microsoft Graph PowerShell:

```powershell
Connect-MgGraph -Scopes "DeviceManagementConfiguration.Read.All","DeviceManagementApps.Read.All" -NoWelcome
$base  = "https://graph.microsoft.com/beta/deviceManagement"
$types = "configurationPolicies","deviceConfigurations","deviceCompliancePolicies",
         "deviceManagementScripts","deviceHealthScripts","intents"
$out   = ".\intune-backup\$(Get-Date -f yyyyMMdd)"
foreach ($t in $types) {
    $null = New-Item -ItemType Directory -Path "$out\$t" -Force
    $uri  = "$base/$t"
    while ($uri) {
        $page = Invoke-MgGraphRequest -Method GET -Uri $uri -OutputType PSObject
        foreach ($p in $page.value) {
            $p | ConvertTo-Json -Depth 20 | Set-Content "$out\$t\$($p.id).json"
        }
        $uri = $page.'@odata.nextLink'
    }
}
```

> **_NOTE:_**  Settings catalog policies (`configurationPolicies`) keep their individual settings in a separate `/settings` relationship. For a full-fidelity backup, also request `configurationPolicies/{id}?$expand=settings`, or use a maintained community tool such as IntuneManagement or Microsoft365DSC.

&nbsp;
<h3><strong>Logging: what Intune records</strong></h3>
Now the part security teams usually miss. Intune telemetry comes from <strong>four different places</strong>, and you need all of them to tell a complete story:

| Source | What's in it | Where it lives | Latency |
|---|---|---|---|
| **Intune AuditLogs** | Every change and remote action: create/update/delete/assign of policies, apps and scripts, wipes, retires, role changes, MAA approvals. Who, when, which object | Diagnostic setting → `IntuneAuditLogs` table | Sent immediately (usually visible within 30 min) |
| **Intune OperationalLogs** | Enrollment successes and failures, noncompliant device details | → `IntuneOperationalLogs` | Immediately |
| **DeviceComplianceOrg** | Organizational compliance report, device by device | → `IntuneDeviceComplianceOrg` | Once per 24 h, up to 48 h |
| **IntuneDevices** | Device inventory: name, OS, owner, compliance, last contact | → `IntuneDevices` | Once per 24 h, up to 48 h |
| **Entra ID sign-in + audit** | Who signed in to the Intune admin center or Graph, from where, with what MFA, plus role assignments and PIM activations | Entra diagnostic settings → `SigninLogs`, `AuditLogs`, `AADNonInteractiveUserSignInLogs`, `AADServicePrincipalSignInLogs` | Minutes |
| **Microsoft Graph activity logs** | Every Graph API call: URI, method, app, IP, status. Shows scripted or automated Intune abuse | Entra diagnostic settings → `MicrosoftGraphActivityLogs` | Minutes |
| **Defender for Endpoint** | What actually ran on the device: AgentExecutor → powershell.exe, files, network | Defender XDR advanced hunting / Sentinel | Near real time |
| **Device-local logs** | IME logs, MDM event logs, registry. The device's own view | On the endpoint (see the DFIR section) | Collect on demand |

> **_NOTE:_**  Intune's own documentation says the export pipeline <strong>might duplicate up to 100% of the data published in a 24-hour period</strong>, and that the log schemas can change. Your SIEM pipeline must de-duplicate, and your detections should use `has` and `contains` instead of exact string matches.

&nbsp;
<h3><strong>Getting Intune telemetry into a SIEM, step by step</strong></h3>
The answer to "can it go to our SIEM?" is <strong>yes</strong>, and there are three supported paths. All of them start from the same place: Intune <strong>Diagnostic settings</strong>.

<div style="margin:2rem 0;padding:1.25rem;background:var(--bg-elevated);border:1px solid var(--border);border-radius:var(--radius-m);">
<svg viewBox="0 0 640 300" style="width:100%;height:auto;font-family:inherit;" role="img" aria-label="SIEM pipeline: Intune diagnostic settings send AuditLogs, OperationalLogs, DeviceComplianceOrg and IntuneDevices to three destinations: a Log Analytics workspace used by Microsoft Sentinel, an Event Hubs namespace consumed by Splunk, QRadar, Elastic, Sumo Logic or custom code, and a storage account for long-term archive; Entra ID and Graph activity logs follow the same path; a Graph API pull of auditEvents is an alternative">
  <defs><marker id="in-a5" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto"><path d="M0,0 L8,4 L0,8 z" fill="var(--text-muted)"/></marker></defs>
  <g style="font-size:11.5px;">
    <rect x="5" y="20" width="170" height="200" rx="10" fill="var(--bg-elevated-2)" stroke="var(--accent)" stroke-width="2"/>
    <text x="18" y="44" font-weight="700" fill="var(--accent)">INTUNE</text>
    <text x="18" y="62" fill="var(--text-muted)">Reports → Diagnostic settings</text>
    <text x="18" y="88" fill="var(--text)">☑ AuditLogs</text>
    <text x="18" y="108" fill="var(--text)">☑ OperationalLogs</text>
    <text x="18" y="128" fill="var(--text)">☑ DeviceComplianceOrg</text>
    <text x="18" y="148" fill="var(--text)">☑ IntuneDevices</text>
    <text x="18" y="176" font-weight="700" fill="var(--text)">ENTRA ID (same pattern)</text>
    <text x="18" y="194" fill="var(--text-muted)">SignInLogs · AuditLogs ·</text>
    <text x="18" y="210" fill="var(--text-muted)">MicrosoftGraphActivityLogs</text>

    <rect x="235" y="20" width="160" height="56" rx="8" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="248" y="43" font-weight="700" fill="var(--text)">① Log Analytics</text><text x="248" y="62" fill="var(--text-muted)">workspace</text>
    <rect x="235" y="112" width="160" height="56" rx="8" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="248" y="135" font-weight="700" fill="var(--text)">② Event Hubs</text><text x="248" y="154" fill="var(--text-muted)">insights-logs-&lt;category&gt;</text>
    <rect x="235" y="204" width="160" height="56" rx="8" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="248" y="227" font-weight="700" fill="var(--text)">③ Storage account</text><text x="248" y="246" fill="var(--text-muted)">cheap long retention</text>

    <rect x="455" y="20" width="180" height="56" rx="8" fill="var(--accent)"/>
    <text x="468" y="43" font-weight="700" fill="var(--accent-contrast)">Microsoft Sentinel</text><text x="468" y="62" fill="var(--accent-contrast)">native KQL tables</text>
    <rect x="455" y="96" width="180" height="88" rx="8" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="468" y="118" font-weight="700" fill="var(--text)">Any SIEM / data lake</text>
    <text x="468" y="137" fill="var(--text-muted)">Splunk (MSCS add-on)</text>
    <text x="468" y="154" fill="var(--text-muted)">QRadar (Event Hubs protocol)</text>
    <text x="468" y="171" fill="var(--text-muted)">Elastic · Sumo · custom code</text>
    <rect x="455" y="204" width="180" height="56" rx="8" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="468" y="227" font-weight="700" fill="var(--text)">Forensic archive</text><text x="468" y="246" fill="var(--text-muted)">immutable, 1–7 years</text>

    <line x1="175" y1="100" x2="232" y2="50" stroke="var(--text-muted)" stroke-width="1.5" marker-end="url(#in-a5)"/>
    <line x1="175" y1="120" x2="232" y2="140" stroke="var(--text-muted)" stroke-width="1.5" marker-end="url(#in-a5)"/>
    <line x1="175" y1="140" x2="232" y2="230" stroke="var(--text-muted)" stroke-width="1.5" marker-end="url(#in-a5)"/>
    <line x1="395" y1="48" x2="452" y2="48" stroke="var(--text-muted)" stroke-width="1.5" marker-end="url(#in-a5)"/>
    <line x1="395" y1="140" x2="452" y2="140" stroke="var(--text-muted)" stroke-width="1.5" marker-end="url(#in-a5)"/>
    <line x1="395" y1="232" x2="452" y2="232" stroke="var(--text-muted)" stroke-width="1.5" marker-end="url(#in-a5)"/>
    <text x="5" y="290" fill="var(--text-muted)">Alternative ④: pull /deviceManagement/auditEvents from Microsoft Graph on a schedule (no Azure subscription needed).</text>
  </g>
</svg>
</div>

<strong>Step 1 — Prerequisites.</strong> You need an Azure subscription in the same tenant, an account with the <strong>Intune Administrator</strong> role (Entra), and one of the destinations: a Log Analytics workspace, an Event Hubs namespace, or a general-purpose storage account.

<strong>Step 2 — Create the destination.</strong> For a non-Microsoft SIEM, create an Event Hubs namespace and a listen-only key for the SIEM:

```bash
az group create -n rg-secops-intune -l westeurope
az eventhubs namespace create -g rg-secops-intune -n eh-intune-logs --sku Standard
# Azure Monitor creates one hub per category (insights-logs-auditlogs, ...) automatically.
# Give the SIEM a listen-only key - never the RootManageSharedAccessKey:
az eventhubs namespace authorization-rule create -g rg-secops-intune \
   --namespace-name eh-intune-logs -n siem-listen --rights Listen
az eventhubs namespace authorization-rule keys list -g rg-secops-intune \
   --namespace-name eh-intune-logs -n siem-listen --query primaryConnectionString -o tsv
```

<strong>Step 3 — Turn on the Intune diagnostic setting.</strong> In the <a href="https://intune.microsoft.com" target="_blank" rel="noopener">Intune admin center</a> go to <strong>Reports → Diagnostic settings → Add diagnostic setting</strong>. Select all four log categories (AuditLogs, OperationalLogs, DeviceComplianceOrg, IntuneDevices), then choose <em>Send to Log Analytics workspace</em> (your Sentinel workspace), <em>Stream to an event hub</em> (your SIEM namespace), and/or <em>Archive to a storage account</em>. Save.

<strong>Step 4 — Do the same in Entra ID.</strong> In the Entra admin center go to <strong>Monitoring &amp; health → Diagnostic settings</strong>, and send SignInLogs, AuditLogs, NonInteractiveUserSignInLogs, ServicePrincipalSignInLogs and <strong>MicrosoftGraphActivityLogs</strong> to the same destination. Without these you can see <em>what</em> happened in Intune, but not <em>how the actor got in</em>.

<strong>Step 5 — Connect the SIEM.</strong>

| SIEM | How it reads the data |
|---|---|
| **Microsoft Sentinel** | Nothing to install. The tables (`IntuneAuditLogs`, `IntuneOperationalLogs`, `IntuneDeviceComplianceOrg`, `IntuneDevices`) appear in the workspace |
| **Splunk** | Splunk Add-on for Microsoft Cloud Services → <em>Azure Event Hub</em> input with the listen key (sourcetype `mscs:azure:eventhub`) |
| **IBM QRadar** | Microsoft Azure Event Hubs protocol on a log source with the connection string |
| **Elastic / Sumo Logic / others** | Their Azure Event Hubs integrations, or a small consumer like the one below |

If your SIEM has no Event Hubs connector, this small consumer reads the hub, removes duplicates and forwards clean JSON lines. Replace `forward()` with your SIEM's HTTP or syslog input:

```python
"""Read Intune diagnostic logs from Azure Event Hubs, de-duplicate, forward as JSON lines."""
import hashlib, json, os
from azure.eventhub import EventHubConsumerClient

seen = set()                                   # use Redis / a DB with a TTL in production

def dedup_key(rec: dict) -> str:
    props = rec.get("properties") or {}
    if isinstance(props, str):
        props = json.loads(props)
    # audit records carry a unique AuditEventId; fall back to a content hash
    return props.get("AuditEventId") or hashlib.sha256(json.dumps(rec, sort_keys=True).encode()).hexdigest()

def forward(rec: dict):
    print(json.dumps({"source": "intune", "category": rec.get("category"),
                      "time": rec.get("time"), "operation": rec.get("operationName"),
                      "identity": rec.get("identity"), "raw": rec}))   # -> replace with your SIEM's HTTP/syslog input

def on_event(partition_context, event):
    for rec in json.loads(event.body_as_str())["records"]:       # Azure Monitor wraps rows in "records"
        key = dedup_key(rec)
        if key in seen:
            continue                                              # Intune can re-send up to 100% of a day's data
        seen.add(key)
        forward(rec)
    partition_context.update_checkpoint(event)

client = EventHubConsumerClient.from_connection_string(
    os.environ["EH_CONN"], consumer_group="siem", eventhub_name="insights-logs-auditlogs")
with client:
    client.receive(on_event=on_event, starting_position="-1")
```

> **_NOTE:_**  Create a dedicated consumer group for each reader (`siem`, `archive`, …). Two readers on the same consumer group fight over partitions and lose events. Also note that this in-memory checkpoint is only for testing. In production, use a blob checkpoint store so a restart doesn't replay or skip data.

<strong>Step 6 — Validate.</strong> Make a harmless change, like renaming a test policy, and confirm the event arrives with the right actor:

```sql
IntuneAuditLogs
| where TimeGenerated > ago(1h)
| extend P = todynamic(Properties)
| project TimeGenerated, OperationName, Identity, ResultType,
          Targets = tostring(P.TargetDisplayNames), ActorType = tostring(P.ActorType)
| order by TimeGenerated desc
```

&nbsp;
<h3><strong>Detections worth building first</strong></h3>
These are the analytics rules I would deploy on day one. They focus on <strong>Intune used as a weapon</strong>, because that is the scenario with the largest blast radius.

<strong>1. Mass wipe or retire (the Stryker pattern)</strong>

```sql
IntuneAuditLogs
| where TimeGenerated > ago(1h)
| where OperationName has_any ("wipe", "retire", "delete") and OperationName has "ManagedDevice"
| mv-expand Target = todynamic(Properties).TargetObjectIds to typeof(string)
| summarize Devices = dcount(Target), Ops = make_set(OperationName),
            First = min(TimeGenerated), Last = max(TimeGenerated)
            by Identity, bin(TimeGenerated, 15m)
| where Devices >= 5                                  // tune to your normal helpdesk volume
```

<strong>2. A script or remediation created and assigned by the same person within a short window</strong>

```sql
let window = 2h;
IntuneAuditLogs
| where TimeGenerated > ago(1d)
| where OperationName has_any ("DeviceManagementScript", "DeviceHealthScript", "DeviceShellScript")
| extend Action = case(OperationName has "Create", "create", OperationName has "Assign", "assign",
                       OperationName has "Patch", "update", "other")
| summarize Actions = make_set(Action), Names = make_set(tostring(todynamic(Properties).TargetDisplayNames)),
            First = min(TimeGenerated), Last = max(TimeGenerated) by Identity
| where Actions has "assign" and (Actions has "create" or Actions has "update") and Last - First < window
```

<strong>3. RBAC changes and Multi Admin Approval tampering</strong>

```sql
IntuneAuditLogs
| where TimeGenerated > ago(1d)
| where OperationName has_any ("RoleAssignment", "RoleDefinition", "OperationApprovalPolic", "ScopeTag")
| project TimeGenerated, Identity, OperationName, Targets = tostring(todynamic(Properties).TargetDisplayNames)
```

<strong>4. Intune operations through Graph from an unusual app or IP</strong>

```sql
MicrosoftGraphActivityLogs
| where TimeGenerated > ago(1d)
| where RequestUri has "/deviceManagement/"
| where RequestMethod in ("POST", "PATCH", "DELETE")
| extend Op = case(RequestUri has "/wipe", "WIPE", RequestUri has "/retire", "RETIRE",
                   RequestUri has "deviceManagementScripts", "SCRIPT", RequestUri has "deviceHealthScripts", "REMEDIATION", "OTHER")
| summarize Calls = count(), Ops = make_set(Op), IPs = make_set(IPAddress)
            by AppId, UserId, ServicePrincipalId
| where Ops has_any ("WIPE", "RETIRE", "SCRIPT", "REMEDIATION")
```

<strong>5. Intune admin sign-in that doesn't look like your admins</strong>

```sql
SigninLogs
| where TimeGenerated > ago(1d)
| where AppDisplayName has_any ("Microsoft Intune", "Microsoft Graph Command Line Tools", "Microsoft Graph PowerShell")
| where ResultType == 0
| extend Country = tostring(LocationDetails.countryOrRegion)
| summarize Countries = make_set(Country), IPs = make_set(IPAddress), Apps = make_set(AppDisplayName) by UserPrincipalName
| join kind=inner (IdentityInfo | where AssignedRoles has "Intune Administrator" | distinct AccountUPN)
    on $left.UserPrincipalName == $right.AccountUPN
```

<strong>6. What actually ran on endpoints from Intune (Defender for Endpoint)</strong>

```sql
DeviceProcessEvents
| where Timestamp > ago(1d)
| where InitiatingProcessFileName =~ "AgentExecutor.exe"
| where FileName in~ ("powershell.exe", "pwsh.exe", "cmd.exe")
| summarize Devices = dcount(DeviceId), Sample = any(ProcessCommandLine) by SHA256 = InitiatingProcessSHA256, FileName
| order by Devices desc
```

> **_NOTE:_**  The table names, `OperationName` values and `Properties` fields above match the documented schemas today, but Microsoft warns that these schemas can change. Test each rule against your own data before enabling it, and keep the matching broad (`has_any`) rather than exact.

&nbsp;
<h3><strong>DFIR on Intune — part 1: the three angles</strong></h3>
In an investigation, Intune shows up in three very different roles:

<div style="margin:2rem 0;padding:1.25rem;background:var(--bg-elevated);border:1px solid var(--border);border-radius:var(--radius-m);">
<svg viewBox="0 0 640 200" style="width:100%;height:auto;font-family:inherit;" role="img" aria-label="Three DFIR angles: Intune as evidence source, with device artifacts and cloud logs; Intune as an IR tool, with remote actions, remediations, device query and collect diagnostics; Intune as the attack surface, where a compromised admin can wipe devices or run scripts as SYSTEM">
  <g style="font-size:12px;">
    <rect x="5" y="10" width="200" height="180" rx="12" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="20" y="36" font-weight="700" font-size="14" fill="var(--text)">🧾 Evidence source</text>
    <text x="20" y="62" fill="var(--text-muted)">IME logs, MDM event logs,</text>
    <text x="20" y="80" fill="var(--text-muted)">registry, cached scripts</text>
    <text x="20" y="104" fill="var(--text-muted)">Audit, operational and</text>
    <text x="20" y="122" fill="var(--text-muted)">Graph activity logs</text>
    <text x="20" y="152" fill="var(--text)" font-weight="700">"What was pushed,</text>
    <text x="20" y="170" fill="var(--text)" font-weight="700">and did it run?"</text>

    <rect x="220" y="10" width="200" height="180" rx="12" fill="var(--bg-elevated-2)" stroke="var(--accent)" stroke-width="2"/>
    <text x="235" y="36" font-weight="700" font-size="14" fill="var(--accent)">🧰 IR tool</text>
    <text x="235" y="62" fill="var(--text-muted)">Device query (live KQL)</text>
    <text x="235" y="80" fill="var(--text-muted)">On-demand remediations</text>
    <text x="235" y="98" fill="var(--text-muted)">Collect diagnostics</text>
    <text x="235" y="116" fill="var(--text-muted)">Rotate LAPS / BitLocker keys</text>
    <text x="235" y="134" fill="var(--text-muted)">MDE isolate via Defender</text>
    <text x="235" y="160" fill="var(--text)" font-weight="700">"Reach every device</text>
    <text x="235" y="178" fill="var(--text)" font-weight="700">in under an hour"</text>

    <rect x="435" y="10" width="200" height="180" rx="12" fill="var(--bg-elevated-2)" stroke="var(--accent-strong)" stroke-width="2"/>
    <text x="450" y="36" font-weight="700" font-size="14" fill="var(--accent-strong)">🎯 Attack surface</text>
    <text x="450" y="62" fill="var(--text-muted)">Compromised admin or</text>
    <text x="450" y="80" fill="var(--text-muted)">Graph app = SYSTEM on</text>
    <text x="450" y="98" fill="var(--text-muted)">the whole fleet</text>
    <text x="450" y="122" fill="var(--text-muted)">Wipe · scripts · rogue app ·</text>
    <text x="450" y="140" fill="var(--text-muted)">disable Defender policy</text>
    <text x="450" y="166" fill="var(--text)" font-weight="700">"Who controls the</text>
    <text x="450" y="184" fill="var(--text)" font-weight="700">controller?"</text>
  </g>
</svg>
</div>

&nbsp;
<h3><strong>DFIR on Intune — part 2: Windows endpoint artifacts</strong></h3>
This is the reference table I use on a Windows endpoint. Every path here is written by the MDM stack or by the Intune Management Extension:

<div style="margin:2rem 0;padding:1.25rem;background:var(--bg-elevated);border:1px solid var(--border);border-radius:var(--radius-m);">
<svg viewBox="0 0 640 330" style="width:100%;height:auto;font-family:inherit;" role="img" aria-label="Windows endpoint artifact map in four layers: file system logs and caches, registry enrollment and policy keys, event logs for MDM, AAD, Autopilot and PowerShell, and execution evidence such as AgentExecutor process trees, scheduled tasks and the MDM certificate">
  <g style="font-size:11.5px;">
    <rect x="5" y="8" width="630" height="74" rx="10" fill="var(--accent)" fill-opacity="0.85"/>
    <text x="18" y="30" font-weight="700" fill="var(--accent-contrast)">FILE SYSTEM</text>
    <text x="18" y="50" fill="var(--accent-contrast)">C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\*.log  ·  C:\Windows\IMECache\HealthScripts\</text>
    <text x="18" y="68" fill="var(--accent-contrast)">C:\Windows\IMECache\&lt;appId&gt;_&lt;ver&gt;\  ·  …\Intune Management Extension\Policies\{Scripts,Results}</text>
    <rect x="5" y="90" width="630" height="74" rx="10" fill="var(--accent)" fill-opacity="0.6"/>
    <text x="18" y="112" font-weight="700" fill="var(--text)">REGISTRY (HKLM\SOFTWARE\Microsoft\…)</text>
    <text x="18" y="132" fill="var(--text)">Enrollments\&lt;GUID&gt;   ·   Provisioning\OMADM\Accounts   ·   PolicyManager\current\device\&lt;area&gt;</text>
    <text x="18" y="150" fill="var(--text)">IntuneManagementExtension\{Win32Apps, Policies, SideCarPolicies}   ·   EnterpriseResourceManager\Tracked</text>
    <rect x="5" y="172" width="630" height="74" rx="10" fill="var(--accent)" fill-opacity="0.35"/>
    <text x="18" y="194" font-weight="700" fill="var(--text)">EVENT LOGS</text>
    <text x="18" y="214" fill="var(--text)">DeviceManagement-Enterprise-Diagnostics-Provider/{Admin,Operational}   ·   AAD/Operational</text>
    <text x="18" y="232" fill="var(--text)">ModernDeployment-Diagnostics-Provider/Autopilot   ·   PowerShell/Operational (4104)   ·   Defender</text>
    <rect x="5" y="254" width="630" height="70" rx="10" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="18" y="276" font-weight="700" fill="var(--text)">EXECUTION EVIDENCE</text>
    <text x="18" y="296" fill="var(--text)">IntuneManagementExtension.exe → AgentExecutor.exe → powershell.exe -executionPolicy bypass -file …</text>
    <text x="18" y="314" fill="var(--text-muted)">Tasks \Microsoft\Windows\EnterpriseMgmt\{GUID} · MDM cert "Microsoft Intune MDM Device CA" · dsregcmd /status</text>
  </g>
</svg>
</div>

| Artifact | Location | Forensic value |
|---|---|---|
| `IntuneManagementExtension.log` | `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\` | Main IME log: check-ins, policies received (with IDs), script processing |
| `AgentExecutor.log` | same | Every script/remediation execution: the command line, exit code and output path. <strong>The best "what ran" artifact</strong> |
| `AppWorkload.log` | same | Win32 app check-in, applicability, detection, download and install (since service release 2408) |
| `HealthScripts.log` | same | Remediations, custom compliance scripts, on-demand remediations |
| `ClientHealth.log`, `Sensor.log`, `DeviceHealthMonitoring.log` | same | Agent health and inventory sensors. Useful to prove the agent was running at a given time |
| Remediation scripts | `C:\Windows\IMECache\HealthScripts\<policyId>_<ver>\detect.ps1`, `remediate.ps1` | <strong>The actual code</strong>, cached between runs |
| Win32 app content | `C:\Windows\IMECache\<appId>_<ver>\` and `…\Microsoft Intune Management Extension\Content\` | Unpacked installer during install. Usually removed afterwards, so check the `$MFT` and `$UsnJrnl` for traces |
| Platform scripts | `…\Microsoft Intune Management Extension\Policies\Scripts\` and `\Results\` | Script staged before execution and its output. Short-lived, so recover from the USN journal if gone |
| Enrollment record | `HKLM\SOFTWARE\Microsoft\Enrollments\<GUID>` | UPN, `ProviderID` = `MS DM Server`, discovery URL, enrollment type. Tells you <em>which tenant</em> manages the device |
| Applied policies | `HKLM\SOFTWARE\Microsoft\PolicyManager\current\device\<area>` and `\providers\<GUID>\` | The current effective CSP values, for example whether Defender or ASR settings were changed by MDM |
| IME state | `HKLM\SOFTWARE\Microsoft\IntuneManagementExtension\Win32Apps\<SID>\<appId>`, `\Policies\<userId>\<scriptId>`, `\SideCarPolicies\` | Per-app and per-script result, error codes and timestamps |
| MDM event log | `Microsoft-Windows-DeviceManagement-Enterprise-Diagnostics-Provider/Admin` | 75/76 = auto-enrollment success/failure, 208/209 = OMA-DM session start/end, 404 = command failure, 813/814 = policy value set (integer/string) |
| Autopilot event log | `Microsoft-Windows-ModernDeployment-Diagnostics-Provider/Autopilot` | Profile download, OOBE progress. Shows <em>when</em> the device was provisioned |
| PowerShell logging | `Microsoft-Windows-PowerShell/Operational` event 4104 | Script block logging captures the content of Intune-delivered scripts, if enabled. <strong>Enable it via Intune</strong> |

> **_NOTE:_**  IME logs roll over at about 3 MB, and the older file is renamed. On a busy device, a week of history can be gone. If you suspect Intune was abused, <strong>collect the logs first</strong>, before anyone "re-syncs" the device to test.

<strong>Triage collector.</strong> This script collects everything in the table above into one hashed zip. Run it elevated, or as SYSTEM through your EDR's live response:

```powershell
#Requires -RunAsAdministrator
<#  Invoke-IntuneTriage.ps1 - collect Intune / MDM artifacts from a Windows endpoint
    Run from an elevated prompt (or as SYSTEM via your EDR live response).          #>
param([string]$Root = "C:\IR")

$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$out   = Join-Path $Root "Intune_${env:COMPUTERNAME}_$stamp"
$null  = New-Item -ItemType Directory -Path $out\logs, $out\reg, $out\evtx, $out\cache -Force
$ime   = "${env:ProgramFiles(x86)}\Microsoft Intune Management Extension"

# 1. Intune Management Extension logs (Win32 apps, scripts, remediations)
Copy-Item "$env:ProgramData\Microsoft\IntuneManagementExtension\Logs\*" "$out\logs" -ErrorAction SilentlyContinue

# 2. Cached scripts and content - remediation scripts stay here between runs
Copy-Item "$env:windir\IMECache\HealthScripts" "$out\cache" -Recurse -ErrorAction SilentlyContinue
Get-ChildItem "$env:windir\IMECache", "$ime\Policies", "$ime\Content" -Recurse -Force -ErrorAction SilentlyContinue |
    Select-Object FullName, Length, CreationTimeUtc, LastWriteTimeUtc |
    Export-Csv "$out\cache\listing.csv" -NoTypeInformation

# 3. Registry: enrollment, applied policies, IME state
$keys = @{
    "enrollments"   = "HKLM\SOFTWARE\Microsoft\Enrollments"
    "omadm"         = "HKLM\SOFTWARE\Microsoft\Provisioning\OMADM"
    "policymanager" = "HKLM\SOFTWARE\Microsoft\PolicyManager"
    "ime"           = "HKLM\SOFTWARE\Microsoft\IntuneManagementExtension"
    "erm"           = "HKLM\SOFTWARE\Microsoft\EnterpriseResourceManager"
}
foreach ($k in $keys.GetEnumerator()) {
    reg.exe export $k.Value "$out\reg\$($k.Key).reg" /y | Out-Null
}

# 4. Event logs
$channels = @(
    "Microsoft-Windows-DeviceManagement-Enterprise-Diagnostics-Provider/Admin",
    "Microsoft-Windows-DeviceManagement-Enterprise-Diagnostics-Provider/Operational",
    "Microsoft-Windows-AAD/Operational",
    "Microsoft-Windows-ModernDeployment-Diagnostics-Provider/Autopilot",
    "Microsoft-Windows-PowerShell/Operational",
    "Microsoft-Windows-Windows Defender/Operational"
)
foreach ($c in $channels) {
    wevtutil.exe epl $c "$out\evtx\$($c -replace '[/ ]','_').evtx" 2>$null
}

# 5. Join state, MDM scheduled tasks, MDM certificates
dsregcmd.exe /status > "$out\dsregcmd.txt"
Get-ScheduledTask -TaskPath "\Microsoft\Windows\EnterpriseMgmt\*" -ErrorAction SilentlyContinue |
    Select-Object TaskPath, TaskName, State, Date, Author | Export-Csv "$out\enterprisemgmt_tasks.csv" -NoTypeInformation
Get-ChildItem Cert:\LocalMachine\My | Where-Object Issuer -like "*Intune*" |
    Select-Object Subject, Issuer, NotBefore, NotAfter, Thumbprint | Export-Csv "$out\mdm_certs.csv" -NoTypeInformation

# 6. Microsoft's own MDM diagnostics bundle
MdmDiagnosticsTool.exe -area "DeviceEnrollment;DeviceProvisioning;Autopilot" -zip "$out\MDMDiag.zip" | Out-Null

# 7. Hash everything, then zip
Get-ChildItem $out -Recurse -File | Get-FileHash -Algorithm SHA256 |
    Export-Csv "$out\manifest_sha256.csv" -NoTypeInformation
Compress-Archive -Path "$out\*" -DestinationPath "$out.zip" -Force
Write-Host "Collected: $out.zip"
```

<strong>Turning IME logs into a timeline.</strong> IME logs use the CMTrace format, which is painful to read in Notepad and impossible to correlate. This function converts them into objects, including multi-line messages, so you can merge all logs into one sorted timeline:

```powershell
function ConvertFrom-CMTraceLog {
    <# Turns IME / CMTrace-format logs into objects you can sort, filter and export #>
    param([Parameter(Mandatory)][string[]]$Path)
    $rx = '<!\[LOG\[(?<msg>[\s\S]*?)\]LOG\]!><time="(?<time>[\d:.]+)[^"]*" date="(?<date>[\d-]+)" component="(?<comp>[^"]*)"[^>]*type="(?<type>\d)" thread="(?<thread>\d+)"'
    foreach ($file in Get-ChildItem $Path) {
        $text = Get-Content $file.FullName -Raw
        foreach ($m in [regex]::Matches($text, $rx)) {
            $ts = [datetime]::ParseExact("$($m.Groups['date'].Value) $($m.Groups['time'].Value.Substring(0,12))",
                                         "M-d-yyyy HH:mm:ss.fff", [cultureinfo]::InvariantCulture)
            [pscustomobject]@{
                Time      = $ts
                Log       = $file.Name
                Component = $m.Groups['comp'].Value
                Severity  = @{ '1'='Info'; '2'='Warning'; '3'='Error' }[$m.Groups['type'].Value]
                Thread    = $m.Groups['thread'].Value
                Message   = $m.Groups['msg'].Value.Trim()
            }
        }
    }
}
# Example: one timeline across all IME logs, errors only
# ConvertFrom-CMTraceLog .\logs\*.log | Where-Object Severity -eq 'Error' | Sort-Object Time | Export-Csv timeline.csv -NoTypeInformation
```

> **_NOTE:_**  IME timestamps are in the device's <strong>local time</strong>, and the time zone offset is written next to the time value. Convert everything to UTC before merging with SIEM data, or your timeline will be shifted by hours.

<strong>macOS, iOS and Android, briefly.</strong> On macOS, the Intune agent logs live in `/Library/Logs/Microsoft/Intune/` (system) and `~/Library/Logs/Microsoft/Intune/` (user). The installed MDM profiles are listed with `sudo profiles show -all`, and MDM activity appears in the unified log: `log show --predicate 'subsystem == "com.apple.ManagedClient"' --last 7d`. On iOS and Android there is very little to collect from the device itself. Use the <strong>Company Portal "send logs"</strong> feature, an iOS sysdiagnose, or an Android bug report, and rely mostly on the cloud-side logs.

&nbsp;
<h3><strong>DFIR on Intune — part 3: investigating the tenant</strong></h3>
When the question is "was our Intune used against us?", the evidence is in the cloud. This is the workflow I follow:

1. **Preserve first.** Export `IntuneAuditLogs`, Entra `AuditLogs`, `SigninLogs` and `MicrosoftGraphActivityLogs` for the incident window, plus the current configuration (backup script above). Don't rely on portal retention.
2. **Find the actor.** Filter the audit log for wipe/retire/delete, script and app creation or assignment, and RBAC changes. Note the `Identity` and the time.
3. **Find how they got in.** Pivot to the sign-in logs for that identity: IP, country, device, MFA method, the app used (admin center vs Graph PowerShell), and any PIM activation just before.
4. **Recover what was pushed.** Graph returns the <strong>full content</strong> of every platform script and remediation, so you can see exactly what code ran as SYSTEM.
5. **Measure the blast radius.** Assignment groups → member devices, then the device-side `AgentExecutor.log` and MDE `DeviceProcessEvents` to confirm execution.

This read-only script does steps 2 and 4 for you: it exports the audit trail and decodes every script and remediation in the tenant, with hashes:

```powershell
<#  Get-IntuneAdminActivity.ps1 - pull Intune audit events and the content of every
    PowerShell script / remediation in the tenant (read-only).                      #>
param([int]$Days = 30, [string]$Out = ".\intune-ir")

Connect-MgGraph -Scopes "DeviceManagementApps.Read.All","DeviceManagementConfiguration.Read.All",
                        "DeviceManagementManagedDevices.Read.All" -NoWelcome
$null = New-Item -ItemType Directory -Path $Out -Force

function Get-GraphAll([string]$Uri) {            # follows @odata.nextLink paging
    while ($Uri) {
        $page = Invoke-MgGraphRequest -Method GET -Uri $Uri -OutputType PSObject
        $page.value
        $Uri = $page.'@odata.nextLink'
    }
}

# 1. Audit events (who did what, from where, to which object)
$since = (Get-Date).ToUniversalTime().AddDays(-$Days).ToString("yyyy-MM-ddTHH:mm:ssZ")
Get-GraphAll "https://graph.microsoft.com/beta/deviceManagement/auditEvents?`$filter=activityDateTime ge $since" |
    Select-Object activityDateTime, activity, activityType, activityOperationType, activityResult, componentName,
        @{n='Actor';   e={ $_.actor.userPrincipalName ?? $_.actor.applicationDisplayName }},
        @{n='ActorIP'; e={ $_.actor.ipAddress }},
        @{n='Targets'; e={ ($_.resources.displayName) -join '; ' }} |
    Sort-Object activityDateTime |
    Export-Csv "$Out\audit_events.csv" -NoTypeInformation

# 2. Platform scripts: decode the actual code that was (or will be) run as SYSTEM
$scripts = foreach ($s in Get-GraphAll "https://graph.microsoft.com/beta/deviceManagement/deviceManagementScripts") {
    $full = Invoke-MgGraphRequest -Method GET -OutputType PSObject `
            -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceManagementScripts/$($s.id)"
    $code = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($full.scriptContent))
    $code | Set-Content "$Out\script_$($s.id)_$($s.fileName)"
    [pscustomobject]@{ Id=$s.id; Name=$s.displayName; File=$s.fileName; RunAs=$s.runAsAccount
                       Created=$s.createdDateTime; Modified=$s.lastModifiedDateTime
                       SHA256=(Get-FileHash "$Out\script_$($s.id)_$($s.fileName)").Hash }
}
$scripts | Export-Csv "$Out\scripts.csv" -NoTypeInformation

# 3. Remediations (detection + remediation pairs)
foreach ($r in Get-GraphAll "https://graph.microsoft.com/beta/deviceManagement/deviceHealthScripts") {
    $full = Invoke-MgGraphRequest -Method GET -OutputType PSObject `
            -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceHealthScripts/$($r.id)"
    foreach ($part in "detection","remediation") {
        $b64 = $full."${part}ScriptContent"
        if ($b64) { [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($b64)) |
                    Set-Content "$Out\remediation_$($r.id)_$part.ps1" }
    }
}
Write-Host "Done. Review $Out\audit_events.csv first, then diff scripts against your known-good baseline."
```

> **_NOTE:_**  This script needs PowerShell 7 or later (it uses the `??` operator) and the Microsoft Graph PowerShell SDK. Run it from a clean, trusted admin workstation, <strong>not</strong> from a device managed by the tenant you are investigating.

<strong>Using Intune as an IR tool.</strong> During an incident the same power works for you:

| Need | Intune feature | Tip |
|---|---|---|
| Ask one device a question <em>now</em> | **Device query** (Advanced Analytics) | KQL against live device state: processes, files, registry, services, local users |
| Hunt across the fleet | **Multi-device query** / MDE advanced hunting | Inventory-based, so better for "which devices have X" than for live processes |
| Run a triage collector everywhere | **Remediations** (on-demand or scheduled) with the triage script above, uploading to a locked-down storage account | Test on one device first, and scope by group. Remember: this is also exactly what an attacker would do |
| Get Microsoft's diagnostic bundle | **Collect diagnostics** remote action | Logs land in the admin center for 28 days |
| Contain a host | Defender for Endpoint **isolate** (from Defender XDR), then Intune for follow-up | Isolation keeps the Defender channel open, so you can still investigate |
| Kill a stolen credential | **Rotate LAPS password / BitLocker key**, revoke the user's sessions in Entra | Rotate after the investigation has captured what it needs |
| Remove access from a lost device | **Retire** (corporate data only) before **wipe** | Wipe destroys evidence. Image first if the device is in scope |

&nbsp;
<h3><strong>DFIR on Intune — part 4: when the admin account is the threat</strong></h3>
This is the playbook for the worst case: an attacker controls an Intune administrator, or an app registration with Intune Graph permissions.

<div style="margin:2rem 0;padding:1.25rem;background:var(--bg-elevated);border:1px solid var(--border);border-radius:var(--radius-m);">
<svg viewBox="0 0 640 260" style="width:100%;height:auto;font-family:inherit;" role="img" aria-label="Attack path: phished or token-stolen admin, then Intune admin center or Graph, then four impacts: mass wipe, script as SYSTEM, malicious app, weakened security policy; the controls that break each step are phishing-resistant MFA and PIM, Conditional Access for admin portals, Multi Admin Approval, and SIEM detections">
  <defs><marker id="in-a6" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto"><path d="M0,0 L8,4 L0,8 z" fill="var(--text-muted)"/></marker></defs>
  <g style="font-size:11.5px;">
    <rect x="5" y="30" width="130" height="70" rx="8" fill="var(--bg-elevated-2)" stroke="var(--accent-strong)" stroke-width="2"/>
    <text x="70" y="56" text-anchor="middle" font-weight="700" fill="var(--text)">Admin identity</text>
    <text x="70" y="74" text-anchor="middle" fill="var(--text-muted)">phish · AiTM token</text>
    <text x="70" y="90" text-anchor="middle" fill="var(--text-muted)">· leaked app secret</text>
    <rect x="175" y="30" width="130" height="70" rx="8" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="240" y="56" text-anchor="middle" font-weight="700" fill="var(--text)">Intune / Graph</text>
    <text x="240" y="74" text-anchor="middle" fill="var(--text-muted)">admin center or</text>
    <text x="240" y="90" text-anchor="middle" fill="var(--text-muted)">scripted API calls</text>
    <line x1="135" y1="65" x2="172" y2="65" stroke="var(--text-muted)" stroke-width="2" marker-end="url(#in-a6)"/>
    <g fill="var(--text)">
      <rect x="350" y="8" width="285" height="26" rx="6" fill="var(--bg-elevated-2)" stroke="var(--border)"/><text x="362" y="26">💥 Mass wipe / retire / delete devices</text>
      <rect x="350" y="40" width="285" height="26" rx="6" fill="var(--bg-elevated-2)" stroke="var(--border)"/><text x="362" y="58">🐚 Script or remediation as SYSTEM</text>
      <rect x="350" y="72" width="285" height="26" rx="6" fill="var(--bg-elevated-2)" stroke="var(--border)"/><text x="362" y="90">📦 "Required" Win32 app = malware</text>
      <rect x="350" y="104" width="285" height="26" rx="6" fill="var(--bg-elevated-2)" stroke="var(--border)"/><text x="362" y="122">🛡️ Weaken Defender / ASR / firewall policy</text>
    </g>
    <g stroke="var(--text-muted)" stroke-width="1.5">
      <line x1="305" y1="65" x2="347" y2="21" marker-end="url(#in-a6)"/><line x1="305" y1="65" x2="347" y2="53" marker-end="url(#in-a6)"/>
      <line x1="305" y1="65" x2="347" y2="85" marker-end="url(#in-a6)"/><line x1="305" y1="65" x2="347" y2="117" marker-end="url(#in-a6)"/>
    </g>
    <rect x="5" y="160" width="630" height="92" rx="10" fill="var(--accent)" fill-opacity="0.12" stroke="var(--accent)"/>
    <text x="18" y="182" font-weight="700" fill="var(--accent)">CONTROLS THAT BREAK THE CHAIN</text>
    <text x="18" y="204" fill="var(--text)">① Phishing-resistant MFA + PIM (no standing Intune Admin) + CA for admin portals from compliant PAWs</text>
    <text x="18" y="224" fill="var(--text)">② Multi Admin Approval on scripts, apps, device actions (wipe/retire/delete), compliance, config and RBAC</text>
    <text x="18" y="244" fill="var(--text)">③ SIEM detections on mass actions + Graph activity  ·  ④ least-privilege Graph apps, no client secrets</text>
  </g>
</svg>
</div>

<strong>Containment, in this order:</strong>

1. **Stop the actor.** Disable the account (or the app's credentials), and revoke sessions with `Revoke-MgUserSignInSession -UserId <upn>`. Remove PIM eligibility until the investigation is finished.
2. **Stop pending damage.** Remove assignments of any new or modified script, remediation or app. Check <em>Devices → Monitor → Device actions</em> for queued wipes or retires. Devices that are offline will run a queued wipe when they come back online.
3. **Look for persistence.** New role assignments, new custom roles, scope tag changes, new app registrations or consents with `DeviceManagement*` permissions, new enrollment program tokens, changed MAA access policies, and a weakened Conditional Access policy.
4. **Use break-glass carefully.** Your break-glass accounts are excluded from CA. Confirm they weren't used, and rotate their credentials after the incident.
5. **Rebuild trust.** Compare the configuration with your last known-good backup, restore it, and keep the diff as evidence.

> **_NOTE:_**  Multi Admin Approval also covers <strong>application-authenticated Graph calls</strong>, not only clicks in the portal. An attacker with a stolen app secret still hits the approval gate, unless that app was explicitly excluded in the access policy. Keep that exclusion list empty, or very short.

&nbsp;
<h3><strong>Security review: the checklist</strong></h3>
These are the checks I run when reviewing an Intune tenant, grouped by domain. Every "no" is a finding:

| # | Domain | Check | Why it matters |
|---|---|---|---|
| 1 | Admin access | Intune Administrator is PIM-eligible only, with at most 2 standing break-glass exceptions | Standing admin = permanent target |
| 2 | Admin access | Phishing-resistant MFA (FIDO2/passkeys) + CA requiring a compliant privileged access workstation for the Intune and Graph admin apps | Stops AiTM token theft, the most common path in |
| 3 | Admin access | Custom RBAC roles with scope tags. Helpdesk can't wipe, script or assign apps | Limits what one stolen account can do |
| 4 | Admin access | **Multi Admin Approval** for scripts, apps, device actions, compliance, configuration and RBAC | The control that directly prevents the Stryker scenario |
| 5 | Admin access | Graph app registrations with `DeviceManagement*.ReadWrite.All` or `PrivilegedOperations.All` reviewed, owned, certificate-based (no secrets), not excluded from MAA | Automation is an admin too |
| 6 | Enrollment | Personal Windows enrollment blocked; device limit per user; corporate identifiers if needed | Stops rogue devices from becoming "trusted" |
| 7 | Enrollment | Apple and Google tokens (APNs, ADE, VPP) owned by a shared service account, with renewal dates tracked | An expired APNs certificate means re-enrolling every Apple device |
| 8 | Compliance | "Devices with no compliance policy" = <strong>Not compliant</strong>; short grace period; minimum OS, encryption, Secure Boot, Defender risk level | Unknown devices must not pass as compliant |
| 9 | Access | CA requires compliant device (or app protection on mobile) for all cloud apps, enforced and not report-only | Compliance without enforcement is only a report |
| 10 | Baseline | BitLocker with key escrow, Defender with tamper protection, ASR in block mode, firewall, Windows LAPS, Credential Guard, PowerShell script block logging | The device must be able to defend itself and record what happened |
| 11 | Apps | Win32 app ownership and review process; Enterprise App Catalog or winget for third-party updates | A rogue "required" app is code execution on every device |
| 12 | Updates | Rings with a real pilot; quality update deadlines; reports reviewed monthly | Unpatched endpoints are still the easiest way in |
| 13 | BYOD | App protection policies on all mobile platforms; selective wipe tested | Corporate data without corporate devices |
| 14 | Logging | All four Intune log categories plus Entra sign-in/audit and Graph activity logs exported; retention ≥ 1 year; SIEM detections live | You can't investigate what you didn't keep |
| 15 | Hygiene | Stale devices (no check-in for 30–90 days) cleaned up; configuration backed up and diffed | Every orphaned object is a hiding place |

The following script automates part of this list using read-only Graph calls. It checks the default compliance posture, standing Intune admins, Multi Admin Approval, risky custom roles, enrollment restrictions and stale devices:

```powershell
<#  Invoke-IntuneSecurityReview.ps1 - quick, read-only posture checks for an Intune tenant #>
Connect-MgGraph -Scopes "DeviceManagementConfiguration.Read.All","DeviceManagementRBAC.Read.All",
                        "DeviceManagementServiceConfig.Read.All","RoleManagement.Read.Directory" -NoWelcome
$g = "https://graph.microsoft.com"
$results = [System.Collections.Generic.List[object]]::new()
function Add-Check($Area, $Check, $Pass, $Detail) {
    $results.Add([pscustomobject]@{ Area=$Area; Check=$Check; Status= if ($Pass) {'PASS'} else {'REVIEW'}; Detail=$Detail })
}

# 1. Devices without a compliance policy must be treated as non-compliant
$settings = (Invoke-MgGraphRequest -Method GET -Uri "$g/beta/deviceManagement" -OutputType PSObject).settings
Add-Check "Compliance" "No-policy devices = Not compliant" $settings.secureByDefault "secureByDefault=$($settings.secureByDefault)"

# 2. Standing Intune Administrators (Entra role template 3a2c62db-...)
$ia = (Invoke-MgGraphRequest -Method GET -Uri ("$g/v1.0/roleManagement/directory/roleAssignments?`$filter=" +
       "roleDefinitionId eq '3a2c62db-5318-420d-8d74-23affee5d9d5'") -OutputType PSObject).value
Add-Check "RBAC" "Permanent Intune Administrators <= 2 (use PIM)" ($ia.Count -le 2) "$($ia.Count) active assignment(s)"

# 3. Multi Admin Approval access policies
try {
    $maa = (Invoke-MgGraphRequest -Method GET -Uri "$g/beta/deviceManagement/operationApprovalPolicies" -OutputType PSObject).value
    $types = ($maa.policyType | Sort-Object -Unique) -join ', '
    Add-Check "RBAC" "Multi Admin Approval protects scripts, apps and wipe" ($maa.Count -ge 3) "Policies: $($maa.Count) [$types]"
} catch { Add-Check "RBAC" "Multi Admin Approval" $false "Could not read access policies: $($_.Exception.Message)" }

# 4. Custom Intune roles with wipe / script rights
$roles = (Invoke-MgGraphRequest -Method GET -Uri "$g/beta/deviceManagement/roleDefinitions" -OutputType PSObject).value
foreach ($r in $roles | Where-Object { -not $_.isBuiltIn }) {
    $acts = $r.rolePermissions.resourceActions.allowedResourceActions
    $risky = $acts | Where-Object { $_ -match 'Wipe|Retire|DeviceManagementScripts|RemoteTasks' }
    if ($risky) { Add-Check "RBAC" "Custom role '$($r.displayName)' has destructive rights" $false ($risky -join ', ') }
}

# 5. Enrollment restrictions: personally owned Windows blocked?
$restr = (Invoke-MgGraphRequest -Method GET -Uri "$g/beta/deviceManagement/deviceEnrollmentConfigurations" -OutputType PSObject).value |
         Where-Object { $_.'@odata.type' -like '*PlatformRestriction*' -and $_.platformType -eq 'windows' }
foreach ($p in $restr) {
    Add-Check "Enrollment" "Personal Windows enrollment blocked ($($p.displayName))" `
              $p.platformRestriction.personalDeviceEnrollmentBlocked "platformBlocked=$($p.platformRestriction.platformBlocked)"
}

# 6. Stale devices (no check-in for 30+ days) widen the attack surface
$stale = (Invoke-MgGraphRequest -Method GET -Uri ("$g/v1.0/deviceManagement/managedDevices?`$select=deviceName,lastSyncDateTime" +
          "&`$top=999") -OutputType PSObject).value | Where-Object { [datetime]$_.lastSyncDateTime -lt (Get-Date).AddDays(-30) }
Add-Check "Hygiene" "Devices not synced for 30+ days" ($stale.Count -eq 0) "$($stale.Count) stale device(s) (first page only)"

$results | Format-Table -AutoSize
$results | Export-Csv ".\intune-security-review.csv" -NoTypeInformation
```

> **_NOTE:_**  Treat the output as a starting point for the review, not a score. Some Graph properties used here are on the <em>beta</em> endpoint and can change. If a check returns an error, verify that setting manually in the admin center.

&nbsp;
<h3><strong>Common mistakes I keep seeing</strong></h3>

| Mistake | Consequence | Better |
|---|---|---|
| Everyone in IT is "Intune Administrator" | One phished helpdesk account can wipe the company | Custom roles + scope tags + PIM + MAA |
| TLS inspection on all traffic | Random enrollment failures, devices fall out of compliance | Bypass the documented Intune endpoints |
| Diagnostic settings never configured | No evidence when it matters | Enable on day one; Sentinel or Event Hubs + archive |
| CA enforced on day one | Executives locked out, rollback, lost trust | Report-only first, enforce app by app |
| Duplicate settings across policies | Conflicts and silent failures | One owner per setting; settings catalog; naming convention |
| Wiping a compromised laptop immediately | The evidence is destroyed | Isolate → collect → image if in scope → then retire/wipe |
| Remediations used as "free admin" with no review | A future attacker's favourite feature is already normal noise | Code review, MAA, and the SIEM detection above |

&nbsp;
<h3><strong>Download the scripts</strong></h3>
All the scripts from this article, ready to adapt:

- <a href="/assets/files/intune/Invoke-IntuneTriage.ps1" target="_blank" rel="noopener">Invoke-IntuneTriage.ps1</a> — endpoint artifact collector
- <a href="/assets/files/intune/ConvertFrom-CMTraceLog.ps1" target="_blank" rel="noopener">ConvertFrom-CMTraceLog.ps1</a> — IME log → timeline parser
- <a href="/assets/files/intune/Get-IntuneAdminActivity.ps1" target="_blank" rel="noopener">Get-IntuneAdminActivity.ps1</a> — tenant audit trail and script recovery
- <a href="/assets/files/intune/Invoke-IntuneSecurityReview.ps1" target="_blank" rel="noopener">Invoke-IntuneSecurityReview.ps1</a> — posture checks
- <a href="/assets/files/intune/intune_eventhub_consumer.py" target="_blank" rel="noopener">intune_eventhub_consumer.py</a> — Event Hubs → SIEM forwarder with de-duplication

> **_NOTE:_**  I tested every script for syntax, and tested the log parser and the Event Hubs de-duplication logic with sample data. The Graph scripts are read-only, but run them first in a test tenant or with a read-only account, and review the code before running anything as SYSTEM.

&nbsp;
<h3><strong>Summary</strong></h3>
Intune is much more than "the tool that installs apps". It is a cloud control plane with two agents on every Windows device, a compliance signal that drives access decisions, and the power to run code as SYSTEM on the whole fleet within an hour. Build it in phases: foundations and RBAC first, report-only before enforcement, rings for everything. Open only the outbound endpoints it needs, and keep TLS inspection away from them. Send all four log categories, plus Entra sign-in and Graph activity logs, to your SIEM, and de-duplicate them. Learn where the IME and the MDM stack leave their traces, so you can tell what was pushed and whether it ran. Most importantly, protect Intune itself: PIM, phishing-resistant MFA and Multi Admin Approval turn "one stolen account wipes the company" into "one stolen account files a request that someone rejects".

You can read more in the official documentation: <a href="https://learn.microsoft.com/en-us/intune/" target="_blank" rel="noopener">Microsoft Intune documentation</a>, <a href="https://learn.microsoft.com/en-us/intune/intune-service/fundamentals/intune-endpoints" target="_blank" rel="noopener">network endpoints for Intune</a>, <a href="https://learn.microsoft.com/en-us/intune/intune-service/fundamentals/review-logs-using-azure-monitor" target="_blank" rel="noopener">routing Intune logs to Azure Monitor</a>, <a href="https://learn.microsoft.com/en-us/intune/intune-service/fundamentals/multi-admin-approval" target="_blank" rel="noopener">Multi Admin Approval</a>, and the <a href="https://learn.microsoft.com/en-us/graph/api/resources/intune-graph-overview" target="_blank" rel="noopener">Intune Graph API reference</a>.
