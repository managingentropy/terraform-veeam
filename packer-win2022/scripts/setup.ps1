$ErrorActionPreference = 'Stop'

Write-Output '=== setup.ps1 start ==='

Set-TimeZone -Id 'Eastern Standard Time'
New-Item -ItemType Directory -Path 'C:\MSP' -Force | Out-Null
Enable-NetFirewallRule -Name 'FPS-ICMP4-ERQ-In'

# Lab WinRM for Ansible (HTTP/NTLM). NSG still locks 5985 to your IP.
Enable-PSRemoting -Force
winrm set winrm/config/service '@{AllowUnencrypted="true"}'
Enable-NetFirewallRule -Name 'WINRM-HTTP-In-TCP'

Write-Output '=== setup.ps1 done (guest apps are Ansible, not Packer) ==='
