#!/usr/bin/env pwsh
param(
    [Parameter(Position = 0)]
    [ValidateSet("build")]
    [string]$Command = "build"
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$srcDir = Join-Path $ScriptDir "FS25_Src"
$outDir = Join-Path $ScriptDir "dist"
$zipPath = Join-Path $outDir "FS25_LeasingExtension.zip"

function New-StagingDir {
    $guid = [System.Guid]::NewGuid().ToString("N")
    return Join-Path ([System.IO.Path]::GetTempPath()) "LeasingExtension-staging-$guid"
}

if (-not (Test-Path $srcDir)) {
    throw "Missing source directory: $srcDir"
}

if (-not (Test-Path $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}

if (Test-Path $zipPath) {
    Remove-Item $zipPath -Force
}

$staging = New-StagingDir
New-Item -ItemType Directory -Path $staging -Force | Out-Null
Copy-Item -Path (Join-Path $srcDir "*") -Destination $staging -Recurse -Force

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zipStream = [System.IO.File]::Create($zipPath)
$archive = New-Object System.IO.Compression.ZipArchive($zipStream, [System.IO.Compression.ZipArchiveMode]::Create)
$stagingFull = (Resolve-Path $staging).Path

Get-ChildItem -Path $staging -Recurse -File | ForEach-Object {
    $relativePath = $_.FullName.Substring($stagingFull.Length + 1).Replace('\\', '/')
    [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, $_.FullName, $relativePath, [System.IO.Compression.CompressionLevel]::Optimal) | Out-Null
}

$archive.Dispose()
$zipStream.Dispose()
Remove-Item $staging -Recurse -Force

Write-Host "Created: $zipPath" -ForegroundColor Green
