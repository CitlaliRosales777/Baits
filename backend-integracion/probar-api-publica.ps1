$ErrorActionPreference = 'Stop'
$ApiUrl = if ($env:MOODSITTO_API_URL) { $env:MOODSITTO_API_URL.TrimEnd('/') } else { 'https://api.lvltechmx.com' }

$response = Invoke-RestMethod -Uri "$ApiUrl/api/healthcheck" -Method Get -TimeoutSec 15
if ($response.status -ne 'ok') { throw 'La API respondió, pero el estado no fue el esperado.' }

Write-Output '[OK] DNS y conexión a Internet'
Write-Output '[OK] Certificado HTTPS válido'
Write-Output '[OK] API pública de Moodsitto disponible'
Write-Output "URL: $ApiUrl"

