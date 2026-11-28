$ErrorActionPreference = 'Continue'
$names = @('lvltechmx', 'desktop-smecf2n', 'desktop-0ddrldi')

Write-Host '=== Servicios automaticos ===' -ForegroundColor Cyan
Get-Service -Name 'MongoDB' -ErrorAction SilentlyContinue | Select-Object Name, Status, StartType
Get-Service | Where-Object DisplayName -Like '*Tailscale*' | Select-Object Name, Status, StartType

Write-Host '=== MagicDNS ===' -ForegroundColor Cyan
foreach ($name in $names) {
    $resolved = Resolve-DnsName $name -Type A -ErrorAction SilentlyContinue | Where-Object IPAddress -Like '100.*' | Select-Object -First 1
    [pscustomobject]@{ Node = $name; TailscaleIP = $resolved.IPAddress; Resolved = [bool]$resolved }
}

Write-Host '=== Puertos MongoDB ===' -ForegroundColor Cyan
foreach ($name in $names) {
    $result = Test-NetConnection $name -Port 27017 -WarningAction SilentlyContinue
    [pscustomobject]@{ Node = $name; Port = 27017; Reachable = $result.TcpTestSucceeded }
}
