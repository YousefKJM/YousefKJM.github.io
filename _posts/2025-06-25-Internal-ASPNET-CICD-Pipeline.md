---
title: "From Manual Copy to a Real Pipeline: CI/CD for an Internal ASP.NET App"
excerpt: "We ship an internal ASP.NET app by publishing from Visual Studio, dropping the build on a file share, and copying it onto a locked-down IIS server through a privileged session. Here's how to turn that into a proper Dev → UAT → Prod pipeline on an on-prem Azure DevOps Server — no GitHub, no internet on the server — with the exact access requests, YAML, deployment script, approvals and rollback."
header:
  image: /images/posts/aspnet-cicd/hero.svg
tags: [Software, Web, DevOps, CI-CD, ASP.NET, IIS, Azure-DevOps]
---
![From manual copy to a real pipeline: CI/CD for an internal ASP.NET app](/images/posts/aspnet-cicd/hero.svg)

Here's a deployment process a lot of internal apps still live with — ours included. I develop an **ASP.NET (Web Forms) line-of-business app** locally in Visual Studio on my corporate workstation, with a connection to the application database. When a change is ready I *clean, rebuild, publish* to get the compiled output, drop that onto a shared **file-drop folder** (our ECM), then open a **privileged (PAM) session** to the internal IIS server — which isn't exposed to the internet and can only reach that file share — pull the build down, copy it into the site folder, and the website updates.

It works. It's also entirely manual, has no version history, no second pair of eyes, no test gate, and no clean rollback when a deploy goes wrong. This post is how I'm replacing it with a controlled **Dev → UAT → Production** pipeline — under three real constraints a lot of corporate environments share:

> **The constraints:** GitHub isn't allowed. The IIS server has no internet access. And Visual Studio isn't permitted on the server. The one thing we *do* have is an **on-prem Azure DevOps Server (TFS)**, managed by IT. Everything below is built to live inside those lines.

## The target architecture

The core idea is a clean separation: my workstation **develops and pushes code**; an **approved agent deploys it**. I never get standing admin on the production server — the pipeline does the deploy under a controlled identity, and every release is recorded.

