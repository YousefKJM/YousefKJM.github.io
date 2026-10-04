---
title: "Global Admin Is Not Azure Owner: Designing Microsoft Entra PIM Across Three Access Layers"
excerpt: "Global Administrator can't touch an Azure VM — until one toggle makes it owner of every subscription. Three access layers, the bridges between them, and a real PIM rollout with code, detections and DFIR questions."
header:
  image: /images/posts/pim/hero.jpg
tags: [Cloud, Detection, identity, PIM, Azure, M365]
---
![Global Admin is not Azure Owner: designing Microsoft Entra PIM across three access layers](/images/posts/pim/hero.jpg)

A short LinkedIn post by <a href="https://www.linkedin.com/feed/update/urn:li:activity:7499820735549321216/" target="_blank" rel="noopener">Rishi .P</a> caught my attention this week with a point I wish more teams heard early: <strong>Global Administrator and Azure Owner are not the same thing</strong>. Before configuring PIM, ask <em>what exactly you're protecting</em> — Entra administration, Azure resources, or membership of a privileged group. The post promised a real-world PIM scenario next, and that's exactly where I see organizations stumble.

In incident response I rarely see an attacker "hack" a firewall. I see them <strong>walk a privilege path</strong>: a helpdesk account that can reset an admin's password, an app registration that can grant itself roles, a Global Admin who flips one toggle and becomes owner of every Azure subscription. So let's take that three-layer idea further — the layers, the hidden bridges between them, and a complete rollout with settings, code, detections and the forensic questions behind it.

![Entra roles vs Azure roles vs PIM for Groups — the three privileged-access layers at a glance: what each one controls, how it works, common mistakes, and the key question to ask before configuring PIM](/images/posts/pim/roles-overview.jpg)

*The whole post in one picture: three different access models for three different problems. The sections below unpack each layer, the bridges between them, and how to roll PIM out across all three.*

## Two permission worlds, and one bridge
Microsoft's cloud has two separate authorization systems that look similar but don't share permissions:

- **Microsoft Entra roles** control the <em>directory</em> and Microsoft 365: users, groups, apps, Conditional Access, Exchange, Intune. Scope: the tenant, or an administrative unit.
- **Azure RBAC roles** control <em>Azure resources</em>: subscriptions, VMs, storage, Key Vault. Scope: management group → subscription → resource group → resource.

A Global Administrator has <strong>no access to Azure resources by default</strong>, and a subscription Owner can't reset a single user's password. But there is a bridge: a Global Administrator can turn on <em>"Access management for Azure resources"</em> in the Entra properties page and instantly become <strong>User Access Administrator at the root scope (`/`)</strong>. From there, they can give themselves Owner on every subscription in the tenant. Groups add a third layer, because one group can carry roles in both worlds at the same time:

<div style="margin:2rem 0;padding:1.25rem;background:var(--bg-elevated);border:1px solid var(--border);border-radius:var(--radius-m);">
<svg viewBox="0 0 640 360" style="width:100%;height:auto;font-family:inherit;" role="img" aria-label="Three access layers: Entra roles controlling the directory and Microsoft 365, Azure RBAC controlling resources from management group down to resource, and PIM for Groups providing just-in-time membership in groups that carry roles in either layer; bridges between them are elevate access from Global Administrator to User Access Administrator at root, role-assignable groups assigned to Entra roles, and groups assigned to Azure roles">
  <defs><marker id="pm-a1" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto"><path d="M0,0 L8,4 L0,8 z" fill="var(--accent-strong)"/></marker>
        <marker id="pm-a1b" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto"><path d="M0,0 L8,4 L0,8 z" fill="var(--text-muted)"/></marker></defs>
  <g style="font-size:12px;">
    <rect x="5" y="10" width="290" height="150" rx="12" fill="var(--bg-elevated-2)" stroke="var(--accent)" stroke-width="2"/>
    <text x="20" y="34" font-weight="700" font-size="14" fill="var(--accent)">① ENTRA ROLES</text>
    <text x="20" y="56" fill="var(--text-muted)">Scope: tenant "/" or administrative unit</text>
    <text x="20" y="80" fill="var(--text)">Global Administrator</text>
    <text x="20" y="98" fill="var(--text)">Privileged Role Administrator</text>
    <text x="20" y="116" fill="var(--text)">Security · Exchange · Intune Admin</text>
    <text x="20" y="140" fill="var(--text-muted)">Controls: users, apps, CA, M365</text>

    <rect x="345" y="10" width="290" height="150" rx="12" fill="var(--bg-elevated-2)" stroke="var(--accent)" stroke-width="2"/>
    <text x="360" y="34" font-weight="700" font-size="14" fill="var(--accent)">② AZURE RBAC</text>
    <text x="360" y="56" fill="var(--text-muted)">Scope: MG → subscription → RG → resource</text>
    <text x="360" y="80" fill="var(--text)">Owner · User Access Administrator</text>
    <text x="360" y="98" fill="var(--text)">RBAC Administrator · Contributor</text>
    <text x="360" y="116" fill="var(--text)">Reader · data roles (Key Vault, Blob)</text>
    <text x="360" y="140" fill="var(--text-muted)">Controls: VMs, storage, networks, keys</text>

    <path d="M295 70 C 320 70, 320 70, 343 70" stroke="var(--accent-strong)" stroke-width="2.5" stroke-dasharray="6 5" fill="none" marker-end="url(#pm-a1)"/>
    <text x="320" y="186" text-anchor="middle" font-weight="700" fill="var(--accent-strong)">⚠ elevate access</text>
    <text x="320" y="202" text-anchor="middle" fill="var(--accent-strong)">GA → User Access Admin at "/"</text>
    <line x1="320" y1="74" x2="320" y2="172" stroke="var(--accent-strong)" stroke-width="1" stroke-dasharray="2 3"/>

    <rect x="120" y="225" width="400" height="125" rx="12" fill="var(--accent)" fill-opacity="0.12" stroke="var(--accent)" stroke-width="2"/>
    <text x="320" y="250" text-anchor="middle" font-weight="700" font-size="14" fill="var(--accent)">③ PIM FOR GROUPS</text>
    <text x="320" y="272" text-anchor="middle" fill="var(--text)">Just-in-time <tspan font-weight="700">membership</tspan> or <tspan font-weight="700">ownership</tspan> of a group</text>
    <text x="320" y="292" text-anchor="middle" fill="var(--text-muted)">The group can hold an Entra role (if role-assignable),</text>
    <text x="320" y="310" text-anchor="middle" fill="var(--text-muted)">Azure roles, app roles, Defender/Intune RBAC, SaaS access…</text>
    <text x="320" y="334" text-anchor="middle" fill="var(--text)">One activation → access in several systems</text>
    <line x1="200" y1="225" x2="150" y2="164" stroke="var(--text-muted)" stroke-width="1.8" marker-end="url(#pm-a1b)"/>
    <line x1="440" y1="225" x2="490" y2="164" stroke="var(--text-muted)" stroke-width="1.8" marker-end="url(#pm-a1b)"/>
    <text x="70" y="205" fill="var(--text-muted)">role-assignable group</text>
    <text x="470" y="205" fill="var(--text-muted)">group as RBAC principal</text>
  </g>
