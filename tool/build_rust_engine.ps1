$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$CrateDir = Join-Path $Root "rust/gravity_engine"
$OutputDir = Join-Path $Root "native"
$Targets = if ($args.Count -gt 0) { $args } else { @() }

if ($Targets.Count -eq 0) {
  if ($IsWindows) {
    $Targets = @("x86_64-pc-windows-msvc")
  } else {
    throw "Default target is only configured for Windows in this PowerShell script. Pass explicit Rust targets as args."
  }
}

if (!(Test-Path $OutputDir)) {
  New-Item -ItemType Directory -Path $OutputDir | Out-Null
}

$TargetDir = if ($env:CARGO_TARGET_DIR) { $env:CARGO_TARGET_DIR } else { Join-Path $CrateDir "target" }

function Get-LibName([string]$Target) {
  if ($Target -like "*-windows-*") {
    return "gravity_engine.dll"
  }
  if ($Target -like "*-apple-darwin" -or $Target -like "*-apple-ios") {
    return "libgravity_engine.dylib"
  }
  return "libgravity_engine.so"
}

function Get-AbiFolder([string]$Target) {
  switch ($Target) {
    "aarch64-apple-darwin" { return "macos-arm64" }
    "x86_64-apple-darwin" { return "macos-x64" }
    "aarch64-unknown-linux-gnu" { return "linux-arm64" }
    "x86_64-unknown-linux-gnu" { return "linux-x64" }
    "armv7-unknown-linux-gnueabihf" { return "linux-arm" }
    "i686-unknown-linux-gnu" { return "linux-ia32" }
    "x86_64-pc-windows-msvc" { return "windows-x64" }
    "x86_64-pc-windows-gnu" { return "windows-x64" }
    "i686-pc-windows-msvc" { return "windows-ia32" }
    "i686-pc-windows-gnu" { return "windows-ia32" }
    "aarch64-pc-windows-msvc" { return "windows-arm64" }
    "aarch64-linux-android" { return "android-arm64" }
    "x86_64-linux-android" { return "android-x64" }
    "i686-linux-android" { return "android-ia32" }
    "armv7-linux-androideabi" { return "android-arm" }
    "aarch64-apple-ios" { return "ios-arm64" }
    "x86_64-apple-ios" { return "ios-x64" }
    default { return $null }
  }
}

Push-Location $CrateDir
try {
  foreach ($Target in $Targets) {
    $AbiFolder = Get-AbiFolder $Target
    if (-not $AbiFolder) {
      throw "Unsupported target mapping: $Target"
    }

    $LibName = Get-LibName $Target
    Write-Host "Building $Target..."
    cargo build --release --lib --target $Target

    $Source = Join-Path $TargetDir "$Target/release/$LibName"
    $DestDir = Join-Path $OutputDir $AbiFolder
    if (!(Test-Path $DestDir)) {
      New-Item -ItemType Directory -Path $DestDir | Out-Null
    }
    $Destination = Join-Path $DestDir $LibName
    Copy-Item -Path $Source -Destination $Destination -Force
    Write-Host "Copied: $Destination"
  }
} finally {
  Pop-Location
}

Write-Host "Rust engine build complete."
