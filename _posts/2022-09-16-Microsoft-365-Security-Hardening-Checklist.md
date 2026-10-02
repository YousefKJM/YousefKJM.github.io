---
title: "Microsoft 365 Security Hardening: The Admin Checklist and the PowerShell Behind It"
excerpt: "Identity, admin roles, email, data, and logging — the Microsoft 365 settings that stop the most common tenant compromises, the exact PowerShell to verify each one, and the commands to run when you suspect a mailbox has already been taken over."
---

Most Microsoft 365 compromises aren't sophisticated. They're a phished password on an account without MFA, followed by an inbox rule that quietly forwards mail outside the company. From the SOC side, I've seen enough of that pattern to keep this checklist close. It pairs the admin settings with the commands that prove they're actually on.

## Five layers, in priority order

<div style="margin:2rem 0;padding:1.25rem;background:var(--bg-elevated);border:1px solid var(--border);border-radius:var(--radius-m);">
<svg viewBox="0 0 640 290" style="width:100%;height:auto;font-family:inherit;" role="img" aria-label="Five defensive layers stacked by priority: identity first, then privileged access, email, data protection, and logging and monitoring at the base supporting all the others">
  <g style="font-size:13px;">
    <rect x="10" y="10" width="620" height="48" rx="8" fill="var(--accent)" fill-opacity="0.9"/>
    <text x="24" y="40" font-weight="700" fill="var(--accent-contrast)">1  IDENTITY</text>
    <text x="200" y="40" fill="var(--accent-contrast)">MFA for everyone · block legacy auth · Conditional Access</text>
    <rect x="10" y="66" width="620" height="48" rx="8" fill="var(--accent)" fill-opacity="0.7"/>
    <text x="24" y="96" font-weight="700" fill="var(--accent-contrast)">2  PRIVILEGED ACCESS</text>
    <text x="200" y="96" fill="var(--accent-contrast)">few Global Admins · least-privilege roles · break-glass</text>
    <rect x="10" y="122" width="620" height="48" rx="8" fill="var(--accent)" fill-opacity="0.5"/>
    <text x="24" y="152" font-weight="700" fill="var(--text)">3  EMAIL</text>
    <text x="200" y="152" fill="var(--text)">SPF/DKIM/DMARC · block auto-forwarding · Safe Links</text>
    <rect x="10" y="178" width="620" height="48" rx="8" fill="var(--accent)" fill-opacity="0.3"/>
    <text x="24" y="208" font-weight="700" fill="var(--text)">4  DATA</text>
    <text x="200" y="208" fill="var(--text)">external sharing limits · DLP · sensitivity labels</text>
    <rect x="10" y="234" width="620" height="48" rx="8" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="24" y="264" font-weight="700" fill="var(--text)">5  LOGGING</text>
    <text x="200" y="264" fill="var(--text)">unified audit log · mailbox auditing · Secure Score</text>
  </g>
</svg>
</div>

Layer 1 stops most attacks. Layer 5 is what lets you *prove* what happened when the others fail.

## Connect once

```powershell
Install-Module ExchangeOnlineManagement, Microsoft.Graph -Scope CurrentUser
Connect-ExchangeOnline -UserPrincipalName admin@contoso.com
Connect-MgGraph -Scopes "Directory.Read.All","Policy.Read.All","AuditLog.Read.All"
```

## Layer 1 — Identity

| Control | Why |
|---|---|
| **MFA for every user** (Security Defaults, or Conditional Access on licensed tenants) | Blocks the overwhelming majority of password-based account takeovers |
| **Block legacy authentication** (IMAP, POP, SMTP AUTH, basic-auth ActiveSync) | Legacy protocols can't do MFA — attackers use them to password-spray *around* it |
| **Conditional Access** — require compliant device / block risky countries for admins | Context, not just credentials |
| **Self-service password reset with MFA-backed methods** | Fewer helpdesk resets = fewer social-engineering opportunities |

Find who still signs in with legacy protocols before you block them:

```powershell
Get-MgAuditLogSignIn -Filter "clientAppUsed eq 'IMAP4' or clientAppUsed eq 'POP3' or clientAppUsed eq 'Authenticated SMTP'" -Top 200 |
  Select-Object UserPrincipalName, ClientAppUsed, CreatedDateTime, IpAddress
```

Block basic auth at the Exchange level as a backstop:

```powershell
New-AuthenticationPolicy -Name "Block Basic Auth"
Set-OrganizationConfig -DefaultAuthenticationPolicy "Block Basic Auth"
```

## Layer 2 — Privileged access

