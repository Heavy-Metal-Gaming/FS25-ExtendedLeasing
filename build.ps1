#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Generic build / release script for FS mods.
.DESCRIPTION
    Builds a distributable .zip mod artifact, or creates a release tag to trigger CI.
    Automatically detects mod name from modDesc.xml and FS version from directory name.

    --fs_ver accepts a single version or comma-separated list (e.g. 25,28).
    If omitted, defaults to the highest-numbered FS*_Src directory found.
.PARAMETER Command
    One of: build, release-test, release
.PARAMETER Version
    Semver for release command (e.g. 1.0.0.0, 1.0.0.0-beta.1). Required for 'release'.
.PARAMETER fs_ver
    FS version(s) as a comma-separated string. Defaults to latest FS*_Src found.
.EXAMPLE
    .\build.ps1 build
    .\build.ps1 build --fs_ver 28
    .\build.ps1 release 1.0.0.0
#>
param(
    [Parameter(Position = 0, Mandatory = $true)]
    [ValidateSet("build", "release-test", "release")]
    [string]$Command,

    [Parameter(Position = 1)]
    [string]$Version,

    [string]$fs_ver
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

# Extract mod name from modDesc.xml
function Get-ModNameFromDescriptor {
    param([string]$DescPath)
    if (-not (Test-Path $DescPath)) {
        Write-Error "modDesc.xml not found: $DescPath"
        exit 1
    }
    
    [xml]$xml = Get-Content $DescPath -Encoding UTF8
    $title = $xml.modDesc.title | Select-Object -First 1
    if ($title -is [string]) {
        $name = $title
    } else {
        $name = $title.en
    }
    
    if (-not $name) {
        Write-Error "Could not parse mod title from $DescPath"
        exit 1
    }
    
    # Convert to valid filename: remove spaces/special chars, keep alphanumeric and underscores
    $safeName = [regex]::Replace($name, '[^a-zA-Z0-9_]', '')
    return $safeName
}

function Get-LatestFsVersion {
    $latest = $null
    Get-ChildItem -Path $ScriptDir -Directory -Filter "FS*_Src" | ForEach-Object {
        $n = $_.Name -replace '^FS(\d+)_Src$', '$1'
        if ($n -match '^\d+$') {
            $num = [int]$n
            if ($null -eq $latest -or $num -gt $latest) {
                $latest = $num
            }
        }
    }
    if ($null -eq $latest) {
        Write-Error "No FS*_Src directories found in $ScriptDir"
        exit 1
    }
    return $latest.ToString()
}

function Resolve-FsVersions {
    param([string]$Raw)
    if ($Raw) {
        return $Raw -split ',' | ForEach-Object { $_.Trim() }
    }
    return @(Get-LatestFsVersion)
}

function Invoke-Build {
    param([string]$FsVer)

    $srcDir  = Join-Path $ScriptDir "FS${FsVer}_Src"
    $modDesc = Join-Path $srcDir "modDesc.xml"
    $modName = Get-ModNameFromDescriptor -DescPath $modDesc
    $zipName = "FS${FsVer}_${modName}"
    $outDir  = Join-Path $ScriptDir "dist"
    $zipPath = Join-Path $outDir "${zipName}.zip"

    if (-not (Test-Path $srcDir)) {
        Write-Error "Source directory not found: $srcDir"
        exit 1
    }

    Write-Host "Building ${zipName}.zip from FS${FsVer}_Src ..." -ForegroundColor Cyan

    if (-not (Test-Path $outDir)) {
        New-Item -ItemType Directory -Path $outDir -Force | Out-Null
    }

    if (Test-Path $zipPath) {
        Remove-Item $zipPath -Force
    }

    # Stage into a temp dir
    $staging = Join-Path ([System.IO.Path]::GetTempPath()) "${zipName}-staging-$(Get-Random)"
    New-Item -ItemType Directory -Path $staging -Force | Out-Null

    # Copy mod contents to staging
    Get-ChildItem -Path $srcDir -Force | ForEach-Object {
        if ($_.PSIsContainer) {
            Copy-Item $_.FullName -Destination (Join-Path $staging $_.Name) -Recurse -Force
        } else {
            Copy-Item $_.FullName -Destination (Join-Path $staging $_.Name) -Force
        }
    }

    # Remove dev files (backups, logs)
    Get-ChildItem -Path $staging -Recurse -Filter '*.bak' | Remove-Item -Force -ErrorAction SilentlyContinue
    Get-ChildItem -Path $staging -Recurse -Filter '*.log' | Remove-Item -Force -ErrorAction SilentlyContinue

    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zipStream = [System.IO.File]::Create($zipPath)
    $archive = New-Object System.IO.Compression.ZipArchive($zipStream, [System.IO.Compression.ZipArchiveMode]::Create)
    $stagingFullPath = (Resolve-Path $staging).Path
    Get-ChildItem -Path $staging -Recurse -File | ForEach-Object {
        $relativePath = $_.FullName.Substring($stagingFullPath.Length + 1).Replace('\', '/')
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, $_.FullName, $relativePath, [System.IO.Compression.CompressionLevel]::Optimal) | Out-Null
    }
    $archive.Dispose()
    $zipStream.Dispose()

    Remove-Item $staging -Recurse -Force

    $sizeKB = [math]::Round((Get-Item $zipPath).Length / 1024, 1)
    Write-Host "  Created: $zipPath ($sizeKB KB)" -ForegroundColor Green
    Write-Host "Done." -ForegroundColor Cyan
}

function Invoke-Release {
    param([string]$Ver, [string[]]$FsVers)

    $tag = "release/$Ver"

    if ($Ver -notmatch '^\d+\.\d+\.\d+\.\d+(-[a-zA-Z]+\.\d+)?$') {
        Write-Error "Invalid version format '$Ver'. Expected: X.Y.Z.W or X.Y.Z.W-alpha.N or X.Y.Z.W-beta.N"
        exit 1
    }

    foreach ($fv in $FsVers) {
        $srcDir = Join-Path $ScriptDir "FS${fv}_Src"
        if (-not (Test-Path $srcDir)) {
            Write-Error "Source directory not found: $srcDir"
            exit 1
        }
    }

    $status = git -C $ScriptDir status --porcelain
    if ($status) {
        Write-Error "Working tree is not clean. Commit or stash changes first."
        exit 1
    }

    foreach ($fv in $FsVers) {
        Invoke-Build -FsVer $fv
    }

    $jsonVersions = $FsVers | ForEach-Object { [int]$_ }
    @{ versions = $jsonVersions } | ConvertTo-Json -Compress | Set-Content (Join-Path $ScriptDir "fs_versions.json") -Encoding UTF8

    git -C $ScriptDir add fs_versions.json
    $null = git -C $ScriptDir diff --cached --quiet 2>&1
    if ($LASTEXITCODE -ne 0) {
        $fsList = $FsVers -join ","
        git -C $ScriptDir commit -m "Set build targets to FS$fsList for $Ver"
    }

    $fsList = $FsVers -join ", "
    Write-Host ""
    Write-Host "Creating tag: $tag (FS versions: $fsList)" -ForegroundColor Cyan
    git -C $ScriptDir tag -a $tag -m "Release $Ver (FS$fsList)"
    git -C $ScriptDir push origin HEAD $tag

    Write-Host ""
    Write-Host "Release tag '$tag' pushed. CI will build and publish the GitHub release." -ForegroundColor Green
}

$fsVersions = @(Resolve-FsVersions -Raw $fs_ver)

switch ($Command) {
    "build" {
        Invoke-Build -FsVer $fsVersions[0]
    }
    "release-test" {
        Invoke-Build -FsVer $fsVersions[0]
    }
    "release" {
        if (-not $Version) {
            Write-Error "release requires a version argument. Usage: .\build.ps1 release <version> [--fs_ver VER]"
            exit 1
        }
        Invoke-Release -Ver $Version -FsVers $fsVersions
    }
}