</svg>
</div>

> **⚠ Attacker favourite:** The elevate-access toggle is a legitimate break-glass feature, for example to recover a subscription nobody owns anymore. It is also a known attacker move: threat actors such as Storm-0501 have used it to jump from a compromised Entra admin into Azure. Treat every use of it as an alert, not a log line.

## Layer 1 — Entra roles: who controls identity
These roles decide who can change <em>identities and policies</em>. Not all of them are equal. Some are effectively Global Administrator, because they control something GA depends on:

| Role | Why it's (near) tier-0 | PIM treatment |
|---|---|---|
| **Global Administrator** | Everything, including elevate access into Azure | Eligible only, approval, ≤ 2 h, phishing-resistant MFA |
| **Privileged Role Administrator** | Can assign any role, including GA, and change PIM settings | Same as GA |
| **Privileged Authentication Administrator** | Can reset passwords and MFA of <em>any</em> user, including GAs | Same as GA |
| **Conditional Access Administrator** | Can turn off the controls that protect admins | Approval, ≤ 4 h |
| **Application / Cloud Application Administrator** | Can add credentials to an app that already holds high Graph permissions, and then act as that app | Approval, ≤ 4 h. Review high-privilege apps |
| **Hybrid Identity Administrator** | Controls sync and federation, the bridge to on-premises | Approval, ≤ 4 h |
| **Security Administrator** | Manages Defender and security policies | Justification + ticket, ≤ 8 h |
| **Intune / Exchange / SharePoint Administrator** | Code execution on devices, access to all mail, all files | Justification + ticket, ≤ 8 h. Intune can run code as SYSTEM on every managed device, so treat it as close to tier-0 |
| **User / Authentication / Helpdesk Administrator** | Password resets for non-admins | Self-activation, ≤ 8 h, or administrative units to limit scope |

## Layer 2 — Azure RBAC: who controls resources
In Azure, the <em>scope</em> matters as much as the role. Owner on one resource group is a small risk. Owner on the root management group is the keys to everything:

| Role | Can do | Watch out for |
|---|---|---|
| **Owner** | Everything, including granting roles | Never standing above the resource group level |
| **User Access Administrator** | Grant any role to anyone at its scope | Often forgotten after an "elevate access" at `/` |
| **Role Based Access Control Administrator** | Grant roles, <strong>with conditions</strong> (for example "only Reader and Contributor, only to these groups") | The modern, safer way to delegate role assignment |
| **Contributor** | Manage everything except access | Still powerful: VM Run Command means code execution as SYSTEM/root, and it can read storage keys |
| **Data plane roles** (Key Vault Secrets Officer, Storage Blob Data Owner…) | Read and write the data itself | Often missed in reviews, though they protect the most valuable data |
| **Reader** | Read configuration | Usually safe to keep standing |

## Layer 3 — PIM for Groups: access to anything a group can hold
PIM for Groups gives users <strong>temporary membership or ownership</strong> of a security group or Microsoft 365 group. Whatever that group grants — an Entra role, Azure roles, an app role, Defender or Intune RBAC, a SaaS application through provisioning — becomes just-in-time too.

Key facts from Microsoft's documentation that shape the design:

1. **Membership and ownership have separate policies.** An owner can change the membership, so treat <em>eligible ownership</em> as at least as sensitive as membership.
2. **Dynamic groups and groups synced from on-premises can't be used** in PIM for Groups.
3. **Only role-assignable groups can hold Entra roles**, and you can have up to 500 of them. They are also protected: only Global Administrators, Privileged Role Administrators or the group's owners can manage them, and no lower admin can reset their members' credentials.
4. **Require approval for groups that elevate into Entra roles.** Otherwise a less-privileged admin who can reset a member's password could activate on that member's behalf.
5. **Activation can trigger SCIM provisioning** to a SaaS app within minutes. That makes "JIT admin in Salesforce/ServiceNow/AWS" possible from one place.

> **Microsoft's advice:** For the Exchange, SharePoint and Purview admin roles, Microsoft recommends using <strong>PIM for Entra roles directly</strong> instead of PIM for Groups, because permissions that flow through a group activation can take a long time to become effective in those services.

## The question to ask first: what am I protecting?
Before touching any PIM setting, I put every privileged request through this simple decision tree:

<div style="margin:2rem 0;padding:1.25rem;background:var(--bg-elevated);border:1px solid var(--border);border-radius:var(--radius-m);">
<svg viewBox="0 0 640 300" style="width:100%;height:auto;font-family:inherit;" role="img" aria-label="Decision tree: if the request is about directory or Microsoft 365 administration, use PIM for Entra roles; if it is about Azure resources, use PIM for Azure resources at the smallest scope; if one person needs access across several systems at once, or to an app that accepts groups, use PIM for Groups; if it is a service or automation, avoid PIM and use workload identities with least privilege">
  <defs><marker id="pm-a2" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto"><path d="M0,0 L8,4 L0,8 z" fill="var(--text-muted)"/></marker></defs>
  <g style="font-size:12px;">
    <rect x="220" y="8" width="200" height="44" rx="22" fill="var(--accent)"/>
    <text x="320" y="35" text-anchor="middle" font-weight="700" fill="var(--accent-contrast)">What am I protecting?</text>
    <line x1="320" y1="52" x2="80" y2="98" stroke="var(--text-muted)" stroke-width="1.5" marker-end="url(#pm-a2)"/>
    <line x1="320" y1="52" x2="240" y2="98" stroke="var(--text-muted)" stroke-width="1.5" marker-end="url(#pm-a2)"/>
    <line x1="320" y1="52" x2="400" y2="98" stroke="var(--text-muted)" stroke-width="1.5" marker-end="url(#pm-a2)"/>
    <line x1="320" y1="52" x2="560" y2="98" stroke="var(--text-muted)" stroke-width="1.5" marker-end="url(#pm-a2)"/>
    <g>
      <rect x="5" y="100" width="150" height="70" rx="8" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
      <text x="80" y="124" text-anchor="middle" font-weight="700" fill="var(--text)">Identity &amp; M365</text>
      <text x="80" y="142" text-anchor="middle" fill="var(--text-muted)">users, CA, apps,</text>
      <text x="80" y="158" text-anchor="middle" fill="var(--text-muted)">Exchange, Intune</text>
      <rect x="165" y="100" width="150" height="70" rx="8" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
      <text x="240" y="124" text-anchor="middle" font-weight="700" fill="var(--text)">Azure resources</text>
      <text x="240" y="142" text-anchor="middle" fill="var(--text-muted)">subscriptions, VMs,</text>
      <text x="240" y="158" text-anchor="middle" fill="var(--text-muted)">Key Vault, storage</text>
      <rect x="325" y="100" width="150" height="70" rx="8" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
      <text x="400" y="124" text-anchor="middle" font-weight="700" fill="var(--text)">A whole job</text>
      <text x="400" y="142" text-anchor="middle" fill="var(--text-muted)">several systems or</text>
      <text x="400" y="158" text-anchor="middle" fill="var(--text-muted)">a SaaS app via groups</text>
      <rect x="485" y="100" width="150" height="70" rx="8" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
      <text x="560" y="124" text-anchor="middle" font-weight="700" fill="var(--text)">Automation</text>
      <text x="560" y="142" text-anchor="middle" fill="var(--text-muted)">pipelines, scripts,</text>
      <text x="560" y="158" text-anchor="middle" fill="var(--text-muted)">service accounts</text>
    </g>
    <line x1="80" y1="170" x2="80" y2="198" stroke="var(--text-muted)" stroke-width="1.5" marker-end="url(#pm-a2)"/>
    <line x1="240" y1="170" x2="240" y2="198" stroke="var(--text-muted)" stroke-width="1.5" marker-end="url(#pm-a2)"/>
    <line x1="400" y1="170" x2="400" y2="198" stroke="var(--text-muted)" stroke-width="1.5" marker-end="url(#pm-a2)"/>
    <line x1="560" y1="170" x2="560" y2="198" stroke="var(--text-muted)" stroke-width="1.5" marker-end="url(#pm-a2)"/>
    <g>
      <rect x="5" y="200" width="150" height="88" rx="8" fill="var(--accent)" fill-opacity="0.15" stroke="var(--accent)"/>
      <text x="80" y="224" text-anchor="middle" font-weight="700" fill="var(--accent)">PIM for Entra roles</text>
      <text x="80" y="244" text-anchor="middle" fill="var(--text)">smallest role,</text>
      <text x="80" y="262" text-anchor="middle" fill="var(--text)">admin units where</text>
      <text x="80" y="278" text-anchor="middle" fill="var(--text)">possible</text>
      <rect x="165" y="200" width="150" height="88" rx="8" fill="var(--accent)" fill-opacity="0.15" stroke="var(--accent)"/>
      <text x="240" y="224" text-anchor="middle" font-weight="700" fill="var(--accent)">PIM for Azure</text>
      <text x="240" y="244" text-anchor="middle" fill="var(--text)">smallest scope,</text>
      <text x="240" y="262" text-anchor="middle" fill="var(--text)">RBAC Admin with</text>
      <text x="240" y="278" text-anchor="middle" fill="var(--text)">conditions</text>
      <rect x="325" y="200" width="150" height="88" rx="8" fill="var(--accent)" fill-opacity="0.15" stroke="var(--accent)"/>
      <text x="400" y="224" text-anchor="middle" font-weight="700" fill="var(--accent)">PIM for Groups</text>
      <text x="400" y="244" text-anchor="middle" fill="var(--text)">role-assignable,</text>
      <text x="400" y="262" text-anchor="middle" fill="var(--text)">approval if it holds</text>
      <text x="400" y="278" text-anchor="middle" fill="var(--text)">an Entra role</text>
      <rect x="485" y="200" width="150" height="88" rx="8" fill="none" stroke="var(--text-muted)" stroke-dasharray="5 4"/>
      <text x="560" y="224" text-anchor="middle" font-weight="700" fill="var(--text)">Not PIM</text>
      <text x="560" y="244" text-anchor="middle" fill="var(--text)">managed identity /</text>
      <text x="560" y="262" text-anchor="middle" fill="var(--text)">workload identity,</text>
      <text x="560" y="278" text-anchor="middle" fill="var(--text)">least privilege</text>
    </g>
  </g>
</svg>
</div>

## A real-world scenario: rolling out PIM step by step
Time to make it concrete. Imagine a company with about 5,000 users, one Entra tenant, and around 40 Azure subscriptions under a management group hierarchy. Today they have 11 permanent Global Administrators, a platform team with Owner on every subscription, and a SOC that "sometimes needs admin". These are the five groups of people we need to serve:

| Persona | What they really need | Layer | Design |
|---|---|---|---|
| **Identity team** (3 people) | Change CA policies, manage roles, rarely GA | Entra | Eligible GA, Privileged Role Admin and CA Admin. Approval for GA, 2 h max |
| **Cloud platform team** (6) | Build and fix landing zones | Azure | Eligible Owner at the <em>platform</em> management group with approval; eligible Contributor on workload subscriptions |
| **Application teams** (~40) | Deploy and troubleshoot their own apps | Azure | Standing Reader; PIM for Groups → Contributor on <em>their</em> resource groups; prod requires approval from the app owner |
| **SOC / DFIR responders** (8) | Investigate across Entra, Defender, Azure and Intune during incidents | Groups | One role-assignable group `PIM-SEC-Responders` → Security Operator + Azure Reader at root MG + Intune Read Only Operator + Defender XDR response roles. One activation, everything an investigation needs |
| **Helpdesk** (25) | Password resets for normal users | Entra | Eligible Helpdesk Administrator scoped to administrative units by region, self-activation 8 h |
| **Break-glass** (2 accounts) | Recover when everything else fails | Entra | The <strong>only</strong> permanent GAs. FIDO2 keys in a safe, excluded from CA, every sign-in alerted |

<strong>Step 1 — Find the standing privilege.</strong> You can't fix what you can't see. This read-only script lists every <em>always-on</em> high-impact assignment across Entra roles and Azure RBAC, including anyone left as User Access Administrator at the root scope after an elevate-access:

```powershell
<#  Find-StandingPrivilege.ps1 - list privileged access that is ALWAYS ON (not just-in-time)
    across Entra roles and Azure RBAC. Read-only.                                          #>
#Requires -Modules Microsoft.Graph.Identity.Governance, Az.Accounts, Az.Resources

# Tier-0 / high-impact Entra roles (built-in role template IDs)
$tier0 = @{
    '62e90394-69f5-4237-9190-012177145e10' = 'Global Administrator'
    'e8611ab8-c189-46e8-94e1-60213ab1f814' = 'Privileged Role Administrator'
    '7be44c8a-adaf-4e2a-84d6-ab2649e08a13' = 'Privileged Authentication Administrator'
    '194ae4cb-b126-40b2-bd5b-6091b380977d' = 'Security Administrator'
    'b1be1c3e-b65d-4f19-8427-f6fa0d97feb9' = 'Conditional Access Administrator'
    '9b895d92-2cd3-44c7-9d02-a6ac2d5ea5c3' = 'Application Administrator'
    '158c047a-c907-4556-b7ef-446551a6b5f7' = 'Cloud Application Administrator'
    '8ac3fc64-6eca-42ea-9e69-59f4c7b60eb2' = 'Hybrid Identity Administrator'
    '3a2c62db-5318-420d-8d74-23affee5d9d5' = 'Intune Administrator'
    '29232cdf-9323-42fd-ade2-1d097af3e4de' = 'Exchange Administrator'
    'fe930be7-5e62-47db-91af-98c3a49a38b1' = 'User Administrator'
    'c4e39bd9-1100-46d3-8c65-fb160da0071f' = 'Authentication Administrator'
}

# ---- Layer 1: Entra roles -------------------------------------------------------------
Connect-MgGraph -Scopes "RoleManagement.Read.Directory","Directory.Read.All" -NoWelcome
$entra = Get-MgRoleManagementDirectoryRoleAssignmentScheduleInstance -All -ExpandProperty "principal" |
    Where-Object { $tier0.ContainsKey($_.RoleDefinitionId) } |
    ForEach-Object {
        [pscustomobject]@{
            Layer     = 'Entra role'
            Role      = $tier0[$_.RoleDefinitionId]
            Scope     = $_.DirectoryScopeId                   # "/" = whole tenant, else an admin unit
            Principal = $_.Principal.AdditionalProperties.userPrincipalName ?? $_.Principal.AdditionalProperties.displayName
            Type      = $_.Principal.AdditionalProperties.'@odata.type' -replace '#microsoft.graph.',''
            Standing  = ($_.AssignmentType -eq 'Assigned' -and -not $_.EndDateTime)   # permanent active
            Ends      = $_.EndDateTime
        }
    }

# ---- Layer 2: Azure RBAC --------------------------------------------------------------
Connect-AzAccount -WarningAction SilentlyContinue | Out-Null
$risky = 'Owner','User Access Administrator','Role Based Access Control Administrator','Contributor'
$azure = foreach ($sub in Get-AzSubscription -WarningAction SilentlyContinue) {
    Set-AzContext -SubscriptionId $sub.Id -WarningAction SilentlyContinue | Out-Null
    Get-AzRoleAssignment -WarningAction SilentlyContinue |
        Where-Object { $_.RoleDefinitionName -in $risky -and $_.ObjectType -in 'User','Group','ServicePrincipal' } |
        ForEach-Object {
            [pscustomobject]@{
                Layer = 'Azure RBAC'; Role = $_.RoleDefinitionName; Scope = $_.Scope
                Principal = $_.SignInName ?? $_.DisplayName; Type = $_.ObjectType
                Standing = $true; Ends = $null      # active RBAC assignment (PIM-activated ones are short-lived)
            }
        }
}
# Anyone with User Access Administrator at the root "/" (often a forgotten "elevate access")
$root = Get-AzRoleAssignment -Scope "/" -RoleDefinitionName "User Access Administrator" -WarningAction SilentlyContinue |
    ForEach-Object { [pscustomobject]@{ Layer='Azure RBAC'; Role='User Access Administrator'; Scope='/ (ROOT)'
                     Principal=$_.SignInName ?? $_.DisplayName; Type=$_.ObjectType; Standing=$true; Ends=$null } }

$all = @($entra) + @($azure) + @($root) | Sort-Object Layer, Role, Principal -Unique
$all | Where-Object Standing | Format-Table Layer, Role, Scope, Principal, Type -AutoSize
$all | Export-Csv .\standing-privilege.csv -NoTypeInformation
"{0} standing privileged assignments found - every one should be eligible (PIM) or a documented break-glass." -f ($all | Where-Object Standing).Count
```

> **Timing:** Run it during a quiet period. Assignments someone has activated through PIM at that moment also appear as active, but with an end date. The `Standing` column only flags assignments with no end date.

<strong>Step 2 — Prepare the ground before converting anyone.</strong> Four things must exist first, or the rollout will lock people out or be bypassed:

1. **Two break-glass accounts**: cloud-only, FIDO2 keys, excluded from Conditional Access, permanently GA, and an alert on every sign-in.
2. **Separate admin accounts** (`adm-name@`), cloud-only, without a mailbox. Admins don't read email with the account that can delete the tenant.
3. **A Conditional Access authentication context**, for example `c1 = "PIM elevation"`, with a CA policy that requires a <strong>phishing-resistant authentication strength</strong> and a <strong>compliant device</strong> (a privileged access workstation if you have one).
4. **Licences**: PIM requires Microsoft Entra ID P2 or Entra ID Governance for the users who benefit from it, including approvers and eligible admins.

