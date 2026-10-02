---
title: "Hosting a Web App on Azure App Service Using the Azure CLI"
excerpt: "In this article I would like to present how to host a web application on Azure App Service from start to finish using only the Azure CLI — resource group, plan, configuration, deployment, security settings and zero-downtime releases with deployment slots."
header:
  image: /images/posts/article2/adevops26.png
---

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

<h3><strong>Short introduction</strong></h3>
In my [Azure DevOps article](/Microsoft-Azure-DevOps-for-ASP-.NET-Core-Web-apps/) we deployed a web app to Azure App Service through the Azure portal and a release pipeline. The portal is great for learning, but clicking through the same screens for every environment gets slow and it is hard to repeat exactly. During my time as an Azure App Developer, I started doing the same setup with the <strong>Azure CLI</strong> instead: every step is one command, so the whole setup can be saved as a script and run again in minutes. In this article I would like to present this setup step by step, and show where each command matches what we did in the portal before.

&nbsp;
<h3><strong>One concept before we start</strong></h3>
The diagram at the top of this article shows how App Service resources are organized. The most important thing to understand is that you pay for the <strong>App Service plan</strong>, not for the app. The plan is the compute (CPU and RAM), and several apps can share one plan. That is cheap for development, but risky in production if one app uses all the resources.

Also notice that everything is inside one <strong>resource group</strong>. Deleting the resource group deletes everything in it, which makes cleaning up very easy.

&nbsp;
<h3><strong>Step 1 — Login and set variables</strong></h3>
Lets start by logging in and choosing the subscription. I like to keep all names in variables so the rest of the commands can be copied without changes:

```bash
az login
az account set --subscription "<subscription-name-or-id>"

RG=rg-myapp-prod
LOC=westeurope
PLAN=plan-myapp-prod
APP=myapp-$RANDOM     # must be globally unique, it becomes $APP.azurewebsites.net
```

&nbsp;
<h3><strong>Step 2 — Resource group and App Service plan</strong></h3>

```bash
az group create -n $RG -l $LOC
az appservice plan create -g $RG -n $PLAN --is-linux --sku S1
```

This is the same as filling the "Create Web App" form in the portal. Here is the screenshot from my DevOps article, where I created the plan with the S1 tier:

<img src="/images/posts/article2/adevops25.png" alt="Create Web App in the Azure portal" width="300" style="margin-inline:auto;" />

Choose the pricing tier carefully:

| SKU | Use it for | You get |
|---|---|---|
| F1 / D1 | Demos | Shared compute, no custom TLS, the app sleeps when idle |
| B1 | Dev/test, small internal tools | Dedicated compute, custom domains and TLS |
| S1 | Small production | **Deployment slots**, autoscale, daily backups |
| P1v3 | Real production | Faster CPUs, VNet integration, more slots |

> **_NOTE:_**  As I mentioned in the DevOps article, deployment slots need the <strong>S1 tier or higher</strong>. We will use them at the end of this article.

&nbsp;
<h3><strong>Step 3 — Create the web app</strong></h3>
First check which runtimes are available, then create the app:

```bash
az webapp list-runtimes --linux

az webapp create -g $RG -p $PLAN -n $APP --runtime "PYTHON|3.8"
# or: --runtime "NODE|14-lts"   or   --runtime "DOTNETCORE|5.0"
```

&nbsp;
<h3><strong>Step 4 — Configure before you deploy</strong></h3>
App settings become <strong>environment variables</strong> inside the app, so secrets never need to be in the code:

```bash
az webapp config appsettings set -g $RG -n $APP --settings \
  DJANGO_SETTINGS_MODULE=core.settings.prod \
  SCM_DO_BUILD_DURING_DEPLOYMENT=true \
  SECRET_KEY="<generate-one>"

# Startup command (Python example: gunicorn serving the WSGI app)
az webapp config set -g $RG -n $APP \
  --startup-file "gunicorn --bind=0.0.0.0 --timeout 600 core.wsgi"
```

&nbsp;
<h3><strong>Step 5 — Deploy</strong></h3>
There are three common ways to deploy, from the quickest to the most professional:

```bash
# A) Zip deploy from your machine
zip -r app.zip . -x "*.git*" "venv/*"
az webapp deployment source config-zip -g $RG -n $APP --src app.zip

# B) Local Git push
az webapp deployment source config-local-git -g $RG -n $APP
git remote add azure <url-from-the-output>
git push azure main

# C) CI/CD — download the publish profile for GitHub Actions or Azure DevOps
az webapp deployment list-publishing-profiles -g $RG -n $APP --xml > profile.xml
```

For anything you will maintain, use option C — the release pipeline from my DevOps article is exactly this.

&nbsp;
<h3><strong>Step 6 — Lock it down</strong></h3>
A new App Service is not as secure as it could be by default. These commands fix the most important settings:

```bash
az webapp update -g $RG -n $APP --https-only true
az webapp config set -g $RG -n $APP --min-tls-version 1.2 --ftps-state Disabled
az webapp config set -g $RG -n $APP --always-on true
az webapp identity assign -g $RG -n $APP     # managed identity, e.g. for Key Vault without stored passwords
```

1. **HTTPS only** is off by default — turn it on.
2. **FTP/FTPS** is on by default — disable it, it is a password-based side door.
3. **Always On** keeps the app loaded, otherwise the first request after idle time is slow.
4. **Managed identity** lets the app access other Azure resources without storing credentials.

&nbsp;
<h3><strong>Step 7 — Watch the logs</strong></h3>

```bash
az webapp log config -g $RG -n $APP --application-logging filesystem --level information
az webapp log tail -g $RG -n $APP
```

&nbsp;
<h3><strong>Zero-downtime releases with deployment slots</strong></h3>
In the DevOps article we created a "demo" slot from the portal. This is how it looked after creating the web app — only the production slot exists:

<img src="/images/posts/article2/adevops26.png" alt="Deployment slots in the Azure portal" style="margin-inline:auto;" />

And this was the "Add a slot" panel:

<img src="/images/posts/article2/adevops27.png" alt="Add a slot panel" width="300" style="margin-inline:auto;" />

With the CLI, the same thing — plus the swap — is just two commands:

```bash
az webapp deployment slot create -g $RG -n $APP --slot staging
# deploy to staging, test it at $APP-staging.azurewebsites.net, then:
az webapp deployment slot swap -g $RG -n $APP --slot staging --target-slot production
```

The swap warms up the staging instance first and then switches the routing, so users don't see downtime. If something is wrong, run the same swap command again to go back.

> **_NOTE:_**  Mark connection strings as <strong>slot settings</strong>, so they stay with the slot during a swap. Otherwise the staging code can end up connected to the production database.

&nbsp;
<h3><strong>Clean up</strong></h3>
When you are done testing, one command deletes everything and stops the billing:

```bash
az group delete -n $RG --yes --no-wait
```

&nbsp;
<h3><strong>Summary</strong></h3>
Everything we did in the portal in the DevOps article can be done with a few Azure CLI commands, and once they are in a script, creating a new environment takes minutes instead of an hour of clicking. Remember the important points: you pay for the plan, S1 is needed for slots, turn on HTTPS-only and disable FTP, and use slots to release without downtime. You can read more in the official <a href="https://docs.microsoft.com/en-us/azure/app-service/" target="_blank" rel="noopener">App Service documentation</a>.
