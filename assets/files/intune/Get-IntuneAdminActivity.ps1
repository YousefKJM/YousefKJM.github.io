<#  Get-IntuneAdminActivity.ps1 - pull Intune audit events and the content of every
    PowerShell script / remediation in the tenant (read-only).                      #>
param([int]$Days = 30, [string]$Out = ".\intune-ir")

Connect-MgGraph -Scopes "DeviceManagementApps.Read.All","DeviceManagementConfiguration.Read.All",
                        "DeviceManagementManagedDevices.Read.All" -NoWelcome
$null = New-Item -ItemType Directory -Path $Out -Force

function Get-GraphAll([string]$Uri) {            # follows @odata.nextLink paging
    while ($Uri) {
        $page = Invoke-MgGraphRequest -Method GET -Uri $Uri -OutputType PSObject
        $page.value
        $Uri = $page.'@odata.nextLink'
    }
}

# 1. Audit events (who did what, from where, to which object)
$since = (Get-Date).ToUniversalTime().AddDays(-$Days).ToString("yyyy-MM-ddTHH:mm:ssZ")
Get-GraphAll "https://graph.microsoft.com/beta/deviceManagement/auditEvents?`$filter=activityDateTime ge $since" |
    Select-Object activityDateTime, activity, activityType, activityOperationType, activityResult, componentName,
        @{n='Actor';   e={ $_.actor.userPrincipalName ?? $_.actor.applicationDisplayName }},
        @{n='ActorIP'; e={ $_.actor.ipAddress }},
        @{n='Targets'; e={ ($_.resources.displayName) -join '; ' }} |
    Sort-Object activityDateTime |
    Export-Csv "$Out\audit_events.csv" -NoTypeInformation

# 2. Platform scripts: decode the actual code that was (or will be) run as SYSTEM
$scripts = foreach ($s in Get-GraphAll "https://graph.microsoft.com/beta/deviceManagement/deviceManagementScripts") {
    $full = Invoke-MgGraphRequest -Method GET -OutputType PSObject `
            -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceManagementScripts/$($s.id)"
    $code = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($full.scriptContent))
    $code | Set-Content "$Out\script_$($s.id)_$($s.fileName)"
    [pscustomobject]@{ Id=$s.id; Name=$s.displayName; File=$s.fileName; RunAs=$s.runAsAccount
                       Created=$s.createdDateTime; Modified=$s.lastModifiedDateTime
                       SHA256=(Get-FileHash "$Out\script_$($s.id)_$($s.fileName)").Hash }
}
$scripts | Export-Csv "$Out\scripts.csv" -NoTypeInformation

# 3. Remediations (detection + remediation pairs)
foreach ($r in Get-GraphAll "https://graph.microsoft.com/beta/deviceManagement/deviceHealthScripts") {
    $full = Invoke-MgGraphRequest -Method GET -OutputType PSObject `
            -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceHealthScripts/$($r.id)"
    foreach ($part in "detection","remediation") {
        $b64 = $full."${part}ScriptContent"
        if ($b64) { [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($b64)) |
                    Set-Content "$Out\remediation_$($r.id)_$part.ps1" }
    }
}
Write-Host "Done. Review $Out\audit_events.csv first, then diff scripts against your known-good baseline."
