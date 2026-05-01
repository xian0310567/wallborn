param(
  [string]$Godot = "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.6.2-stable_win64_console.exe"
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$LogDir = Join-Path $ProjectRoot "logs"
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
$LogPath = Join-Path $LogDir "test-last.log"

& $Godot --headless --path $ProjectRoot --quit-after 1 2>&1 | Tee-Object -FilePath $LogPath
if ($LASTEXITCODE -ne 0) {
  Write-Error "Godot smoke test failed. See $LogPath"
}
Write-Host "Godot smoke test passed. Log: $LogPath"