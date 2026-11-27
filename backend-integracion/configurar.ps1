# Prepara el .env local del backend con credenciales ingresadas en privado.
$ErrorActionPreference = 'Stop'
$Here = $PSScriptRoot
$Template = Join-Path $Here '.env.example'
$EnvFile = Join-Path $Here '.env'

if (-not (Get-Command tailscale -ErrorAction SilentlyContinue)) {
    throw 'Falta Tailscale. Instálalo, inicia sesión con acceso autorizado y vuelve a ejecutar.'
}
& tailscale status | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Tailscale está instalado pero no está conectado.' }

if (Test-Path $EnvFile) {
    $answer = Read-Host 'Ya existe .env. ¿Crear respaldo y reemplazarlo? (s/N)'
    if ($answer -notmatch '^[sS]$') { Write-Output 'No se modificó .env'; exit 0 }
    Copy-Item $EnvFile "$EnvFile.$(Get-Date -Format yyyyMMddHHmmss).bak"
}

$mariaSecure = Read-Host 'Contraseña de aplicación MariaDB' -AsSecureString
$mongoSecure = Read-Host 'Contraseña de aplicación MongoDB' -AsSecureString
function Reveal([Security.SecureString]$Value) {
    $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Value)
    try { [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr) }
}
$mariaPass = Reveal $mariaSecure
$mongoPass = Reveal $mongoSecure
$content = Get-Content $Template -Raw
$content = $content -replace '(?m)^DB_PASS=.*$', ('DB_PASS=' + $mariaPass)
$content = $content -replace '(?m)^MONGODB_PASSWORD=.*$', ('MONGODB_PASSWORD=' + $mongoPass)
[IO.File]::WriteAllText($EnvFile, $content, [Text.UTF8Encoding]::new($false))
& icacls.exe $EnvFile '/inheritance:r' '/grant:r' "$($env:USERNAME):(R,W)" | Out-Null
$mariaPass = $null; $mongoPass = $null

Write-Output "Configuración creada en $EnvFile"
if (Get-Command php -ErrorAction SilentlyContinue) {
    $modules = & php -m
    if ($modules -contains 'pdo_mysql') { Write-Output '[OK] PHP pdo_mysql disponible' }
    else { Write-Warning 'PHP existe, pero falta pdo_mysql.' }
} else { Write-Warning 'PHP no está en PATH; usa el PHP/Docker del backend.' }
if (-not (Get-Command mariadb -ErrorAction SilentlyContinue)) { Write-Warning 'Falta cliente mariadb para la prueba automática.' }
if (-not (Get-Command mongosh -ErrorAction SilentlyContinue)) { Write-Warning 'Falta mongosh para la prueba automática.' }
Write-Output 'Siguiente paso: .\probar-conexiones.ps1'

