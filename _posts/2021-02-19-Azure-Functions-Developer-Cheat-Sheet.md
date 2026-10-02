---
title: "Azure Functions: The Developer Cheat Sheet"
excerpt: "Triggers, bindings, hosting plans, and the local-to-cloud workflow on one page. Everything you need to ship a serverless function on Azure without reading forty pages of docs."
---

Serverless on Azure comes down to one idea: **a trigger starts your code, bindings move data in and out, and you write only the part in the middle.**

<div style="margin:2rem 0;padding:1.25rem;background:var(--bg-elevated);border:1px solid var(--border);border-radius:var(--radius-m);">
<svg viewBox="0 0 640 200" style="width:100%;height:auto;font-family:inherit;" role="img" aria-label="Azure Function anatomy: one trigger feeds the function, input bindings supply data, output bindings write results">
  <defs><marker id="af-arr" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto"><path d="M0,0 L8,4 L0,8 z" fill="var(--text-muted)"/></marker></defs>
  <g style="font-size:13px;">
    <rect x="10" y="20" width="160" height="60" rx="8" fill="var(--bg-elevated-2)" stroke="var(--accent)" stroke-width="2"/>
    <text x="24" y="45" font-weight="700" fill="var(--accent)">TRIGGER (exactly 1)</text>
    <text x="24" y="66" fill="var(--text-muted)">HTTP · Timer · Queue · Blob</text>
    <rect x="10" y="110" width="160" height="60" rx="8" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="24" y="135" font-weight="700" fill="var(--text)">INPUT BINDINGS (0+)</text>
    <text x="24" y="156" fill="var(--text-muted)">Blob · Cosmos DB · Table</text>
    <rect x="240" y="55" width="160" height="80" rx="10" fill="var(--bg-elevated)" stroke="var(--text)" stroke-width="2"/>
    <text x="262" y="90" font-weight="700" fill="var(--text)">your function</text>
    <text x="262" y="112" fill="var(--text-muted)">just the logic</text>
    <rect x="470" y="65" width="160" height="60" rx="8" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="484" y="90" font-weight="700" fill="var(--text)">OUTPUT BINDINGS (0+)</text>
    <text x="484" y="111" fill="var(--text-muted)">Queue · Blob · SendGrid</text>
    <line x1="170" y1="50" x2="236" y2="80" stroke="var(--text-muted)" stroke-width="2" marker-end="url(#af-arr)"/>
    <line x1="170" y1="140" x2="236" y2="112" stroke="var(--text-muted)" stroke-width="2" marker-end="url(#af-arr)"/>
    <line x1="400" y1="95" x2="466" y2="95" stroke="var(--text-muted)" stroke-width="2" marker-end="url(#af-arr)"/>
  </g>
</svg>
</div>

## Pick the hosting plan first

| Plan | Scales | Cold start | Max run time | Use when |
|---|---|---|---|---|
| **Consumption** | To zero, auto | Yes | 5 min default (10 max) | Spiky, low-volume, cost-sensitive |
| **Premium** | Pre-warmed instances | No | Unbounded | Latency matters, VNet access needed |
| **Dedicated (App Service)** | Manual / autoscale | No | Unbounded | You already pay for an App Service plan |

The trap: Consumption is cheap until a function needs more than the timeout. Long-running work belongs in **Durable Functions** or a queue-driven fan-out, not one giant function.

## Local setup

```bash
npm install -g azure-functions-core-tools@3 --unsafe-perm true

func init MyFuncApp --python          # or --dotnet / --node
cd MyFuncApp
func new --name HttpHello --template "HTTP trigger"
func start                            # runs locally on http://localhost:7071
```

`local.settings.json` holds your local app settings and connection strings. **It's in `.gitignore` for a reason** — keep it there.

## An HTTP trigger with a queue output binding

`HttpHello/function.json`:

```json
{
  "bindings": [
    { "type": "httpTrigger", "direction": "in", "name": "req",
      "authLevel": "function", "methods": ["post"] },
    { "type": "http", "direction": "out", "name": "$return" },
    { "type": "queue", "direction": "out", "name": "msg",
      "queueName": "orders", "connection": "AzureWebJobsStorage" }
  ]
}
```

`HttpHello/__init__.py`:

```python
import json
import azure.functions as func

def main(req: func.HttpRequest, msg: func.Out[str]) -> func.HttpResponse:
    order = req.get_json()
    if "id" not in order:
        return func.HttpResponse("missing id", status_code=400)
    msg.set(json.dumps(order))          # lands in the 'orders' queue — no SDK code
    return func.HttpResponse(f"queued {order['id']}", status_code=202)
```

Notice what's missing: no storage SDK, no connection handling, no retry loop. The binding does it.

## Triggers you'll actually use

| Trigger | Fires on | Classic use |
|---|---|---|
| HTTP | A request | Webhooks, lightweight APIs |
| Timer | CRON schedule | `0 */5 * * * *` = every 5 minutes (note the **seconds** field) |
| Queue Storage | New message | Decoupled background jobs |
| Blob Storage | New/updated blob | Thumbnails, file processing |
| Event Grid | Azure event | React to resource changes |
| Cosmos DB | Change feed | Sync, materialized views |

## Deploy

```bash
az functionapp create -g rg-func -n myfuncapp-$RANDOM \
  --storage-account <storage-name> --consumption-plan-location westeurope \
  --runtime python --runtime-version 3.8 --functions-version 3 --os-type linux

func azure functionapp publish <function-app-name>
```

## Auth levels — get these right

- `anonymous` — anyone can call it. Only for public webhooks you validate yourself.
- `function` — requires the function key (`?code=...` or `x-functions-key` header). The sensible default.
- `admin` — requires the master key. Never hand this out.

Function keys are shared secrets, not identity. For real user auth, put **App Service Authentication (Easy Auth)** or API Management in front.

## Rules that save you later

1. **Idempotent by default.** Queue triggers retry on failure — the same message can arrive twice. Design for it.
2. **One function, one job.** If the name needs "and", split it.
3. **Poison queues are your error log.** After 5 failed attempts a message moves to `<queue>-poison`. Monitor it.
4. **Turn on Application Insights** at creation. Debugging serverless without it is guesswork.
5. **Don't share one storage account** between the function runtime and heavy application data — the runtime's own traffic competes with yours.
