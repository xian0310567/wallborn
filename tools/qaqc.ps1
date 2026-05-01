param(
  [string]$Godot = "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.6.2-stable_win64_console.exe",
  [switch]$SkipBuild
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$LogDir = Join-Path $ProjectRoot "logs"
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
$QaLog = Join-Path $LogDir "qaqc-last.log"
$SummaryPath = Join-Path $LogDir "qaqc-summary.json"

function Write-Step($Message) {
  $line = "[$(Get-Date -Format o)] $Message"
  Write-Host $line
  Add-Content -LiteralPath $QaLog -Value $line -Encoding UTF8
}

function Assert-File($Path, [int64]$MinBytes) {
  if (-not (Test-Path -LiteralPath $Path)) {
    throw "Missing expected artifact: $Path"
  }
  $item = Get-Item -LiteralPath $Path
  if ($item.Length -lt $MinBytes) {
    throw "Artifact too small: $Path ($($item.Length) bytes, expected >= $MinBytes)"
  }
  return @{ path = $Path; bytes = $item.Length }
}

Set-Content -LiteralPath $QaLog -Value "Wallborn QA/QC run started $(Get-Date -Format o)" -Encoding UTF8
$started = Get-Date
$artifacts = @()

try {
  Write-Step "Checking Godot executable"
  if (-not (Test-Path -LiteralPath $Godot)) {
    throw "Godot executable not found: $Godot"
  }
  $godotVersion = (& $Godot --version).Trim()
  Write-Step "Godot version: $godotVersion"

  Write-Step "Running automated tests"
  & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "test.ps1") -Godot $Godot
  if ($LASTEXITCODE -ne 0) { throw "Automated tests failed" }

  if (-not $SkipBuild) {
    Write-Step "Building desktop exports"
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "build.ps1") -Godot $Godot
    if ($LASTEXITCODE -ne 0) { throw "Desktop export failed" }

    Write-Step "Validating build artifacts"
    $artifacts += Assert-File (Join-Path $ProjectRoot "builds\windows\Wallborn.exe") 1000000
    $artifacts += Assert-File (Join-Path $ProjectRoot "builds\macos\Wallborn.zip") 1000000
  }

  Write-Step "Checking git status"
  $gitStatus = git -C $ProjectRoot status --short

  $summary = [ordered]@{
    ok = $true
    startedAt = $started.ToString("o")
    finishedAt = (Get-Date).ToString("o")
    godotVersion = $godotVersion
    skipBuild = [bool]$SkipBuild
    artifacts = $artifacts
    gitDirty = [bool]$gitStatus
    gitStatus = @($gitStatus)
  }
  $summary | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $SummaryPath -Encoding UTF8
  Write-Step "QA/QC passed. Summary: $SummaryPath"
}
catch {
  $summary = [ordered]@{
    ok = $false
    startedAt = $started.ToString("o")
    finishedAt = (Get-Date).ToString("o")
    error = $_.Exception.Message
  }
  $summary | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $SummaryPath -Encoding UTF8
  Write-Step "QA/QC failed: $($_.Exception.Message)"
  throw
}