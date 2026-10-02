---
title: "Full Stack, End to End: What Actually Happens When a User Clicks 'Save'"
excerpt: "One click, traced through every layer — browser, DNS, TLS, load balancer, API, database and back — with what can go wrong at each hop and the one tool that tells you which hop it was."
---

"Full stack" means owning a request from the click to the database row and back. When something's slow or broken, the skill isn't knowing every framework — it's knowing **which hop** to look at. Here's the whole path.

<div style="margin:2rem 0;padding:1.25rem;background:var(--bg-elevated);border:1px solid var(--border);border-radius:var(--radius-m);">
<svg viewBox="0 0 640 470" style="width:100%;height:auto;font-family:inherit;" role="img" aria-label="Request lifecycle in eight hops: browser event, DNS lookup, TCP and TLS handshake, CDN or load balancer, web server, application code, database, then response rendered back in the browser">
  <line x1="40" y1="30" x2="40" y2="440" stroke="var(--border)" stroke-width="2"/>
  <g style="font-size:13px;">
    <circle cx="40" cy="30" r="9" fill="var(--accent)"/>
    <text x="64" y="35"><tspan font-weight="700" fill="var(--text)">1  Browser</tspan><tspan fill="var(--text-muted)">  click → JS handler → fetch('/api/items', {method:'POST'})</tspan></text>
    <circle cx="40" cy="88" r="9" fill="var(--accent)"/>
    <text x="64" y="93"><tspan font-weight="700" fill="var(--text)">2  DNS</tspan><tspan fill="var(--text-muted)">  api.example.com → IP (browser, OS, resolver caches)</tspan></text>
    <circle cx="40" cy="146" r="9" fill="var(--accent)"/>
    <text x="64" y="151"><tspan font-weight="700" fill="var(--text)">3  TCP + TLS</tspan><tspan fill="var(--text-muted)">  handshake, certificate check, keys agreed</tspan></text>
    <circle cx="40" cy="204" r="9" fill="var(--accent)"/>
    <text x="64" y="209"><tspan font-weight="700" fill="var(--text)">4  CDN / Load balancer</tspan><tspan fill="var(--text-muted)">  TLS often ends here; picks a healthy server</tspan></text>
    <circle cx="40" cy="262" r="9" fill="var(--accent)"/>
    <text x="64" y="267"><tspan font-weight="700" fill="var(--text)">5  Web server</tspan><tspan fill="var(--text-muted)">  nginx/IIS → app server (gunicorn, node, Kestrel)</tspan></text>
    <circle cx="40" cy="320" r="9" fill="var(--accent)"/>
    <text x="64" y="325"><tspan font-weight="700" fill="var(--text)">6  Application</tspan><tspan fill="var(--text-muted)">  route → auth → validate → business logic</tspan></text>
    <circle cx="40" cy="378" r="9" fill="var(--accent)"/>
    <text x="64" y="383"><tspan font-weight="700" fill="var(--text)">7  Database</tspan><tspan fill="var(--text-muted)">  pooled connection → query → transaction commit</tspan></text>
    <circle cx="40" cy="436" r="9" fill="var(--accent-strong)"/>
    <text x="64" y="441"><tspan font-weight="700" fill="var(--text)">8  Back up the stack</tspan><tspan fill="var(--text-muted)">  JSON → browser → state update → re-render</tspan></text>
  </g>
</svg>
</div>

## Each hop: what breaks, and how you'd know

| Hop | Typical failure | Symptom | First tool to reach for |
|---|---|---|---|
| 1 Browser | JS error, CORS block, double-submit | Nothing happens / console red | DevTools → Console + Network tab |
| 2 DNS | Stale record, wrong TTL after migration | Works for some users, not others | `nslookup api.example.com` / `dig +trace` |
| 3 TLS | Expired cert, missing intermediate | Browser warning, mobile clients fail first | `openssl s_client -connect host:443 -servername host` |
| 4 Load balancer | Unhealthy backend, sticky session missing | Random 502/503, users "logged out" | LB health probe logs |
| 5 Web server | Timeout too short, body size limit | 413 / 504 on big uploads or slow calls | Access + error logs |
| 6 Application | Unhandled exception, N+1 queries | 500, or slow only on big lists | APM / app logs, query count per request |
| 7 Database | Missing index, lock contention, pool exhausted | Slow everywhere at peak | `EXPLAIN ANALYZE`, slow query log |
| 8 Render | Huge payload, re-rendering everything | Fast API, slow page | DevTools Performance tab |

**The Network tab answers "which hop" in seconds.** Click the request and read the Timing breakdown: long *DNS lookup* → hop 2; long *Initial connection/SSL* → hop 3; long *Waiting (TTFB)* → hops 4–7, it's the server; long *Content download* → payload too big.

## The minimal full-stack, layer by layer

What I'd pick for a new small-to-medium web app, and why:

| Layer | Pick | Why |
|---|---|---|
| Frontend | Vue or React + Vite | Component model, huge ecosystem, fast dev server |
| API | Django REST Framework or Express | Batteries included vs. minimal — pick by team |
| Auth | Session cookies (same domain) or OAuth/OIDC via a provider | Don't hand-roll password storage |
| Database | PostgreSQL | Relational integrity, JSON columns when you need them |
| Cache / queue | Redis | Sessions, rate limiting, background job broker |
| Hosting | PaaS (App Service, Heroku) | Skip OS patching until you have a reason not to |
| Observability | Structured logs + request IDs | One ID across every hop = one search to trace a request |

## Patterns that save you at every layer

**Frontend**
- Disable the button on submit. Double-clicks become duplicate rows otherwise.
- Validate on the client for UX, **re-validate on the server for security.** The client is not yours.

**API**
- Return consistent errors: `{"error": {"code": "VALIDATION", "fields": {...}}}` — the frontend can render any of them the same way.
- Make writes **idempotent** where possible (client sends an idempotency key) so retries are safe.

**Database**
- Index every column you filter or join on. Check with `EXPLAIN` before shipping.
- Wrap multi-step writes in a transaction — partial saves are worse than failed saves.
- Use a connection pool; opening a connection per request falls over under load.

**Everywhere**
- Generate a request ID at the edge, pass it in a header (`X-Request-ID`), log it at every layer.

```python
# Django middleware: attach a request ID to every log line and response
import uuid, logging

class RequestIDMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        rid = request.headers.get("X-Request-ID", str(uuid.uuid4()))
        request.request_id = rid
        response = self.get_response(request)
        response["X-Request-ID"] = rid
        logging.getLogger("app").info("req %s %s %s", rid, request.path, response.status_code)
        return response
```

When a user reports "it failed," ask for the ID in the error message. One search across your logs and you have the whole path.

## The one-sentence version

Every bug lives at a hop — **find the hop first, then the bug.** The Network tab, a request ID, and `EXPLAIN` will locate 90% of them before you've opened your editor.
