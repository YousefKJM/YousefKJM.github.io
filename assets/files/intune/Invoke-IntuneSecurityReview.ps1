<#  Invoke-IntuneSecurityReview.ps1 - quick, read-only posture checks for an Intune tenant #>
Connect-MgGraph -Scopes "DeviceManagementConfiguration.Read.All","DeviceManagementRBAC.Read.All",
                        "DeviceManagementServiceConfig.Read.All","RoleManagement.Read.Directory" -NoWelcome
$g = "https://graph.microsoft.com"
$results = [System.Collections.Generic.List[object]]::new()
function Add-Check($Area, $Check, $Pass, $Detail) {
    $results.Add([pscustomobject]@{ Area=$Area; Check=$Check; Status= if ($Pass) {'PASS'} else {'REVIEW'}; Detail=$Detail })
}

# 1. Devices without a compliance policy must be treated as non-compliant
$settings = (Invoke-MgGraphRequest -Method GET -Uri "$g/beta/deviceManagement" -OutputType PSObject).settings
Add-Check "Compliance" "No-policy devices = Not compliant" $settings.secureByDefault "secureByDefault=$($settings.secureByDefault)"

# 2. Standing Intune Administrators (Entra role template 3a2c62db-...)
$ia = (Invoke-MgGraphRequest -Method GET -Uri ("$g/v1.0/roleManagement/directory/roleAssignments?`$filter=" +
       "roleDefinitionId eq '3a2c62db-5318-420d-8d74-23affee5d9d5'") -OutputType PSObject).value
Add-Check "RBAC" "Permanent Intune Administrators <= 2 (use PIM)" ($ia.Count -le 2) "$($ia.Count) active assignment(s)"

# 3. Multi Admin Approval access policies
try {
    $maa = (Invoke-MgGraphRequest -Method GET -Uri "$g/beta/deviceManagement/operationApprovalPolicies" -OutputType PSObject).value
    $types = ($maa.policyType | Sort-Object -Unique) -join ', '
    Add-Check "RBAC" "Multi Admin Approval protects scripts, apps and wipe" ($maa.Count -ge 3) "Policies: $($maa.Count) [$types]"
} catch { Add-Check "RBAC" "Multi Admin Approval" $false "Could not read access policies: $($_.Exception.Message)" }

# 4. Custom Intune roles with wipe / script rights
$roles = (Invoke-MgGraphRequest -Method GET -Uri "$g/beta/deviceManagement/roleDefinitions" -OutputType PSObject).value
foreach ($r in $roles | Where-Object { -not $_.isBuiltIn }) {
    $acts = $r.rolePermissions.resourceActions.allowedResourceActions
    $risky = $acts | Where-Object { $_ -match 'Wipe|Retire|DeviceManagementScripts|RemoteTasks' }
    if ($risky) { Add-Check "RBAC" "Custom role '$($r.displayName)' has destructive rights" $false ($risky -join ', ') }
}

# 5. Enrollment restrictions: personally owned Windows blocked?
$restr = (Invoke-MgGraphRequest -Method GET -Uri "$g/beta/deviceManagement/deviceEnrollmentConfigurations" -OutputType PSObject).value |
         Where-Object { $_.'@odata.type' -like '*PlatformRestriction*' -and $_.platformType -eq 'windows' }
foreach ($p in $restr) {
    Add-Check "Enrollment" "Personal Windows enrollment blocked ($($p.displayName))" `
              $p.platformRestriction.personalDeviceEnrollmentBlocked "platformBlocked=$($p.platformRestriction.platformBlocked)"
}

# 6. Stale devices (no check-in for 30+ days) widen the attack surface
$stale = (Invoke-MgGraphRequest -Method GET -Uri ("$g/v1.0/deviceManagement/managedDevices?`$select=deviceName,lastSyncDateTime" +
          "&`$top=999") -OutputType PSObject).value | Where-Object { [datetime]$_.lastSyncDateTime -lt (Get-Date).AddDays(-30) }
Add-Check "Hygiene" "Devices not synced for 30+ days" ($stale.Count -eq 0) "$($stale.Count) stale device(s) (first page only)"

$results | Format-Table -AutoSize
$results | Export-Csv ".\intune-security-review.csv" -NoTypeInformation
