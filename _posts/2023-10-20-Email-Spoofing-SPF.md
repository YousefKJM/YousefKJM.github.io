---
title: "Anyone Can Email as Your CEO: Spoofing, SPF, and How to Shut It Down"
excerpt: "Free web tools let a stranger send mail that says it's from your CEO, because plain SMTP never checked who the sender really is. Here's why spoofing is so easy, how SPF, DKIM and DMARC actually stop it, how to read a header to catch a fake — and how to test your own domain before an attacker does."
header:
  image: /images/posts/email-spoofing/hero.jpg
tags: [Hardening, Detection, email-security, spoofing, SPF, DKIM, DMARC, phishing, SOC]
---
![Anyone can email as your CEO: spoofing, SPF, and how to shut it down](/images/posts/email-spoofing/hero.jpg)

Here's an uncomfortable demo you can reason through without touching a keyboard. There are free websites — emkei.cz is the one everyone knows — that present a little form: *To, From, Subject, Message.* You type whatever you want in the **From** box — `ceo@yourbank.com`, `it-support@yourcompany.com`, anyone — hit send, and the email goes out claiming to be from that person. No password, no access to their mailbox, nothing. These "online fake mailers" exist to make a point that email security people learned the hard way: **the From address on an email is about as trustworthy as the return address scribbled on a postcard.**

I'm writing this from the defender's side. Understanding *why* this works, and seeing how trivially a web form can forge a sender, is exactly what makes you take SPF, DKIM and DMARC seriously — and those three, configured properly, are what turn "anyone can email as your CEO" into "that forgery lands in junk, or never arrives at all." Let's pull it apart and then lock it down.

> **Scope:** everything here is for understanding the threat and hardening **your own** domains. Test against domains you control. Sending forged mail impersonating others isn't a prank — depending on where you are and what you do with it, it's fraud.

## Why it's this easy: SMTP never asked

Email runs on SMTP, a protocol from 1982, built by a small community who trusted each other. It was never designed to verify identity. The thing that makes spoofing trivial is a quirk most people never notice: an email has **two different "from" addresses**, and the one you *see* is not the one the mail system uses to deliver.

<div style="margin:2rem 0;padding:1.25rem;background:var(--bg-elevated);border:1px solid var(--border);border-radius:var(--radius-m);">
<svg viewBox="0 0 640 230" style="width:100%;height:auto;font-family:inherit;" role="img" aria-label="An email has two from addresses: the envelope sender (MAIL FROM), used for delivery and checked by SPF, which the recipient never sees; and the header From, shown in the mail client, which the sender can set to anything. Spoofing works by putting a trusted name in the header From while the envelope comes from somewhere else.">
  <g style="font-size:12px;">
    <rect x="5" y="20" width="300" height="190" rx="12" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="22" y="44" font-weight="700" fill="var(--text)">Envelope sender</text>
    <text x="22" y="62" fill="var(--text-muted)">(SMTP MAIL FROM)</text>
    <text x="22" y="90" font-family="var(--font-mono)" font-size="11" fill="var(--text)">x9f3@some-random-host.ru</text>
    <text x="22" y="118" fill="var(--text-muted)">• used to route &amp; deliver</text>
    <text x="22" y="138" fill="var(--text-muted)">• this is what <tspan fill="var(--accent)" font-weight="700">SPF checks</tspan></text>
    <text x="22" y="158" fill="var(--text-muted)">• the recipient <tspan font-weight="700" fill="var(--text)">never sees it</tspan></text>
    <text x="22" y="192" fill="var(--text-muted)">like the postmark on a letter</text>

    <rect x="335" y="20" width="300" height="190" rx="12" fill="var(--bg-elevated-2)" stroke="var(--accent-strong)" stroke-width="2"/>
    <text x="352" y="44" font-weight="700" fill="var(--text)">Header From</text>
    <text x="352" y="62" fill="var(--text-muted)">(the "From:" line)</text>
    <text x="352" y="90" font-family="var(--font-mono)" font-size="11" fill="var(--accent-strong)">ceo@yourbank.com</text>
    <text x="352" y="118" fill="var(--text-muted)">• shown in the mail client</text>
    <text x="352" y="138" fill="var(--text-muted)">• the sender can set it to</text>
    <text x="352" y="156" fill="var(--text-muted)">  <tspan font-weight="700" fill="var(--text)">anything at all</tspan></text>
    <text x="352" y="192" fill="var(--text-muted)">like handwriting on the postcard</text>
  </g>
</svg>
</div>

