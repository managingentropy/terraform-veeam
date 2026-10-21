# Glue only: pull IP/user/pass from Terraform so Ansible has an inventory.
# Does NOT run the playbook.

$ErrorActionPreference = 'Stop'

$ansibleDir = $PSScriptRoot
$terraformDir = Join-Path $ansibleDir '..\tf-demo'
$inventoryFile = Join-Path $ansibleDir 'inventory.ini'
$passwordFile = Join-Path $ansibleDir 'extra-vars.json'

# terraform output only works from the dir that has terraform.tfstate
Set-Location $terraformDir
$ip = terraform output -raw public_ip
$user = terraform output -raw admin_username
$password = terraform output -raw admin_password
Set-Location $ansibleDir

$inventory = @"
[vbr]
vm-test01 ansible_host=$ip ansible_user=$user
"@
Set-Content -Path $inventoryFile -Value $inventory -Encoding ASCII

$passwordJson = @{ ansible_password = $password } | ConvertTo-Json
Set-Content -Path $passwordFile -Value $passwordJson -Encoding ASCII

Write-Host "Wrote $inventoryFile"
Write-Host "  host = $ip"
Write-Host "  user = $user"
Write-Host "Wrote $passwordFile (ansible_password)"
Write-Host ""
Write-Host "Next (WSL, from this ansible folder):"
Write-Host "  ansible-playbook -i inventory.ini site.yml -e @extra-vars.json"
