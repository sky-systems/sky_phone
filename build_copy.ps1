[CmdletBinding()]
param(
    [Alias("TargetRoot")]
    [string[]]$TargetRoots = @(
        "C:\Users\alecs\Desktop\Development\_SkySystems\ESX\txData\serverdata\resources\[sky]",
        "C:\Users\alecs\Desktop\Development\_SkySystems\Qbox\txData\Qbox_67DABE.base\resources\[sky]"
    ),
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

$resource = "sky_phone"
$workspace_root = [IO.Path]::GetFullPath($PSScriptRoot)
$source = [IO.Path]::GetFullPath((Join-Path $workspace_root $resource))
$deployments = @()

if (-not (Test-Path -LiteralPath (Join-Path $source "fxmanifest.lua") -PathType Leaf)) {
    throw "Missing deployable sky_phone resource: $source"
}

foreach ($configured_target_root in $TargetRoots) {
    $target_root = [IO.Path]::GetFullPath($configured_target_root)
    $target_prefix = $target_root.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    $destination = [IO.Path]::GetFullPath((Join-Path $target_root $resource))

    if ([IO.Path]::GetFileName($target_root) -ne "[sky]") {
        throw "Target root must be the [sky] resource category: $target_root"
    }

    if (-not (Test-Path -LiteralPath $target_root -PathType Container)) {
        throw "Target resource category does not exist: $target_root"
    }

    if (-not $destination.StartsWith($target_prefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Resolved destination left the target resource category: $destination"
    }

    if (Test-Path -LiteralPath $destination) {
        $destination_item = Get-Item -LiteralPath $destination -Force
        $is_reparse_point = ($destination_item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0

        if (-not $destination_item.PSIsContainer) {
            throw "Destination exists but is not a directory: $destination"
        }

        if ($is_reparse_point -and $destination_item.LinkType -notin @("SymbolicLink", "Junction")) {
            throw "Unsupported reparse point at destination: $destination"
        }
    }

    $deployments += [PSCustomObject]@{
        TargetRoot = $target_root
        Destination = $destination
    }
}

foreach ($deployment in $deployments) {
    $destination = $deployment.Destination

    if (Test-Path -LiteralPath $destination) {
        $destination_item = Get-Item -LiteralPath $destination -Force

        Write-Host "[DELETE] $destination"

        if (-not $DryRun) {
            $is_reparse_point = ($destination_item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0

            if ($is_reparse_point) {
                [IO.Directory]::Delete($destination)
            } else {
                Remove-Item -LiteralPath $destination -Recurse -Force
            }
        }
    }

    Write-Host "[COPY]   $resource"
    Write-Host "         $source"
    Write-Host "      -> $destination"

    if ($DryRun) {
        continue
    }

    & robocopy.exe $source $destination /E /R:2 /W:1 /NFL /NDL /NJH /NJS /NP
    $robocopy_exit_code = $LASTEXITCODE

    if ($robocopy_exit_code -ge 8) {
        throw "Robocopy failed for $resource with exit code $robocopy_exit_code"
    }
}

if ($DryRun) {
    Write-Host ""
    Write-Host "[DRY RUN] No files were changed."
}

exit 0
