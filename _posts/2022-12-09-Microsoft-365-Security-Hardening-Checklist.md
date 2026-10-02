---
title: "Hardening Microsoft 365: An Admin Checklist with PowerShell"
excerpt: "Phished password, no MFA, a silent forwarding rule — the same Microsoft 365 compromise, again and again. The settings that stop it, the PowerShell that proves they're on, and the first 15 minutes when one gets through."
tags: [Cloud, Detection, M365, security, PowerShell, SOC]
---
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

Working in a SOC, I've watched the same Microsoft 365 attack play out many times. It's rarely clever: a phished password on an account without MFA, then an inbox rule that quietly forwards mail outside the company. Most of these incidents could have been stopped by settings that already exist in every tenant — someone just has to turn them on and check.

Below is the checklist I use, in the five layers from the diagram above, with the PowerShell that <strong>proves</strong> each setting is really on. It ends with the commands I run first when a mailbox may already be compromised.

## Connect to Microsoft 365
First, install the PowerShell modules and connect. We will use Exchange Online PowerShell and Microsoft Graph PowerShell:

```powershell
Install-Module ExchangeOnlineManagement, Microsoft.Graph -Scope CurrentUser
Connect-ExchangeOnline -UserPrincipalName admin@contoso.com
Connect-MgGraph -Scopes "Directory.Read.All","Policy.Read.All","AuditLog.Read.All"
```

## Layer 1 — Identity
Identity is the first layer because it stops most attacks:

| Control | Why |
|---|---|
| **MFA for every user** (Security Defaults, or Conditional Access with Azure AD Premium) | Blocks the vast majority of password-based account takeovers |
| **Block legacy authentication** (IMAP, POP, SMTP AUTH, basic-auth ActiveSync) | These protocols can't do MFA, so attackers use them to password-spray around it |
| **Conditional Access** — for example require a compliant device for admins | Context, not only credentials |
| **Self-service password reset with MFA methods** | Fewer helpdesk resets, fewer social-engineering chances |

Before blocking legacy authentication, find out who still uses it, so you don't break a business process by surprise:

```powershell
Get-MgAuditLogSignIn -Filter "clientAppUsed eq 'IMAP4' or clientAppUsed eq 'POP3' or clientAppUsed eq 'Authenticated SMTP'" -Top 200 |
  Select-Object UserPrincipalName, ClientAppUsed, CreatedDateTime, IpAddress
```

Then block basic authentication in Exchange as an extra layer:

```powershell
New-AuthenticationPolicy -Name "Block Basic Auth"
Set-OrganizationConfig -DefaultAuthenticationPolicy "Block Basic Auth"
```

## Layer 2 — Privileged access
1. **Keep 2–4 Global Admins, no more.** Everyone else gets a role with only what they need: Exchange Administrator, User Administrator, Helpdesk Administrator, Security Reader.
2. **Use separate admin accounts**, like `admin-yousef@`, without a license or mailbox. Your daily account reads email; your admin account doesn't.
3. **Create two break-glass accounts** — cloud-only, excluded from Conditional Access, with long random passwords stored offline, and an <strong>alert on every sign-in</strong>. They exist for the day a policy locks everyone out.

To check who has Global Admin right now:

```powershell
$ga = Get-MgDirectoryRole -Filter "displayName eq 'Global Administrator'"
Get-MgDirectoryRoleMember -DirectoryRoleId $ga.Id |
  ForEach-Object { Get-MgUser -UserId $_.Id | Select-Object DisplayName, UserPrincipalName }
```

## Layer 3 — Email
Next, close the most common way data leaves a compromised mailbox — automatic forwarding — and set up email authentication for the domain:

```powershell
# Block automatic forwarding to external addresses
Set-HostedOutboundSpamFilterPolicy -Identity Default -AutoForwardingMode Off

# Turn on DKIM signing (then publish the two CNAME records it shows)
New-DkimSigningConfig -DomainName contoso.com -Enabled $true
```

