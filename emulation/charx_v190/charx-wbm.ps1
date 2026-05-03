param(
    [Parameter(Position = 0)]
    [ValidateSet("start", "stop", "restart", "status", "open")]
    [string]$Action = "status",

    [string]$Distro = "Debian",
    [string]$LabDir = "",
    [string]$RunId = "",

    [switch]$CoreOnly
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($LabDir)) {
    $defaultUser = (& wsl.exe -d $Distro -- bash -lc "id -un").Trim()
    $LabDir = "/home/$defaultUser/charx_labs/charx_v190"
}

function Invoke-WslRoot {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Command,
        [switch]$AllowFailure
    )

    & wsl.exe -d $Distro -u root -- bash -lc $Command
    $code = $LASTEXITCODE
    if (-not $AllowFailure -and $code -ne 0) {
        throw "WSL command failed with exit code $code"
    }
}

function New-RunId {
    return "wbm-full-" + (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmssZ")
}

function Start-Wbm {
    if ([string]::IsNullOrWhiteSpace($RunId)) {
        $script:RunId = New-RunId
    }

    $coreServices = @(
        "mosquitto",
        "charx-system-config-manager",
        "charx-website",
        "nginx",
        "charx-jupicore"
    )

    $fullServices = $coreServices + @(
        "charx-controller-agent",
        "charx-ocpp16-agent",
        "charx-modbus-server",
        "charx-modbus-agent",
        "charx-loadmanagement"
    )

    $services = if ($CoreOnly) { $coreServices } else { $fullServices }
    $serviceArgs = ($services | ForEach-Object { "'$_'" }) -join " "
    $safeRunId = $RunId -replace "'", "'\''"

    Write-Host "Starting CHARX WBM run: $RunId"
    Write-Host "Mode: $(if ($CoreOnly) { 'core WBM only' } else { 'full WBM + OCPP/Modbus/LoadManagement' })"

    $cmd = @"
set -e
cd '$LabDir'
setsid -f ./scripts/start_fresh_wbm_roles_session.sh '$safeRunId' $serviceArgs > /tmp/charx-wbm-$safeRunId.out 2>&1
echo '$safeRunId' > /tmp/charx-wbm-last-run-id
sleep 8
echo 'Run ID: $safeRunId'
echo 'Start log: /tmp/charx-wbm-$safeRunId.out'
echo
tail -n 40 /tmp/charx-wbm-$safeRunId.out || true
echo
echo 'Listening ports:'
ss -lntp | egrep ':(80|81|443|1883|4444|4999|5000|5001|5002|5555|2106|1603|9502|9555|502)\b' || true
echo
echo 'Open from Windows browser: https://localhost/'
"@

    Invoke-WslRoot $cmd
}

function Stop-Wbm {
    Write-Host "Stopping CHARX WBM session..."
    $cmd = @"
set +e
cd '$LabDir'
./scripts/stop_wbm_session.sh >/tmp/charx-wbm-stop.out 2>&1
status=`$?
cat /tmp/charx-wbm-stop.out
echo
echo 'Remaining CHARX-related listeners:'
ss -lntp | egrep ':(80|81|443|1883|4444|4999|5000|5001|5002|5555|2106|1603|9502|9555|502)\b' || true
exit `$status
"@
    Invoke-WslRoot $cmd -AllowFailure
}

function Show-WbmStatus {
    $cmd = @"
set +e
cd '$LabDir'
echo 'Session state:'
if [ -f state/wbm_session.env ]; then
  cat state/wbm_session.env
else
  echo 'No state/wbm_session.env found.'
fi
echo
echo 'Last detached run id:'
cat /tmp/charx-wbm-last-run-id 2>/dev/null || true
echo
echo 'Listening ports:'
ss -lntp | egrep ':(80|81|443|1883|4444|4999|5000|5001|5002|5555|2106|1603|9502|9555|502)\b' || true
echo
echo 'HTTP smoke:'
curl -k -sS -o /dev/null -w 'frontend https://localhost/ => %{http_code}\n' https://localhost/ || true
curl -k -sS -o /dev/null -w 'system-name API => %{http_code}\n' https://localhost/api/v1.0/web/system-name || true
"@
    Invoke-WslRoot $cmd -AllowFailure
}

function Open-Wbm {
    Start-Process "https://localhost/"
}

switch ($Action) {
    "start" {
        Start-Wbm
    }
    "stop" {
        Stop-Wbm
    }
    "restart" {
        Stop-Wbm
        Start-Sleep -Seconds 2
        Start-Wbm
    }
    "status" {
        Show-WbmStatus
    }
    "open" {
        Open-Wbm
    }
}
