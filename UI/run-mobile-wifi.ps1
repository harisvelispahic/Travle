#!/usr/bin/env pwsh
<#
.SYNOPSIS
  Run the Travle Flutter mobile app on a physical phone over Wi-Fi (no cable),
  reusing the existing adb-reverse + localhost setup from RUNNING.md.

.DESCRIPTION
  Uses "ADB over TCP/IP" (adb tcpip 5555). The crucial point: `adb reverse` works
  over the wireless adb transport exactly like it does over USB, so the API can
  stay bound to localhost and NOTHING about the backend / firewall changes.
  BASE_URL stays http://localhost:<port>/ just like the cabled flow.

  First run (or after a phone reboot, which resets tcpip mode): plug the phone in
  via USB once. The script flips it into TCP/IP mode, learns its Wi-Fi IP, and
  saves it to $env:USERPROFILE\.travle-phone. After that, run the script with the
  cable unplugged while the phone is awake on the same Wi-Fi.

  Steps it performs (RUNNING.md, automated):
    1. establish an adb link to the phone over Wi-Fi
    2. adb reverse tcp:<port> tcp:<port>   (phone localhost -> laptop API)
    3. flutter run -d <phone> --dart-define-from-file=<env file>

.PARAMETER Docker
  Target the docker-compose API on port 5121 (env.docker.json) instead of the
  dotnet-run dev API on 5126 (env.json).

.PARAMETER Ip
  Phone Wi-Fi IP (e.g. 192.168.1.42). Overrides the saved IP and skips USB
  auto-detection. Useful if the phone's IP changed.

.PARAMETER Reset
  Forget the saved IP and force a fresh USB-based setup.

.EXAMPLE
  .\run-mobile-wifi.ps1
.EXAMPLE
  .\run-mobile-wifi.ps1 -Docker
.EXAMPLE
  .\run-mobile-wifi.ps1 -Ip 192.168.1.42
#>
[CmdletBinding()]
param(
  [switch]$Docker,
  [string]$Ip,
  [switch]$Reset
)

$ErrorActionPreference = 'Stop'

# --- config ---------------------------------------------------------------
$AdbPort   = 5555
$ApiPort   = if ($Docker) { 5121 } else { 5126 }
$EnvFile   = if ($Docker) { 'env.docker.json' } else { 'env.json' }
$MobileDir = Join-Path $PSScriptRoot 'travle_mobile'
$StateFile = Join-Path $env:USERPROFILE '.travle-phone'

function Info($m) { Write-Host "[travle] $m" -ForegroundColor Cyan }
function Warn($m) { Write-Host "[travle] $m" -ForegroundColor Yellow }
function Die ($m) { Write-Host "[travle] $m" -ForegroundColor Red; exit 1 }

# --- preflight ------------------------------------------------------------
foreach ($tool in 'adb', 'flutter') {
  if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) { Die "$tool not found on PATH." }
}
if (-not (Test-Path (Join-Path $MobileDir $EnvFile))) { Die "$EnvFile not found in $MobileDir." }
if ($Reset -and (Test-Path $StateFile)) { Remove-Item $StateFile -Force }

adb start-server | Out-Null

# --- helpers --------------------------------------------------------------
function Get-AdbDevices {
  # Parse `adb devices`, skipping the header line, into {Serial, State} objects.
  adb devices | Select-Object -Skip 1 | ForEach-Object {
    $parts = $_ -split '\s+'
    if ($parts.Count -ge 2 -and $parts[1] -in 'device', 'unauthorized', 'offline') {
      [pscustomobject]@{ Serial = $parts[0]; State = $parts[1] }
    }
  }
}
function Get-WirelessDevice {
  Get-AdbDevices | Where-Object { $_.Serial -match ':\d+$' -and $_.State -eq 'device' } | Select-Object -First 1
}
function Get-UsbDevice {
  Get-AdbDevices | Where-Object { $_.Serial -notmatch ':\d+$' -and $_.State -eq 'device' } | Select-Object -First 1
}
function Try-Connect([string]$targetIp) {
  if (-not $targetIp) { return $false }
  $serial = "${targetIp}:${AdbPort}"
  Info "Connecting to $serial ..."
  for ($i = 0; $i -lt 3; $i++) {
    adb connect $serial | Out-Null
    Start-Sleep -Milliseconds 700
    if (Get-AdbDevices | Where-Object { $_.Serial -eq $serial -and $_.State -eq 'device' }) { return $true }
  }
  return $false
}
function Test-ApiPort([int]$p) {
  try {
    $c = New-Object Net.Sockets.TcpClient
    $c.Connect('127.0.0.1', $p); $c.Close(); return $true
  } catch { return $false }
}

# --- 1. establish a wireless adb link -------------------------------------
$wireless = Get-WirelessDevice

