#requires -RunAsAdministrator
$ErrorActionPreference = 'Stop'
$name = 'Moodsitto MariaDB desde VPS backend'

Get-NetFirewallRule -DisplayName $name -ErrorAction SilentlyContinue | Remove-NetFirewallRule
New-NetFirewallRule `
    -DisplayName $name `
    -Direction Inbound `
    -Action Allow `
    -Protocol TCP `
    -LocalPort 3306 `
    -LocalAddress 100.89.172.17 `
    -RemoteAddress 100.94.145.63 `
    -Profile Any | Out-Null

$rule = Get-NetFirewallRule -DisplayName $name
$address = $rule | Get-NetFirewallAddressFilter
if ($rule.Enabled -ne 'True' -or $address.RemoteAddress -notcontains '100.94.145.63') {
    throw 'La regla no quedó configurada como se esperaba.'
}

Write-Output 'VPS autorizado para MariaDB únicamente por Tailscale.'

