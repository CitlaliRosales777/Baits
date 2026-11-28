[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateLength(20, 200)]
    [string]$AgentToken,

    [string]$ProjectPath = (Split-Path -Parent $PSScriptRoot),
    [string]$MongoService = 'MongoDB'
)

$ErrorActionPreference = 'Stop'
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)
if (-not $isAdmin) { throw 'Ejecuta este script desde PowerShell como administrador.' }

$tailscaleService = Get-Service -Name 'Tailscale' -ErrorAction SilentlyContinue
if (-not $tailscaleService) { $tailscaleService = Get-Service | Where-Object DisplayName -Like '*Tailscale*' | Select-Object -First 1 }
if (-not $tailscaleService) { throw 'Tailscale no esta instalado como servicio.' }

Set-Service -Name $tailscaleService.Name -StartupType Automatic
Start-Service -Name $tailscaleService.Name
$tailscaleExe = Get-Command tailscale.exe -ErrorAction SilentlyContinue
if (-not $tailscaleExe) {
    $tailscalePath = (Get-Item 'C:\Program Files\Tailscale\tailscale.exe' -ErrorAction Stop).FullName
} else {
    $tailscalePath = $tailscaleExe.Source
}
& $tailscalePath set --unattended=true
if ($LASTEXITCODE -ne 0) { throw 'No fue posible activar el modo desatendido de Tailscale.' }
Set-Service -Name $MongoService -StartupType Automatic
Start-Service -Name $MongoService

$nodeCommand = Get-Command node.exe -ErrorAction Stop
$agentPath = Join-Path $ProjectPath 'agent\server.js'
$agentEnv = Join-Path $ProjectPath 'agent\.env'
if (-not (Test-Path -LiteralPath $agentPath)) { throw "No se encontro $agentPath" }

@"
AGENT_HOST=0.0.0.0
AGENT_PORT=4318
LAB_AGENT_TOKEN=$AgentToken
MONGODB_SERVICE=$MongoService
"@ | Set-Content -LiteralPath $agentEnv -Encoding utf8

$taskName = 'MoodsittoLabAgent'
$action = New-ScheduledTaskAction -Execute $nodeCommand.Source -Argument "`"$agentPath`""
$trigger = New-ScheduledTaskTrigger -AtStartup
$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit ([TimeSpan]::Zero) -RestartCount 5 -RestartInterval (New-TimeSpan -Minutes 1) -StartWhenAvailable
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null
Start-ScheduledTask -TaskName $taskName

$ruleName = 'Moodsitto Lab Agent - Tailscale only'
Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue | Remove-NetFirewallRule
New-NetFirewallRule -DisplayName $ruleName -Direction Inbound -Action Allow -Protocol TCP -LocalPort 4318 -RemoteAddress '100.64.0.0/10' -Profile Any | Out-Null

Write-Host 'Nodo configurado para reconexion automatica.' -ForegroundColor Green
Write-Host "Tailscale: inicio Automatico y modo desatendido ($($tailscaleService.Name))"
Write-Host "MongoDB: inicio Automatico ($MongoService)"
Write-Host "Agente: tarea $taskName con recuperacion automatica"
Write-Host 'La IP de Tailscale y MagicDNS permanecen estables al cambiar de red.'
