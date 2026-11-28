[CmdletBinding()]
param([Parameter(Mandatory)][switch]$Aplicar)

$ErrorActionPreference = 'Stop'
if (-not $Aplicar -or $env:COMPUTERNAME -ne 'DESKTOP-SMECF2N') {
    throw 'Este procedimiento se aplica únicamente al Windows fijo.'
}

function Get-MariaHandshakeVersion {
    $tcp = [Net.Sockets.TcpClient]::new()
    try {
        $tcp.Connect('127.0.0.1', 3306)
        $tcp.ReceiveTimeout = 3000
        $reader = [IO.BinaryReader]::new($tcp.GetStream())
        $header = $reader.ReadBytes(4)
        if ($header.Length -ne 4) { throw 'Cabecera de MariaDB incompleta.' }
        $size = [int]$header[0] + 256 * [int]$header[1] + 65536 * [int]$header[2]
        if ($size -lt 3 -or $size -gt 4096) { throw 'Paquete de presentación MariaDB inesperado.' }
        $packet = $reader.ReadBytes($size)
        if ($packet[0] -ne 10) { throw 'El puerto local no presentó el protocolo esperado de MariaDB.' }
        $end = [Array]::IndexOf($packet, [byte]0, 1)
        if ($end -le 1) { throw 'La versión de MariaDB no está disponible.' }
        [Text.Encoding]::ASCII.GetString($packet, 1, $end - 1)
    } finally { $tcp.Dispose() }
}

function Wait-MariaService {
    param([System.ServiceProcess.ServiceControllerStatus]$Status)
    (Get-Service -Name MariaDB).WaitForStatus($Status, [TimeSpan]::FromSeconds(45))
}

$oldRoot = 'C:\Program Files\MariaDB 11.4'
$data = Join-Path $oldRoot 'data'
$ini = Join-Path $data 'my.ini'
$official = 'C:\Program Files\MariaDB 11.8.6 Moodsitto\mariadb-11.8.6-winx64\bin'
$upgrader = Join-Path $official 'mysql_upgrade_service.exe'
$executable = Join-Path $official 'mariadbd.exe'
$service = Get-CimInstance Win32_Service -Filter "Name='MariaDB'"
if ($service.State -ne 'Running' -or $service.PathName -notmatch 'MariaDB 11\.4.*my\.ini' -or
    (Resolve-Path -LiteralPath $data).Path -ine $data -or
    -not (Test-Path -LiteralPath $ini -PathType Leaf) -or
    -not (Test-Path -LiteralPath $upgrader -PathType Leaf) -or
    -not (Test-Path -LiteralPath $executable -PathType Leaf)) {
    throw 'El servicio, los datos o el paquete preparado no coinciden con el entorno verificado.'
}
if ((Get-Item -LiteralPath $data).Attributes -band [IO.FileAttributes]::ReparsePoint) {
    throw 'El directorio de datos es un punto de reanálisis. Revisa su destino antes de copiarlo.'
}
$check = & $executable --version
if ($LASTEXITCODE -ne 0 -or $check -notmatch '\b11\.8\.6-MariaDB\b') {
    throw 'La versión del paquete preparado no coincide con la del HP.'
}
$before = Get-MariaHandshakeVersion
if ($before -notmatch '\b11\.4\.3-MariaDB\b') {
    throw "Versión de origen inesperada: $before"
}
$oldImage = $service.PathName
$stamp = (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [Guid]::NewGuid().ToString('N').Substring(0, 6)
$snapshot = Join-Path $oldRoot "data-antes-11.8-$stamp"
$failedData = Join-Path $oldRoot "data-11.8-retenida-$stamp"
$fence = "Moodsitto-MariaDB-Mantenimiento-$stamp"
$blocked = $false
$stopping = $false
$modifying = $false
$recovered = $false
try {
    New-NetFirewallRule -Name $fence -DisplayName $fence -Direction Inbound -Action Block -Protocol TCP -LocalPort 3306 -LocalAddress '100.89.172.17' -Profile Any | Out-Null
    $blocked = $true
    if (-not (Get-NetFirewallRule -Name $fence -PolicyStore ActiveStore -ErrorAction SilentlyContinue)) {
        throw 'No se pudo aplicar el aislamiento temporal de MariaDB en el firewall.'
    }
    $stopping = $true
    Stop-Service -Name MariaDB
    Wait-MariaService Stopped
    [void][IO.Directory]::CreateDirectory($snapshot)
    Set-Acl -LiteralPath $snapshot -AclObject (Get-Acl -LiteralPath $data)
    & robocopy.exe $data $snapshot /E /COPY:DATS /DCOPY:DAT /XJ /R:1 /W:1 /NFL /NDL /NJH /NJS /NP | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "Falló la copia en frío. Robocopy: $LASTEXITCODE." }
    & robocopy.exe $data $snapshot /L /E /COPY:DATS /DCOPY:DAT /XJ /R:1 /W:1 /NFL /NDL /NJH /NJS /NP | Out-Null
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath (Join-Path $snapshot 'my.ini') -PathType Leaf)) {
        throw 'La verificación de la copia en frío no coincidió con el origen.'
    }
    Write-Output "COPIA_EN_FRIO=$snapshot"

    $modifying = $true
    & $upgrader --service=MariaDB
    if ($LASTEXITCODE -ne 0) { throw "La utilidad oficial terminó con código $LASTEXITCODE." }
    if ((Get-Service MariaDB).Status -eq 'Stopped') { Start-Service MariaDB }
    Wait-MariaService Running
    $after = Get-MariaHandshakeVersion
    if ($after -notmatch '\b11\.8\.6-MariaDB\b') { throw "MariaDB inició con una versión inesperada: $after" }
    $updated = Get-CimInstance Win32_Service -Filter "Name='MariaDB'"
    if ($updated.PathName -notmatch 'MariaDB 11\.8\.6 Moodsitto') {
        throw 'El servicio no quedó configurado para iniciar la versión actualizada.'
    }
    $recovered = $true
    Write-Output "VERSION_LOCAL=$after"
} catch {
    $problem = $_
    if ($modifying) {
        if ((Get-Service MariaDB).Status -ne 'Stopped') { Stop-Service MariaDB }
        Wait-MariaService Stopped
        if ((Resolve-Path -LiteralPath $data).Path -ine $data -or
            (Resolve-Path -LiteralPath $snapshot).Path -ine $snapshot -or
            (Test-Path -LiteralPath $failedData)) {
            throw 'No se cumplieron las condiciones de la reversión. El acceso remoto a MariaDB permanece bloqueado.'
        }
        $activeService = Get-CimInstance Win32_Service -Filter "Name='MariaDB'"
        $restore = Invoke-CimMethod -InputObject $activeService -MethodName Change -Arguments @{ PathName = $oldImage }
        if ($restore.ReturnValue -ne 0) { throw "No se pudo restaurar la ruta del servicio: $($restore.ReturnValue)." }
        [IO.Directory]::Move($data, $failedData)
        [IO.Directory]::Move($snapshot, $data)
    }
    if ($stopping) {
        if ((Get-Service MariaDB).Status -eq 'Stopped') { Start-Service MariaDB }
        Wait-MariaService Running
        if ((Get-MariaHandshakeVersion) -notmatch '\b11\.4\.3-MariaDB\b') {
            throw 'La versión original no se pudo verificar después de la reversión.'
        }
    }
    $recovered = $true
    throw $problem
} finally {
    if ($blocked -and ($recovered -or -not $stopping)) {
        Remove-NetFirewallRule -Name $fence
    }
}