<strong>Step 3 — Define the tiers.</strong> One setting profile per tier keeps it understandable:

<div style="margin:2rem 0;padding:1.25rem;background:var(--bg-elevated);border:1px solid var(--border);border-radius:var(--radius-m);">
<svg viewBox="0 0 640 230" style="width:100%;height:auto;font-family:inherit;" role="img" aria-label="Three tiers of PIM settings: tier 0 with approval, phishing-resistant step-up, 2 hour maximum activation and 6 month eligibility expiry; tier 1 with justification and ticket, step-up MFA, 4 to 8 hours and 12 month expiry; tier 2 with self-activation, MFA, 8 hours and quarterly access reviews">
  <g style="font-size:12px;">
    <text x="195" y="20" font-weight="700" fill="var(--text-muted)">ACTIVATION</text>
    <text x="325" y="20" font-weight="700" fill="var(--text-muted)">STEP-UP</text>
    <text x="450" y="20" font-weight="700" fill="var(--text-muted)">MAX TIME</text>
    <text x="535" y="20" font-weight="700" fill="var(--text-muted)">ELIGIBILITY</text>
    <rect x="5" y="32" width="630" height="58" rx="10" fill="var(--accent)" fill-opacity="0.85"/>
    <text x="18" y="56" font-weight="700" font-size="14" fill="var(--accent-contrast)">TIER 0</text>
    <text x="18" y="76" fill="var(--accent-contrast)">GA · PRA · PAA</text>
    <text x="195" y="56" fill="var(--accent-contrast)">approval (2 named</text><text x="195" y="74" fill="var(--accent-contrast)">approver groups)</text>
    <text x="325" y="56" fill="var(--accent-contrast)">auth context:</text><text x="325" y="74" fill="var(--accent-contrast)">FIDO2 + PAW</text>
    <text x="450" y="66" font-weight="700" font-size="15" fill="var(--accent-contrast)">2 h</text>
    <text x="535" y="56" fill="var(--accent-contrast)">expires after</text><text x="535" y="74" fill="var(--accent-contrast)">6 months</text>
    <rect x="5" y="100" width="630" height="58" rx="10" fill="var(--accent)" fill-opacity="0.45"/>
    <text x="18" y="124" font-weight="700" font-size="14" fill="var(--text)">TIER 1</text>
    <text x="18" y="144" fill="var(--text)">CA · Security · Owner</text>
    <text x="195" y="124" fill="var(--text)">justification +</text><text x="195" y="142" fill="var(--text)">ticket number</text>
    <text x="325" y="124" fill="var(--text)">auth context:</text><text x="325" y="142" fill="var(--text)">phishing-resistant</text>
    <text x="450" y="134" font-weight="700" font-size="15" fill="var(--text)">4–8 h</text>
    <text x="535" y="124" fill="var(--text)">expires after</text><text x="535" y="142" fill="var(--text)">12 months</text>
    <rect x="5" y="168" width="630" height="58" rx="10" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="18" y="192" font-weight="700" font-size="14" fill="var(--text)">TIER 2</text>
    <text x="18" y="212" fill="var(--text)">Helpdesk · RG Contrib.</text>
    <text x="195" y="192" fill="var(--text)">self-activation +</text><text x="195" y="210" fill="var(--text)">justification</text>
    <text x="325" y="192" fill="var(--text)">MFA</text>
    <text x="450" y="202" font-weight="700" font-size="15" fill="var(--text)">8 h</text>
    <text x="535" y="192" fill="var(--text)">quarterly</text><text x="535" y="210" fill="var(--text)">access review</text>
  </g>
</svg>
</div>

<strong>Step 4 — Apply the settings as code.</strong> Clicking through PIM settings for 30 roles is how inconsistencies are born. Every PIM role has a policy made of <em>rules</em>, and Microsoft Graph can set them. This script hardens one tier-0 role and then makes an admin <strong>eligible</strong>, not active, with an expiry:

```powershell
<#  Set-PimTier0.ps1 - PIM as code for one Entra role:
    1) harden the activation settings  2) make an admin ELIGIBLE (with an expiry)          #>
param(
    [string]$RoleTemplateId = '62e90394-69f5-4237-9190-012177145e10',   # Global Administrator
    [string]$AdminUpn       = 'adm-yousef@contoso.com',
    [string]$AuthContextId  = 'c1'                                       # CA authentication context "PIM elevation"
)
Connect-MgGraph -Scopes "RoleManagementPolicy.ReadWrite.Directory","RoleManagement.ReadWrite.Directory" -NoWelcome

# 1. Find the PIM policy attached to this role
$policyId = (Get-MgPolicyRoleManagementPolicyAssignment -Filter "scopeId eq '/' and scopeType eq 'DirectoryRole' and roleDefinitionId eq '$RoleTemplateId'").PolicyId

# 2. Activation lasts at most 2 hours
Update-MgPolicyRoleManagementPolicyRule -UnifiedRoleManagementPolicyId $policyId `
    -UnifiedRoleManagementPolicyRuleId 'Expiration_EndUser_Assignment' -BodyParameter @{
        '@odata.type' = '#microsoft.graph.unifiedRoleManagementPolicyExpirationRule'
        id = 'Expiration_EndUser_Assignment'; isExpirationRequired = $true; maximumDuration = 'PT2H'
        target = @{ caller = 'EndUser'; operations = @('All'); level = 'Assignment' }
    }