- **2–4 Global Admins, no more.** Everyone else gets a scoped role: Exchange Admin, User Admin, Helpdesk Admin, Security Reader.
- **Separate admin accounts** — `admin-yousef@`, unlicensed, no mailbox. Your daily account reads email; your admin account doesn't.
- **Two break-glass accounts** — cloud-only, excluded from Conditional Access, long random passwords stored offline, **alert on every sign-in.** They exist for the day CA locks everyone out.

Audit who holds Global Admin right now:

```powershell
$ga = Get-MgDirectoryRole -Filter "displayName eq 'Global Administrator'"
Get-MgDirectoryRoleMember -DirectoryRoleId $ga.Id |
  ForEach-Object { Get-MgUser -UserId $_.Id | Select-Object DisplayName, UserPrincipalName }
```

## Layer 3 — Email

```powershell
# Block automatic forwarding to external addresses (the #1 data-exfil trick after a takeover)
Set-HostedOutboundSpamFilterPolicy -Identity Default -AutoForwardingMode Off

# DKIM: turn on signing for your domain
New-DkimSigningConfig -DomainName contoso.com -Enabled $true   # then publish the two CNAMEs it gives you
```

DNS records for the domain (adjust to your sending services):

```
contoso.com.          TXT  "v=spf1 include:spf.protection.outlook.com -all"
_dmarc.contoso.com.   TXT  "v=DMARC1; p=quarantine; rua=mailto:dmarc@contoso.com; pct=100"
```

Start DMARC at `p=none`, read the reports for a few weeks, fix every legitimate sender that fails, then move to `quarantine`, then `reject`.

## Layer 4 — Data

- **SharePoint/OneDrive external sharing:** "New and existing guests" at most; never "Anyone" links by default. Set anonymous links to expire.
- **DLP policies** for the data types you actually hold (national IDs, card numbers, financial data) — start in test mode, review matches, then enforce.
- **Sensitivity labels** so "Confidential" travels with the file, not the folder it happens to sit in.

## Layer 5 — Logging (verify, don't assume)

```powershell
# Unified audit log must be ON — without it, there's nothing to investigate later
Get-AdminAuditLogConfig | Format-List UnifiedAuditLogIngestionEnabled
Set-AdminAuditLogConfig -UnifiedAuditLogIngestionEnabled $true

# Mailbox auditing org-wide (AuditDisabled should be False)
Get-OrganizationConfig | Format-List AuditDisabled
```

Then check **Microsoft Secure Score** monthly. It's a prioritized to-do list generated from your actual tenant config — treat each recommendation as a ticket.

## When you suspect a mailbox takeover: first 15 minutes

This is the business email compromise (BEC) triage I'd run, in order:

```powershell
$u = "victim@contoso.com"

# 1. Inbox rules that forward, redirect, or hide mail (attackers love "move to RSS Feeds" + mark as read)
Get-InboxRule -Mailbox $u |
  Where-Object { $_.ForwardTo -or $_.ForwardAsAttachmentTo -or $_.RedirectTo -or $_.DeleteMessage -or $_.MoveToFolder } |
  Format-List Name, Enabled, From, SubjectContainsWords, ForwardTo, RedirectTo, MoveToFolder, DeleteMessage

# 2. Mailbox-level forwarding
Get-Mailbox $u | Format-List ForwardingSmtpAddress, ForwardingAddress, DeliverToMailboxAndForward

# 3. Who else has access to the mailbox
Get-MailboxPermission $u | Where-Object { $_.User -notlike "NT AUTHORITY*" }

# 4. What the account did recently (rule creation, logins, mail access)
Search-UnifiedAuditLog -StartDate (Get-Date).AddDays(-14) -EndDate (Get-Date) -UserIds $u `
  -Operations New-InboxRule,Set-InboxRule,UpdateInboxRules,Set-Mailbox,MailItemsAccessed,UserLoggedIn -ResultSize 5000 |
  Select-Object CreationDate, Operations, AuditData
```

**Contain** in this order: reset the password → **revoke sessions** (`Revoke-MgUserSignInSession -UserId $u`) → remove malicious rules and forwarding → confirm MFA methods weren't changed by the attacker → review the account's sent items for internal phishing.

The order matters: resetting the password without revoking sessions leaves the attacker's existing tokens working.

## The one-page checklist

- [ ] MFA enforced for 100% of users
- [ ] Legacy authentication blocked
- [ ] ≤ 4 Global Admins, separate admin accounts, 2 monitored break-glass accounts
- [ ] External auto-forwarding blocked
- [ ] SPF, DKIM, DMARC published; DMARC heading to `reject`
- [ ] External sharing restricted; anonymous links expire
- [ ] Unified audit log and mailbox auditing confirmed ON
- [ ] Secure Score reviewed monthly
- [ ] BEC triage commands saved somewhere you can find at 2 a.m.
