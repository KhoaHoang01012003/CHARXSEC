param(
    [string]$BundlePath = "",
    [string]$Distro = "Debian",
    [string]$LabUser = "",
    [switch]$SkipQiling,
    [switch]$SkipPrepare,
    [switch]$StartFullService
)

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path

if ([string]::IsNullOrWhiteSpace($BundlePath)) {
    $candidate = Join-Path $repoRoot "CHARXSEC3XXXSoftwareBundleV190.raucb"
    if (Test-Path -LiteralPath $candidate) {
        $BundlePath = $candidate
    } else {
        throw "BundlePath is required. Example: .\emulation\charx_v190\bootstrap-from-bundle.cmd -BundlePath C:\path\CHARXSEC3XXXSoftwareBundleV190.raucb"
    }
}

$bundleFull = (Resolve-Path -LiteralPath $BundlePath).Path

function Convert-ToWslPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    $resolved = (Resolve-Path -LiteralPath $Path).Path
    $drive = $resolved.Substring(0, 1).ToLowerInvariant()
    $rest = $resolved.Substring(3) -replace '\\', '/'
    return "/mnt/$drive/$rest"
}

$repoWsl = Convert-ToWslPath -Path $repoRoot
$bundleWsl = Convert-ToWslPath -Path $bundleFull

if ([string]::IsNullOrWhiteSpace($LabUser)) {
    $LabUser = (wsl -d $Distro -- bash -lc "id -un").Trim()
}

$script = "$repoWsl/emulation/charx_v190/scripts/bootstrap_from_bundle.sh"
$skipQilingValue = if ($SkipQiling) { "1" } else { "0" }
$skipPrepareValue = if ($SkipPrepare) { "1" } else { "0" }
$startFullValue = if ($StartFullService) { "1" } else { "0" }

Write-Host "Repo: $repoWsl"
Write-Host "Bundle: $bundleWsl"
Write-Host "WSL distro: $Distro"
Write-Host "Lab user: $LabUser"

$cmd = @"
set -euo pipefail
export CHARX_WORKSPACE='$repoWsl'
export CHARX_BUNDLE_SOURCE='$bundleWsl'
export CHARX_LAB_USER='$LabUser'
export CHARX_SKIP_QILING='$skipQilingValue'
export CHARX_SKIP_PREPARE='$skipPrepareValue'
export CHARX_START_FULL_SERVICE='$startFullValue'
bash '$script'
"@

wsl -d $Distro -u root -- bash -lc $cmd
exit $LASTEXITCODE
