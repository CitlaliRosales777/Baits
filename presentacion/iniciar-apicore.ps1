param(
    [string]$RepoApiCore = (Join-Path ([Environment]::GetFolderPath('Desktop')) 'Baits-demo'),
    [string]$Php = 'C:\xampp\php\php.exe',
    [ValidateRange(1, 65535)][int]$PuertoHttp = 8000,
    [switch]$ProbarProxy
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'accesos-panel.ps1')
$entrada = Join-Path $RepoApiCore 'apicore\api\v1\php\index.php'
if (-not (Test-Path -LiteralPath $entrada)) { throw "No se encuentra APIcore en $RepoApiCore." }
if (-not (Test-Path -LiteralPath $Php)) { throw "No se encuentra PHP en $Php." }
$Php = (Resolve-Path -LiteralPath $Php).Path
$modulos = & $Php -m
if ($LASTEXITCODE -ne 0) { throw 'PHP no pudo cargar sus módulos.' }
foreach ($modulo in 'pdo_mysql', 'mbstring', 'mongodb') {
    if ($modulos -notcontains $modulo) {
        if ($modulo -eq 'mongodb') { throw 'Falta mongodb. Ejecuta instalar-mongodb-php.ps1 desde la carpeta presentacion y vuelve a arrancar APIcore.' }
        throw "Activa $modulo en el php.ini de XAMPP y vuelve a arrancar APIcore."
    }
}

$access = Get-ApiCoreAccess
if (-not $access) { throw 'Primero usa Solicitar accesos y Recibir accesos en la pestaña Inicio local del panel.' }

$rutaProxy = Join-Path $env:LOCALAPPDATA 'Moodsitto\mariadb-proxy.activo'
$usarProxy = $ProbarProxy -or (Test-Path -LiteralPath $rutaProxy -PathType Leaf)

# Los accesos se descifran solo en este usuario de Windows y se pasan a PHP durante la ejecución.
$claves = 'DB_HOST', 'DB_PORT', 'DB_NAME', 'DB_USER', 'DB_PASSWORD', 'JWT_SECRET', 'MOODSITTO_MONGO_URI'
$anteriores = @{}
foreach ($nombre in $claves) {
    $anteriores[$nombre] = [Environment]::GetEnvironmentVariable($nombre, 'Process')
}
Push-Location (Split-Path -Parent $entrada)
try {
    $env:DB_HOST = if ($usarProxy) { '100.94.145.63' } else { '100.89.172.17' }
    $env:DB_PORT = if ($usarProxy) { '4006' } else { '3306' }
    $env:DB_NAME = 'apicore'
    $env:DB_USER = 'apicore_app'
    $env:DB_PASSWORD = $access.Maria.GetNetworkCredential().Password
    $mongoTexto = $access.Mongo.GetNetworkCredential().Password
    $mongoCodificada = [uri]::EscapeDataString($mongoTexto)
    $env:MOODSITTO_MONGO_URI = "mongodb://apicore_emociones:${mongoCodificada}@100.94.145.63:27017,100.89.172.17:27017,100.86.5.50:27017/moodsitto?authSource=moodsitto&replicaSet=rsMoodsitto"
    Remove-Variable mongoTexto, mongoCodificada
    $env:JWT_SECRET = & $Php -r 'echo bin2hex(random_bytes(32));'
    if ($LASTEXITCODE -ne 0 -or $env:JWT_SECRET -notmatch '^[0-9a-f]{64}$') { throw 'PHP no pudo generar la clave de sesión.' }
    if ($PuertoHttp -eq 8000) {
        # Identifica el lanzador y su destino SQL para las comprobaciones del panel.
        $routePath = Join-Path $env:LOCALAPPDATA 'Moodsitto\apicore-ruta-8000.json'
        try {
            @{
                LauncherId = $PID
                StartedUtcTicks = (Get-Process -Id $PID).StartTime.ToUniversalTime().Ticks
                MariaHost = $env:DB_HOST
                MariaPort = [int]$env:DB_PORT
            } | ConvertTo-Json -Compress | Set-Content -LiteralPath $routePath -Encoding UTF8
        } catch {
            Write-Warning 'No se pudo registrar la ruta de esta instancia para el panel.'
        }
    }
    Write-Host "APIcore usará MariaDB en $($env:DB_HOST):$($env:DB_PORT)."
    & $Php -S "localhost:$PuertoHttp" index.php
    if ($LASTEXITCODE -ne 0) { throw 'APIcore no pudo mantener abierto el servidor local.' }
} finally {
    foreach ($nombre in $claves) {
        [Environment]::SetEnvironmentVariable($nombre, $anteriores[$nombre], 'Process')
    }
    Pop-Location
}