if (-not $wireless) {
  # Try an explicit / remembered IP first - no cable needed.
  $targetIp = $Ip
  if (-not $targetIp -and (Test-Path $StateFile)) { $targetIp = (Get-Content $StateFile -Raw).Trim() }
  if ($targetIp -and (Try-Connect $targetIp)) {
    Set-Content -Path $StateFile -Value $targetIp -Encoding ascii
    $wireless = Get-WirelessDevice
  }
}

if (-not $wireless) {
  # First-time setup / after reboot: needs the cable once.
  $usb = Get-UsbDevice
  if (-not $usb) {
    if (Get-AdbDevices | Where-Object { $_.State -eq 'unauthorized' }) {
      Die "Phone shows as 'unauthorized' - unlock it and tap 'Allow USB debugging', then re-run."
    }
    Die (@(
        'No wireless link and no USB device found.'
        'First-time setup (or after a phone reboot) needs the cable once:'
        '  1. Plug the phone in via USB, accept the debugging prompt.'
        '  2. Re-run this script - it switches the phone to Wi-Fi and remembers its IP.'
        'Then run it cable-free while on the same Wi-Fi.'
        '  Or, if you know the phone IP:  .\run-mobile-wifi.ps1 -Ip <phone-ip>'
      ) -join [Environment]::NewLine)
  }

  Info "USB device $($usb.Serial) found - switching it to Wi-Fi debugging."

  # Learn the phone's Wi-Fi IP.
  $phoneIp = $Ip
  if (-not $phoneIp) {
    $out = (adb -s $usb.Serial shell ip -f inet addr show wlan0) -join "`n"
    if ($out -match 'inet\s+(\d+\.\d+\.\d+\.\d+)') { $phoneIp = $Matches[1] }
  }
  if (-not $phoneIp) {
    $out = (adb -s $usb.Serial shell ip route) -join "`n"
    if ($out -match 'src\s+(\d+\.\d+\.\d+\.\d+)') { $phoneIp = $Matches[1] }
  }
  if (-not $phoneIp) { Die "Couldn't detect the phone's Wi-Fi IP. Make sure Wi-Fi is on, or pass -Ip <phone-ip>." }
  Info "Phone Wi-Fi IP: $phoneIp"

  adb -s $usb.Serial tcpip $AdbPort | Out-Null
  Start-Sleep -Seconds 2
  if (-not (Try-Connect $phoneIp)) { Die "adb connect to $phoneIp failed. Same Wi-Fi network? Then try again." }
  Set-Content -Path $StateFile -Value $phoneIp -Encoding ascii
  $wireless = Get-WirelessDevice
  Warn "Connected over Wi-Fi - you can UNPLUG the USB cable now."
}

if (-not $wireless) { Die "Could not establish a wireless device connection." }
Info "Wireless device: $($wireless.Serial)"

# --- 2. adb reverse (phone localhost -> laptop API) -----------------------
Info "adb reverse tcp:$ApiPort tcp:$ApiPort"
adb -s $wireless.Serial reverse tcp:$ApiPort tcp:$ApiPort | Out-Null

if (-not (Test-ApiPort $ApiPort)) {
  Warn "Nothing is listening on localhost:$ApiPort yet - start the API ($(if ($Docker) {'docker compose up'} else {'dotnet run'})). The app will fail to reach it until you do."
}

# --- 3. keep the link + reverse alive, then flutter run -------------------
# A wireless adb link drops when the phone sleeps or Wi-Fi blips, and that wipes
# the reverse tunnel - which is why the reverse "stops working" mid-session and you
# end up re-running it by hand. This background watchdog re-connects the device and
# re-asserts `adb reverse` every few seconds for the whole run. Both commands are
# idempotent (a no-op when already in place), so re-running them is safe.
$watchdog = Start-Job -Name 'travle-adb-reverse' -ScriptBlock {
  param($serial, $apiPort)
  $pattern = '{0}\s+device' -f [regex]::Escape($serial)
  while ($true) {
    Start-Sleep -Seconds 5
    if (((adb devices) -join "`n") -notmatch $pattern) { adb connect $serial | Out-Null }
    adb -s $serial reverse tcp:$apiPort tcp:$apiPort | Out-Null
  }
} -ArgumentList $wireless.Serial, $ApiPort
Info "adb-reverse watchdog started (re-asserts tcp:$ApiPort if the Wi-Fi link drops)."

Info "flutter run  (device $($wireless.Serial), $EnvFile -> port $ApiPort)"
Push-Location $MobileDir
try {
  flutter run -d $wireless.Serial --dart-define-from-file=$EnvFile
} finally {
  Pop-Location
  Stop-Job   $watchdog -ErrorAction SilentlyContinue
  Remove-Job $watchdog -Force -ErrorAction SilentlyContinue
  Info "adb-reverse watchdog stopped."
}
