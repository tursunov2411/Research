$ErrorActionPreference = "Stop"

$ProjectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $ProjectRoot

New-Item -ItemType Directory -Force -Path "output/latex" | Out-Null

$latexmk = Get-Command latexmk -ErrorAction SilentlyContinue
$lualatex = Get-Command lualatex -ErrorAction SilentlyContinue
$pdflatex = Get-Command pdflatex -ErrorAction SilentlyContinue

if ($latexmk) {
  & $latexmk.Source -pdf -interaction=nonstopmode -halt-on-error -output-directory=output/latex thesis/main.tex
  exit $LASTEXITCODE
}

$engine = $null
if ($lualatex) {
  $engine = $lualatex.Source
} elseif ($pdflatex) {
  $engine = $pdflatex.Source
}

if (-not $engine) {
  Write-Error "No LaTeX engine found. Install TinyTeX, TeX Live, or MiKTeX, then rerun thesis/build_latex.ps1."
  exit 1
}

for ($i = 0; $i -lt 2; $i++) {
  & $engine -interaction=nonstopmode -halt-on-error -output-directory=output/latex thesis/main.tex
  if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
  }
}

Write-Host "LaTeX PDF written to output/latex/main.pdf"
