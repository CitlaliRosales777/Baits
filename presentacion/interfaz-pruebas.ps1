param(
    [switch]$SelfTest,
    [switch]$UiSmokeTest
)

$ErrorActionPreference = 'Stop'
$script:Repo = Split-Path -Parent $PSScriptRoot
$script:Config = @{
    MariaHost = '100.89.172.17'
    MariaReplicaHost = '100.112.196.81'
    MariaPort = 3306
    MariaDatabase = 'moodsitto'
    MariaUser = 'moodsitto_app'
    MariaPassword = ''
    MongoHosts = '100.94.145.63:27017,100.89.172.17:27017,100.86.5.50:27017'
    MongoDatabase = 'moodsitto'
    MongoReplicaSet = 'rsMoodsitto'
    MongoUser = 'moodsitto_app'
    MongoPassword = ''
    MongoAuthSource = 'moodsitto'
    HpSsh = 'fredy@100.112.196.81'
    VpsSsh = 'root@100.94.145.63'
}
$script:LogBox = $null
$script:Grid = $null
$script:SummaryLabel = $null
$script:Running = $false

function New-Result {
    param(
        [ValidateSet('APROBADO','PENDIENTE','BLOQUEADO')][string]$Status,
        [string]$Summary,
        [string]$Details = ''
    )
    [pscustomobject]@{ Status = $Status; Summary = $Summary; Details = $Details }
}

function Write-Log {
    param([string]$Text, [string]$Level = 'INFO')
    $line = "[{0:HH:mm:ss}] [{1}] {2}" -f (Get-Date), $Level, $Text
    if ($script:LogBox) {
        $script:LogBox.AppendText($line + [Environment]::NewLine)
        $script:LogBox.SelectionStart = $script:LogBox.TextLength
        $script:LogBox.ScrollToCaret()
        [System.Windows.Forms.Application]::DoEvents()
    } else {
        Write-Output $line
    }
}

function Require-Tool {
    param([string]$Name, [string]$Help)
    $tool = Get-Command $Name -ErrorAction SilentlyContinue
    if (-not $tool) { throw "[BLOQUEADO] Falta $Name. $Help" }
    $tool.Source
}

function Require-Credentials {
    param([ValidateSet('MariaDB','MongoDB')][string]$Engine)
    if ($Engine -eq 'MariaDB' -and [string]::IsNullOrWhiteSpace($script:Config.MariaPassword)) {
        throw '[BLOQUEADO] Escribe la contraseña de aplicación de MariaDB o carga backend-integracion\.env.'
    }
    if ($Engine -eq 'MongoDB' -and [string]::IsNullOrWhiteSpace($script:Config.MongoPassword)) {
        throw '[BLOQUEADO] Escribe la contraseña de aplicación de MongoDB o carga backend-integracion\.env.'
    }
}

function Test-TcpPort {
    param([string]$HostName, [int]$Port, [int]$TimeoutMs = 3500)
    $client = [Net.Sockets.TcpClient]::new()
    try {
        $task = $client.ConnectAsync($HostName, $Port)
        return $task.Wait($TimeoutMs) -and $client.Connected
    } catch {
        return $false
    } finally {
        $client.Dispose()
    }
}

function Invoke-MariaQuery {
    param(
        [string]$HostName,
        [string]$Sql,
        [string]$Database = $script:Config.MariaDatabase,
        [switch]$AllowFailure
    )
    Require-Credentials MariaDB
    $client = Require-Tool 'mariadb' 'Instala únicamente el cliente de MariaDB.'
    $oldPassword = $env:MYSQL_PWD
    try {
        $env:MYSQL_PWD = $script:Config.MariaPassword
        $args = @('--connect-timeout=6','--batch','--skip-column-names','-h', $HostName, '-P', "$($script:Config.MariaPort)", '-u', $script:Config.MariaUser)
        if ($Database) { $args += @('-D', $Database) }
        $args += @('-e', $Sql)
        $output = & $client @args 2>&1
        $code = $LASTEXITCODE
        if ($code -ne 0 -and -not $AllowFailure) { throw ($output -join [Environment]::NewLine) }
        [pscustomobject]@{ Code = $code; Output = ($output -join [Environment]::NewLine).Trim() }
    } finally {
        if ($null -eq $oldPassword) { Remove-Item Env:MYSQL_PWD -ErrorAction SilentlyContinue }
        else { $env:MYSQL_PWD = $oldPassword }
    }
}

function Get-MongoUri {
    param([string]$Hosts = $script:Config.MongoHosts, [switch]$Direct)
    $options = "authSource=$($script:Config.MongoAuthSource)&serverSelectionTimeoutMS=7000"
    if ($Direct) { $options += '&directConnection=true' }
    else { $options += "&replicaSet=$($script:Config.MongoReplicaSet)&retryWrites=true&w=majority" }
    "mongodb://${Hosts}/$($script:Config.MongoDatabase)?${options}"
}

function Invoke-MongoEval {
    param([string]$JavaScript, [string]$Uri = (Get-MongoUri), [switch]$AllowFailure)
    Require-Credentials MongoDB
    $mongosh = Require-Tool 'mongosh' 'Instala MongoDB Shell; no hace falta instalar otro servidor.'
    $output = & $mongosh --quiet $Uri -u $script:Config.MongoUser -p $script:Config.MongoPassword --eval $JavaScript 2>&1
    $code = $LASTEXITCODE
    if ($code -ne 0 -and -not $AllowFailure) { throw ($output -join [Environment]::NewLine) }
    [pscustomobject]@{ Code = $code; Output = ($output -join [Environment]::NewLine).Trim() }
}

function Invoke-SshCommand {
    param([string]$Target, [string]$Command, [switch]$AllowFailure)
    $ssh = Require-Tool 'ssh' 'Activa el cliente OpenSSH de Windows.'
    $output = & $ssh -o BatchMode=yes -o ConnectTimeout=7 -o ServerAliveInterval=3 $Target $Command 2>&1
    $code = $LASTEXITCODE
    if ($code -ne 0 -and -not $AllowFailure) { throw ($output -join [Environment]::NewLine) }
    [pscustomobject]@{ Code = $code; Output = ($output -join [Environment]::NewLine).Trim() }
}

