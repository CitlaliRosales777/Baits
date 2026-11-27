# Revisa conectividad y ejecuta las pruebas autenticadas si hay un .env local.
$ErrorActionPreference = 'Stop'
$Repo = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Write-Output '=== MOODSITTO PREFLIGHT ==='
& (Join-Path $Repo 'monitoreo\scripts\estado-general.ps1')
if (Test-Path (Join-Path $Repo 'backend-integracion\.env')) {
    & (Join-Path $Repo 'backend-integracion\probar-conexiones.ps1')
} else {
    Write-Warning 'Falta backend-integracion\.env local; no se ejecutaron pruebas autenticadas.'
}
Write-Output 'Verifica visualmente que todos los resultados obligatorios estén OK antes de presentar.'

