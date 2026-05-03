param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$RemainingArgs
)

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$qilingScriptWin = Join-Path $scriptDir "qiling\scripts\qiling_lab.sh"

if (-not (Test-Path $qilingScriptWin)) {
    throw "Missing Qiling lab script: $qilingScriptWin"
}

function Convert-ToWslPath {
    param([Parameter(Mandatory = $true)][string]$Path)

    $resolved = (Resolve-Path -LiteralPath $Path).Path
    if ($resolved -match '^([A-Za-z]):\\(.*)$') {
        $drive = $matches[1].ToLowerInvariant()
        $rest = $matches[2] -replace '\\', '/'
        return "/mnt/$drive/$rest"
    }

    return ($resolved -replace '\\', '/')
}

$qilingScriptWsl = Convert-ToWslPath -Path $qilingScriptWin
wsl -d Debian -- bash "$qilingScriptWsl" @RemainingArgs
exit $LASTEXITCODE