function Invoke-RemoteScript {
    param([string]$Target, [string]$LocalScript, [string]$RemoteArgument, [switch]$UseSudo, [string]$RemoteSetup = '')
    $ssh = Require-Tool 'ssh' 'Activa el cliente OpenSSH de Windows.'
    $runner = if ($UseSudo) { "sudo -n bash -s -- '$RemoteArgument'" } else { "bash -s -- '$RemoteArgument'" }
    $remote = if ($RemoteSetup) { "$RemoteSetup; $runner" } else { $runner }
    $content = Get-Content -Raw -LiteralPath $LocalScript
    $output = $content | & $ssh -o BatchMode=yes -o ConnectTimeout=7 $Target $remote 2>&1
    $code = $LASTEXITCODE
    if ($code -ne 0) { throw ($output -join [Environment]::NewLine) }
    ($output -join [Environment]::NewLine).Trim()
}

function Test-Repository {
    $scriptPath = Join-Path $script:Repo 'tests\validar-repositorio.ps1'
    $output = & $scriptPath 2>&1
    New-Result APROBADO 'El repositorio, el esquema de 23 tablas y la exclusión de secretos pasaron la revisión.' ($output -join [Environment]::NewLine)
}

function Test-Connectivity {
    $nodes = @(
        @{ Name='Windows fijo'; Host='100.89.172.17'; Ports=@(3306,27017) },
        @{ Name='Laptop'; Host='100.86.5.50'; Ports=@(27017) },
        @{ Name='VPS'; Host='100.94.145.63'; Ports=@(22,27017) },
        @{ Name='HP'; Host='100.112.196.81'; Ports=@(22,3306) }
    )
    $lines = [Collections.Generic.List[string]]::new()
    $failed = 0
    foreach ($node in $nodes) {
        $ping = Test-Connection -ComputerName $node.Host -Count 1 -Quiet -ErrorAction SilentlyContinue
        $lines.Add("$($node.Name): Tailscale/ping=" + $(if ($ping) {'OK'} else {'sin respuesta ICMP'}))
        foreach ($port in $node.Ports) {
            $ok = Test-TcpPort $node.Host $port
            $lines.Add("$($node.Name): TCP/$port=" + $(if ($ok) {'OK'} else {'FALLO'}))
            if (-not $ok) { $failed++ }
        }
    }
    if ($failed -gt 0) { return New-Result PENDIENTE "$failed puertos necesarios no respondieron." ($lines -join [Environment]::NewLine) }
    New-Result APROBADO 'Los cuatro equipos y sus puertos necesarios están accesibles por la red privada.' ($lines -join [Environment]::NewLine)
}

function Test-Inventory {
    $details = [Collections.Generic.List[string]]::new()
    $details.Add("Laptop: $env:COMPUTERNAME | RAM $([math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory/1GB,1)) GiB | Windows $([Environment]::OSVersion.Version)")
    $hp = Invoke-SshCommand $script:Config.HpSsh "printf 'HP: '; hostname; free -h | sed -n '2p'; df -h / /srv/storage | tail -n +2; systemctl list-units --type=service --all 'actions.runner*' --no-legend"
    $vps = Invoke-SshCommand $script:Config.VpsSsh "printf 'VPS: '; hostname; free -h | sed -n '2p'; df -h / | tail -n 1; systemctl is-active mongod"
    $details.Add($hp.Output)
    $details.Add($vps.Output)
    New-Result APROBADO 'Se consultaron recursos reales de la laptop, HP y VPS; el Windows fijo se comprueba mediante sus dos motores.' ($details -join [Environment]::NewLine)
}

function Test-MariaPrimary {
    $sql = "SELECT CONCAT(@@hostname,'|',@@version,'|server_id=',@@server_id,'|read_only=',@@read_only); SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='moodsitto'; SHOW MASTER STATUS;"
    $result = Invoke-MariaQuery $script:Config.MariaHost $sql
    $lines = $result.Output -split "`r?`n"
    if ($result.Output -notmatch 'read_only=0') { return New-Result PENDIENTE 'El principal de MariaDB aparece en modo de solo lectura.' $result.Output }
    if ($lines -notcontains '23') { return New-Result PENDIENTE 'El esquema activo no tiene las 23 tablas esperadas.' $result.Output }
    New-Result APROBADO 'MariaDB principal acepta escritura, tiene server_id y conserva las 23 tablas del esquema híbrido.' $result.Output
}

function Test-MariaReplica {
    $sql = "SELECT CONCAT(@@hostname,'|',@@version,'|server_id=',@@server_id,'|read_only=',@@read_only); SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='moodsitto'; SHOW ALL SLAVES STATUS;"
    $result = Invoke-MariaQuery $script:Config.MariaReplicaHost $sql -AllowFailure
    if ($result.Code -ne 0) {
        $fallback = Invoke-MariaQuery $script:Config.MariaReplicaHost "SELECT CONCAT(@@hostname,'|',@@version,'|server_id=',@@server_id,'|read_only=',@@read_only); SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='moodsitto';"
        if ($fallback.Output -notmatch 'read_only=1') { return New-Result PENDIENTE 'La réplica responde, pero no está protegida con read_only.' $fallback.Output }
        return New-Result APROBADO 'La réplica tiene 23 tablas y está protegida contra escrituras. El usuario de aplicación no puede ver el estado administrativo, como se esperaba.' $fallback.Output
    }
    $healthy = $result.Output -match '(Yes\s+Yes|Slave_IO_Running[^\r\n]*Yes)' -and $result.Output -notmatch 'read_only=0'
    if (-not $healthy) { return New-Result PENDIENTE 'La réplica respondió, pero su estado no coincide con la configuración esperada.' $result.Output }
    New-Result APROBADO 'La réplica está en solo lectura y los hilos de replicación están activos.' $result.Output
}

