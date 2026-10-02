#Requires -RunAsAdministrator
<#  Invoke-IntuneTriage.ps1 - collect Intune / MDM artifacts from a Windows endpoint
    Run from an elevated prompt (or as SYSTEM via your EDR live response).          #>
param([string]$Root = "C:\IR")

$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$out   = Join-Path $Root "Intune_${env:COMPUTERNAME}_$stamp"
$null  = New-Item -ItemType Directory -Path $out\logs, $out\reg, $out\evtx, $out\cache -Force
$ime   = "${env:ProgramFiles(x86)}\Microsoft Intune Management Extension"

# 1. Intune Management Extension logs (Win32 apps, scripts, remediations)
Copy-Item "$env:ProgramData\Microsoft\IntuneManagementExtension\Logs\*" "$out\logs" -ErrorAction SilentlyContinue

# 2. Cached scripts and content - remediation scripts stay here between runs
Copy-Item "$env:windir\IMECache\HealthScripts" "$out\cache" -Recurse -ErrorAction SilentlyContinue
Get-ChildItem "$env:windir\IMECache", "$ime\Policies", "$ime\Content" -Recurse -Force -ErrorAction SilentlyContinue |
    Select-Object FullName, Length, CreationTimeUtc, LastWriteTimeUtc |
    Export-Csv "$out\cache\listing.csv" -NoTypeInformation

# 3. Registry: enrollment, applied policies, IME state
$keys = @{
    "enrollments"   = "HKLM\SOFTWARE\Microsoft\Enrollments"
    "omadm"         = "HKLM\SOFTWARE\Microsoft\Provisioning\OMADM"
    "policymanager" = "HKLM\SOFTWARE\Microsoft\PolicyManager"
    "ime"           = "HKLM\SOFTWARE\Microsoft\IntuneManagementExtension"
    "erm"           = "HKLM\SOFTWARE\Microsoft\EnterpriseResourceManager"
}
foreach ($k in $keys.GetEnumerator()) {
    reg.exe export $k.Value "$out\reg\$($k.Key).reg" /y | Out-Null
}

# 4. Event logs
$channels = @(
    "Microsoft-Windows-DeviceManagement-Enterprise-Diagnostics-Provider/Admin",
    "Microsoft-Windows-DeviceManagement-Enterprise-Diagnostics-Provider/Operational",
    "Microsoft-Windows-AAD/Operational",
    "Microsoft-Windows-ModernDeployment-Diagnostics-Provider/Autopilot",
    "Microsoft-Windows-PowerShell/Operational",
    "Microsoft-Windows-Windows Defender/Operational"
)
foreach ($c in $channels) {
    wevtutil.exe epl $c "$out\evtx\$($c -replace '[/ ]','_').evtx" 2>$null
}

# 5. Join state, MDM scheduled tasks, MDM certificates
dsregcmd.exe /status > "$out\dsregcmd.txt"
Get-ScheduledTask -TaskPath "\Microsoft\Windows\EnterpriseMgmt\*" -ErrorAction SilentlyContinue |
    Select-Object TaskPath, TaskName, State, Date, Author | Export-Csv "$out\enterprisemgmt_tasks.csv" -NoTypeInformation
Get-ChildItem Cert:\LocalMachine\My | Where-Object Issuer -like "*Intune*" |
    Select-Object Subject, Issuer, NotBefore, NotAfter, Thumbprint | Export-Csv "$out\mdm_certs.csv" -NoTypeInformation

# 6. Microsoft's own MDM diagnostics bundle
MdmDiagnosticsTool.exe -area "DeviceEnrollment;DeviceProvisioning;Autopilot" -zip "$out\MDMDiag.zip" | Out-Null

# 7. Hash everything, then zip
Get-ChildItem $out -Recurse -File | Get-FileHash -Algorithm SHA256 |
    Export-Csv "$out\manifest_sha256.csv" -NoTypeInformation
Compress-Archive -Path "$out\*" -DestinationPath "$out.zip" -Force
Write-Host "Collected: $out.zip"