The spoof is simply: put `ceo@yourbank.com` in the **header From** (what the victim sees), while the **envelope** comes from wherever the attacker is actually sending. Classic SMTP does nothing to stop that mismatch. That gap is the entire reason the three email-authentication standards exist.

## The three guards: SPF, DKIM, DMARC

Over the years the industry bolted authentication on top of SMTP. Three layers, each closing part of the gap:

<div style="margin:2rem 0;padding:1.25rem;background:var(--bg-elevated);border:1px solid var(--border);border-radius:var(--radius-m);">
<svg viewBox="0 0 640 250" style="width:100%;height:auto;font-family:inherit;" role="img" aria-label="Three email authentication layers. SPF: the domain publishes which mail servers are allowed to send for it; the receiver checks the envelope sender's IP against that list. DKIM: the sending server cryptographically signs the message; the receiver verifies the signature using a public key in DNS. DMARC: ties it together, requires that SPF or DKIM pass AND align with the visible From domain, and tells receivers what to do on failure plus where to send reports.">
  <g style="font-size:11.5px;">
    <rect x="5" y="15" width="200" height="140" rx="10" fill="var(--bg-elevated-2)" stroke="var(--accent)"/>
    <text x="20" y="38" font-weight="700" font-size="14" fill="var(--accent)">SPF</text>
    <text x="20" y="60" fill="var(--text)">"who may send</text>
    <text x="20" y="76" fill="var(--text)">for this domain?"</text>
    <text x="20" y="100" fill="var(--text-muted)">DNS lists allowed</text>
    <text x="20" y="116" fill="var(--text-muted)">sending IPs; receiver</text>
    <text x="20" y="132" fill="var(--text-muted)">checks the envelope IP</text>
    <text x="20" y="150" fill="var(--text-muted)">✗ breaks on forwarding</text>

    <rect x="220" y="15" width="200" height="140" rx="10" fill="var(--bg-elevated-2)" stroke="var(--accent)"/>
    <text x="235" y="38" font-weight="700" font-size="14" fill="var(--accent)">DKIM</text>
    <text x="235" y="60" fill="var(--text)">"was it signed by</text>
    <text x="235" y="76" fill="var(--text)">the domain?"</text>
    <text x="235" y="100" fill="var(--text-muted)">server signs the mail;</text>
    <text x="235" y="116" fill="var(--text-muted)">receiver verifies with</text>
    <text x="235" y="132" fill="var(--text-muted)">a public key in DNS</text>
    <text x="235" y="150" fill="var(--text-muted)">✓ survives forwarding</text>

    <rect x="435" y="15" width="200" height="140" rx="10" fill="var(--accent)" fill-opacity="0.12" stroke="var(--accent)" stroke-width="2"/>
    <text x="450" y="38" font-weight="700" font-size="14" fill="var(--accent)">DMARC</text>
    <text x="450" y="60" fill="var(--text)">"do they match the</text>
    <text x="450" y="76" fill="var(--text)">visible From — and</text>
    <text x="450" y="92" fill="var(--text)">what if not?"</text>
    <text x="450" y="116" fill="var(--text-muted)">requires alignment +</text>
    <text x="450" y="132" fill="var(--text-muted)">sets policy (none/</text>
    <text x="450" y="148" fill="var(--text-muted)">quarantine/reject)</text>

    <rect x="5" y="170" width="630" height="70" rx="10" fill="none" stroke="var(--text-muted)" stroke-dasharray="5 5"/>
    <text x="20" y="193" font-weight="700" fill="var(--text)">The key idea: alignment</text>
    <text x="20" y="215" fill="var(--text-muted)">SPF and DKIM check the envelope / signing domain. DMARC demands that a passing check <tspan font-weight="700" fill="var(--text)">aligns</tspan> with the</text>
    <text x="20" y="233" fill="var(--text-muted)">domain in the <tspan font-weight="700" fill="var(--text)">visible From</tspan> — which is the address a human actually reads. That's what kills the spoof.</text>
  </g>
</svg>
</div>

- **SPF (Sender Policy Framework)** — you publish, in DNS, the list of mail servers allowed to send for your domain. The receiver checks the *envelope* sender's IP against that list. Its weakness: it checks the envelope, not the visible From, and it breaks when mail is forwarded.
- **DKIM (DomainKeys Identified Mail)** — your sending server adds a cryptographic signature; the receiver verifies it against a public key you publish in DNS. Tamper-evident and survives forwarding, but on its own it doesn't say anything about the visible From either.
- **DMARC** — the glue. It says: for mail claiming to be from my domain, require SPF **or** DKIM to pass **and** to *align* with the visible From domain; if that fails, here's what to do (`none`, `quarantine`, or `reject`), and here's where to send me reports. **Alignment with the From the human sees** is the piece that actually defeats the fake-mailer spoof.

