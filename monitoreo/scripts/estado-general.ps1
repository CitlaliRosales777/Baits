# Resume el estado de los cuatro equipos y sus puertos privados.
$ErrorActionPreference = 'Continue'
$nodes = @(
    @{ Name='Windows fijo'; Host='100.89.172.17'; Ports=@(3306,27017) },
    @{ Name='Laptop'; Host='100.86.5.50'; Ports=@(27017) },
    @{ Name='VPS'; Host='100.94.145.63'; Ports=@(22,27017) },
    @{ Name='HP'; Host='100.112.196.81'; Ports=@(22,3306) }
)
function Tcp([string]$HostName,[int]$Port) {
    $c=[Net.Sockets.TcpClient]::new()
    try { $a=$c.ConnectAsync($HostName,$Port); return $a.Wait(2500)-and$c.Connected }
    catch { return $false }
    finally { $c.Dispose() }
}
$results = foreach($node in $nodes) {
    $ping=Test-Connection -TargetName $node.Host -Count 1 -Quiet -TimeoutSeconds 2
    [pscustomobject]@{Nodo=$node.Name;IP=$node.Host;Prueba='Tailscale';Estado=if($ping){'OK'}else{'FALLO'}}
    foreach($port in $node.Ports) {
        [pscustomobject]@{Nodo=$node.Name;IP=$node.Host;Prueba="TCP/$port";Estado=if(Tcp $node.Host $port){'OK'}else{'FALLO'}}
    }
}
$results | Format-Table -AutoSize

Write-Output 'Para autenticación y pruebas de lectura/escritura ejecuta backend-integracion\probar-conexiones.ps1.'

