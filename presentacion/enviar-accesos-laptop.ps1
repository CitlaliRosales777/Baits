param([Parameter(Mandatory)][ValidatePattern('^[0-9a-f]{32}$')][string]$Codigo)

$ErrorActionPreference = 'Stop'
if ($env:COMPUTERNAME -ine 'DESKTOP-SMECF2N') { throw 'Envía los accesos desde el Windows fijo.' }
. (Join-Path $PSScriptRoot 'accesos-panel.ps1')
$api = Get-ApiCoreAccess
if (-not $api) { throw 'El Windows fijo no tiene guardados los accesos de APIcore.' }

$application = @{}
$envPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'backend-integracion\.env'
foreach ($line in (Get-Content -LiteralPath $envPath)) {
    if ($line -match '^(DB_USER|DB_PASS|MONGODB_USER|MONGODB_PASSWORD)=(.*)$') { $application[$Matches[1]] = $Matches[2] }
}
if ($application.DB_USER -ne 'moodsitto_app' -or $application.MONGODB_USER -ne 'moodsitto_app') {
    throw 'La configuración local debe usar las cuentas de aplicación del panel.'
}
$access = @{
    apicoreMaria = $api.Maria
    apicoreMongo = $api.Mongo
    panelMaria = [pscredential]::new('moodsitto_app', (ConvertTo-SecureString $application.DB_PASS -AsPlainText -Force))
    panelMongo = [pscredential]::new('moodsitto_app', (ConvertTo-SecureString $application.MONGODB_PASSWORD -AsPlainText -Force))
}
$inbox = Get-AccessInbox
& tailscale file get $inbox | Out-Null
$request = Join-Path $inbox "moodsitto-solicitud-$Codigo.json"
if (-not (Test-Path -LiteralPath $request)) { throw 'La solicitud de esa laptop aún no llegó al Windows fijo.' }
$package = Join-Path $inbox "moodsitto-accesos-$Codigo.json"
try {
    New-PresentationPackage $request $Codigo $access | Set-Content -LiteralPath $package -Encoding UTF8
    & tailscale file cp $package '100.86.5.50:' | Out-Null
    if ($LASTEXITCODE) { throw 'Tailscale no confirmó el envío a la laptop.' }
    Remove-Item -LiteralPath $request
    Write-Output 'Paquete cifrado enviado. Pulsa Recibir accesos en la laptop.'
} finally {
    if (Test-Path -LiteralPath $package) { Remove-Item -LiteralPath $package }
}
