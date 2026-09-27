---
title: "Building a Secure Website, Layer by Layer: A DFIR Specialist's Checklist"
excerpt: "Most 'secure your website' guides stop at HTTPS and a login form. This is the checklist I'd actually use — DNS to database, headers to CI/CD — written from the other side of the fence: I'm usually the one investigating what happens when one of these layers gets skipped."
---

Most of my working hours go into figuring out what happened *after* something already broke. That gives you an opinion on prevention that's different from a typical AppSec checklist: I don't just want a website to resist an attacker, I want it to leave a trail if one gets through anyway. Prevention fails eventually. The question is whether you find out in an hour or in six months.

This is the full-stack version — DNS on one end, incident-ready logging on the other. Treat each section as a layer of the same onion. Skipping one doesn't sink the site; it just means the next layer has to catch everything alone.

## 1. Before the first request: DNS and domain

Nobody thinks about this layer until it's the one that got them.

- **Registrar lock + 2FA on the registrar account itself.** Domain hijacking is quiet and devastating — whoever holds the domain holds your TLS certs, your email, and your users' trust.
- **CAA records** restrict which Certificate Authorities can issue certs for your domain. Costs one DNS record, closes off a whole class of mis-issuance.
  ```
  example.com. CAA 0 issue "letsencrypt.org"
  example.com. CAA 0 issuewild ";"
  ```
- **DNSSEC** if your registrar and DNS provider both support it — stops cache-poisoning attacks that redirect your domain at the resolver level.
- **SPF, DKIM, and DMARC** even if the site itself doesn't send much mail. An unprotected domain is a free spoofing platform for phishing your own users.

## 2. Transport: TLS is the floor, not the ceiling

