param(
  [string]$Portable = "",
  [switch]$Uninstall
)
$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$version = "1.0.0"

if ($Uninstall) {
  $cfg = Join-Path $env:APPDATA "potmpv"
  $cmd = Join-Path $env:LOCALAPPDATA "PotMPV\PotMPV.cmd"
  Remove-Item $cmd -Force -ErrorAction SilentlyContinue
  $desk = [Environment]::GetFolderPath("Desktop")
  Remove-Item (Join-Path $desk "PotMPV.lnk") -Force -ErrorAction SilentlyContinue
  Write-Host "Removed PotMPV launcher. Config kept at $cfg"
  exit 0
}

$target = if ($Portable -ne "") { $Portable } else { Join-Path $env:APPDATA "potmpv" }
$cfg = if ($Portable -ne "") { Join-Path $target "config" } else { $target }
New-Item -ItemType Directory -Force -Path $cfg | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $cfg "fonts") | Out-Null

Copy-Item (Join-Path $here "mpv.conf") $cfg -Force
Copy-Item (Join-Path $here "input.conf") $cfg -Force
Copy-Item (Join-Path $here "scripts") $cfg -Recurse -Force
Copy-Item (Join-Path $here "script-opts") $cfg -Recurse -Force
Copy-Item (Join-Path $here "fonts\*.ttf") (Join-Path $cfg "fonts") -Force -ErrorAction SilentlyContinue

$mpv = $null
foreach ($c in @((Join-Path $here "mpv\mpv.exe"), (Join-Path $target "mpv\mpv.exe"))) {
  if (Test-Path $c) { $mpv = $c; break }
}
if (-not $mpv) { $mpv = "mpv.exe" }

$launcherDir = if ($Portable -ne "") { $target } else { Join-Path $env:LOCALAPPDATA "PotMPV" }
New-Item -ItemType Directory -Force -Path $launcherDir | Out-Null
$cmdPath = Join-Path $launcherDir "PotMPV.cmd"
$lines = @(
  "@echo off",
  "set MPV=$mpv",
  "`"%MPV%`" --config-dir=`"$cfg`" %*"
)
Set-Content -Path $cmdPath -Value $lines -Encoding ASCII

if ($Portable -eq "") {
  $shell = New-Object -ComObject WScript.Shell
  $desk = [Environment]::GetFolderPath("Desktop")
  $sc = $shell.CreateShortcut((Join-Path $desk "PotMPV.lnk"))
  $sc.TargetPath = $cmdPath
  $sc.WorkingDirectory = Split-Path $cmdPath
  $sc.IconLocation = if ($mpv -ne "mpv.exe") { "$mpv,0" } else { "$env:SystemRoot\System32\wmploc.dll,0" }
  $sc.Save()
  Write-Host "Installed PotMPV $version"
  Write-Host "  config : $cfg"
  Write-Host "  launch : $cmdPath  (Desktop shortcut: PotMPV)"
} else {
  Write-Host "Portable install ready: $cmdPath"
}
