<#  Start-PimActivation.ps1 - what an admin runs to activate an eligible Entra role #>
param([string]$RoleTemplateId = '3a2c62db-5318-420d-8d74-23affee5d9d5',   # Intune Administrator
      [string]$Reason = 'INC-7731: remove malicious remediation script', [string]$Hours = '1')

Connect-MgGraph -Scopes "RoleAssignmentSchedule.ReadWrite.Directory" -NoWelcome
$me = (Get-MgContext).Account
$myId = (Get-MgUser -UserId $me).Id

New-MgRoleManagementDirectoryRoleAssignmentScheduleRequest -Action 'selfActivate' `
    -PrincipalId $myId -RoleDefinitionId $RoleTemplateId -DirectoryScopeId '/' `
    -Justification $Reason -TicketInfo @{ ticketNumber = ($Reason -split ':')[0]; ticketSystem = 'ServiceNow' } `
    -ScheduleInfo @{ startDateTime = (Get-Date).ToUniversalTime().ToString('o')
                     expiration    = @{ type = 'afterDuration'; duration = "PT${Hours}H" } }

# Done early? Give it back instead of waiting for expiry:
# New-MgRoleManagementDirectoryRoleAssignmentScheduleRequest -Action 'selfDeactivate' -PrincipalId $myId `
#     -RoleDefinitionId $RoleTemplateId -DirectoryScopeId '/'
