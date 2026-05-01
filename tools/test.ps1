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

  "== 3D scene smoke test ==" | Tee-Object -FilePath $LogPath -Append
  & $Godot --headless --path $ProjectRoot --scene res://scenes/main_3d.tscn --quit-after 1 2>&1 | Tee-Object -FilePath $LogPath -Append
  if ($LASTEXITCODE -ne 0) {
    Write-Error "Godot 3D scene smoke test failed. See $LogPath"
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

  "== 3D grid view unit test ==" | Tee-Object -FilePath $LogPath -Append
  & $Godot --headless --path $ProjectRoot --script res://tests/test_grid_view_3d.gd 2>&1 | Tee-Object -FilePath $LogPath -Append
  if ($LASTEXITCODE -ne 0) {
    Write-Error "Godot 3D grid view test failed. See $LogPath"
  }

  "== 3D camera rig unit test ==" | Tee-Object -FilePath $LogPath -Append
  & $Godot --headless --path $ProjectRoot --script res://tests/test_camera_rig_3d.gd 2>&1 | Tee-Object -FilePath $LogPath -Append
  if ($LASTEXITCODE -ne 0) {
    Write-Error "Godot 3D camera rig test failed. See $LogPath"
  }

  "== 3D enemy unit test ==" | Tee-Object -FilePath $LogPath -Append
  & $Godot --headless --path $ProjectRoot --script res://tests/test_enemy_3d.gd 2>&1 | Tee-Object -FilePath $LogPath -Append
  if ($LASTEXITCODE -ne 0) {
    Write-Error "Godot 3D enemy test failed. See $LogPath"
  }

  "== 3D path visual unit test ==" | Tee-Object -FilePath $LogPath -Append
  & $Godot --headless --path $ProjectRoot --script res://tests/test_main_3d_path_visuals.gd 2>&1 | Tee-Object -FilePath $LogPath -Append
  if ($LASTEXITCODE -ne 0) {
    Write-Error "Godot 3D path visual test failed. See $LogPath"
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

  "== Card unit test ==" | Tee-Object -FilePath $LogPath -Append
  & $Godot --headless --path $ProjectRoot --script res://tests/test_cards.gd 2>&1 | Tee-Object -FilePath $LogPath -Append
  if ($LASTEXITCODE -ne 0) {
    Write-Error "Godot card test failed. See $LogPath"
  }

  Write-Host "All tests passed. Log: $LogPath"
}
finally {
  Pop-Location
}



