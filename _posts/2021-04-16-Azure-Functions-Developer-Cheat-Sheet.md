---
title: "Getting Started with Azure Functions: Triggers, Bindings and Deployment"
excerpt: "Not every job needs a web app. Resize an image, drain a queue, run a nightly cleanup — Azure Functions with triggers and bindings, from local project to deployed function."
tags: [Cloud, Azure, serverless, Functions]
---
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

After hosting a full web app on [App Service](/Azure-App-Service-Hosting-Guide/), I kept running into small jobs that didn't deserve one: resize an image when it lands in storage, process a message from a queue, clean up old records every night.

That is what <strong>Azure Functions</strong> is for. You write the code for the task; Azure runs it when something happens. Two ideas make it so productive — <strong>triggers and bindings</strong> — and both show up in the walkthrough below, from a local project to a deployed function.

## Triggers and bindings
The diagram at the top of this article shows how a function is built:

- A **trigger** starts the function. Every function has exactly one — an HTTP request, a timer, a new queue message, a new blob, and so on.
- **Input bindings** bring data into the function, for example a file from Blob Storage.
- **Output bindings** send data out, for example a message to a queue.

The nice part is that bindings replace a lot of SDK code. You don't open connections or write retry loops — you declare the binding and use it like a normal variable.

## Choose the hosting plan first
Before writing code, decide where the function will run, because it affects how long the function can run and how fast it starts:

| Plan | Scaling | Cold start | Max run time | Use it when |
|---|---|---|---|---|
| **Consumption** | Automatic, scales to zero | Yes | 5 min by default (10 max) | Low or spiky traffic, lowest cost |
| **Premium** | Pre-warmed instances | No | Unlimited | Latency matters, you need VNet access |
| **Dedicated (App Service)** | Manual or autoscale | No | Unlimited | You already pay for an App Service plan |

> **Watch the clock:** The Consumption plan is cheap until a function needs more than the time limit. Long-running work should be split into smaller steps using a queue, or use <strong>Durable Functions</strong> — not one big function.

## Create and run a function locally
Everything starts on your own machine. Install the Azure Functions Core Tools and create a new project:

```bash
npm install -g azure-functions-core-tools@3 --unsafe-perm true

func init MyFuncApp --python          # or --dotnet / --node
cd MyFuncApp
func new --name HttpHello --template "HTTP trigger"
func start                            # runs locally on http://localhost:7071
```

The project contains a file called `local.settings.json` with your local settings and connection strings. It is already in `.gitignore`, and it should stay there.

## An HTTP trigger with a queue output binding
Now something useful: an HTTP endpoint that receives an order and puts it in a queue for background processing. First we declare the bindings in `HttpHello/function.json`:

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

Then the code in `HttpHello/__init__.py`:

```python
import json
import azure.functions as func

def main(req: func.HttpRequest, msg: func.Out[str]) -> func.HttpResponse:
    order = req.get_json()
    if "id" not in order:
        return func.HttpResponse("missing id", status_code=400)
    msg.set(json.dumps(order))          # goes to the 'orders' queue, no SDK code needed
    return func.HttpResponse(f"queued {order['id']}", status_code=202)
```

Notice there is no storage SDK, no connection handling and no retry logic in the code. The output binding takes care of all of it.

## Triggers you will use most
| Trigger | Runs when | Typical use |
|---|---|---|
| HTTP | A request arrives | Webhooks, small APIs |
| Timer | A CRON schedule fires | `0 */5 * * * *` = every 5 minutes (note the first field is **seconds**) |
| Queue Storage | A new message arrives | Background jobs |
| Blob Storage | A file is created or updated | Thumbnails, file processing |
| Event Grid | An Azure event happens | Reacting to resource changes |
| Cosmos DB | The change feed has new items | Syncing data, materialized views |

## Deploy to Azure
Once the function works locally, we create the Function App in Azure and publish:

```bash
az functionapp create -g rg-func -n myfuncapp-$RANDOM \
  --storage-account <storage-name> --consumption-plan-location westeurope \
  --runtime python --runtime-version 3.8 --functions-version 3 --os-type linux

func azure functionapp publish <function-app-name>
```

After publishing, the output shows the URL of the function, including the function key.

## Security: choose the right auth level
1. `anonymous` — anyone can call it. Use it only for public webhooks that you validate yourself.
2. `function` — the caller needs the function key (`?code=...` or the `x-functions-key` header). This is the sensible default.
3. `admin` — needs the master key. Never share it.

> **Security note:** Function keys are shared secrets, not user identity. If you need real user authentication, put App Service Authentication or API Management in front of the function.

## Keep it small

Functions let you focus on the small piece of logic in the middle: triggers start your code, bindings move data in and out. Pick the hosting plan deliberately, keep functions small and idempotent (a queue message can arrive more than once), watch the poison queue, and switch on Application Insights from day one. More in the official <a href="https://docs.microsoft.com/en-us/azure/azure-functions/" target="_blank" rel="noopener">Azure Functions documentation</a>.