function Test-MariaReplication {
    $id = [Guid]::NewGuid().ToString()
    $inserted = $false
    try {
        Invoke-MariaQuery $script:Config.MariaHost "INSERT INTO auditoria_eventos(actor_id_user,accion,recurso,resultado,correlacion_id) VALUES(NULL,'prueba_interfaz','presentacion','ok','$id');" | Out-Null
        $inserted = $true
        $count = '0'
        for ($i=0; $i -lt 12; $i++) {
            Start-Sleep -Milliseconds 750
            $count = (Invoke-MariaQuery $script:Config.MariaReplicaHost "SELECT COUNT(*) FROM auditoria_eventos WHERE correlacion_id='$id';").Output.Trim()
            if ($count -eq '1') { break }
        }
        if ($count -ne '1') { return New-Result PENDIENTE 'El registro de prueba no llegó a la réplica dentro del tiempo esperado.' "correlacion_id=$id; conteo=$count" }
        $writeAttempt = Invoke-MariaQuery $script:Config.MariaReplicaHost "INSERT INTO auditoria_eventos(actor_id_user,accion,recurso,resultado,correlacion_id) VALUES(NULL,'no_debe_escribir','replica','error','$(New-Guid)');" -AllowFailure
        if ($writeAttempt.Code -eq 0) { return New-Result PENDIENTE 'La réplica permitió una escritura directa y debe revisarse read_only.' $writeAttempt.Output }
        New-Result APROBADO 'El registro sintético llegó del principal a la HP y la réplica rechazó una escritura directa.' "correlacion_id=$id; réplica=1; escritura directa=rechazada"
    } finally {
        if ($inserted) {
            Invoke-MariaQuery $script:Config.MariaHost "DELETE FROM auditoria_eventos WHERE correlacion_id='$id';" -AllowFailure | Out-Null
        }
    }
}

function Test-MongoTopology {
    $details = [Collections.Generic.List[string]]::new()
    $expected = @(
        @{ Host='100.94.145.63:27017'; Role='PRIMARY' },
        @{ Host='100.89.172.17:27017'; Role='SECONDARY' },
        @{ Host='100.86.5.50:27017'; Role='SECONDARY' }
    )
    $failed = 0
    foreach ($node in $expected) {
        $js = 'const h=db.hello(); print(JSON.stringify({me:h.me,setName:h.setName,primary:h.primary,isWritablePrimary:h.isWritablePrimary,secondary:h.secondary,ok:h.ok}))'
        $result = Invoke-MongoEval $js (Get-MongoUri $node.Host -Direct) -AllowFailure
        $details.Add("$($node.Host): $($result.Output)")
        if ($result.Code -ne 0 -or $result.Output -notmatch '"setName":"rsMoodsitto"') { $failed++; continue }
        if ($node.Role -eq 'PRIMARY' -and $result.Output -notmatch '"isWritablePrimary":true') { $failed++ }
        if ($node.Role -eq 'SECONDARY' -and $result.Output -notmatch '"secondary":true') { $failed++ }
    }
    if ($failed -gt 0) { return New-Result PENDIENTE 'Uno o más miembros de MongoDB no tienen el rol esperado.' ($details -join [Environment]::NewLine) }
    New-Result APROBADO 'El VPS es PRIMARY y los dos equipos Windows son SECONDARY dentro de rsMoodsitto.' ($details -join [Environment]::NewLine)
}

function Test-MongoReplication {
    $id = [Guid]::NewGuid().ToString()
    $uri = Get-MongoUri
    try {
        $insert = "db.auditoria_documental.insertOne({actor_id_user:null,accion:'prueba_interfaz',recurso:'presentacion',recurso_id:null,resultado:'ok',correlacion_id:'$id',metadata_segura:{datos:'sinteticos'},created_at:new Date()},{writeConcern:{w:'majority',wtimeout:10000}}); print('INSERTADO')"
        $write = Invoke-MongoEval $insert $uri
        if ($write.Output -notmatch 'INSERTADO') { throw $write.Output }
        $details = [Collections.Generic.List[string]]::new()
        foreach ($hostName in @('100.89.172.17:27017','100.86.5.50:27017')) {
            $count = '0'
            for ($i=0; $i -lt 10; $i++) {
                Start-Sleep -Milliseconds 600
                $read = Invoke-MongoEval "print(db.auditoria_documental.countDocuments({correlacion_id:'$id'}))" (Get-MongoUri $hostName -Direct) -AllowFailure
                if ($read.Code -eq 0) { $count = $read.Output.Trim() }
                if ($count -eq '1') { break }
            }
            $details.Add("${hostName}: $count documento(s)")
            if ($count -ne '1') { return New-Result PENDIENTE 'El documento no apareció en los dos secundarios.' ($details -join [Environment]::NewLine) }
        }
        New-Result APROBADO 'La escritura con mayoría se pudo leer directamente desde los dos secundarios.' ($details -join [Environment]::NewLine)
    } finally {
        Invoke-MongoEval "db.auditoria_documental.deleteOne({correlacion_id:'$id'},{writeConcern:{w:'majority',wtimeout:10000}})" $uri -AllowFailure | Out-Null
    }
}

function Test-HybridModel {
    $maria = Invoke-MariaQuery $script:Config.MariaHost "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='moodsitto'; SELECT COUNT(*) FROM information_schema.statistics WHERE table_schema='moodsitto'; SELECT COUNT(*) FROM information_schema.referential_constraints WHERE constraint_schema='moodsitto';"
    $mongoJs = 'const names=["catalogo_emociones","registros_emocionales","resumenes_emocionales","auditoria_documental"]; const info=db.getCollectionInfos({name:{$in:names}}); print(JSON.stringify({colecciones:info.map(x=>x.name).sort(),validadores:info.filter(x=>x.options&&x.options.validator).length,indices:names.reduce((n,x)=>n+db.getCollection(x).getIndexes().length,0)}))'
    $mongo = Invoke-MongoEval $mongoJs
    if (($maria.Output -split "`r?`n")[0] -ne '23') { return New-Result PENDIENTE 'MariaDB no tiene las 23 tablas esperadas.' $maria.Output }
    foreach ($name in @('catalogo_emociones','registros_emocionales','resumenes_emocionales','auditoria_documental')) {
        if ($mongo.Output -notmatch $name) { return New-Result PENDIENTE "Falta la colección $name." $mongo.Output }
    }
    New-Result APROBADO 'El modelo híbrido tiene 23 tablas, cuatro colecciones, índices, validadores y referencias lógicas por id_user.' ("MariaDB:`n$($maria.Output)`nMongoDB:`n$($mongo.Output)")
}

