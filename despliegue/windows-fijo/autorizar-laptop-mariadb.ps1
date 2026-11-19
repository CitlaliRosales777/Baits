$ErrorActionPreference = 'Stop'
$name = 'Moodsitto MariaDB desde HP Tailscale'
Get-NetFirewallRule -DisplayName $name -ErrorAction SilentlyContinue | Remove-NetFirewallRule
New-NetFirewallRule -DisplayName $name -Direction Inbound -Action Allow -Protocol TCP `
    -LocalPort 3306 -LocalAddress 100.89.172.17 `
    -RemoteAddress 100.112.196.81,100.86.5.50 -Profile Any | Out-Null
Write-Output 'Firewall MariaDB limitado a HP y laptop.'