## Catching a spoof: read the header

When a suspicious email lands, the truth is in the headers, specifically the `Authentication-Results` line your mail system stamps on. This is the single most useful habit for any analyst triaging reported phishing. A clean, legitimate message looks like:

```text
Authentication-Results: mx.google.com;
   spf=pass (google.com: domain of newsletter@realsender.com designates 203.0.113.9 as permitted sender)
       smtp.mailfrom=newsletter@realsender.com;
   dkim=pass header.d=realsender.com;
   dmarc=pass (p=REJECT) header.from=realsender.com
```

A spoof of your domain, by contrast, gives itself away:

```text
Authentication-Results: mx.yourcompany.com;
   spf=fail (sender IP is 198.51.100.44)
       smtp.mailfrom=bounce@some-random-host.ru;   <-- envelope ≠ the From you see
   dkim=none;
   dmarc=fail (p=QUARANTINE) header.from=yourbank.com
```

What to scan for, in order:
1. **`dmarc=`** — `fail` on a message claiming your domain is the loudest signal. `pass` is reassuring; `none` means the domain published no policy.
2. **`spf=` and the `smtp.mailfrom`** — does the envelope domain match the visible From? A `From: ceo@yourbank.com` with `smtp.mailfrom=x@random.ru` is the postcard tell.
3. **`dkim=`** — `none` or `fail` on a brand that should be signing is suspicious.
4. **`Received:` chain** — read bottom-to-top; the earliest hop shows where it really originated, not where it claims to.

> **Header, not display name:** the easiest spoofs don't even forge the domain — they just set the *display name* to "Yousef Majeed" while the actual address is `attacker@gmail.com`. Always expand the real address, and never trust the name your client shows in bold.

## Test your own domain before someone else does

Here's the empowering part. You can check, in under a minute and completely safely, whether *your* domain is a soft target — using nothing but DNS lookups against domains you own.

**1. Do you even have the records?**

```bash
# SPF — look for a "v=spf1 ... " TXT record
dig +short TXT yourdomain.com | grep spf1

# DMARC — published at the _dmarc subdomain
dig +short TXT _dmarc.yourdomain.com

# DKIM — needs the selector your mail provider uses (e.g. "selector1" for M365, "google" for Workspace)
dig +short TXT selector1._domainkey.yourdomain.com
```

**2. Read what they say.** A strong posture looks roughly like:

```text
yourdomain.com.        TXT  "v=spf1 include:spf.protection.outlook.com -all"
_dmarc.yourdomain.com. TXT  "v=DMARC1; p=reject; rua=mailto:dmarc@yourdomain.com; pct=100"
```

The two things that matter most: SPF ends in **`-all`** (hard fail, not `~all` softfail or `?all` neutral), and DMARC policy is **`p=reject`** (or at least `quarantine`) rather than `p=none`. A domain sitting on `p=none` with no SPF is wide open — anyone with that web form can impersonate it and most receivers will deliver it.

**3. Send yourself a test.** Mail a message from your real sending platform to a free analyser like mail-tester.com or to a Gmail account, open the full headers, and confirm `spf=pass`, `dkim=pass`, `dmarc=pass` with everything aligned. That proves your *legitimate* mail authenticates — which you must verify *before* you tighten policy, or you'll block your own invoices.

## Harden it: the rollout that won't break your mail

The reason so many domains linger on `p=none` is fear of blocking real mail. The safe path is gradual, and it's the same discipline as any production change — measure, then enforce. (I walked through the M365 side of this in my [Microsoft 365 hardening checklist](/Microsoft-365-Security-Hardening-Checklist/); here's the vendor-neutral version.)

