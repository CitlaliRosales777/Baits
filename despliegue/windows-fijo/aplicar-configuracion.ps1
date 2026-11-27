# Aplica los archivos de configuración y las reglas de red del Windows fijo.
$ErrorActionPreference = 'Stop'

$Repo = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$MariaIni = 'C:\Program Files\MariaDB 11.4\data\my.ini'
$MongoCfg = 'C:\Program Files\MongoDB\Server\8.0\bin\mongod.cfg'
$MariaSource = Join-Path $Repo 'mariadb\configuracion\windows-principal.ini'
$MongoSource = Join-Path $Repo 'mongodb\configuracion\mongod-windows-fijo.cfg'
$KeySource = Join-Path $Repo 'secrets\mongodb-keyfile'
$ProtectedDir = 'C:\ProgramData\Moodsitto'
$ProtectedKey = Join-Path $ProtectedDir 'mongodb-keyfile'
$Log = Join-Path $Repo 'secrets\elevated-windows-fixed.log'

function Write-DeployLog([string]$Message) {
    "$(Get-Date -Format o) $Message" | Add-Content -LiteralPath $Log -Encoding UTF8
}

foreach ($Path in @($MariaIni, $MongoCfg, $MariaSource, $MongoSource, $KeySource)) {
    if (-not (Test-Path -LiteralPath $Path)) { throw "Falta archivo requerido: $Path" }
}

$MariaBackup = "$MariaIni.pre-moodsitto"
$MongoBackup = "$MongoCfg.pre-moodsitto"
if (-not (Test-Path -LiteralPath $MariaBackup)) { Copy-Item $MariaIni $MariaBackup }
if (-not (Test-Path -LiteralPath $MongoBackup)) { Copy-Item $MongoCfg $MongoBackup }

try {
    Write-DeployLog 'Inicio de configuración administrativa.'
    Stop-Service MariaDB -Force
    Stop-Service MongoDB -Force

    Copy-Item $MariaSource $MariaIni -Force
    New-Item -ItemType Directory -Path $ProtectedDir -Force | Out-Null
    if (Test-Path -LiteralPath $ProtectedKey) {
        & takeown.exe /F $ProtectedKey /A | Out-Null
        & icacls.exe $ProtectedKey '/grant' '*S-1-5-32-544:F' | Out-Null
        Remove-Item -LiteralPath $ProtectedKey -Force
    }
    Copy-Item $KeySource $ProtectedKey -Force
    & icacls.exe $ProtectedKey '/inheritance:r' | Out-Null
    & icacls.exe $ProtectedKey '/grant:r' '*S-1-5-18:F' '*S-1-5-20:R' '*S-1-5-32-544:F' | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'No fue posible establecer ACL del keyfile.' }
    Copy-Item $MongoSource $MongoCfg -Force

    Get-NetFirewallRule -DisplayName 'Moodsitto MariaDB desde HP Tailscale' -ErrorAction SilentlyContinue |
        Remove-NetFirewallRule
    New-NetFirewallRule -DisplayName 'Moodsitto MariaDB desde HP Tailscale' `
        -Direction Inbound -Action Allow -Protocol TCP -LocalPort 3306 `
        -LocalAddress 100.89.172.17 -RemoteAddress 100.112.196.81 -Profile Any | Out-Null

    Get-NetFirewallRule -DisplayName 'Moodsitto MongoDB replica set Tailscale' -ErrorAction SilentlyContinue |
        Remove-NetFirewallRule
    New-NetFirewallRule -DisplayName 'Moodsitto MongoDB replica set Tailscale' `
        -Direction Inbound -Action Allow -Protocol TCP -LocalPort 27017 `
        -LocalAddress 100.89.172.17 -RemoteAddress 100.94.145.63,100.86.5.50 -Profile Any | Out-Null

    Start-Service MariaDB
    Start-Service MongoDB
    $services = Get-Service MariaDB, MongoDB
    if ($services.Status -contains 'Stopped') { throw 'Uno de los servicios no arrancó.' }
    Write-DeployLog 'Configuración aplicada; ambos servicios activos.'
    exit 0
}
catch {
    Write-DeployLog "ERROR: $($_.Exception.Message). Restaurando configuración previa."
    Stop-Service MariaDB -Force -ErrorAction SilentlyContinue
    Stop-Service MongoDB -Force -ErrorAction SilentlyContinue
    if (Test-Path $MariaBackup) { Copy-Item $MariaBackup $MariaIni -Force }
    if (Test-Path $MongoBackup) { Copy-Item $MongoBackup $MongoCfg -Force }
    Start-Service MariaDB -ErrorAction SilentlyContinue
    Start-Service MongoDB -ErrorAction SilentlyContinue
    throw
}
