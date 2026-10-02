---
title: "What Happens When a User Clicks Save: The Full-Stack Request Lifecycle"
excerpt: "In this article I would like to follow a single click through every layer of a web application — browser, DNS, TLS, load balancer, web server, application and database — and show what can go wrong at each step and how to find it quickly."
---

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

<h3><strong>Short introduction</strong></h3>
In my last two articles we built a [Vue 3 frontend](/Vue-3-Composition-API-Cheat-Sheet/) and a [Django REST API](/Django-REST-API-in-10-Steps/). Being a full-stack developer means owning everything in between as well — the whole path from a user's click to a row in the database and back. In my web development work, I learned that when something is slow or broken, the important skill is not knowing every framework, but knowing <strong>which step</strong> of that path to look at. In this article I would like to follow one click through all of these steps, shown in the diagram above, and explain how to find the problem at each one.

&nbsp;
<h3><strong>The eight steps of a request</strong></h3>
Lets follow what happens when a user clicks "Save" on a form:

1. **Browser** — a JavaScript click handler sends `fetch('/api/items', {method: 'POST'})`.
2. **DNS** — the browser converts `api.example.com` to an IP address, checking the browser, OS and resolver caches.
3. **TCP and TLS** — the connection is opened, the certificate is checked and encryption keys are agreed.
4. **CDN / load balancer** — TLS often ends here, and a healthy backend server is chosen.
5. **Web server** — nginx or IIS forwards the request to the application server (gunicorn, Node, Kestrel).
6. **Application** — routing, authentication, validation and business logic run.
7. **Database** — a connection from the pool runs the query and commits the transaction.
8. **Back up the stack** — the JSON response returns to the browser, which updates the state and re-renders.

&nbsp;
<h3><strong>What breaks at each step</strong></h3>
Every step has its typical problems. This is the table I wish I had when I started:

| Step | Typical problem | Symptom | First tool to use |
|---|---|---|---|
| 1 Browser | JS error, CORS block, double submit | Nothing happens, red errors in the console | DevTools → Console and Network tab |
| 2 DNS | Old record, wrong TTL after a migration | Works for some users but not others | `nslookup api.example.com` |
| 3 TLS | Expired certificate, missing intermediate | Browser warning; mobile apps fail first | `openssl s_client -connect host:443 -servername host` |
| 4 Load balancer | Unhealthy backend, no sticky sessions | Random 502/503, users "logged out" | Health probe logs |
| 5 Web server | Timeout too short, body size limit | 413 or 504 on big uploads or slow calls | Access and error logs |
| 6 Application | Unhandled exception, N+1 queries | 500 errors, or slow only on big lists | Application logs, query count per request |
| 7 Database | Missing index, locks, connection pool full | Slow everywhere at peak times | `EXPLAIN ANALYZE`, slow query log |
| 8 Render | Huge payload, re-rendering everything | Fast API but slow page | DevTools Performance tab |

> **_NOTE:_**  The Network tab in the browser DevTools tells you the step in seconds. Click the request and open "Timing": a long <em>DNS lookup</em> means step 2, a long <em>Initial connection / SSL</em> means step 3, a long <em>Waiting (TTFB)</em> means the server side (steps 4–7), and a long <em>Content download</em> means the response is too big.

&nbsp;
<h3><strong>A simple full stack for a new project</strong></h3>
In this section I want to share what I would choose for a new small-to-medium web app, and why:

| Layer | Choice | Why |
|---|---|---|
| Frontend | Vue or React with Vite | Component model, big ecosystem, fast dev server |
| API | Django REST Framework or Express | "Batteries included" vs. minimal — choose by team |
| Authentication | Session cookies (same domain) or OAuth/OIDC with a provider | Don't build password storage yourself |
| Database | PostgreSQL | Relational integrity, JSON columns when needed |
| Cache / queue | Redis | Sessions, rate limiting, background jobs |
| Hosting | PaaS, like [Azure App Service](/Azure-App-Service-Hosting-Guide/) | No OS patching until you really need it |
| Observability | Structured logs with request IDs | One ID across all steps = one search to trace a request |

&nbsp;
<h3><strong>Good habits at every layer</strong></h3>
<strong>Frontend</strong>

1. Disable the button after the first click — otherwise double clicks become duplicate rows.
2. Validate in the browser for a good user experience, but <strong>validate again on the server</strong> for security. The browser is not under your control.

<strong>API</strong>

1. Return errors in one consistent format, for example `{"error": {"code": "VALIDATION", "fields": {...}}}`, so the frontend can show all of them the same way.
2. Make writes <strong>idempotent</strong> when possible (the client sends an idempotency key), so retries are safe.

<strong>Database</strong>

1. Add an index for every column you filter or join on, and check with `EXPLAIN` before going live.
2. Put multi-step writes in a transaction — a half-saved record is worse than a failed save.
3. Use a connection pool; opening a new connection for every request fails under load.

&nbsp;
<h3><strong>Request IDs: one search to follow a request</strong></h3>
The habit that helped me the most is adding a <strong>request ID</strong> at the first step and logging it everywhere. In Django, this is a small middleware:

```python
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

When a user reports "it failed", ask for the ID shown in the error message. One search in the logs, and you can see the whole path of that request.

&nbsp;
<h3><strong>Summary</strong></h3>
Every bug lives at one of the steps between the click and the database. Find the step first, then the bug: the Network tab, a request ID and `EXPLAIN` will locate most problems before you even open your editor. You can read more about the Network tab timing in the official <a href="https://developer.chrome.com/docs/devtools/network/reference/" target="_blank" rel="noopener">Chrome DevTools documentation</a>.
