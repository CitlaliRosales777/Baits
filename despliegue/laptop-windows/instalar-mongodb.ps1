$ErrorActionPreference='Stop'
$Repo=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if ($env:COMPUTERNAME -ne 'DESKTOP-0DDRLDI') { throw "Este script es solo para desktop-0ddrldi; equipo actual: $env:COMPUTERNAME" }
$admin=([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if(-not $admin){throw 'Abre PowerShell como administrador.'}
if(-not(Get-Command tailscale -ErrorAction SilentlyContinue)){throw 'Falta Tailscale.'}

winget install --exact --id MongoDB.Server --version 8.0.23 --silent --accept-package-agreements --accept-source-agreements
if($LASTEXITCODE -ne 0){throw 'Falló instalación MongoDB Server'}
winget install --exact --id MongoDB.Shell --silent --accept-package-agreements --accept-source-agreements
if($LASTEXITCODE -ne 0){throw 'Falló instalación mongosh'}

$inbox=Join-Path $env:TEMP 'moodsitto-key-inbox'
New-Item -ItemType Directory -Path $inbox -Force|Out-Null
tailscale file get $inbox
$received=Get-ChildItem $inbox -File | Where-Object Name -eq 'mongodb-keyfile' | Select-Object -First 1
if(-not $received){throw 'No llegó mongodb-keyfile por Tailscale File Transfer.'}

$cfg='C:\Program Files\MongoDB\Server\8.0\bin\mongod.cfg'
$cfgSource=Join-Path $Repo 'mongodb\configuracion\mongod-laptop.cfg'
if(-not(Test-Path "$cfg.pre-moodsitto")){Copy-Item $cfg "$cfg.pre-moodsitto"}
Stop-Service MongoDB -Force
$destDir='C:\ProgramData\Moodsitto'
New-Item -ItemType Directory -Path $destDir -Force|Out-Null
$key=Join-Path $destDir 'mongodb-keyfile'
Copy-Item $received.FullName $key -Force
icacls.exe $key '/inheritance:r'|Out-Null
icacls.exe $key '/grant:r' '*S-1-5-18:F' '*S-1-5-20:R' '*S-1-5-32-544:F'|Out-Null
Copy-Item $cfgSource $cfg -Force
Get-NetFirewallRule -DisplayName 'Moodsitto MongoDB replica set Tailscale' -ErrorAction SilentlyContinue|Remove-NetFirewallRule
New-NetFirewallRule -DisplayName 'Moodsitto MongoDB replica set Tailscale' -Direction Inbound -Action Allow -Protocol TCP -LocalPort 27017 -LocalAddress 100.86.5.50 -RemoteAddress 100.94.145.63,100.89.172.17 -Profile Any|Out-Null
Remove-Item $received.FullName -Force
Start-Service MongoDB
Get-Service MongoDB|Select-Object Name,Status,StartType
Get-NetTCPConnection -State Listen -LocalPort 27017|Select-Object LocalAddress,LocalPort