<div style="margin:2rem 0;padding:1.25rem;background:var(--bg-elevated);border:1px solid var(--border);border-radius:var(--radius-m);">
<svg viewBox="0 0 640 170" style="width:100%;height:auto;font-family:inherit;" role="img" aria-label="DMARC rollout in four steps: publish SPF and DKIM for every legitimate sender; publish DMARC at policy none with reporting to collect data; read the aggregate reports and fix any legitimate senders that fail; then move policy to quarantine and finally reject.">
  <defs><marker id="es-a" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto"><path d="M0,0 L8,4 L0,8 z" fill="var(--accent)"/></marker></defs>
  <g style="font-size:11.5px;">
    <rect x="5" y="40" width="140" height="90" rx="10" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="75" y="64" text-anchor="middle" font-weight="700" fill="var(--text)">1 · Publish</text>
    <text x="75" y="86" text-anchor="middle" fill="var(--text-muted)">SPF + DKIM for</text>
    <text x="75" y="102" text-anchor="middle" fill="var(--text-muted)">every real sender</text>
    <rect x="165" y="40" width="140" height="90" rx="10" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="235" y="64" text-anchor="middle" font-weight="700" fill="var(--text)">2 · Observe</text>
    <text x="235" y="86" text-anchor="middle" fill="var(--text-muted)">DMARC p=none</text>
    <text x="235" y="102" text-anchor="middle" fill="var(--text-muted)">+ rua reports</text>
    <rect x="325" y="40" width="140" height="90" rx="10" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="395" y="64" text-anchor="middle" font-weight="700" fill="var(--text)">3 · Fix</text>
    <text x="395" y="86" text-anchor="middle" fill="var(--text-muted)">repair legit senders</text>
    <text x="395" y="102" text-anchor="middle" fill="var(--text-muted)">that fail alignment</text>
    <rect x="485" y="40" width="150" height="90" rx="10" fill="var(--accent)" fill-opacity="0.9"/>
    <text x="560" y="64" text-anchor="middle" font-weight="700" fill="var(--accent-contrast)">4 · Enforce</text>
    <text x="560" y="86" text-anchor="middle" fill="var(--accent-contrast)">quarantine → reject</text>
    <text x="560" y="102" text-anchor="middle" fill="var(--accent-contrast)">pct ramp if needed</text>
    <line x1="145" y1="85" x2="163" y2="85" stroke="var(--accent)" stroke-width="2" marker-end="url(#es-a)"/>
    <line x1="305" y1="85" x2="323" y2="85" stroke="var(--accent)" stroke-width="2" marker-end="url(#es-a)"/>
    <line x1="465" y1="85" x2="483" y2="85" stroke="var(--accent)" stroke-width="2" marker-end="url(#es-a)"/>
  </g>
</svg>
</div>

1. **Publish SPF and DKIM** for every system that legitimately sends as you — your mail platform, your marketing tool, your ticketing system, your invoicing app. The commonest cause of self-inflicted failures is a forgotten legitimate sender.
2. **Start DMARC at `p=none` with `rua=`** reporting. This changes nothing for delivery but starts the flow of aggregate reports telling you who's sending as your domain.
3. **Read the reports and fix.** Use a DMARC report reader; repair any real senders that fail alignment until the only failures left are the spoofers.
4. **Move to `p=quarantine`, then `p=reject`.** Use `pct=` to ramp gradually if you're cautious. End state: a forged email claiming your domain is rejected outright by every compliant receiver.

> **The payoff:** once you're at `p=reject` with SPF `-all` and DKIM in place, that free web form can still *type* your CEO's address — but the message gets refused or binned at the recipient's gateway. You can't stop anyone from filling in a form; you *can* make the result harmless.

## The honest limits

Email authentication defeats **exact-domain** spoofing — forging `yourbank.com` itself. It does not stop everything, and pretending otherwise gets people phished:

- **Look-alike domains.** `yourbank-support.com` or `yourbamk.com` will happily pass their *own* SPF/DKIM/DMARC. Authentication proves a message really came from the domain it claims — it can't tell you that domain isn't a trap. Register the obvious look-alikes, and detect the rest.
- **Compromised real accounts.** If an attacker is sending from a genuinely logged-in mailbox, the mail authenticates perfectly, because it *is* legitimate at the protocol level. That's a [BEC/account-takeover problem](/Microsoft-365-Security-Hardening-Checklist/), handled with MFA and anomaly detection, not SPF.
- **The human.** Authentication is one layer. Analyst header-reading, user training, and attachment/link scanning carry the rest.

So: DMARC at `reject` makes impersonating *you* hard, which is a huge win and removes an entire class of attack. Pair it with look-alike monitoring, account protection, and people who know to open the header before they trust the name — and the fake-mailer's party trick stops being funny.

Start by checking your own domain with the three `dig` commands above. If DMARC comes back empty or `p=none`, you've just found your most valuable hour of work this week. The <a href="https://dmarc.org/" target="_blank" rel="noopener">DMARC.org</a> resources and Microsoft's <a href="https://learn.microsoft.com/en-us/defender-office-365/email-authentication-about" target="_blank" rel="noopener">email authentication documentation</a> are the references I'd keep open while you do it.
