#requires -Version 5.1
param([string]$PbrSource='C:\GitClonedProjects\PBR',[string]$CMake='cmake',[string]$Python='python')
$ErrorActionPreference='Stop'
$專案=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$PbrSource=[IO.Path]::GetFullPath($PbrSource)
$快取=Join-Path $PSScriptRoot 'cache'
New-Item -ItemType Directory -Force -Path $快取 | Out-Null
& $CMake -S $PSScriptRoot -B (Join-Path $PSScriptRoot 'build') "-DPBR_SOURCE=$PbrSource"
if($LASTEXITCODE){throw '無法設定資產烘焙工具。'}
& $CMake --build (Join-Path $PSScriptRoot 'build') --config Release --parallel
if($LASTEXITCODE){throw '無法建置資產烘焙工具。'}
Push-Location (Join-Path $PbrSource 'data')
try {
    & (Join-Path $PSScriptRoot 'build/Release/bake.exe') $快取
    if($LASTEXITCODE){throw '資產烘焙失敗。'}
} finally {Pop-Location}
& $Python (Join-Path $PSScriptRoot 'pack-assets.py') $快取 $專案 --source $PbrSource
if($LASTEXITCODE){throw '資產封裝失敗。'}
