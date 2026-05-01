param(
  [string]$Godot = "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.6.2-stable_win64_console.exe"
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$LogDir = Join-Path $ProjectRoot "logs"
$WindowsDir = Join-Path $ProjectRoot "builds\windows"
$MacDir = Join-Path $ProjectRoot "builds\macos"
New-Item -ItemType Directory -Force -Path $LogDir, $WindowsDir, $MacDir | Out-Null
$LogPath = Join-Path $LogDir "build-last.log"

Push-Location $ProjectRoot
try {
  "== Windows export ==" | Tee-Object -FilePath $LogPath
  & $Godot --headless --path $ProjectRoot --export-release "Windows Desktop" "builds/windows/Wallborn.exe" 2>&1 | Tee-Object -FilePath $LogPath -Append
  if ($LASTEXITCODE -ne 0) { Write-Error "Windows export failed. See $LogPath" }

  "== macOS export ==" | Tee-Object -FilePath $LogPath -Append
  & $Godot --headless --path $ProjectRoot --export-release "macOS" "builds/macos/Wallborn.zip" 2>&1 | Tee-Object -FilePath $LogPath -Append
  if ($LASTEXITCODE -ne 0) { Write-Error "macOS export failed. See $LogPath" }

  Write-Host "Builds completed. Log: $LogPath"
}
finally {
  Pop-Location
}