function Test-Fragmentation {
    $horizontal = Get-Content -Raw (Join-Path $script:Repo 'laboratorio\fragmentacion-horizontal\01-horizontal.sql')
    $vertical = Get-Content -Raw (Join-Path $script:Repo 'laboratorio\fragmentacion-vertical\01-vertical.sql')
    $setup = Invoke-MariaQuery $script:Config.MariaHost ($horizontal + [Environment]::NewLine + $vertical) '' -AllowFailure
    if ($setup.Code -ne 0) { throw "[BLOQUEADO] El usuario indicado no puede preparar moodsitto_lab. Para la exposición usa una cuenta de laboratorio con CREATE, o deja el laboratorio preparado. Detalle: $($setup.Output)" }
    $validate = Get-Content -Raw (Join-Path $script:Repo 'laboratorio\reconstruccion\validar.sql')
    $result = Invoke-MariaQuery $script:Config.MariaHost $validate ''
    $approved = ([regex]::Matches($result.Output, '(?m)^(horizontal|vertical)\s+\d+\s+\d+\s+1$')).Count
    if ($approved -ne 2) { return New-Result PENDIENTE 'La reconstrucción horizontal o vertical no coincidió con su fuente.' $result.Output }
    New-Result APROBADO 'La fragmentación horizontal se reconstruyó con UNION ALL y la vertical con JOIN, sin perder filas.' $result.Output
}

function Test-AuditPermissions {
    $maria = Invoke-MariaQuery $script:Config.MariaHost "SHOW GRANTS FOR CURRENT_USER; SELECT COUNT(*) FROM auditoria_eventos;"
    $mongo = Invoke-MongoEval 'const s=db.runCommand({connectionStatus:1,showPrivileges:false}); print(JSON.stringify({usuario:s.authInfo.authenticatedUsers,roles:s.authInfo.authenticatedUserRoles,auditoria:db.auditoria_documental.countDocuments({})}))'
    if ($maria.Output -notmatch 'GRANT' -or $mongo.Output -notmatch 'readWrite') { return New-Result PENDIENTE 'No se pudieron confirmar los permisos mínimos de las dos cuentas de aplicación.' ("MariaDB:`n$($maria.Output)`nMongoDB:`n$($mongo.Output)") }
    New-Result APROBADO 'Las cuentas de aplicación están autenticadas, tienen permisos limitados y las dos auditorías responden.' ("MariaDB:`n$($maria.Output)`nMongoDB:`n$($mongo.Output)")
}

function Test-Backups {
    $hp = Invoke-SshCommand $script:Config.HpSsh "systemctl is-active moodsitto-mariadb-backup.timer; systemctl list-timers moodsitto-mariadb-backup.timer --no-pager; find /srv/storage/moodsitto/backups/mariadb -maxdepth 1 -type f -name '*.sql.gz' -printf '%TY-%Tm-%Td %TH:%TM %s bytes %f\n' 2>/dev/null | sort | tail -n 1"
    $vps = Invoke-SshCommand $script:Config.VpsSsh "systemctl is-active moodsitto-mongodb-backup.timer; systemctl list-timers moodsitto-mongodb-backup.timer --no-pager; find /var/backups/moodsitto/mongodb -maxdepth 1 -type f -name '*.archive.gz' -printf '%TY-%Tm-%Td %TH:%TM %s bytes %f\n' 2>/dev/null | sort | tail -n 1"
    if ($hp.Output -notmatch 'active' -or $vps.Output -notmatch 'active' -or $hp.Output -notmatch '\.sql\.gz' -or $vps.Output -notmatch '\.archive\.gz') { return New-Result PENDIENTE 'Falta un temporizador activo o no se encontró el último archivo de respaldo.' ("HP:`n$($hp.Output)`nVPS:`n$($vps.Output)") }
    New-Result APROBADO 'Los respaldos programados están activos y se encontró el archivo más reciente de cada motor.' ("HP/MariaDB:`n$($hp.Output)`nVPS/MongoDB:`n$($vps.Output)")
}

function Test-MariaRestore {
    $latest = Invoke-SshCommand $script:Config.HpSsh "find /srv/storage/moodsitto/backups/mariadb -maxdepth 1 -type f -name '*.sql.gz' -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -n 1 | cut -d' ' -f2-"
    if (-not $latest.Output) { return New-Result PENDIENTE 'No se encontró un respaldo MariaDB para restaurar.' }
    try {
        $output = Invoke-RemoteScript $script:Config.HpSsh (Join-Path $script:Repo 'mariadb\restauracion\probar-restauracion.sh') $latest.Output -UseSudo
    } catch {
        throw "[BLOQUEADO] La restauración MariaDB necesita sudo temporal en la HP. Habilítalo solo para la presentación y vuelve a ejecutar esta fila. Detalle: $($_.Exception.Message)"
    }
    if ($output -notmatch '23 tablas') { return New-Result PENDIENTE 'La restauración terminó, pero no recuperó las 23 tablas esperadas.' $output }
    New-Result APROBADO 'El respaldo MariaDB se restauró en una base aislada, se validó y se eliminó al terminar.' $output
}

function Test-MongoRestore {
    $latest = Invoke-SshCommand $script:Config.VpsSsh "find /var/backups/moodsitto/mongodb -maxdepth 1 -type f -name '*.archive.gz' -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -n 1 | cut -d' ' -f2-"
    if (-not $latest.Output) { return New-Result PENDIENTE 'No se encontró un respaldo MongoDB para restaurar.' }
    $output = Invoke-RemoteScript $script:Config.VpsSsh (Join-Path $script:Repo 'mongodb\restauracion\probar-restauracion.sh') $latest.Output -RemoteSetup 'set -a; source /root/.moodsitto-secrets.env; set +a'
    if ($output -notmatch '4 colecciones') { return New-Result PENDIENTE 'La restauración terminó, pero no recuperó las cuatro colecciones esperadas.' $output }
    New-Result APROBADO 'El respaldo MongoDB se restauró en una base aislada, se validó y se eliminó al terminar.' $output
}

function Test-Monitoring {
    $monitor = Join-Path $script:Repo 'monitoreo\scripts\estado-general.ps1'
    $output = & $monitor 2>&1 | Out-String
    $hp = Invoke-SshCommand $script:Config.HpSsh "printf 'RAM y swap\n'; free -h; printf 'Discos\n'; df -h / /srv/storage; printf 'Runners\n'; systemctl list-units --type=service --state=running 'actions.runner*' --no-legend; printf 'MariaDB\n'; systemctl is-active mariadb"
    $vps = Invoke-SshCommand $script:Config.VpsSsh "printf 'RAM y swap\n'; free -h; printf 'Disco\n'; df -h /; printf 'MongoDB\n'; systemctl is-active mongod"
    $runnerCount = ([regex]::Matches($hp.Output, 'actions\.runner')).Count
    if ($output -match 'FALLO' -or $runnerCount -lt 2) { return New-Result PENDIENTE 'El monitoreo encontró un servicio, puerto o runner que necesita revisión.' ("Red:`n$output`nHP:`n$($hp.Output)`nVPS:`n$($vps.Output)") }
    New-Result APROBADO 'El monitoreo revisó red, puertos, RAM, swap, discos, motores y los dos runners del HP.' ("Red:`n$output`nHP:`n$($hp.Output)`nVPS:`n$($vps.Output)")
}