<div style="margin:2rem 0;padding:1.25rem;background:var(--bg-elevated);border:1px solid var(--border);border-radius:var(--radius-m);">
<svg viewBox="0 0 640 300" style="width:100%;height:auto;font-family:inherit;" role="img" aria-label="Pipeline architecture: the corporate workstation commits and pushes to the on-prem Azure DevOps Server, which holds the private Git repo. A CI build runs on a self-hosted Windows build agent that compiles and publishes one versioned artifact. A release deploys that artifact to UAT (with a test database) for validation; after a manual approval gate, the same artifact deploys to the production IIS server (with the production database) via an approved deployment agent.">
  <defs><marker id="a-a" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto"><path d="M0,0 L8,4 L0,8 z" fill="var(--accent)"/></marker></defs>
  <g style="font-size:11.5px;">
    <rect x="6" y="120" width="120" height="60" rx="9" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="66" y="144" text-anchor="middle" font-weight="700" fill="var(--text)">Workstation</text>
    <text x="66" y="162" text-anchor="middle" fill="var(--text-muted)">VS · Git · dev DB</text>
    <rect x="160" y="112" width="130" height="76" rx="9" fill="var(--bg-elevated-2)" stroke="var(--accent)"/>
    <text x="225" y="136" text-anchor="middle" font-weight="700" fill="var(--accent)">Azure DevOps</text>
    <text x="225" y="154" text-anchor="middle" fill="var(--text-muted)">Server (TFS)</text>
    <text x="225" y="170" text-anchor="middle" fill="var(--text-muted)">private Git repo</text>
    <rect x="160" y="18" width="130" height="64" rx="9" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="225" y="40" text-anchor="middle" font-weight="700" fill="var(--text)">Build agent</text>
    <text x="225" y="58" text-anchor="middle" fill="var(--text-muted)">Windows + Build</text>
    <text x="225" y="73" text-anchor="middle" fill="var(--text-muted)">Tools → 1 artifact</text>
    <rect x="330" y="112" width="120" height="76" rx="9" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="390" y="140" text-anchor="middle" font-weight="700" fill="var(--text)">UAT IIS</text>
    <text x="390" y="158" text-anchor="middle" fill="var(--text-muted)">test database</text>
    <text x="390" y="174" text-anchor="middle" fill="var(--text-muted)">validate</text>
    <rect x="330" y="218" width="120" height="58" rx="9" fill="var(--bg-elevated-2)" stroke="#f5b84a"/>
    <text x="390" y="244" text-anchor="middle" font-weight="700" fill="#f5b84a">Approval gate</text>
    <text x="390" y="261" text-anchor="middle" fill="var(--text-muted)">human sign-off</text>
    <rect x="500" y="112" width="134" height="76" rx="9" fill="var(--accent)" fill-opacity="0.10" stroke="var(--accent-strong)"/>
    <text x="567" y="140" text-anchor="middle" font-weight="700" fill="var(--text)">Production IIS</text>
    <text x="567" y="158" text-anchor="middle" fill="var(--text-muted)">prod database</text>
    <text x="567" y="174" text-anchor="middle" fill="var(--text-muted)">via deploy agent</text>
    <line x1="126" y1="150" x2="158" y2="150" stroke="var(--accent)" stroke-width="2" marker-end="url(#a-a)"/>
    <text x="142" y="142" text-anchor="middle" fill="var(--text-muted)" font-size="9">push</text>
    <line x1="225" y1="112" x2="225" y2="84" stroke="var(--accent)" stroke-width="2" marker-end="url(#a-a)"/>
    <line x1="290" y1="150" x2="328" y2="150" stroke="var(--accent)" stroke-width="2" marker-end="url(#a-a)"/>
    <line x1="390" y1="188" x2="390" y2="216" stroke="var(--text-muted)" stroke-width="1.5" marker-end="url(#a-a)"/>
    <line x1="450" y1="150" x2="498" y2="150" stroke="var(--accent-strong)" stroke-width="2" marker-end="url(#a-a)"/>
    <text x="474" y="142" text-anchor="middle" fill="var(--text-muted)" font-size="9">after ✓</text>
    <text x="320" y="296" text-anchor="middle" fill="var(--text-muted)">UAT and Production receive the <tspan font-weight="700" fill="var(--text)">same tested artifact</tspan> — production deploys only after validation + approval.</text>
  </g>
</svg>
</div>

What this buys you over the manual flow: **source control and history, a second reviewer, build-once/deploy-many, a test gate before production, approvals, an audit trail, and a real rollback** — without punching a hole in the network boundaries your security team put there on purpose.

## Step 0 — this is an access project before it's a pipeline

The biggest mistake here is trying to build the pipeline before IT has provisioned anything. On an IT-managed Azure DevOps Server you don't stand up your own server or agent — you *request* a project and access. If you open the collection and get a **`TF400813` ("not authorized")** error, that's the tell: it's an access-provisioning task for IT, not something you fix in a pipeline.

So the first deliverable is a single, well-formed request. Here's what to ask for, and who typically owns each piece:

| Request | Detail | Owner |
|---|---|---|
| **TFS access** | Resolve the `TF400813` authorization error for the dev team | IT |
| **Project** | Create a private team project | IT provisions |
| **Repository** | Enable a private **Git** repo in the project | IT |
| **Permissions** | Contribute, create branches, create & run pipelines | IT |
| **Agent pool** | A dedicated or approved shared **Windows build-agent** pool | IT |
| **Build tools** | MSBuild, the exact .NET Framework targeting pack, NuGet | IT |
| **UAT** | A separate IIS app + **test database** | IT / DB team |
| **Deployment** | An approved mechanism to update UAT and prod IIS files | IT / Web Ops |
| **Secrets** | Protected pipeline variables or an IT-managed secret store | IT |
| **Network** | Approved agent → TFS and (if used) agent → IIS connectivity | Network |
| **Approvals** | Named production release approver + change control | You / IT |

