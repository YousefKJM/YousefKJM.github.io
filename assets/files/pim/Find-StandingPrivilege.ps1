<#  Find-StandingPrivilege.ps1 - list privileged access that is ALWAYS ON (not just-in-time)
    across Entra roles and Azure RBAC. Read-only.                                          #>
#Requires -Modules Microsoft.Graph.Identity.Governance, Az.Accounts, Az.Resources

# Tier-0 / high-impact Entra roles (built-in role template IDs)
$tier0 = @{
    '62e90394-69f5-4237-9190-012177145e10' = 'Global Administrator'
    'e8611ab8-c189-46e8-94e1-60213ab1f814' = 'Privileged Role Administrator'
    '7be44c8a-adaf-4e2a-84d6-ab2649e08a13' = 'Privileged Authentication Administrator'
    '194ae4cb-b126-40b2-bd5b-6091b380977d' = 'Security Administrator'
    'b1be1c3e-b65d-4f19-8427-f6fa0d97feb9' = 'Conditional Access Administrator'
    '9b895d92-2cd3-44c7-9d02-a6ac2d5ea5c3' = 'Application Administrator'
    '158c047a-c907-4556-b7ef-446551a6b5f7' = 'Cloud Application Administrator'
    '8ac3fc64-6eca-42ea-9e69-59f4c7b60eb2' = 'Hybrid Identity Administrator'
    '3a2c62db-5318-420d-8d74-23affee5d9d5' = 'Intune Administrator'
    '29232cdf-9323-42fd-ade2-1d097af3e4de' = 'Exchange Administrator'
    'fe930be7-5e62-47db-91af-98c3a49a38b1' = 'User Administrator'
    'c4e39bd9-1100-46d3-8c65-fb160da0071f' = 'Authentication Administrator'
}

# ---- Layer 1: Entra roles -------------------------------------------------------------
Connect-MgGraph -Scopes "RoleManagement.Read.Directory","Directory.Read.All" -NoWelcome
$entra = Get-MgRoleManagementDirectoryRoleAssignmentScheduleInstance -All -ExpandProperty "principal" |
    Where-Object { $tier0.ContainsKey($_.RoleDefinitionId) } |
    ForEach-Object {
        [pscustomobject]@{
            Layer     = 'Entra role'
            Role      = $tier0[$_.RoleDefinitionId]
            Scope     = $_.DirectoryScopeId                   # "/" = whole tenant, else an admin unit
            Principal = $_.Principal.AdditionalProperties.userPrincipalName ?? $_.Principal.AdditionalProperties.displayName
            Type      = $_.Principal.AdditionalProperties.'@odata.type' -replace '#microsoft.graph.',''
            Standing  = ($_.AssignmentType -eq 'Assigned' -and -not $_.EndDateTime)   # permanent active
            Ends      = $_.EndDateTime
        }
    }

# ---- Layer 2: Azure RBAC --------------------------------------------------------------
Connect-AzAccount -WarningAction SilentlyContinue | Out-Null
$risky = 'Owner','User Access Administrator','Role Based Access Control Administrator','Contributor'
$azure = foreach ($sub in Get-AzSubscription -WarningAction SilentlyContinue) {
    Set-AzContext -SubscriptionId $sub.Id -WarningAction SilentlyContinue | Out-Null
    Get-AzRoleAssignment -WarningAction SilentlyContinue |
        Where-Object { $_.RoleDefinitionName -in $risky -and $_.ObjectType -in 'User','Group','ServicePrincipal' } |
        ForEach-Object {
            [pscustomobject]@{
                Layer = 'Azure RBAC'; Role = $_.RoleDefinitionName; Scope = $_.Scope
                Principal = $_.SignInName ?? $_.DisplayName; Type = $_.ObjectType
                Standing = $true; Ends = $null      # active RBAC assignment (PIM-activated ones are short-lived)
            }
        }
}
# Anyone with User Access Administrator at the root "/" (often a forgotten "elevate access")
$root = Get-AzRoleAssignment -Scope "/" -RoleDefinitionName "User Access Administrator" -WarningAction SilentlyContinue |
    ForEach-Object { [pscustomobject]@{ Layer='Azure RBAC'; Role='User Access Administrator'; Scope='/ (ROOT)'
                     Principal=$_.SignInName ?? $_.DisplayName; Type=$_.ObjectType; Standing=$true; Ends=$null } }

$all = @($entra) + @($azure) + @($root) | Sort-Object Layer, Role, Principal -Unique
$all | Where-Object Standing | Format-Table Layer, Role, Scope, Principal, Type -AutoSize
$all | Export-Csv .\standing-privilege.csv -NoTypeInformation
"{0} standing privileged assignments found - every one should be eligible (PIM) or a documented break-glass." -f ($all | Where-Object Standing).Count
