[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

$workspace_root = [IO.Path]::GetFullPath($PSScriptRoot)
$resource_root = [IO.Path]::GetFullPath((Join-Path $workspace_root "sky_phone"))
$resource_prefix = $resource_root.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
$frontend = [IO.Path]::GetFullPath((Join-Path $workspace_root "frontend"))
$html = [IO.Path]::GetFullPath((Join-Path $resource_root "source\html"))
$package_json = Join-Path $frontend "package.json"
$node_modules = Join-Path $frontend "node_modules"
$manifest = Join-Path $resource_root "fxmanifest.lua"

if (-not $html.StartsWith($resource_prefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Resolved HTML directory left the sky_phone resource root: $html"
}

if (-not (Test-Path -LiteralPath $package_json -PathType Leaf)) {
    throw "Missing sky_phone frontend package.json: $package_json"
}

if (-not (Test-Path -LiteralPath $manifest -PathType Leaf)) {
    throw "Missing deployable sky_phone resource: $resource_root"
}

if (-not (Test-Path -LiteralPath $node_modules -PathType Container)) {
    throw "Missing frontend dependencies. Run pnpm install in: $frontend"
}

$pnpm = Get-Command "pnpm.cmd" -ErrorAction Stop

Write-Host "[BUILD]  sky_phone"
Write-Host "         $frontend"

Push-Location -LiteralPath $frontend
try {
    & $pnpm.Source build
    $build_exit_code = $LASTEXITCODE
} finally {
    Pop-Location
}

if ($build_exit_code -ne 0) {
    throw "sky_phone frontend build failed with exit code $build_exit_code"
}

if (-not (Test-Path -LiteralPath (Join-Path $html "index.html") -PathType Leaf)) {
    throw "Frontend build succeeded but did not create source/html/index.html: $html"
}

Write-Host "[OK]     sky_phone frontend"
Write-Host ""
Write-Host "[COPY]   Deploying sky_phone to the configured servers..."

& (Join-Path $workspace_root "build_copy.bat")
$copy_exit_code = $LASTEXITCODE

if ($copy_exit_code -ne 0) {
    throw "sky_phone resource copy failed with exit code $copy_exit_code"
}

exit 0