> **The one thing worth repeating to IT:** the **build agent** needs *Visual Studio Build Tools*, not the full IDE — and the **production server needs neither**. That usually unblocks the "we don't allow Visual Studio on servers" objection immediately.

Before you touch a pipeline, get four answers from IT — they decide the whole implementation and stop you from guessing at their config:

1. The exact **Azure DevOps Server version**.
2. Whether **Git** and **YAML pipelines** are enabled, or only **Classic** build/release.
3. Whether a **self-hosted Windows build agent** is available (or you provide the VM).
4. Whether agents are **allowed to deploy to the internal IIS** servers.

## Step 1 — get the code into Git

Once the repo exists, put the solution under source control from your workstation. In Visual Studio: **Git → Create Git Repository**, pick the internal Azure DevOps repo as the remote, commit, push. Or from PowerShell in the solution folder:

```powershell
cd "C:\Projects\MyApp"
git init
git branch -M main
git add .
git commit -m "Initial baseline of the app"
git remote add origin "https://tfs.corp.internal/tfs/DefaultCollection/MyProject/_git/MyApp"
git push -u origin main
```

Copy the real remote URL from the repo's **Clone** button rather than assuming its shape — the collection and project names are whatever IT created.

> **Before `git add .`:** make sure no database credentials, production `web.config` secrets, publish profiles or private certificates get committed. A `.gitignore` for the build artifacts and local settings goes in *first*:

```gitignore
# .gitignore
bin/
obj/
packages/
*.user
*.suo
.vs/
PublishProfiles/*.pubxml.user
appsettings.*.local.json
```

A branch model that keeps `main` always-deployable:

| Branch | Purpose |
|---|---|
| `main` | Approved, production-ready code |
| `develop` | Integration + UAT preparation |
| `feature/*` | Individual enhancements |
| `hotfix/*` | Urgent production fixes |

```powershell
git checkout develop
git checkout -b feature/report-filtering
# ...develop and test locally...
git add .
git commit -m "Improve report filtering"
git push -u origin feature/report-filtering
# open a Pull Request into develop; after review + UAT, promote to main
```

Then add a **branch policy** on `main`: require a successful build and at least one reviewer before any merge. That single setting is most of what "DevOps maturity" actually means in practice.

## Step 2 — the build agent

IT provisions a Windows VM that can reach the TFS server. It needs:

- Windows Server (or an approved Windows OS).
- **Visual Studio Build Tools** with the ASP.NET / .NET Framework build workload.
- The **exact .NET Framework targeting pack** your app builds against.
- Git and NuGet.
- A dedicated, least-privilege service identity.

Registering the agent is a couple of commands on that VM (IT supplies the collection URL, auth, pool name and identity):

```powershell
# on the dedicated build-agent VM
cd C:\agent
.\config.cmd
# then run it as a Windows service when prompted
```

> **Keep build and deploy separate.** The build agent compiles code; it should *not* have write access to production. If you later add an agent that deploys to IIS, make it a different identity with narrowly scoped permissions.

## Step 3 — the build pipeline (build once, version it)

If IT confirms YAML support, this is a complete starter `azure-pipelines.yml` for an ASP.NET Web Forms app: restore, build + publish to a folder, zip it, and publish a **versioned artifact**. The whole point is that the thing UAT tests is byte-for-byte the thing production gets.

