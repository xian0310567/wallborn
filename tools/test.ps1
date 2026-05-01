param(
  [string]$Godot = "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.6.2-stable_win64_console.exe"
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$LogDir = Join-Path $ProjectRoot "logs"
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
$LogPath = Join-Path $LogDir "test-last.log"

Push-Location $ProjectRoot
try {
  "== Smoke test ==" | Tee-Object -FilePath $LogPath
  & $Godot --headless --path $ProjectRoot --quit-after 1 2>&1 | Tee-Object -FilePath $LogPath -Append
  if ($LASTEXITCODE -ne 0) {
    Write-Error "Godot smoke test failed. See $LogPath"
  }

  "== Grid unit test ==" | Tee-Object -FilePath $LogPath -Append
  & $Godot --headless --path $ProjectRoot --script res://tests/test_grid.gd 2>&1 | Tee-Object -FilePath $LogPath -Append
  if ($LASTEXITCODE -ne 0) {
    Write-Error "Godot grid test failed. See $LogPath"
  }

  "== Grid view unit test ==" | Tee-Object -FilePath $LogPath -Append
  & $Godot --headless --path $ProjectRoot --script res://tests/test_grid_view.gd 2>&1 | Tee-Object -FilePath $LogPath -Append
  if ($LASTEXITCODE -ne 0) {
    Write-Error "Godot grid view test failed. See $LogPath"
  }

  "== Enemy unit test ==" | Tee-Object -FilePath $LogPath -Append
  & $Godot --headless --path $ProjectRoot --script res://tests/test_enemy.gd 2>&1 | Tee-Object -FilePath $LogPath -Append
  if ($LASTEXITCODE -ne 0) {
    Write-Error "Godot enemy test failed. See $LogPath"
  }

  "== Combat unit test ==" | Tee-Object -FilePath $LogPath -Append
  & $Godot --headless --path $ProjectRoot --script res://tests/test_combat.gd 2>&1 | Tee-Object -FilePath $LogPath -Append
  if ($LASTEXITCODE -ne 0) {
    Write-Error "Godot combat test failed. See $LogPath"
  }

  "== Wave unit test ==" | Tee-Object -FilePath $LogPath -Append
  & $Godot --headless --path $ProjectRoot --script res://tests/test_wave.gd 2>&1 | Tee-Object -FilePath $LogPath -Append
  if ($LASTEXITCODE -ne 0) {
    Write-Error "Godot wave test failed. See $LogPath"
  }

  Write-Host "All tests passed. Log: $LogPath"
}
finally {
  Pop-Location
}


