# URL from C:\MSP\kaseya.url (Ansible writes it; SAS has &).

$ErrorActionPreference = 'Stop'
$log     = 'C:\MSP\ansible.log'
$agent   = 'C:\Windows\Temp\kaseya.exe'
$urlFile = 'C:\MSP\kaseya.url'

function Write-Log([string]$Message) {
  $line = '{0} {1}' -f (Get-Date -Format 's'), $Message
  Add-Content -Path $log -Value $line
  Write-Output $line
}

Write-Log '=== Kaseya start ==='
if (-not (Test-Path $urlFile)) { throw "Missing $urlFile" }
$Url = (Get-Content -Path $urlFile -Raw).Trim()
if ([string]::IsNullOrWhiteSpace($Url)) { throw 'kaseya.url is empty' }

Write-Log 'Downloading Kaseya agent...'
curl.exe -sS -L --fail --retry 3 -o $agent -- $Url
if (-not (Test-Path $agent) -or (Get-Item $agent).Length -eq 0) {
  throw "Kaseya download failed: $agent"
}
Write-Log ("Downloaded {0} MB" -f [math]::Round((Get-Item $agent).Length / 1MB, 2))

Write-Log 'Starting kaseya.exe /s ...'
$p = Start-Process -FilePath $agent -ArgumentList '/s' -PassThru
$timeoutSec = 300
$sw = [System.Diagnostics.Stopwatch]::StartNew()
while (-not $p.HasExited -and $sw.Elapsed.TotalSeconds -lt $timeoutSec) {
  Write-Log ("Kaseya installer running... {0:mm\:ss}" -f $sw.Elapsed)
  Start-Sleep -Seconds 15
  $p.Refresh()
}

if ($p.HasExited) {
  Write-Log ("Kaseya exited {0} after {1}s" -f $p.ExitCode, [int]$sw.Elapsed.TotalSeconds)
  if ($p.ExitCode -ne 0) {
    throw "kaseya.exe exited $($p.ExitCode)"
  }
}
else {
  Write-Log "Kaseya still running after ${timeoutSec}s - continuing"
}

Remove-Item $agent -Force -ErrorAction SilentlyContinue
Write-Log '=== Kaseya done ==='