- **TLS 1.3 only, if you can afford to drop old clients; 1.2 minimum otherwise.** Disable TLS 1.0/1.1 and all the export/RC4/3DES ciphers — they're not "extra compatibility," they're a downgrade attack surface.
- **HSTS, preloaded:**
  ```
  Strict-Transport-Security: max-age=63072000; includeSubDomains; preload
  ```
  Submit to [hstspreload.org](https://hstspreload.org) once you're confident every subdomain is HTTPS-only — this is baked into the browser, not just your server config, so it survives even a first-request downgrade attempt.
- **Automate renewal.** An expired cert is a self-inflicted outage. ACME (Let's Encrypt, ZeroSSL) with a cron/systemd timer means you never touch this again.
- **OCSP stapling** so the client doesn't leak your users' browsing to the CA on every visit and doesn't stall on a slow OCSP responder.

## 3. HTTP security headers: cheap, and most sites still skip them

Every one of these is a single response header. There's no excuse.

| Header | What it stops | Example |
|---|---|---|
| `Content-Security-Policy` | XSS, data exfil via injected `<script>`/`<img>` | `default-src 'self'; script-src 'self' 'nonce-<random>'; object-src 'none'; base-uri 'self'` |
| `X-Content-Type-Options` | MIME-sniffing turning a JSON response into executable script | `nosniff` |
| `Referrer-Policy` | leaking full URLs (with tokens in query strings) to third parties | `strict-origin-when-cross-origin` |
| `Permissions-Policy` | pages/iframes silently claiming camera, mic, geolocation | `geolocation=(), camera=(), microphone=()` |
| `X-Frame-Options` / `frame-ancestors` | clickjacking | `frame-ancestors 'self'` |
| `Cross-Origin-Opener-Policy` | cross-origin window references (Spectre-class leaks) | `same-origin` |

CSP is the one worth doing properly rather than copy-pasting. Start in **report-only** mode (`Content-Security-Policy-Report-Only`) pointed at a `report-uri`/`report-to` endpoint, watch what breaks for a week, then flip it to enforcing. A CSP with `unsafe-inline` in it is a header for compliance checklists, not for security — use nonces or hashes instead.

## 4. The application layer: where most real breaches happen

**Authentication**

- Hash passwords with **Argon2id** (or bcrypt if the stack doesn't support it) — never SHA-256/MD5, never your own scheme. Never with a fixed, non-configurable cost.
- MFA, TOTP at minimum, for anything with elevated privilege (admin panels, financial actions).
- Cookies:
  ```
  Set-Cookie: session=<opaque-token>; HttpOnly; Secure; SameSite=Strict; Path=/
  ```
  `HttpOnly` blocks JS exfil via XSS, `Secure` blocks cleartext transmission, `SameSite` kills most CSRF at the cookie level before you even write CSRF token logic.
- **Rotate the session ID on privilege change** (login, password change, role escalation) — this is the actual fix for session fixation, and it's one line most frameworks give you for free.
- Rate-limit and lock out on repeated auth failures, but respond with the same timing/message for "wrong password" and "no such user" — don't hand out a username-enumeration oracle.

**Input handling**

- **Parameterized queries, always.** Not "sanitized," not "escaped" — parameterized. String-building SQL is the single most reproduced vulnerability class in twenty-five years of web security for a reason.
  ```sql
  -- Not this: "SELECT * FROM users WHERE email = '" + input + "'"
  SELECT * FROM users WHERE email = $1;
  ```
- **Output-encode for the context you're rendering into** — HTML body, HTML attribute, JS string, and URL each need different encoding. A templating engine with auto-escaping (React, Vue, Jinja2 autoescape, Rails ERB) removes most of this class of bug by default — don't fight it with `dangerouslySetInnerHTML`/`| safe` unless you've actually sanitized what's going in.
- **CSRF tokens** on every state-changing request, even with `SameSite=Strict` cookies as a second layer — defense in depth means not trusting either control alone.
- **File uploads:** validate the actual file content (magic bytes), not the extension or the client-supplied MIME type; store outside the webroot or in object storage with no execute permission; re-encode images rather than trusting them as-is.

## 5. Dependencies: you inherit every CVE in your lockfile

- Commit the lockfile (`package-lock.json`, `poetry.lock`, `Gemfile.lock`) — reproducible builds are a security control, not just a convenience.
- Run dependency scanning in CI (`npm audit`, `pip-audit`, Dependabot/Renovate, Snyk) and actually triage the output instead of muting it.
- Generate an **SBOM** (`cyclonedx` or `syft`) on every release build. When the next `log4j`-shaped CVE drops, "grep the SBOM" beats "guess which services are affected."
- Fewer dependencies beats more dependencies. Every package is code you didn't write, running with the same privileges as the code you did.

## 6. Infrastructure: least privilege, everywhere

- **Secrets never in git, ever** — not in a `.env` that "isn't tracked" (someone will `git add -A` eventually), not in a config file, not in a Docker image layer. Use a secrets manager (Vault, AWS Secrets Manager, cloud-native KMS) and inject at runtime.
- **Least-privilege IAM.** The database user your app connects as should not be able to `DROP TABLE`. The deploy role should not have console access to every other environment. Scope every credential to exactly what it needs.
- **WAF in front of the app** — not a substitute for fixing the code, but it buys you time against the automated scanning that hits every public IP within hours of going live, and it's often your first alert that something's being probed.
- **Network segmentation:** database and internal services on a private subnet, not reachable from the internet even if a security group rule gets fat-fingered later.
- If you're running containers, see my [earlier post on container DFIR](/DFIR-Considerations-for-Docker-Containers/) for what changes when the thing you're securing is ephemeral by design.

## 7. CI/CD: the pipeline is part of your attack surface

- **SAST** (Semgrep, CodeQL) on every PR — catches the SQL string-concat and the `eval()` before it ships, not after.
- **Secret scanning pre-commit and in CI** (gitleaks, truffleHog) — the fastest way a secret leaks is a commit that gets reverted five minutes later but stays in history forever.
- **DAST** against a staging environment before production deploys, for the classes of bug static analysis can't see (auth bypass, business-logic flaws).
- **Signed commits and signed build artifacts** if you can manage it — supply-chain integrity is the difference between "we deployed our code" and "we deployed *a* build."

## 8. Make it investigable — the layer most guides skip

Everything above is aimed at prevention. This section is aimed at the day prevention doesn't work, because eventually it won't, and that's the day the rest of this list stops mattering and your logs become the entire case.

- **Log ship off-host, continuously**, to something the attacker can't reach by compromising the web server (SIEM, a log aggregator, cold storage with write-once retention). A log that only exists on the box that got popped is a log that gets deleted along with the evidence.
- **Log enough to actually answer questions later:** who (authenticated user/session ID), what (action, endpoint, parameters — minus secrets), when (UTC, synced NTP), and from where (source IP, and the *original* IP if you're behind a proxy — get `X-Forwarded-For` handling right or every log entry says your load balancer did it).
- **Alert on the auth anomalies that actually matter:** impossible travel, a spike in failed logins against one account, a service account authenticating interactively, a privilege escalation outside a change window.
- **Immutable audit trail for anything privileged** — admin actions, permission changes, data exports. If it can be tampered with by the same account that would abuse it, it's not an audit trail.
- **Know your retention before you need it.** "We'd have caught that, but the logs rolled off three weeks ago" is a sentence I hear more often than any exploit technique.

## The one-page version

| Layer | Non-negotiable |
|---|---|
| DNS/Domain | Registrar 2FA + lock, CAA record, DNSSEC if supported |
| Transport | TLS 1.2+ only, HSTS preloaded, auto-renewed certs |
| Headers | CSP (enforcing, no `unsafe-inline`), `nosniff`, `frame-ancestors`, `Referrer-Policy` |
| Auth | Argon2id/bcrypt, MFA on privileged accounts, `HttpOnly`+`Secure`+`SameSite` cookies |
| Input | Parameterized queries, context-aware output encoding, CSRF tokens |
| Dependencies | Lockfiles committed, CI dependency scanning, SBOM per release |
| Infrastructure | Secrets manager (never in git), least-privilege IAM, WAF, private subnets |
| CI/CD | SAST + secret scanning on every PR, DAST before prod |
| Investigability | Off-host log shipping, enough context per log line, alerting on auth anomalies, known retention |

None of this is exotic. It's mostly discipline applied consistently across every layer instead of concentrated on one — which is exactly the pattern I see broken in almost every incident that starts with "but we had a WAF."
