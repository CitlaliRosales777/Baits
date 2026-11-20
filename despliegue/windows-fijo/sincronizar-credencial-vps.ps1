$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$rootSecret = Join-Path $repo 'secrets\windows-fixed.env'
$maria = 'C:\Program Files\MariaDB 11.4\bin\mariadb.exe'

if (-not (Test-Path $rootSecret)) { throw 'Falta el archivo local de credenciales MariaDB.' }
if (-not (Test-Path $maria)) { throw 'No se encontró el cliente MariaDB.' }

$rootLine = Get-Content -LiteralPath $rootSecret |
    Where-Object { $_ -match '^MARIADB_ROOT_PASSWORD=' } |
    Select-Object -First 1
if (-not $rootLine) { throw 'Falta la contraseña root de MariaDB.' }
$rootPassword = $rootLine.Substring($rootLine.IndexOf('=') + 1)

[string]$remoteLine = & ssh -o BatchMode=yes -o ConnectTimeout=7 root@100.94.145.63 'cat /opt/moodsitto-api/.env'
if ($LASTEXITCODE -ne 0 -or $remoteLine -notmatch '^DB_PASS=([0-9a-f]{64})$') {
    throw 'No se pudo leer la credencial protegida del VPS.'
}
$apiPassword = $matches[1]

$env:MYSQL_PWD = $rootPassword
try {
    $sql = "ALTER USER 'moodsitto_api'@'100.94.145.63' IDENTIFIED BY '$apiPassword'; GRANT SELECT, INSERT, UPDATE, DELETE ON moodsitto.* TO 'moodsitto_api'@'100.94.145.63'; FLUSH PRIVILEGES;"
    & $maria -h 127.0.0.1 -u root -e $sql
    if ($LASTEXITCODE -ne 0) { throw 'MariaDB rechazó la actualización del usuario API.' }
} finally {
    Remove-Item Env:MYSQL_PWD -ErrorAction SilentlyContinue
    $rootPassword = $null
    $apiPassword = $null
    $remoteLine = $null
}

Write-Output 'Credencial del backend sincronizada sin mostrar su valor.'

