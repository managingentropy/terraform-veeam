Enable-PSRemoting -Force
winrm quickconfig -q
Set-Item -Path WSMan:\localhost\Service\AllowUnencrypted -Value $true
Set-Item -Path WSMan:\localhost\Service\Auth\Basic -Value $true
if (-not (Get-NetFirewallRule -Name 'WinRM-HTTP-Ansible' -ErrorAction SilentlyContinue)) {
  New-NetFirewallRule -Name 'WinRM-HTTP-Ansible' -DisplayName 'WinRM HTTP Ansible' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 5985 | Out-Null
}
Write-Output "AllowUnencrypted=$((Get-Item WSMan:\localhost\Service\AllowUnencrypted).Value)"
winrm enumerate winrm/config/listener