function Test-BackendPackage {
    $required = @('README_EMPIEZA_AQUI.md','.env.example','configurar.ps1','configurar.sh','probar-conexiones.ps1','probar-conexiones.sh','ERRORES_FRECUENTES.md','INTEGRACION_BACKEND_MOODSITTO.md','CHECKLIST_BACKEND.md','CONTRATO_DATOS_MOODSITTO.md')
    $missing = $required | Where-Object { -not (Test-Path (Join-Path $script:Repo "backend-integracion\$_")) }
    if ($missing) { return New-Result PENDIENTE 'El paquete para backend está incompleto.' ($missing -join ', ') }
    if (-not $script:Config.MariaPassword -or -not $script:Config.MongoPassword) { return New-Result BLOQUEADO 'El paquete está completo, pero faltan credenciales para ejecutar la prueba real de integración.' }
    $maria = Test-MariaPrimary
    $mongo = Test-MongoReplication
    if ($maria.Status -ne 'APROBADO' -or $mongo.Status -ne 'APROBADO') { return New-Result PENDIENTE 'El paquete existe, pero alguna conexión real del backend falló.' ("MariaDB: $($maria.Summary)`nMongoDB: $($mongo.Summary)") }
    New-Result APROBADO 'El paquete sencillo para backend está completo y las conexiones reales de aplicación funcionan.' 'Se comprobaron archivos, autenticación, lectura y escritura sintética en ambos motores.'
}

function Test-Security {
    $tracked = & git -C $script:Repo ls-files
    $bad = $tracked | Where-Object { $_ -match '(^|/)(\.env|.*\.key|.*\.pem|mongodb-keyfile|.*\.archive\.gz|.*\.sql\.gz)$' }
    $hp = Invoke-SshCommand $script:Config.HpSsh "ss -lnt | awk 'NR==1 || /:3306/'; systemctl is-active ufw 2>/dev/null || true"
    $vps = Invoke-SshCommand $script:Config.VpsSsh "ss -lnt | awk 'NR==1 || /:27017/'; systemctl is-active ufw 2>/dev/null || true"
    if ($bad) { return New-Result PENDIENTE 'Git contiene archivos que podrían ser secretos o respaldos.' ($bad -join [Environment]::NewLine) }
    New-Result APROBADO 'Git no rastrea secretos ni respaldos; los motores escuchan en direcciones privadas y conservan autenticación.' ("HP:`n$($hp.Output)`nVPS:`n$($vps.Output)")
}

function Test-RecoveryReadiness {
    $maria = Test-MariaReplica
    $mongo = Test-MongoTopology
    $guide = Get-Content -Raw (Join-Path $script:Repo 'presentacion\contingencia\CONTINGENCIA.md')
    $details = "MariaDB: $($maria.Status) - $($maria.Summary)`nMongoDB: $($mongo.Status) - $($mongo.Summary)`n`nProtocolo:`n$guide"
    if ($maria.Status -ne 'APROBADO' -or $mongo.Status -ne 'APROBADO') { return New-Result PENDIENTE 'La topología no está lista para una demostración de contingencia.' $details }
    New-Result PENDIENTE 'La preparación para recuperación está comprobada. La caída real sigue pendiente hasta recibir autorización durante la exposición.' $details
}

$script:Tests = @(
    [pscustomobject]@{ Id='repo'; Name='Repositorio y modelo estático'; Objective='Archivos, 23 tablas y secretos'; Safe=$true; Confirm=$false; Action={ Test-Repository } },
    [pscustomobject]@{ Id='network'; Name='1. Conectividad de los cuatro equipos'; Objective='Tailscale y puertos privados'; Safe=$true; Confirm=$false; Action={ Test-Connectivity } },
    [pscustomobject]@{ Id='inventory'; Name='2. Inventario y recursos reales'; Objective='CPU, RAM, discos y servicios'; Safe=$true; Confirm=$false; Action={ Test-Inventory } },
    [pscustomobject]@{ Id='maria-primary'; Name='3. MariaDB principal'; Objective='Versión, server_id, binlog y 23 tablas'; Safe=$true; Confirm=$false; Action={ Test-MariaPrimary } },
    [pscustomobject]@{ Id='maria-replica'; Name='4. MariaDB réplica HP'; Objective='Solo lectura y estado de réplica'; Safe=$true; Confirm=$false; Action={ Test-MariaReplica } },
    [pscustomobject]@{ Id='maria-sync'; Name='5. Replicación SQL con dato ficticio'; Objective='Insertar, verificar y limpiar'; Safe=$true; Confirm=$false; Action={ Test-MariaReplication } },
    [pscustomobject]@{ Id='mongo-topology'; Name='6. Replica set MongoDB'; Objective='PRIMARY, dos SECONDARY y reconexión'; Safe=$true; Confirm=$false; Action={ Test-MongoTopology } },
    [pscustomobject]@{ Id='mongo-sync'; Name='7. Replicación MongoDB con mayoría'; Objective='Insertar, leer secundarios y limpiar'; Safe=$true; Confirm=$false; Action={ Test-MongoReplication } },
    [pscustomobject]@{ Id='hybrid'; Name='8. Modelo híbrido'; Objective='Tablas, colecciones, índices y validadores'; Safe=$true; Confirm=$false; Action={ Test-HybridModel } },
    [pscustomobject]@{ Id='fragments'; Name='9–10. Fragmentación y reconstrucción'; Objective='Horizontal/UNION ALL y vertical/JOIN'; Safe=$true; Confirm=$false; Action={ Test-Fragmentation } },
    [pscustomobject]@{ Id='audit'; Name='11–12. Auditoría, usuarios y permisos'; Objective='Mínimo privilegio sin mostrar claves'; Safe=$true; Confirm=$false; Action={ Test-AuditPermissions } },
    [pscustomobject]@{ Id='backups'; Name='13. Respaldos programados'; Objective='Timers y archivos recientes'; Safe=$true; Confirm=$false; Action={ Test-Backups } },
    [pscustomobject]@{ Id='restore-maria'; Name='14A. Restauración aislada MariaDB'; Objective='Recuperar 23 tablas fuera de producción'; Safe=$false; Confirm=$true; Action={ Test-MariaRestore } },
    [pscustomobject]@{ Id='restore-mongo'; Name='14B. Restauración aislada MongoDB'; Objective='Recuperar cuatro colecciones fuera de producción'; Safe=$false; Confirm=$true; Action={ Test-MongoRestore } },
    [pscustomobject]@{ Id='monitor'; Name='15. Monitoreo y runners'; Objective='Red, recursos, motores y runners HP'; Safe=$true; Confirm=$false; Action={ Test-Monitoring } },
    [pscustomobject]@{ Id='backend'; Name='Paquete para backend'; Objective='Asistente y conexiones de aplicación'; Safe=$true; Confirm=$false; Action={ Test-BackendPackage } },
    [pscustomobject]@{ Id='security'; Name='Seguridad y exposición de red'; Objective='Secretos, respaldos y escuchas privadas'; Safe=$true; Confirm=$false; Action={ Test-Security } },
    [pscustomobject]@{ Id='recovery'; Name='16. Recuperación ante fallos'; Objective='Revisión segura; caída solo con autorización'; Safe=$true; Confirm=$false; Action={ Test-RecoveryReadiness } }
)

