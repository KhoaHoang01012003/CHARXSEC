param(
    [Parameter(Position = 0)]
    [ValidateSet("start", "stop", "restart", "status", "open", "logs")]
    [string]$Action = "status",

    [string]$Distro = "Debian",
    [string]$LabDir = "",
    [string]$RunId = "",
    [int]$WaitSeconds = 180,
    [switch]$SkipRoleProbe,
    [switch]$NoOpen
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($LabDir)) {
    $defaultUser = (& wsl.exe -d $Distro -- bash -lc "id -un").Trim()
    $LabDir = "/home/$defaultUser/charx_labs/charx_v190"
}

$ScriptPath = Join-Path $PSScriptRoot "scripts\charx_full_service.sh"
$ResolvedScriptPath = (Resolve-Path $ScriptPath).Path
$WslScriptPath = $ResolvedScriptPath -replace "\\", "/"
if ($WslScriptPath -match "^([A-Za-z]):/(.*)$") {
    $WslScriptPath = "/mnt/" + $Matches[1].ToLower() + "/" + $Matches[2]
}

$argsList = @($Action)
$argsList += @("--wait", [string]$WaitSeconds)

if (-not [string]::IsNullOrWhiteSpace($RunId)) {
    $argsList += @("--run-id", $RunId)
}
if ($SkipRoleProbe) {
    $argsList += "--skip-role-probe"
}
if ($NoOpen) {
    $argsList += "--no-open"
}

& wsl.exe -d $Distro -u root -- env "CHARX_LAB_DIR=$LabDir" bash "$WslScriptPath" @argsList
$code = $LASTEXITCODE

if ($Action -eq "open") {
    Start-Process "https://localhost/"
}

exit $code