# 3. Justification + ticket number on every activation
Update-MgPolicyRoleManagementPolicyRule -UnifiedRoleManagementPolicyId $policyId `
    -UnifiedRoleManagementPolicyRuleId 'Enablement_EndUser_Assignment' -BodyParameter @{
        '@odata.type' = '#microsoft.graph.unifiedRoleManagementPolicyEnablementRule'
        id = 'Enablement_EndUser_Assignment'; enabledRules = @('Justification','Ticketing')
        target = @{ caller = 'EndUser'; operations = @('All'); level = 'Assignment' }
    }

# 4. Step-up through Conditional Access (phishing-resistant MFA + compliant device in the CA policy)
Update-MgPolicyRoleManagementPolicyRule -UnifiedRoleManagementPolicyId $policyId `
    -UnifiedRoleManagementPolicyRuleId 'AuthenticationContext_EndUser_Assignment' -BodyParameter @{
        '@odata.type' = '#microsoft.graph.unifiedRoleManagementPolicyAuthenticationContextRule'
        id = 'AuthenticationContext_EndUser_Assignment'; isEnabled = $true; claimValue = $AuthContextId
        target = @{ caller = 'EndUser'; operations = @('All'); level = 'Assignment' }
    }
# (Approval: set it in the portal or with the 'Approval_EndUser_Assignment' rule - approvers are named groups.)

# 5. Eligible - not active - for 180 days, then it must be re-approved
$adminId = (Get-MgUser -UserId $AdminUpn).Id
New-MgRoleManagementDirectoryRoleEligibilityScheduleRequest -Action 'adminAssign' `
    -PrincipalId $adminId -RoleDefinitionId $RoleTemplateId -DirectoryScopeId '/' `
    -Justification 'Tier-0 eligibility, approved in CHG-2041' `
    -ScheduleInfo @{ startDateTime = (Get-Date).ToUniversalTime().ToString('o')
                     expiration    = @{ type = 'afterDuration'; duration = 'P180D' } }
```

For Azure, keep eligibility in the same Git repository as your landing zone. This Bicep file makes a group eligible for Contributor on a subscription, and the eligibility itself expires after six months:

```bicep
targetScope = 'subscription'

@description('Object ID of the Entra group that becomes eligible (PIM for Groups recommended)')
param principalId string

@description('Built-in role to make eligible - default: Contributor')
param roleDefinitionGuid string = 'b24988ac-6181-4d38-a0d7-8a2c4aeb6a31'

param startDateTime string = utcNow()

resource eligible 'Microsoft.Authorization/roleEligibilityScheduleRequests@2022-04-01-preview' = {
  name: guid(subscription().id, principalId, roleDefinitionGuid)
  properties: {
    principalId: principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionGuid)
    requestType: 'AdminAssign'
    justification: 'Eligible Contributor for the platform team - managed in Git'
    scheduleInfo: {
      startDateTime: startDateTime
      expiration: {
        type: 'AfterDuration'
        duration: 'P180D'          // eligibility itself expires: forces a re-review every 6 months
      }
    }
  }
}
```

```bash
az deployment sub create -l westeurope -f pim-eligible.bicep -p principalId=<group-object-id>
```

<strong>Step 5 — Convert, one tier at a time.</strong> Start with tier 2, because it has the most people and the lowest risk, so you learn the friction early. Then tier 1, then tier 0 last, with the identity team in the room. For each person: create the eligible assignment, ask them to activate once while you watch, then remove the permanent assignment. Keep a rollback list for the first week.

<strong>Step 6 — Teach the activation habit.</strong> Activation should be quick and boring. The portal works, but many admins prefer one command:

```powershell
<#  Start-PimActivation.ps1 - what an admin runs to activate an eligible Entra role #>
param([string]$RoleTemplateId = '3a2c62db-5318-420d-8d74-23affee5d9d5',   # Intune Administrator
      [string]$Reason = 'INC-7731: remove malicious remediation script', [string]$Hours = '1')

Connect-MgGraph -Scopes "RoleAssignmentSchedule.ReadWrite.Directory" -NoWelcome
$me = (Get-MgContext).Account
$myId = (Get-MgUser -UserId $me).Id

New-MgRoleManagementDirectoryRoleAssignmentScheduleRequest -Action 'selfActivate' `
    -PrincipalId $myId -RoleDefinitionId $RoleTemplateId -DirectoryScopeId '/' `
    -Justification $Reason -TicketInfo @{ ticketNumber = ($Reason -split ':')[0]; ticketSystem = 'ServiceNow' } `
    -ScheduleInfo @{ startDateTime = (Get-Date).ToUniversalTime().ToString('o')
                     expiration    = @{ type = 'afterDuration'; duration = "PT${Hours}H" } }

