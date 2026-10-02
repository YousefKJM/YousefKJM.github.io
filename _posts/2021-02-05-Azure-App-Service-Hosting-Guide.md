---
title: "Hosting on Azure App Service: The 15-Minute Deploy Runbook"
excerpt: "Resource group to live HTTPS URL in fifteen minutes, using nothing but the Azure CLI. The exact commands, the order they go in, and the five settings people forget until production breaks."
---

App Service is the fastest way to get a web app onto Azure without managing a VM. This is the runbook I use — CLI only, so it's repeatable and scriptable.

<div style="margin:2rem 0;padding:1.25rem;background:var(--bg-elevated);border:1px solid var(--border);border-radius:var(--radius-m);">
<svg viewBox="0 0 640 230" style="width:100%;height:auto;font-family:inherit;" role="img" aria-label="Azure App Service hierarchy: subscription contains resource group, which contains an App Service plan, which hosts one or more web apps with deployment slots">
  <g style="font-size:13px;">
    <rect x="10" y="10" width="620" height="210" rx="10" fill="none" stroke="var(--border)" stroke-width="2"/>
    <text x="24" y="32" font-weight="700" fill="var(--text-muted)">SUBSCRIPTION — billing boundary</text>
    <rect x="30" y="45" width="580" height="160" rx="8" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="44" y="66" font-weight="700" fill="var(--text)">Resource Group  rg-myapp-prod</text>
    <text x="300" y="66" fill="var(--text-muted)">lifecycle boundary: delete RG = delete everything</text>
    <rect x="50" y="80" width="540" height="110" rx="8" fill="none" stroke="var(--accent)" stroke-width="2"/>
    <text x="64" y="101" font-weight="700" fill="var(--accent)">App Service Plan  (B1 / S1 / P1v3)</text>
    <text x="330" y="101" fill="var(--text-muted)">= the compute you pay for</text>
    <rect x="70" y="115" width="155" height="60" rx="6" fill="var(--bg-elevated)" stroke="var(--border)"/>
    <text x="84" y="140" font-weight="700" fill="var(--text)">Web App #1</text>
    <text x="84" y="160" fill="var(--text-muted)">production slot</text>
    <rect x="240" y="115" width="155" height="60" rx="6" fill="var(--bg-elevated)" stroke="var(--border)"/>
    <text x="254" y="140" font-weight="700" fill="var(--text)">staging slot</text>
    <text x="254" y="160" fill="var(--text-muted)">swap → zero downtime</text>
    <rect x="410" y="115" width="160" height="60" rx="6" fill="var(--bg-elevated)" stroke="var(--border)"/>
    <text x="424" y="140" font-weight="700" fill="var(--text)">Web App #2</text>
    <text x="424" y="160" fill="var(--text-muted)">shares the same plan</text>
  </g>
</svg>
</div>

**The one mental model that matters:** you pay for the **plan**, not the app. Multiple apps on one plan share its CPU and RAM — cheap for dev, dangerous for prod if one app eats the box.

## Step 1 — Log in and set variables

```bash
az login
az account set --subscription "<subscription-name-or-id>"

RG=rg-myapp-prod
LOC=westeurope
PLAN=plan-myapp-prod
APP=myapp-$RANDOM          # must be globally unique: becomes $APP.azurewebsites.net
```

## Step 2 — Resource group and plan

```bash
az group create -n $RG -l $LOC
az appservice plan create -g $RG -n $PLAN --is-linux --sku B1
```

Pick the SKU deliberately:

| SKU | Use it for | Gets you |
|---|---|---|
| F1 / D1 | Throwaway demos | Shared compute, no custom TLS, sleeps when idle |
| B1 | Dev/test, small internal tools | Dedicated compute, custom domains + TLS |
| S1 | Small production | **Deployment slots**, autoscale, daily backups |
| P1v3 | Real production | Faster CPUs, VNet integration, more slots |

If you need slots (you do, for production), you need **S1 or higher**.

## Step 3 — Create the web app with a runtime

```bash
az webapp list-runtimes --os linux      # see what's available

az webapp create -g $RG -p $PLAN -n $APP --runtime "PYTHON:3.9"
# or: --runtime "NODE:14-lts"   --runtime "DOTNETCORE:5.0"
```

## Step 4 — Configure before you deploy

App settings become **environment variables** inside the app. Never bake secrets into code.

```bash
az webapp config appsettings set -g $RG -n $APP --settings \
  DJANGO_SETTINGS_MODULE=core.settings.prod \
  SCM_DO_BUILD_DURING_DEPLOYMENT=true \
  SECRET_KEY="<generate-one>"

# Startup command (Python example — gunicorn serving your WSGI app)
az webapp config set -g $RG -n $APP \
  --startup-file "gunicorn --bind=0.0.0.0 --timeout 600 core.wsgi"
```

## Step 5 — Deploy

Three options, from quickest to most professional:

```bash
# A) Zip deploy from your machine
zip -r app.zip . -x "*.git*" "venv/*"
az webapp deployment source config-zip -g $RG -n $APP --src app.zip

# B) Local Git push
az webapp deployment source config-local-git -g $RG -n $APP
git remote add azure <url-from-output>
git push azure main

# C) CI/CD — generate a publish profile and let GitHub Actions / Azure DevOps deploy
az webapp deployment list-publishing-profiles -g $RG -n $APP --xml > profile.xml
```

Use **C** for anything you'll maintain. (I covered the Azure DevOps pipeline version in [an earlier post](/Microsoft-Azure-DevOps-for-ASP-.NET-Core-Web-apps/).)

## Step 6 — Lock it down

```bash
az webapp update -g $RG -n $APP --https-only true
az webapp config set -g $RG -n $APP --min-tls-version 1.2 --ftps-state Disabled
az webapp identity assign -g $RG -n $APP      # managed identity → Key Vault, no stored creds
```

## Step 7 — Watch it

```bash
az webapp log config -g $RG -n $APP --application-logging filesystem --level information
az webapp log tail -g $RG -n $APP
```

## The five settings people forget

1. **HTTPS-only** is off by default. Turn it on.
2. **FTP/FTPS** is enabled by default. Disable it — it's a credential-based side door.
3. **Always On** (Basic+) — without it the app unloads when idle and the first request is slow.
   `az webapp config set -g $RG -n $APP --always-on true`
4. **Health check path** so the platform can pull a broken instance out of rotation.
   `az webapp config set -g $RG -n $APP --generic-configurations '{"healthCheckPath": "/health"}'`
5. **Slot-sticky settings** — mark connection strings as "slot setting" so a swap doesn't point staging code at the production database.

## Zero-downtime releases with slots

```bash
az webapp deployment slot create -g $RG -n $APP --slot staging
# deploy to staging, test it at $APP-staging.azurewebsites.net, then:
az webapp deployment slot swap -g $RG -n $APP --slot staging --target-slot production
```

The swap warms up the staging instance first, then flips routing. Broke something? Swap back — it's the same command.

## Tear down

```bash
az group delete -n $RG --yes --no-wait
```

One command, everything gone, billing stops. This is why everything goes in a resource group.