```yaml
# azure-pipelines.yml
trigger:
  branches:
    include: [ main, develop ]

pool:
  name: 'OnPrem-Windows'          # your self-hosted Windows agent pool

variables:
  solution: '**/*.sln'
  buildPlatform: 'Any CPU'
  buildConfiguration: 'Release'

steps:
- task: NuGetToolInstaller@1

- task: NuGetCommand@2
  displayName: 'Restore packages'
  inputs:
    restoreSolution: '$(solution)'

- task: VSBuild@1
  displayName: 'Build & publish to a folder'
  inputs:
    solution: '$(solution)'
    platform: '$(buildPlatform)'
    configuration: '$(buildConfiguration)'
    # Web Forms / Web Application publish to the file system:
    msbuildArgs: >
      /p:DeployOnBuild=true
      /p:WebPublishMethod=FileSystem
      /p:PublishProvider=FileSystem
      /p:SkipInvalidConfigurations=true
      /p:publishUrl="$(Build.ArtifactStagingDirectory)\site"

- task: ArchiveFiles@2
  displayName: 'Zip the published site'
  inputs:
    rootFolderOrFile: '$(Build.ArtifactStagingDirectory)\site'
    includeRootFolder: false
    archiveType: 'zip'
    archiveFile: '$(Build.ArtifactStagingDirectory)\app_$(Build.BuildNumber).zip'

- task: PublishBuildArtifacts@1
  displayName: 'Publish the artifact'
  inputs:
    PathtoPublish: '$(Build.ArtifactStagingDirectory)\app_$(Build.BuildNumber).zip'
    ArtifactName: 'drop'
```

Create it in the project: **Pipelines → New Pipeline → your repo → Existing YAML file → `azure-pipelines.yml`**, confirm the agent pool, run it, and then do the one check that matters: **download the artifact and diff its contents against a known-good manual Visual Studio publish.** They should match. Older Web Forms projects sometimes need project-specific MSBuild publish parameters — this is where you find that out, safely.

> **If your server is Classic-only**, the same four steps exist in the visual designer: *NuGet restore → Visual Studio Build → Archive files → Publish build artifacts*. Nothing below changes.

## Step 4 — deploy to UAT, then (after approval) production

The release takes that one artifact and pushes it to environments. **UAT and production use the same artifact** — never rebuild separately for prod, or you've thrown away the thing you tested.

Here's a deployment script template to run on the IIS target under an approved deployment identity. It backs up the current site, stops the app pool, swaps the files while **preserving the environment-specific `web.config`**, and restarts:

```powershell
# Deploy-IIS.ps1  — run on the target IIS host under an approved identity
param(
  [Parameter(Mandatory)] [string]$Package,      # path to the app zip
  [Parameter(Mandatory)] [string]$SitePath,     # IIS physical path, e.g. C:\inetpub\MyApp
  [Parameter(Mandatory)] [string]$BackupRoot,   # e.g. D:\IISBackups\MyApp
  [string]$AppPoolName = 'MyAppPool'
)
$ErrorActionPreference = 'Stop'
Import-Module WebAdministration

$stamp  = Get-Date -Format 'yyyyMMdd_HHmmss'
$backup = Join-Path $BackupRoot $stamp
New-Item -ItemType Directory -Force -Path $backup | Out-Null

Write-Host "Backing up current site -> $backup"
Copy-Item -Path (Join-Path $SitePath '*') -Destination $backup -Recurse -Force

# Preserve the live, environment-specific web.config
$savedConfig = Join-Path $env:TEMP "web.config.$stamp"
if (Test-Path (Join-Path $SitePath 'web.config')) {
    Copy-Item (Join-Path $SitePath 'web.config') $savedConfig -Force
}

Write-Host "Stopping app pool: $AppPoolName"
if ((Get-WebAppPoolState -Name $AppPoolName).Value -ne 'Stopped') { Stop-WebAppPool -Name $AppPoolName }
Start-Sleep -Seconds 3

Write-Host "Deploying new build"
$tmp = Join-Path $env:TEMP "deploy_$stamp"
Expand-Archive -Path $Package -DestinationPath $tmp -Force
# copy everything EXCEPT web.config, so prod config survives the deploy
Get-ChildItem $tmp -Exclude 'web.config' | Copy-Item -Destination $SitePath -Recurse -Force
if (Test-Path $savedConfig) { Copy-Item $savedConfig (Join-Path $SitePath 'web.config') -Force }

Write-Host "Starting app pool"
Start-WebAppPool -Name $AppPoolName
Write-Host "Done. Rollback copy is at $backup"
```