And the DNS records (adjust SPF to the services that send email for you):

```
contoso.com.          TXT  "v=spf1 include:spf.protection.outlook.com -all"
_dmarc.contoso.com.   TXT  "v=DMARC1; p=quarantine; rua=mailto:dmarc@contoso.com; pct=100"
```

> **Go slow on DMARC:** Start DMARC with `p=none` and read the reports for a few weeks. Fix every legitimate sender that fails, then move to `quarantine`, and finally to `reject`. Going directly to `reject` can block your own invoices or newsletters.

## Layer 4 — Data
1. **SharePoint and OneDrive sharing:** allow "New and existing guests" at most, never "Anyone" links by default, and set an expiry for anonymous links.
2. **Data Loss Prevention (DLP)** policies for the data you really have (national IDs, card numbers, financial data). Start in test mode, review the matches, then enforce.
3. **Sensitivity labels**, so "Confidential" stays with the file wherever it goes, not with the folder it is in.

## Layer 5 — Logging: verify, don't assume
This layer doesn't stop attacks, but without it there is nothing to investigate when the other layers fail:

```powershell
# The unified audit log must be ON
Get-AdminAuditLogConfig | Format-List UnifiedAuditLogIngestionEnabled
Set-AdminAuditLogConfig -UnifiedAuditLogIngestionEnabled $true

# Mailbox auditing for the whole organization (AuditDisabled should be False)
Get-OrganizationConfig | Format-List AuditDisabled
```

After that, check the <strong>Microsoft Secure Score</strong> every month. It is a prioritized to-do list generated from your real tenant configuration — treat every recommendation as a ticket.

## When a mailbox may be compromised: the first 15 minutes
This is the business email compromise (BEC) triage I run first, in this order:

```powershell
$u = "victim@contoso.com"

# 1. Inbox rules that forward, redirect, delete or hide emails
Get-InboxRule -Mailbox $u |
  Where-Object { $_.ForwardTo -or $_.ForwardAsAttachmentTo -or $_.RedirectTo -or $_.DeleteMessage -or $_.MoveToFolder } |
  Format-List Name, Enabled, From, SubjectContainsWords, ForwardTo, RedirectTo, MoveToFolder, DeleteMessage

# 2. Forwarding on the mailbox itself
Get-Mailbox $u | Format-List ForwardingSmtpAddress, ForwardingAddress, DeliverToMailboxAndForward

# 3. Who else has access to the mailbox
Get-MailboxPermission $u | Where-Object { $_.User -notlike "NT AUTHORITY*" }

# 4. What the account did in the last 14 days
Search-UnifiedAuditLog -StartDate (Get-Date).AddDays(-14) -EndDate (Get-Date) -UserIds $u `
  -Operations New-InboxRule,Set-InboxRule,UpdateInboxRules,Set-Mailbox,MailItemsAccessed,UserLoggedIn -ResultSize 5000 |
  Select-Object CreationDate, Operations, AuditData
```

Attackers like rules that move emails to a hidden folder like "RSS Feeds" and mark them as read, so the user never sees the replies. Then contain, in this order:

1. Reset the password.
2. **Revoke all sessions** — `Revoke-MgUserSignInSession -UserId $u`.
3. Remove the malicious rules and forwarding.
4. Check that the attacker didn't add their own MFA method.
5. Review the sent items for phishing emails sent to colleagues.

> **Order matters:** If you reset the password but don't revoke the sessions, the attacker's existing tokens keep working.

## The short list

Most Microsoft 365 compromises are stopped by a short list: MFA for everyone, legacy authentication blocked, few and separate admin accounts, external forwarding off, SPF/DKIM/DMARC published, sharing limited and auditing confirmed on. Keep the triage commands somewhere you can find them at 2 a.m. — the day something gets through, you'll need them. Microsoft's <a href="https://docs.microsoft.com/en-us/microsoft-365/security/" target="_blank" rel="noopener">Microsoft 365 security documentation</a> has the details.
