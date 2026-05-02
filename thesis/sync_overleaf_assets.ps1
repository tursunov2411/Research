$ErrorActionPreference = "Stop"

$ProjectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$SourceFigures = Join-Path $ProjectRoot "output/figures"
$TargetFigures = Join-Path $PSScriptRoot "figures"

if (-not (Test-Path $SourceFigures)) {
  throw "Source figure folder not found: $SourceFigures"
}

New-Item -ItemType Directory -Force -Path $TargetFigures | Out-Null
Copy-Item -Path (Join-Path $SourceFigures "*.png") -Destination $TargetFigures -Force

Write-Host "Copied figure assets to thesis/figures for Overleaf upload."