# Done early? Give it back instead of waiting for expiry:
# New-MgRoleManagementDirectoryRoleAssignmentScheduleRequest -Action 'selfDeactivate' -PrincipalId $myId `
#     -RoleDefinitionId $RoleTemplateId -DirectoryScopeId '/'
```

This is what happens behind the scenes during one activation, and where each control and each log entry comes from:

<div style="margin:2rem 0;padding:1.25rem;background:var(--bg-elevated);border:1px solid var(--border);border-radius:var(--radius-m);">
<svg viewBox="0 0 640 210" style="width:100%;height:auto;font-family:inherit;" role="img" aria-label="Activation lifecycle: eligible admin requests activation with justification and ticket, Conditional Access authentication context forces phishing-resistant step-up, approvers approve, the role is active for a limited window, then it expires or is deactivated automatically; every step writes to the Entra audit log">
  <defs><marker id="pm-a3" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto"><path d="M0,0 L8,4 L0,8 z" fill="var(--text-muted)"/></marker></defs>
  <g style="font-size:11.5px;">
    <rect x="5" y="20" width="110" height="74" rx="8" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="60" y="44" text-anchor="middle" font-weight="700" fill="var(--text)">① Request</text>
    <text x="60" y="64" text-anchor="middle" fill="var(--text-muted)">eligible admin,</text>
    <text x="60" y="80" text-anchor="middle" fill="var(--text-muted)">reason + ticket</text>
    <rect x="135" y="20" width="110" height="74" rx="8" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="190" y="44" text-anchor="middle" font-weight="700" fill="var(--text)">② Step-up</text>
    <text x="190" y="64" text-anchor="middle" fill="var(--text-muted)">auth context →</text>
    <text x="190" y="80" text-anchor="middle" fill="var(--text-muted)">FIDO2 + PAW</text>
    <rect x="265" y="20" width="110" height="74" rx="8" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="320" y="44" text-anchor="middle" font-weight="700" fill="var(--text)">③ Approve</text>
    <text x="320" y="64" text-anchor="middle" fill="var(--text-muted)">tier 0 only,</text>
    <text x="320" y="80" text-anchor="middle" fill="var(--text-muted)">never self</text>
    <rect x="395" y="20" width="110" height="74" rx="8" fill="var(--accent)"/>
    <text x="450" y="44" text-anchor="middle" font-weight="700" fill="var(--accent-contrast)">④ Active</text>
    <text x="450" y="64" text-anchor="middle" fill="var(--accent-contrast)">1–8 h window,</text>
    <text x="450" y="80" text-anchor="middle" fill="var(--accent-contrast)">do the work</text>
    <rect x="525" y="20" width="110" height="74" rx="8" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="580" y="44" text-anchor="middle" font-weight="700" fill="var(--text)">⑤ Expire</text>
    <text x="580" y="64" text-anchor="middle" fill="var(--text-muted)">automatic, or</text>
    <text x="580" y="80" text-anchor="middle" fill="var(--text-muted)">self-deactivate</text>
    <line x1="115" y1="57" x2="132" y2="57" stroke="var(--text-muted)" stroke-width="2" marker-end="url(#pm-a3)"/>
    <line x1="245" y1="57" x2="262" y2="57" stroke="var(--text-muted)" stroke-width="2" marker-end="url(#pm-a3)"/>
    <line x1="375" y1="57" x2="392" y2="57" stroke="var(--text-muted)" stroke-width="2" marker-end="url(#pm-a3)"/>
    <line x1="505" y1="57" x2="522" y2="57" stroke="var(--text-muted)" stroke-width="2" marker-end="url(#pm-a3)"/>
    <rect x="5" y="120" width="630" height="80" rx="10" fill="none" stroke="var(--text-muted)" stroke-dasharray="5 5"/>
    <text x="18" y="142" font-weight="700" fill="var(--text)">EVIDENCE TRAIL (Entra audit log · LoggedByService = PIM)</text>
    <text x="18" y="164" fill="var(--text-muted)">request → approval decision → "Add member to role completed (PIM activation)" → expiry / removal</text>
    <text x="18" y="184" fill="var(--text-muted)">+ SigninLogs (which auth method satisfied the context)  ·  + what the admin did inside the window</text>
  </g>
</svg>
</div>

<strong>Step 7 — Review and expire.</strong> Configure <strong>access reviews</strong> for PIM roles and groups (quarterly for tier 1–2, monthly for tier 0), and let eligibilities expire. "Eligible forever" is the new "permanent admin": it removes the time limit from the activation, but not from the attack surface.

## Detection: watching the privilege paths
PIM writes everything to the Entra audit log. These are the rules I would build first, in Microsoft Sentinel or any SIEM that receives Entra logs:

<strong>1. Role assigned outside PIM.</strong> After the rollout, this should almost never happen:

```sql
AuditLogs
| where TimeGenerated > ago(1d)
| where Category == "RoleManagement"
| where OperationName has "outside of PIM"
| extend Actor  = coalesce(tostring(InitiatedBy.user.userPrincipalName), tostring(InitiatedBy.app.displayName))
| mv-apply tr = TargetResources on (
    summarize Role = take_anyif(tostring(tr.displayName), tostring(tr.type) == "Role"),
              Target = take_anyif(tostring(tr.userPrincipalName), tostring(tr.type) == "User"))
| project TimeGenerated, OperationName, Actor, Role, Target
```

<strong>2. Elevate access into Azure (the bridge).</strong>

```sql
AuditLogs
| where TimeGenerated > ago(7d)
| where OperationName == "User has elevated their access to User Access Administrator for their Azure Resources"
| project TimeGenerated, Actor = tostring(InitiatedBy.user.userPrincipalName),
          IP = tostring(InitiatedBy.user.ipAddress), Result
```

<strong>3. Tier-0 activation at an unusual time or from a new IP.</strong>

```sql
let tier0 = dynamic(["Global Administrator", "Privileged Role Administrator", "Privileged Authentication Administrator"]);
AuditLogs
| where TimeGenerated > ago(1d)
| where LoggedByService == "PIM" and OperationName has "PIM activation" and OperationName has "completed"
| mv-apply tr = TargetResources on (summarize Role = take_anyif(tostring(tr.displayName), tostring(tr.type) == "Role"))
| where Role in (tier0)
| extend Actor = tostring(InitiatedBy.user.userPrincipalName), IP = tostring(InitiatedBy.user.ipAddress),
         Hour = datetime_part("hour", TimeGenerated), Reason = tostring(ResultReason)
| where Hour !between (6 .. 20)                       // adjust to your admins' working hours (UTC)
| project TimeGenerated, Actor, Role, IP, Reason
```

<strong>4. Someone changed the PIM rules themselves.</strong> An attacker with Privileged Role Administrator will try to remove approval or extend the maximum duration:

```sql
AuditLogs
| where TimeGenerated > ago(7d)
| where LoggedByService == "PIM" and OperationName has "role setting"
| project TimeGenerated, OperationName, Actor = tostring(InitiatedBy.user.userPrincipalName),
          Changes = TargetResources[0].modifiedProperties
