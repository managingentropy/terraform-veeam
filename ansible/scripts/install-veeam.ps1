# Must run as local admin (Ansible -> mspadmin), not SYSTEM.
# URL from C:\MSP\veeam.url

$ErrorActionPreference = 'Stop'
$log        = 'C:\MSP\ansible.log'
$isoPath    = 'C:\Windows\Temp\veeam.iso'
$answerFile = 'C:\MSP\VbrAnswerFile_install.xml'
$veeamLog   = 'C:\MSP\veeam-setup-logs'
$urlFile    = 'C:\MSP\veeam.url'

function Write-Log([string]$Message) {
  $line = '{0} {1}' -f (Get-Date -Format 's'), $Message
  Add-Content -Path $log -Value $line
  Write-Output $line
}

Write-Log '=== Veeam start ==='
Write-Log ("Running as {0} on {1}" -f $env:USERNAME, $env:COMPUTERNAME)

if (-not (Test-Path $urlFile)) { throw "Missing $urlFile" }
if (-not (Test-Path $answerFile)) { throw "Missing $answerFile" }

$veeamUrl = (Get-Content -Path $urlFile -Raw).Trim()
if ([string]::IsNullOrWhiteSpace($veeamUrl)) { throw 'veeam.url is empty' }

New-Item -ItemType Directory -Path $veeamLog -Force | Out-Null

Write-Log 'Downloading Veeam ISO...'
curl.exe -sS -L --fail --retry 3 --retry-all-errors -o $isoPath -- $veeamUrl
if (-not (Test-Path $isoPath) -or (Get-Item $isoPath).Length -lt 1GB) {
  throw "Veeam ISO download failed or too small: $isoPath"
}
Write-Log ("ISO {0} GB" -f [math]::Round((Get-Item $isoPath).Length / 1GB, 2))

Dismount-DiskImage -ImagePath $isoPath -ErrorAction SilentlyContinue | Out-Null
Mount-DiskImage -ImagePath $isoPath | Out-Null
Start-Sleep -Seconds 3
$drive = (Get-DiskImage -ImagePath $isoPath | Get-Volume).DriveLetter
if (-not $drive) { throw "Failed to mount $isoPath" }

$exe = "${drive}:\Setup\Silent\Veeam.Silent.Install.exe"
if (-not (Test-Path $exe)) { throw "Missing $exe" }
Write-Log "Setup: $exe"

$arg = "/AnswerFile `"$answerFile`" /SkipNetworkLogonErrors /LogFolder `"$veeamLog`""
$proc = Start-Process -FilePath $exe -ArgumentList $arg -Wait -PassThru
Write-Log ("Veeam.Silent.Install.exe exited $($proc.ExitCode)")

Dismount-DiskImage -ImagePath $isoPath -ErrorAction SilentlyContinue | Out-Null
Remove-Item $isoPath -Force -ErrorAction SilentlyContinue

if ($proc.ExitCode -notin 0, 3010, 3011) {
  throw "Veeam silent install failed $($proc.ExitCode) - see $veeamLog"
}

Write-Log '=== Veeam done ==='
exit $proc.ExitCode