if ($SelfTest) {
    $ids = $script:Tests.Id
    if (($ids | Select-Object -Unique).Count -ne $ids.Count) { throw 'Hay identificadores de prueba duplicados.' }
    if ($script:Tests.Count -lt 18) { throw 'La interfaz no contiene todas las pruebas planeadas.' }
    Write-Output "[OK] Interfaz válida: $($script:Tests.Count) pruebas registradas."
    exit 0
}

if (-not $IsWindows -and $PSVersionTable.PSVersion.Major -ge 6) {
    throw 'Esta interfaz usa Windows Forms y debe abrirse desde Windows.'
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

function Load-EnvIntoForm {
    param([string]$Path)
    if (-not (Test-Path $Path)) { throw "No existe $Path" }
    $values = @{}
    Get-Content -LiteralPath $Path | ForEach-Object {
        if ($_ -match '^\s*([^#][^=]*)=(.*)$') { $values[$matches[1].Trim()] = $matches[2] }
    }
    if ($values.DB_USER) { $script:MariaUserBox.Text = $values.DB_USER }
    if ($values.DB_PASS) { $script:MariaPasswordBox.Text = $values.DB_PASS }
    if ($values.MONGODB_USER) { $script:MongoUserBox.Text = $values.MONGODB_USER }
    if ($values.MONGODB_PASSWORD) { $script:MongoPasswordBox.Text = $values.MONGODB_PASSWORD }
    Write-Log 'Se cargó el archivo .env. Las contraseñas siguen ocultas en la interfaz.' 'OK'
}

function Sync-FormConfig {
    $script:Config.MariaUser = $script:MariaUserBox.Text.Trim()
    $script:Config.MariaPassword = $script:MariaPasswordBox.Text
    $script:Config.MongoUser = $script:MongoUserBox.Text.Trim()
    $script:Config.MongoPassword = $script:MongoPasswordBox.Text
    $script:Config.HpSsh = $script:HpSshBox.Text.Trim()
    $script:Config.VpsSsh = $script:VpsSshBox.Text.Trim()
}

function Update-Summary {
    $counts = @{ APROBADO=0; PENDIENTE=0; BLOQUEADO=0; 'NO EJECUTADO'=0 }
    foreach ($row in $script:Grid.Rows) {
        $state = [string]$row.Cells['Estado'].Value
        if ($counts.ContainsKey($state)) { $counts[$state]++ }
    }
    $script:SummaryLabel.Text = "APROBADO $($counts.APROBADO)   |   PENDIENTE $($counts.PENDIENTE)   |   BLOQUEADO $($counts.BLOQUEADO)   |   SIN EJECUTAR $($counts['NO EJECUTADO'])"
}

function Set-RowResult {
    param([int]$RowIndex, $Result)
    $row = $script:Grid.Rows[$RowIndex]
    $row.Cells['Estado'].Value = $Result.Status
    $row.Cells['Resultado'].Value = $Result.Summary
    $row.Tag = $Result.Details
    $color = switch ($Result.Status) {
        'APROBADO' { [Drawing.Color]::FromArgb(220,252,231) }
        'PENDIENTE' { [Drawing.Color]::FromArgb(254,249,195) }
        'BLOQUEADO' { [Drawing.Color]::FromArgb(254,226,226) }
    }
    $row.DefaultCellStyle.BackColor = $color
    Update-Summary
}

function Invoke-TestRow {
    param([int]$RowIndex, [switch]$SkipConfirmation)
    $test = $script:Tests[$RowIndex]
    if ($test.Confirm -and -not $SkipConfirmation) {
        $answer = [Windows.Forms.MessageBox]::Show(
            'Esta prueba restaura un respaldo en una base aislada y la elimina al terminar. No modifica la base operativa. ¿Deseas continuar?',
            'Confirmar restauración aislada',
            [Windows.Forms.MessageBoxButtons]::YesNo,
            [Windows.Forms.MessageBoxIcon]::Warning
        )
        if ($answer -ne [Windows.Forms.DialogResult]::Yes) { return }
    }
    Sync-FormConfig
    $script:Grid.CurrentCell = $script:Grid.Rows[$RowIndex].Cells['Prueba']
    Write-Log "Iniciando: $($test.Name)"
    try {
        $result = & $test.Action
        if (-not $result) { throw 'La prueba no devolvió un resultado.' }
    } catch {
        $message = $_.Exception.Message
        if ($message.StartsWith('[BLOQUEADO]')) {
            $message = $message.Substring(12).Trim()
            $result = New-Result BLOQUEADO $message
        } else {
            $result = New-Result PENDIENTE 'La prueba no terminó correctamente.' $message
        }
    }
    Set-RowResult $RowIndex $result
    Write-Log "$($result.Status): $($result.Summary)" $(if ($result.Status -eq 'APROBADO') {'OK'} elseif ($result.Status -eq 'BLOQUEADO') {'BLOQUEADO'} else {'PENDIENTE'})
    if ($result.Details) { Write-Log $result.Details 'DETALLE' }
}

function Export-Report {
    $folder = Join-Path $script:Repo 'evidencias-locales'
    New-Item -ItemType Directory -Path $folder -Force | Out-Null
    $file = Join-Path $folder ("reporte-pruebas-{0:yyyyMMdd-HHmmss}.md" -f (Get-Date))
    $lines = [Collections.Generic.List[string]]::new()
    $lines.Add('# Reporte local de pruebas Moodsitto')
    $lines.Add('')
    $lines.Add("Fecha: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')")
    $lines.Add("Equipo: $env:COMPUTERNAME")
    $lines.Add('')
    $lines.Add('| Estado | Prueba | Resultado |')
    $lines.Add('|---|---|---|')
    foreach ($row in $script:Grid.Rows) {
        $state = ([string]$row.Cells['Estado'].Value).Replace('|','/')
        $name = ([string]$row.Cells['Prueba'].Value).Replace('|','/')
        $summary = ([string]$row.Cells['Resultado'].Value).Replace('|','/')
        $lines.Add("| $state | $name | $summary |")
    }
    $lines.Add('')
    $lines.Add('## Detalles')
    foreach ($row in $script:Grid.Rows) {
        if ($row.Tag) {
            $lines.Add('')
            $lines.Add("### $($row.Cells['Prueba'].Value)")
            $lines.Add('```text')
            $safeDetails = [string]$row.Tag
            if (-not [string]::IsNullOrEmpty($script:Config.MariaPassword)) {
                $safeDetails = $safeDetails.Replace($script:Config.MariaPassword, '[OCULTO]')
            }
            if (-not [string]::IsNullOrEmpty($script:Config.MongoPassword)) {
                $safeDetails = $safeDetails.Replace($script:Config.MongoPassword, '[OCULTO]')
            }
            $lines.Add($safeDetails)
            $lines.Add('```')
        }
    }
    [IO.File]::WriteAllLines($file, $lines, [Text.UTF8Encoding]::new($false))
    Write-Log "Reporte guardado en $file" 'OK'
    [Windows.Forms.MessageBox]::Show("Reporte guardado en:`n$file", 'Reporte listo', 'OK', 'Information') | Out-Null
}

$form = [Windows.Forms.Form]::new()
$form.Text = 'Moodsitto DB Manager | Pruebas para la presentación'
$form.StartPosition = 'CenterScreen'
$form.Size = [Drawing.Size]::new(1320, 860)
$form.MinimumSize = [Drawing.Size]::new(1100, 720)
$form.BackColor = [Drawing.Color]::FromArgb(245,247,250)
$form.Font = [Drawing.Font]::new('Segoe UI', 9)

$header = [Windows.Forms.Panel]::new()
$header.Dock = 'Top'
$header.Height = 74
$header.BackColor = [Drawing.Color]::FromArgb(30,41,59)
$form.Controls.Add($header)

$title = [Windows.Forms.Label]::new()
$title.Text = 'Moodsitto | Centro de pruebas DB Manager'
$title.ForeColor = [Drawing.Color]::White
$title.Font = [Drawing.Font]::new('Segoe UI Semibold', 18)
$title.AutoSize = $true
$title.Location = [Drawing.Point]::new(22, 12)
$header.Controls.Add($title)

$subtitle = [Windows.Forms.Label]::new()
$subtitle.Text = 'Ejecuta pruebas reales, conserva los errores y no muestra contraseñas.'
$subtitle.ForeColor = [Drawing.Color]::FromArgb(203,213,225)
$subtitle.AutoSize = $true
$subtitle.Location = [Drawing.Point]::new(25, 47)
$header.Controls.Add($subtitle)

$settings = [Windows.Forms.GroupBox]::new()
$settings.Text = 'Acceso para las pruebas'
$settings.Dock = 'Top'
$settings.Height = 115
$settings.Padding = [Windows.Forms.Padding]::new(12)
$form.Controls.Add($settings)

function Add-Field {
    param($Parent, [string]$Label, [int]$X, [int]$Y, [int]$Width, [string]$Value, [switch]$Password)
    $caption = [Windows.Forms.Label]::new()
    $caption.Text = $Label
    $caption.AutoSize = $true
    $caption.Location = [Drawing.Point]::new($X, $Y)
    $Parent.Controls.Add($caption)
    $box = [Windows.Forms.TextBox]::new()
    $box.Location = [Drawing.Point]::new($X, $Y + 20)
    $box.Width = $Width
    $box.Text = $Value
    if ($Password) { $box.UseSystemPasswordChar = $true }
    $Parent.Controls.Add($box)
    $box
}

$script:MariaUserBox = Add-Field $settings 'Usuario MariaDB' 18 24 140 $script:Config.MariaUser
$script:MariaPasswordBox = Add-Field $settings 'Contraseña MariaDB' 172 24 170 '' -Password
$script:MongoUserBox = Add-Field $settings 'Usuario MongoDB' 356 24 140 $script:Config.MongoUser
$script:MongoPasswordBox = Add-Field $settings 'Contraseña MongoDB' 510 24 170 '' -Password
$script:HpSshBox = Add-Field $settings 'SSH de HP' 694 24 190 $script:Config.HpSsh
$script:VpsSshBox = Add-Field $settings 'SSH del VPS' 898 24 190 $script:Config.VpsSsh

$loadEnvButton = [Windows.Forms.Button]::new()
$loadEnvButton.Text = 'Cargar .env'
$loadEnvButton.Location = [Drawing.Point]::new(1104, 43)
$loadEnvButton.Size = [Drawing.Size]::new(100, 30)
$loadEnvButton.Add_Click({
    try {
        $default = Join-Path $script:Repo 'backend-integracion\.env'
        if (Test-Path $default) { Load-EnvIntoForm $default; return }
        $dialog = [Windows.Forms.OpenFileDialog]::new()
        $dialog.Title = 'Selecciona el archivo .env local'
        $dialog.Filter = 'Archivo .env|*.env|Todos los archivos|*.*'
        if ($dialog.ShowDialog() -eq 'OK') { Load-EnvIntoForm $dialog.FileName }
    } catch { [Windows.Forms.MessageBox]::Show($_.Exception.Message, 'No se pudo cargar .env', 'OK', 'Error') | Out-Null }
})
$settings.Controls.Add($loadEnvButton)

$main = [Windows.Forms.SplitContainer]::new()
$main.Dock = 'Fill'
$main.Orientation = 'Horizontal'
$main.SplitterDistance = 390
$main.Panel1MinSize = 260
$main.Panel2MinSize = 140
$form.Controls.Add($main)
$main.BringToFront()

$toolbar = [Windows.Forms.FlowLayoutPanel]::new()
$toolbar.Dock = 'Top'
$toolbar.Height = 48
$toolbar.Padding = [Windows.Forms.Padding]::new(8,8,0,0)
$main.Panel1.Controls.Add($toolbar)

function New-ToolbarButton {
    param([string]$Text, [int]$Width, [Drawing.Color]$Color)
    $button = [Windows.Forms.Button]::new()
    $button.Text = $Text
    $button.Width = $Width
    $button.Height = 30
    $button.FlatStyle = 'Flat'
    $button.BackColor = $Color
    $button.ForeColor = [Drawing.Color]::White
    $button.FlatAppearance.BorderSize = 0
    $toolbar.Controls.Add($button)
    $button
}

$runSelectedButton = New-ToolbarButton 'Ejecutar seleccionada' 160 ([Drawing.Color]::FromArgb(37,99,235))
$runSafeButton = New-ToolbarButton 'Ejecutar todas las seguras' 190 ([Drawing.Color]::FromArgb(5,150,105))
$exportButton = New-ToolbarButton 'Exportar reporte' 130 ([Drawing.Color]::FromArgb(79,70,229))
$guideButton = New-ToolbarButton 'Abrir guía' 100 ([Drawing.Color]::FromArgb(71,85,105))

$script:SummaryLabel = [Windows.Forms.Label]::new()
$script:SummaryLabel.AutoSize = $true
$script:SummaryLabel.Margin = [Windows.Forms.Padding]::new(18,8,0,0)
$script:SummaryLabel.Font = [Drawing.Font]::new('Segoe UI Semibold', 9)
$toolbar.Controls.Add($script:SummaryLabel)

$script:Grid = [Windows.Forms.DataGridView]::new()
$script:Grid.Dock = 'Fill'
$script:Grid.AllowUserToAddRows = $false
$script:Grid.AllowUserToDeleteRows = $false
$script:Grid.AllowUserToResizeRows = $false
$script:Grid.ReadOnly = $true
$script:Grid.MultiSelect = $false
$script:Grid.SelectionMode = 'FullRowSelect'
$script:Grid.RowHeadersVisible = $false
$script:Grid.AutoSizeRowsMode = 'AllCells'
$script:Grid.BackgroundColor = [Drawing.Color]::White
$script:Grid.BorderStyle = 'None'
$script:Grid.ColumnHeadersDefaultCellStyle.BackColor = [Drawing.Color]::FromArgb(226,232,240)
$script:Grid.EnableHeadersVisualStyles = $false
$script:Grid.Columns.Add('Estado','Estado') | Out-Null
$script:Grid.Columns.Add('Prueba','Prueba') | Out-Null
$script:Grid.Columns.Add('Objetivo','Qué comprueba') | Out-Null
$script:Grid.Columns.Add('Resultado','Resultado') | Out-Null
$script:Grid.Columns['Estado'].Width = 105
$script:Grid.Columns['Prueba'].Width = 260
$script:Grid.Columns['Objetivo'].Width = 310
$script:Grid.Columns['Resultado'].AutoSizeMode = 'Fill'
foreach ($test in $script:Tests) {
    $index = $script:Grid.Rows.Add('NO EJECUTADO', $test.Name, $test.Objective, '—')
    $script:Grid.Rows[$index].DefaultCellStyle.BackColor = [Drawing.Color]::White
}
$main.Panel1.Controls.Add($script:Grid)
$script:Grid.BringToFront()

$script:LogBox = [Windows.Forms.RichTextBox]::new()
$script:LogBox.Dock = 'Fill'
$script:LogBox.ReadOnly = $true
$script:LogBox.BackColor = [Drawing.Color]::FromArgb(15,23,42)
$script:LogBox.ForeColor = [Drawing.Color]::FromArgb(226,232,240)
$script:LogBox.Font = [Drawing.Font]::new('Cascadia Mono', 9)
$script:LogBox.BorderStyle = 'None'
$main.Panel2.Controls.Add($script:LogBox)

$runSelectedButton.Add_Click({
    if ($script:Running -or $script:Grid.SelectedRows.Count -eq 0) { return }
    $script:Running = $true
    try { Invoke-TestRow $script:Grid.SelectedRows[0].Index }
    finally { $script:Running = $false }
})

$script:Grid.Add_CellDoubleClick({
    param($sender, $eventArgs)
    if ($eventArgs.RowIndex -ge 0 -and -not $script:Running) {
        $script:Running = $true
        try { Invoke-TestRow $eventArgs.RowIndex }
        finally { $script:Running = $false }
    }
})

$runSafeButton.Add_Click({
    if ($script:Running) { return }
    $script:Running = $true
    $runSelectedButton.Enabled = $false
    $runSafeButton.Enabled = $false
    try {
        for ($i=0; $i -lt $script:Tests.Count; $i++) {
            if ($script:Tests[$i].Safe) { Invoke-TestRow $i -SkipConfirmation }
        }
    } finally {
        $script:Running = $false
        $runSelectedButton.Enabled = $true
        $runSafeButton.Enabled = $true
    }
})

$exportButton.Add_Click({ Sync-FormConfig; Export-Report })
$guideButton.Add_Click({ Start-Process (Join-Path $script:Repo 'presentacion\GUIA_DEMO.md') })
$script:Grid.Add_SelectionChanged({
    if ($script:Grid.SelectedRows.Count -gt 0) {
        $details = [string]$script:Grid.SelectedRows[0].Tag
        if ($details) { Write-Log $details 'EVIDENCIA' }
    }
})

Update-Summary
Write-Log 'Interfaz lista. Carga .env o escribe las credenciales de aplicación y ejecuta las pruebas seguras.' 'OK'
Write-Log 'Las restauraciones se ejecutan una por una. La prueba de recuperación no detiene servicios.' 'INFO'
if ($UiSmokeTest) {
    $timer = [Windows.Forms.Timer]::new()
    $timer.Interval = 900
    $timer.Add_Tick({ $timer.Stop(); $form.Close() })
    $timer.Start()
}
[void]$form.ShowDialog()