```

<strong>5. New eligibility for a tier-0 role, or a new owner on a PIM group.</strong>

```sql
AuditLogs
| where TimeGenerated > ago(7d)
| where LoggedByService == "PIM"
| where OperationName has "eligible" and OperationName has "completed"
| mv-apply tr = TargetResources on (summarize Object = take_anyif(tostring(tr.displayName), tostring(tr.type) in ("Role", "Group")))
| project TimeGenerated, OperationName, Actor = tostring(InitiatedBy.user.userPrincipalName), Object
```

> **Schema drift:** Exact `OperationName` strings differ slightly between Entra roles, Azure resources and groups, and Microsoft occasionally renames them. That's why the rules above match on stable keywords (`has "PIM activation"`, `has "eligible"`). Run each query over 30 days of your own data before turning it into an alert.

## DFIR: questions to answer when a privileged account goes wrong
PIM is not only a prevention control. It is one of the best <strong>forensic data sources</strong> in the tenant, because it turns "this person is an admin" into precise time windows. When an admin account is suspected, I work through these questions:

| # | Question | Where the answer is |
|---|---|---|
| 1 | Which roles could the account activate, and which did it actually activate? | PIM eligibility and assignment schedules (Graph), `AuditLogs` (PIM activation events) |
| 2 | When exactly was it privileged? | Activation start → expiry or deactivation events. These windows are your timeline anchors |
| 3 | Who approved it, and with what justification and ticket? | Approval events and `ResultReason`. A fake ticket number is a strong signal |
| 4 | How did it satisfy the step-up? | `SigninLogs`: authentication method, device, IP and the authentication context claim at activation time |
| 5 | What did it do inside the window? | Entra `AuditLogs`, `AzureActivity`, `MicrosoftGraphActivityLogs`, the Intune audit log, Defender, filtered to the activation window |
| 6 | Did it change the paths themselves? | PIM setting changes, new eligibilities, group owner changes, elevate access, new app credentials |
| 7 | Did it leave a way back in? | New role-assignable group members, app registrations with credentials, federated domains, CA exclusions |

Question 5 is where PIM really pays off. This query takes every PIM activation of a suspect account and pulls everything that account changed during each window:

```sql
let suspect = "adm-someone@contoso.com";
let windows = AuditLogs
    | where TimeGenerated > ago(30d)
    | where LoggedByService == "PIM" and OperationName has "PIM activation" and OperationName has "completed"
    | where tostring(InitiatedBy.user.userPrincipalName) =~ suspect
    | mv-apply tr = TargetResources on (summarize Role = take_anyif(tostring(tr.displayName), tostring(tr.type) == "Role"))
    | project Start = TimeGenerated, End = TimeGenerated + 8h, Role;   // use your max activation time
union
    (AuditLogs | where InitiatedBy.user.userPrincipalName =~ suspect
               | project TimeGenerated, Source = "Entra", Operation = OperationName,
                         Target = tostring(TargetResources[0].displayName)),
    (AzureActivity | where Caller =~ suspect and ActivityStatusValue == "Success"
               | project TimeGenerated, Source = "Azure", Operation = OperationNameValue, Target = _ResourceId)
| extend k = 1
| join kind=inner (windows | extend k = 1) on k          // KQL joins need equality: join on a constant…
| where TimeGenerated between (Start .. End)              // …then keep only events inside a window
| project TimeGenerated, Role, Source, Operation, Target
| order by TimeGenerated asc
```

> **Scaling up:** The constant-key join is fine for one suspect account over a few weeks. For a whole tenant, bin both sides by hour and join on the bin instead. Microsoft Graph activity logs and the Intune audit log can be added to the `union` the same way.

If the account is confirmed compromised, contain in this order: <strong>remove the eligibility</strong> (not only the active assignment, or the attacker simply activates again), revoke sessions, reset credentials and remove attacker-registered MFA methods, then review everything from question 6 and 7. Finally, rotate the break-glass credentials if there is any chance they were exposed.

## Common mistakes
| Mistake | Why it hurts | Better |
|---|---|---|
| "We have PIM" but eligible assignments never expire | Same attack surface as permanent, plus a false sense of security | Eligibility expiry + access reviews |
| Approval required, but the approver group contains the requester's own other account | Self-approval by design | Separate approver groups, no admin-to-admin loops |
| GA activation only needs normal MFA | Token theft (AiTM) defeats it | Authentication context with phishing-resistant strength |
| Azure Owner at management-group level made eligible "to be safe" | One activation = everything | Smallest scope; RBAC Administrator with conditions |
| PIM groups that hold Entra roles allow self-activation | A lower admin can reset a member's password and activate for them | Role-assignable groups + approval |
| Nobody watches elevate access | The quietest path from Entra into Azure | Alert on every use; remove root UAA afterwards |
| Service accounts put in PIM | Automation breaks, then someone makes it permanent "temporarily" | Managed / workload identities with least privilege |

## Download the scripts
- <a href="/assets/files/pim/Find-StandingPrivilege.ps1" target="_blank" rel="noopener">Find-StandingPrivilege.ps1</a> — standing privilege across Entra and Azure
- <a href="/assets/files/pim/Set-PimTier0.ps1" target="_blank" rel="noopener">Set-PimTier0.ps1</a> — PIM settings and eligibility as code
- <a href="/assets/files/pim/Start-PimActivation.ps1" target="_blank" rel="noopener">Start-PimActivation.ps1</a> — one-command activation
- <a href="/assets/files/pim/pim-eligible.bicep" target="_blank" rel="noopener">pim-eligible.bicep</a> — Azure eligibility in Git

> **Tested how:** I parse-checked all the PowerShell, confirmed every cmdlet and parameter exists in the current Microsoft Graph and Az modules, and compiled the Bicep file. Test the write operations in a non-production tenant first. A wrong PIM rule on Global Administrator can lock out your own admins, which is exactly why the break-glass accounts come first.

## Follow the paths, not just the roles

Global Administrator and Azure Owner live in different permission worlds, and PIM for Groups lets a single activation reach into both. Good PIM design starts with the original post's question — <em>what am I protecting?</em> — and then follows the paths between layers: elevate access, role-assignable groups, app credentials and password-reset rights. Convert standing access tier by tier, enforce step-up through an authentication context, let eligibility expire, and alert on anything that happens outside PIM. When something does go wrong, activation windows become the backbone of your timeline. Thanks again to <a href="https://www.linkedin.com/feed/update/urn:li:activity:7499820735549321216/" target="_blank" rel="noopener">Rishi .P</a> for the spark.

Further reading: <a href="https://learn.microsoft.com/en-us/entra/id-governance/privileged-identity-management/pim-configure" target="_blank" rel="noopener">Microsoft Entra Privileged Identity Management</a>, <a href="https://learn.microsoft.com/en-us/entra/id-governance/privileged-identity-management/concept-pim-for-groups" target="_blank" rel="noopener">PIM for Groups</a>, <a href="https://learn.microsoft.com/en-us/azure/role-based-access-control/elevate-access-global-admin" target="_blank" rel="noopener">elevate access for a Global Administrator</a>, and the <a href="https://learn.microsoft.com/en-us/graph/api/resources/privilegedidentitymanagementv3-overview" target="_blank" rel="noopener">PIM APIs in Microsoft Graph</a>.
