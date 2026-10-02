<#  Set-PimTier0.ps1 - PIM as code for one Entra role:
    1) harden the activation settings  2) make an admin ELIGIBLE (with an expiry)          #>
param(
    [string]$RoleTemplateId = '62e90394-69f5-4237-9190-012177145e10',   # Global Administrator
    [string]$AdminUpn       = 'adm-yousef@contoso.com',
    [string]$AuthContextId  = 'c1'                                       # CA authentication context "PIM elevation"
)
Connect-MgGraph -Scopes "RoleManagementPolicy.ReadWrite.Directory","RoleManagement.ReadWrite.Directory" -NoWelcome

# 1. Find the PIM policy attached to this role
$policyId = (Get-MgPolicyRoleManagementPolicyAssignment -Filter "scopeId eq '/' and scopeType eq 'DirectoryRole' and roleDefinitionId eq '$RoleTemplateId'").PolicyId

# 2. Activation lasts at most 2 hours
Update-MgPolicyRoleManagementPolicyRule -UnifiedRoleManagementPolicyId $policyId `
    -UnifiedRoleManagementPolicyRuleId 'Expiration_EndUser_Assignment' -BodyParameter @{
        '@odata.type' = '#microsoft.graph.unifiedRoleManagementPolicyExpirationRule'
        id = 'Expiration_EndUser_Assignment'; isExpirationRequired = $true; maximumDuration = 'PT2H'
        target = @{ caller = 'EndUser'; operations = @('All'); level = 'Assignment' }
    }

# 3. Justification + ticket number on every activation
Update-MgPolicyRoleManagementPolicyRule -UnifiedRoleManagementPolicyId $policyId `
    -UnifiedRoleManagementPolicyRuleId 'Enablement_EndUser_Assignment' -BodyParameter @{
        '@odata.type' = '#microsoft.graph.unifiedRoleManagementPolicyEnablementRule'
        id = 'Enablement_EndUser_Assignment'; enabledRules = @('Justification','Ticketing')
        target = @{ caller = 'EndUser'; operations = @('All'); level = 'Assignment' }
    }

# 4. Step-up through Conditional Access (phishing-resistant MFA + compliant device in the CA policy)
Update-MgPolicyRoleManagementPolicyRule -UnifiedRoleManagementPolicyId $policyId `
    -UnifiedRoleManagementPolicyRuleId 'AuthenticationContext_EndUser_Assignment' -BodyParameter @{
        '@odata.type' = '#microsoft.graph.unifiedRoleManagementPolicyAuthenticationContextRule'
        id = 'AuthenticationContext_EndUser_Assignment'; isEnabled = $true; claimValue = $AuthContextId
        target = @{ caller = 'EndUser'; operations = @('All'); level = 'Assignment' }
    }
# (Approval: set it in the portal or with the 'Approval_EndUser_Assignment' rule - approvers are named groups.)

# 5. Eligible - not active - for 180 days, then it must be re-approved
$adminId = (Get-MgUser -UserId $AdminUpn).Id
New-MgRoleManagementDirectoryRoleEligibilityScheduleRequest -Action 'adminAssign' `
    -PrincipalId $adminId -RoleDefinitionId $RoleTemplateId -DirectoryScopeId '/' `
    -Justification 'Tier-0 eligibility, approved in CHG-2041' `
    -ScheduleInfo @{ startDateTime = (Get-Date).ToUniversalTime().ToString('o')
                     expiration    = @{ type = 'afterDuration'; duration = 'P180D' } }