```powershell
# how the release calls it
.\Deploy-IIS.ps1 `
    -Package "C:\agent\_work\artifacts\app_2025.06.25.1.zip" `
    -SitePath "C:\inetpub\MyApp" `
    -BackupRoot "D:\IISBackups\MyApp"
```

> **Honest caveat:** this is a *starter*, not a hardened production deployer. It doesn't yet do transactional file replacement, obsolete-file cleanup, or a full automated rollback with health gating. Harden and test all of that **on UAT** before it ever runs against production. And on a shared IIS box, **recycle only this app's pool** — never `iisreset`.

**The UAT stage** should: download the artifact, back up, stop the app, deploy files, keep UAT-specific config, restart, then run a smoke test:

```powershell
$r = Invoke-WebRequest -Uri "http://uat-host/MyApp/Default.aspx" -UseBasicParsing -TimeoutSec 30
if ($r.StatusCode -ne 200) { throw "UAT health check failed" }
```

That only proves the homepage answers. Add real checks — a page that touches the database, an authenticated page — because a 200 or a redirect to a login page doesn't prove the app is *healthy*. And UAT must point at a **separate test database**, never production data.

**The production stage** is gated:

> **No automatic production deploys.** A developer pushing code must never deploy to production on its own. The release waits for a **named approver** and your change-control sign-off, then deploys the **same artifact** that passed UAT.

## How the deploy actually reaches a locked-down server

Your ECM/PAM boundary exists on purpose, and a pipeline shouldn't quietly bypass it. IT approves one of these models — I'd start at the bottom and climb:

<div style="margin:2rem 0;padding:1.25rem;background:var(--bg-elevated);border:1px solid var(--border);border-radius:var(--radius-m);">
<svg viewBox="0 0 640 170" style="width:100%;height:auto;font-family:inherit;" role="img" aria-label="Three deployment models, from most to least automated. One: a deployment agent installed on the IIS server pulls approved jobs from TFS — preferred if IT allows it. Two: a dedicated deployment VM reaches IIS over approved PowerShell remoting, Web Deploy or a controlled share — a good alternative. Three: the pipeline builds and publishes to the existing file-drop folder, and an authorized operator finishes the copy — a transitional step that still gives you source control, versioned artifacts and traceability on day one.">
  <g style="font-size:11px;">
    <rect x="4" y="14" width="206" height="142" rx="10" fill="var(--accent)" fill-opacity="0.08" stroke="var(--accent-strong)"/>
    <text x="20" y="38" font-weight="700" fill="var(--text)">A · Agent on IIS</text>
    <text x="20" y="60" fill="var(--text-muted)">deploy agent on the</text>
    <text x="20" y="76" fill="var(--text-muted)">server pulls approved</text>
    <text x="20" y="92" fill="var(--text-muted)">jobs from TFS</text>
    <text x="20" y="128" fill="var(--accent)" font-weight="700">most automated</text>
    <text x="20" y="145" fill="var(--text-muted)">preferred if allowed</text>
    <rect x="217" y="14" width="206" height="142" rx="10" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="233" y="38" font-weight="700" fill="var(--text)">B · Deployment VM</text>
    <text x="233" y="60" fill="var(--text-muted)">agent reaches IIS via</text>
    <text x="233" y="76" fill="var(--text-muted)">PS remoting, Web</text>
    <text x="233" y="92" fill="var(--text-muted)">Deploy or a share</text>
    <text x="233" y="128" fill="var(--text)" font-weight="700">good alternative</text>
    <text x="233" y="145" fill="var(--text-muted)">no agent on prod</text>
    <rect x="430" y="14" width="206" height="142" rx="10" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="446" y="38" font-weight="700" fill="var(--text)">C · Pipeline + file drop</text>
    <text x="446" y="60" fill="var(--text-muted)">pipeline publishes to</text>
    <text x="446" y="76" fill="var(--text-muted)">the file share; an</text>
    <text x="446" y="92" fill="var(--text-muted)">operator finishes it</text>
    <text x="446" y="128" fill="var(--text)" font-weight="700">start here</text>
    <text x="446" y="145" fill="var(--text-muted)">value on day one</text>
  </g>
</svg>
</div>

Model **C** is the quiet win: even if IT won't yet install an agent on the production server, you *immediately* get source control, reviewed changes, automated builds, versioned artifacts and release traceability — the risky manual part just shrinks to the final approved copy, which is exactly your current PAM step. Then graduate to **B**, then **A**, as IT authorizes the deployment identity and network path. Only request the connectivity the chosen model needs — don't ask for broad admin just to make things work.

## Don't forget the database

Application rollback is easy; schema rollback is not. Keep migrations in source control and apply them deliberately:

```text
MyApp/
└── Database/
    └── Migrations/
        ├── 001_Baseline.sql
        ├── 002_AddColumns.sql
        └── 003_LookupTableChange.sql
