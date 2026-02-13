$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$CrateDir = Join-Path $Root "rust/gravity_engine"
$OutputDir = Join-Path $Root "native"

if (!(Test-Path $OutputDir)) {
  New-Item -ItemType Directory -Path $OutputDir | Out-Null
}

Push-Location $CrateDir
cargo build --release --lib
Pop-Location

$LibName = "gravity_engine.dll"
$TargetDir = if ($env:CARGO_TARGET_DIR) { $env:CARGO_TARGET_DIR } else { Join-Path $CrateDir "target" }
$Source = Join-Path $TargetDir "release/$LibName"
$Destination = Join-Path $OutputDir $LibName

Copy-Item -Path $Source -Destination $Destination -Force
Write-Host "Built and copied: $Destination"
