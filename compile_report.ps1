# Compile the LaTeX report_main.tex document
# Usage: .\compile_report.ps1

$report = "report_main.tex"
if (-not (Test-Path $report)) {
    Write-Error "File not found: $report"
    exit 1
}

$pdflatex = Get-Command pdflatex -ErrorAction SilentlyContinue
$bibtex   = Get-Command bibtex -ErrorAction SilentlyContinue

if (-not $pdflatex) {
    Write-Error "pdflatex not found. Install MiKTeX or TeX Live and add pdflatex to your PATH."
    exit 1
}
if (-not $bibtex) {
    Write-Error "bibtex not found. Install MiKTeX or TeX Live and add bibtex to your PATH."
    exit 1
}

$basename = [System.IO.Path]::GetFileNameWithoutExtension($report)

& $pdflatex.Source $report
& $bibtex.Source $basename
& $pdflatex.Source $report
& $pdflatex.Source $report

Write-Host "Compilation complete. Check report_main.pdf."
