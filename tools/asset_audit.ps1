#requires -Version 5.1

[CmdletBinding(DefaultParameterSetName = 'All')]
param(
    [Parameter(Mandatory = $true, ParameterSetName = 'Single')]
    [string]$Asset,

    [Parameter(ParameterSetName = 'All')]
    [switch]$All,

    [Parameter(ParameterSetName = 'Single')]
    [ValidateSet('GENERIC_BUILDING', 'HERO_BUILDING', 'VILLAGER', 'PRIMALIS', 'TREE', 'VEGETATION', 'ROCK', 'PROP', 'ENEMY', 'BOSS', 'UNKNOWN')]
    [string]$Category = '',

    [switch]$Summary
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..')).TrimEnd('\', '/')
$pythonScript = Join-Path $PSScriptRoot 'asset_audit.py'
$budgetConfig = Join-Path $PSScriptRoot 'asset_budgets.json'
$reportText = Join-Path $projectRoot 'captures\audit\latest_asset_audit.txt'
$reportJson = Join-Path $projectRoot 'captures\audit\latest_asset_audit.json'

if (-not (Test-Path -LiteralPath $pythonScript -PathType Leaf)) {
    Write-Error "Asset audit helper is missing: $pythonScript"
    exit 2
}
if (-not (Test-Path -LiteralPath $budgetConfig -PathType Leaf)) {
    Write-Error "Asset budget configuration is missing: $budgetConfig"
    exit 2
}

$python = Get-Command python -ErrorAction SilentlyContinue
if ($null -eq $python) {
    Write-Error 'Python is not available on PATH. The asset audit requires the existing local Python installation.'
    exit 2
}

$arguments = @(
    $pythonScript,
    '--project-root', $projectRoot,
    '--budgets', $budgetConfig,
    '--output-text', $reportText,
    '--output-json', $reportJson
)
if ($PSCmdlet.ParameterSetName -eq 'Single') {
    $arguments += @('--asset', $Asset)
    if (-not [string]::IsNullOrWhiteSpace($Category)) {
        $arguments += @('--category', $Category)
    }
} else {
    $arguments += '--all'
}
if ($Summary) {
    $arguments += '--summary'
}

& $python.Source @arguments
exit $LASTEXITCODE
