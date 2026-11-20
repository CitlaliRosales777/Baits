#requires -RunAsAdministrator
$ErrorActionPreference = 'Stop'

$tailscaleIp = (& tailscale ip -4 | Select-Object -First 1).Trim()
if ($tailscaleIp -ne '100.89.172.17') {
    throw "La dirección Tailscale esperada no está disponible: $tailscaleIp"
}

Restart-Service MariaDB
$service = Get-Service MariaDB
$service.WaitForStatus('Running', [TimeSpan]::FromSeconds(30))

$listening = Get-NetTCPConnection -LocalPort 3306 -State Listen -ErrorAction SilentlyContinue |
    Where-Object LocalAddress -eq '100.89.172.17'
if (-not $listening) {
    throw 'MariaDB inició, pero no quedó escuchando en la dirección Tailscale.'
}

Write-Output 'MariaDB volvió a escuchar por localhost y Tailscale.'

