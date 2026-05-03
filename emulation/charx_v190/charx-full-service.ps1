param(
    [Parameter(Position = 0)]
    [ValidateSet("start", "stop", "restart", "status", "open", "logs")]
    [string]$Action = "status",

    [string]$Distro = "Debian",
    [string]$LabDir = "/home/khoa/charx_labs/charx_v190",
    [string]$RunId = "",
    [int]$WaitSeconds = 180,
    [switch]$SkipRoleProbe,
    [switch]$NoOpen
)

$ErrorActionPreference = "Stop"

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

$env:CHARX_LAB_DIR = $LabDir

& wsl.exe -d $Distro -u root -- bash "$WslScriptPath" @argsList
$code = $LASTEXITCODE

if ($Action -eq "open") {
    Start-Process "https://localhost/"
}

exit $code
