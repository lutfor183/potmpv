param(
  [string]$MpvUrl = "https://sourceforge.net/projects/mpv-player-windows/files/release/mpv-x86_64-20240101-git-4b1c9ad.7z/download"
)
$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$win = Join-Path $here "dist\win"
$mpv = Join-Path $win "mpv"

New-Item -ItemType Directory -Force -Path $win | Out-Null
if (-not (Test-Path (Join-Path $mpv "mpv.exe"))) {
  $zip = Join-Path $win "mpv.7z"
  Invoke-WebRequest -Uri $MpvUrl -OutFile $zip
  $seven = Get-Command 7z -ErrorAction SilentlyContinue
  if (-not $seven) { throw "7-Zip is required to unpack mpv (winget install 7zip.7zip)" }
  7z x $zip "-o$win" -y | Out-Null
  $dir = Get-ChildItem $win -Directory | Where-Object { $_.Name -like "mpv-x86_64*" } | Select-Object -First 1
  if ($dir) { if (Test-Path $mpv) { Remove-Item $mpv -Recurse -Force }; Move-Item $dir.FullName $mpv }
  Remove-Item $zip -Force
}

$iscc = Get-Command iscc -ErrorAction SilentlyContinue
if (-not $iscc) {
  $cand = @("${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe", "$env:ProgramFiles\Inno Setup 6\ISCC.exe") |
    Where-Object { Test-Path $_ } | Select-Object -First 1
  if ($cand) { $iscc = Get-Command $cand }
}
if (-not $iscc) { throw "Inno Setup 6 is required (winget install JRSoftware.InnoSetup)" }

$ver = (Get-Content (Join-Path $here "VERSION") -Raw).Trim()
& $iscc.Source "/DMyAppVersion=$ver" (Join-Path $here "installer\potmpv.iss")
Write-Host "Built dist\PotMPV-$ver-setup.exe"
