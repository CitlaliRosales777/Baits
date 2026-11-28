[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)
if (-not $admin) { throw 'Abre PowerShell como administrador.' }

$projectPath = Split-Path -Parent $PSScriptRoot
$agentPath = Join-Path $projectPath 'agent\server.js'
$agentEnv = Join-Path $projectPath 'agent\.env'
$nodePath = (Get-Command node.exe -ErrorAction Stop).Source
$npmPath = (Get-Command npm.cmd -ErrorAction Stop).Source

if (-not (Test-Path -LiteralPath $agentPath)) { throw "Falta $agentPath" }
if (-not (Test-Path -LiteralPath $agentEnv)) { throw "Falta $agentEnv" }
if (-not (Get-Service MongoDB -ErrorAction SilentlyContinue)) { throw 'MongoDB no esta instalado como servicio.' }

Push-Location $projectPath
try {
    & $npmPath install --omit=dev
    if ($LASTEXITCODE -ne 0) { throw 'npm install fallo.' }
} finally {
    Pop-Location
}

$taskName = 'MoodsittoLabAgent'
$action = New-ScheduledTaskAction -Execute $nodePath -Argument "`"$agentPath`""
$trigger = New-ScheduledTaskTrigger -AtStartup
$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit ([TimeSpan]::Zero) -RestartCount 10 -RestartInterval (New-TimeSpan -Minutes 1) -StartWhenAvailable
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null

$ruleName = 'Moodsitto Lab Agent - Tailscale only'
Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue | Remove-NetFirewallRule
New-NetFirewallRule -DisplayName $ruleName -Direction Inbound -Action Allow -Protocol TCP -LocalPort 4318 -RemoteAddress '100.86.5.50' -Profile Any | Out-Null

Start-ScheduledTask -TaskName $taskName
Start-Sleep -Seconds 3

$tokenLine = Get-Content -LiteralPath $agentEnv | Where-Object { $_ -like 'LAB_AGENT_TOKEN=*' } | Select-Object -First 1
$token = $tokenLine.Substring('LAB_AGENT_TOKEN='.Length)
$headers = @{ Authorization = "Bearer $token" }
$status = Invoke-RestMethod -Uri 'http://127.0.0.1:4318/status' -Headers $headers

Write-Host 'Agente Moodsitto instalado correctamente.' -ForegroundColor Green
$status | Format-List
