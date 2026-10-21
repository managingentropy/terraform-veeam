# Verbose Packer logging + normal build
$env:PACKER_LOG = '1'
$env:PACKER_LOG_PATH = Join-Path $PSScriptRoot 'packer.log'

Write-Host "PACKER_LOG=1 -> $env:PACKER_LOG_PATH"
Write-Host "Running: packer build ."
Set-Location $PSScriptRoot
packer build @args .