```

Each script gets reviewed and tested against UAT first. **Never auto-run arbitrary SQL against production on every build.** Production migrations are explicitly approved, backed up, and applied with a narrowly scoped account. And test the ordering: if you roll back the app files but a migration already changed the schema, the old build may not run against the new schema — plan schema changes to be backward-compatible for one version where you can.

## Release record + rollback

Capture this for every release — it's your audit trail and your rollback map:

| Field | Example |
|---|---|
| App / Release | MyApp · `2025.06.25.1` |
| Commit | Git commit ID |
| Artifact | `app_2025.06.25.1.zip` |
| UAT result | Passed |
| Prod approval | Approver + date |
| DB migration | None / `003` |
| Rollback to | Previous successful release |

A failed production deploy = restore the previous artifact and config from the backup the script made, then smoke-test. Keep those backups in a restricted location *outside* the live site directory.

## The roadmap, realistically

| Phase | What happens | Rough time |
|---|---|---|
| **1 · Access & onboarding** | TFS auth fixed, project + Git created, agent pool confirmed | 1–2 weeks (IT-gated) |
| **2 · Source control & CI** | Import solution, branches, build, validate the artifact | 3–5 days after access |
| **3 · UAT deployment** | Provision UAT, wire deployment, test rollback | 1–2 weeks |
| **4 · Production enablement** | Approvals, prod deploy, health checks, handover | ~1 week after UAT sign-off |

Those are planning estimates, not promises — the long poles are all IT approvals, which is exactly why Step 0 comes first.

## Where this leaves you

Once it's running, my day looks like: build the change locally, push, open a PR, let the pipeline build one versioned artifact, deploy it to UAT and validate, get the production approval, and let the approved agent deploy the *same* artifact — with a recorded outcome and a one-command rollback. The repeated manual copying through a file share and interactive privileged sessions goes away, while the governance and access boundaries that made that process safe stay exactly where they were.

My honest first milestone, before any of the fancy stuff: **get the solution into the internal Git repo and have the pipeline produce the same published package Visual Studio produces today.** Once that's boringly reliable, adding UAT and production automation on top is the easy part.

Worth reading next: Microsoft's docs on [self-hosted Windows agents](https://learn.microsoft.com/en-us/azure/devops/pipelines/agents/windows-agent), [deployment groups](https://learn.microsoft.com/en-us/azure/devops/pipelines/release/deployment-groups/) for Azure DevOps Server, and [environments & approvals](https://learn.microsoft.com/en-us/azure/devops/pipelines/process/environments) — those three decide the shape of the deployment half.
