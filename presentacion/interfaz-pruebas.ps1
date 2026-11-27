param(
    [switch]$SelfTest,
    [switch]$UiSmokeTest,
    [switch]$CheckApiCore
)

# Destinos privados de Moodsitto y estado de la ventana durante la sesión.
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
$script:CommandBox = $null
$script:ActiveCommands = $null
$script:OperationLogBox = $null
$script:RunningOperation = $false
$script:OperationHistory = [Collections.Generic.List[string]]::new()
. (Join-Path $PSScriptRoot 'operaciones-panel.ps1')

# Cada prueba devuelve el mismo formato para la tabla y el reporte.
function New-Result {
    param(
        [ValidateSet('APROBADO','PENDIENTE','BLOQUEADO')][string]$Status,
        [string]$Summary,
        [string]$Details = ''
    )
    [pscustomobject]@{ Status = $Status; Summary = $Summary; Details = $Details }
}

function Protect-LogText {
    param([string]$Text)
    # Cubre tanto una contraseña en texto como su forma dentro de una URI.
    $forms = foreach ($secret in $script:Config.MariaPassword, $script:Config.MongoPassword) {
        if ($secret) {
            $secret
            [Uri]::EscapeDataString($secret)
        }
    }
    foreach ($form in ($forms | Sort-Object Length -Descending)) {
        $Text = $Text.Replace($form, '[OCULTO]')
    }
    $Text
}

function Register-TestCommand {
    param([string]$Command, [string[]]$Arguments = @(), [string]$Note = '', [switch]$PowerShell)
    if ($null -eq $script:ActiveCommands) { return }
    # Las comillas mantienen juntos los argumentos con espacios, como SQL o JavaScript.
    $parts = @("& '$($Command.Replace("'", "''"))'")
    $parts += foreach ($argument in $Arguments) {
        if ($PowerShell -and $argument -cmatch '^-[A-Z][A-Za-z]+$') { $argument }
        else { "'$($argument.Replace("'", "''"))'" }
    }
    $line = $parts -join ' '
    if ($Note) { $line = "# $Note`n$line" }
    $script:ActiveCommands.Add((Protect-LogText $line))
}

function Write-Log {
    param([string]$Text, [string]$Level = 'INFO')
    $line = "[{0:HH:mm:ss}] [{1}] {2}" -f (Get-Date), $Level, (Protect-LogText $Text)
    if ($script:LogBox) {
        $script:LogBox.AppendText($line + [Environment]::NewLine)
        $script:LogBox.SelectionStart = $script:LogBox.TextLength
        $script:LogBox.ScrollToCaret()
        if ($script:RunningOperation -and $script:OperationLogBox) {
            $script:OperationLogBox.AppendText($line + [Environment]::NewLine)
            $script:OperationLogBox.SelectionStart = $script:OperationLogBox.TextLength
            $script:OperationLogBox.ScrollToCaret()
        }
        [System.Windows.Forms.Application]::DoEvents()
    } else {
        Write-Output $line
    }
}

function Require-Tool {
    param([string]$Name, [string]$Help)
    $tool = Get-Command $Name -ErrorAction SilentlyContinue
    if ($tool) { return $tool.Source }
    if ($Name -eq 'mariadb') {
        $candidate = Get-ChildItem -Path "$env:ProgramFiles\MariaDB *\bin\mariadb.exe" -File -ErrorAction SilentlyContinue |
            Sort-Object FullName -Descending | Select-Object -First 1
        if ($candidate) { return $candidate.FullName }
    }
    if ($Name -eq 'mongosh') {
        $candidate = Get-ChildItem -Path "$env:LOCALAPPDATA\Programs\mongosh\mongosh.exe","$env:ProgramFiles\MongoDB\mongosh\*\bin\mongosh.exe" -File -ErrorAction SilentlyContinue |
            Select-Object -First 1
        if ($candidate) { return $candidate.FullName }
    }
    throw "[BLOQUEADO] Falta $Name. $Help"
}

function Require-Credentials {
    param([ValidateSet('MariaDB','MongoDB')][string]$Engine)
    if ($Engine -eq 'MariaDB' -and [string]::IsNullOrWhiteSpace($script:Config.MariaPassword)) {
        throw '[BLOQUEADO] No se pudo cargar automáticamente la credencial local de MariaDB.'
    }
    if ($Engine -eq 'MongoDB' -and [string]::IsNullOrWhiteSpace($script:Config.MongoPassword)) {
        throw '[BLOQUEADO] No se pudo cargar automáticamente la credencial local de MongoDB.'
    }
}

function Test-TcpPort {
    param([string]$HostName, [int]$Port, [int]$TimeoutMs = 3500)
    $client = [Net.Sockets.TcpClient]::new()
    try {
        if ($null -ne $script:ActiveCommands) {
            $script:ActiveCommands.Add((Protect-LogText "`$client.ConnectAsync('$HostName', $Port).Wait($TimeoutMs)  # TcpClient"))
        }
        $task = $client.ConnectAsync($HostName, $Port)
        return $task.Wait($TimeoutMs) -and $client.Connected
    } catch {
        return $false
    } finally {
        $client.Dispose()
    }
}

# La variable de conexión solo se usa mientras se ejecuta el cliente SQL.
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
        Register-TestCommand $client $args 'MariaDB toma la contraseña de MYSQL_PWD.'
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
    if ($Direct) { $options += '&directConnection=true&readPreference=secondaryPreferred' }
    else { $options += "&replicaSet=$($script:Config.MongoReplicaSet)&retryWrites=true&w=majority" }
    "mongodb://${Hosts}/$($script:Config.MongoDatabase)?${options}"
}

function Invoke-MongoEval {
    param([string]$JavaScript, [string]$Uri = (Get-MongoUri), [switch]$AllowFailure)
    Require-Credentials MongoDB
    $mongosh = Require-Tool 'mongosh' 'Instala MongoDB Shell; no hace falta instalar otro servidor.'
    Register-TestCommand $mongosh @('--quiet', $Uri, '-u', $script:Config.MongoUser, '-p', '[OCULTO]', '--eval', $JavaScript)
    $output = & $mongosh --quiet $Uri -u $script:Config.MongoUser -p $script:Config.MongoPassword --eval $JavaScript 2>&1
    $code = $LASTEXITCODE
    if ($code -ne 0 -and -not $AllowFailure) { throw ($output -join [Environment]::NewLine) }
    [pscustomobject]@{ Code = $code; Output = ($output -join [Environment]::NewLine).Trim() }
}

function Invoke-SshCommand {
    param([string]$Target, [string]$Command, [switch]$AllowFailure)
    $ssh = Require-Tool 'ssh' 'Activa el cliente OpenSSH de Windows.'
    $sshArgs = @('-o', 'BatchMode=yes', '-o', 'ConnectTimeout=7', '-o', 'ServerAliveInterval=3', '--', $Target, $Command)
    Register-TestCommand $ssh $sshArgs
    $output = & $ssh @sshArgs 2>&1
    $code = $LASTEXITCODE
    if ($code -ne 0 -and -not $AllowFailure) { throw ($output -join [Environment]::NewLine) }
    [pscustomobject]@{ Code = $code; Output = ($output -join [Environment]::NewLine).Trim() }
}

function Invoke-RemoteScript {
    param([string]$Target, [string]$LocalScript, [string]$RemoteArgument, [switch]$UseSudo)
    $ssh = Require-Tool 'ssh' 'Activa el cliente OpenSSH de Windows.'
    $runner = if ($UseSudo) { "sudo -n bash -s -- '$RemoteArgument'" } else { "bash -s -- '$RemoteArgument'" }
    # Envía el script en UTF-8 con saltos de Linux para que Bash lea bien los acentos y el final del archivo.
    $content = [IO.File]::ReadAllText($LocalScript).Replace("`r`n", "`n")
    $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($content))
    $remote = "set -eo pipefail; printf %s '$encoded' | base64 -d | $runner"
    $sshArgs = @('-o', 'BatchMode=yes', '-o', 'ConnectTimeout=7', '--', $Target)
    Register-TestCommand $ssh ($sshArgs + @($runner)) "Envía por SSH el contenido de $LocalScript al Bash remoto."
    $output = & $ssh @sshArgs $remote 2>&1
    $code = $LASTEXITCODE
    if ($code -ne 0) { throw ($output -join [Environment]::NewLine) }
    ($output -join [Environment]::NewLine).Trim()
}

function Test-Repository {
    $scriptPath = Join-Path $script:Repo 'tests\validar-repositorio.ps1'
    Register-TestCommand $scriptPath
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
        Register-TestCommand 'Test-Connection' @('-ComputerName', $node.Host, '-Count', '1', '-Quiet', '-ErrorAction', 'SilentlyContinue') -PowerShell
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
    Register-TestCommand 'Get-CimInstance' @('Win32_ComputerSystem')
    $details.Add("Laptop: $env:COMPUTERNAME | RAM $([math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory/1GB,1)) GiB | Windows $([Environment]::OSVersion.Version)")
    $hp = Invoke-SshCommand $script:Config.HpSsh "printf 'HP: '; hostname; free -h | sed -n '2p'; df -h / /srv/storage | tail -n +2; systemctl list-units --type=service --all 'actions.runner*' --no-legend"
    $vps = Invoke-SshCommand $script:Config.VpsSsh "printf 'VPS: '; hostname; free -h | sed -n '2p'; df -h / | tail -n 1; systemctl is-active mongod"
    $details.Add($hp.Output)
    $details.Add($vps.Output)
    New-Result APROBADO 'Se consultaron recursos reales de la laptop, HP y VPS; el Windows fijo se comprueba mediante sus dos motores.' ($details -join [Environment]::NewLine)
}

# Usa variables de lectura disponibles para la cuenta de la aplicación.
function Test-MariaPrimary {
    # login_intentos es una tabla adicional del backend y no cuenta en las 23 del modelo base.
    $sql = "SELECT CONCAT(@@hostname,'|',@@version,'|server_id=',@@server_id,'|read_only=',@@read_only,'|log_bin=',@@log_bin); SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='moodsitto' AND table_name<>'login_intentos';"
    $result = Invoke-MariaQuery $script:Config.MariaHost $sql
    $lines = $result.Output -split "`r?`n"
    if ($result.Output -notmatch 'read_only=0') { return New-Result PENDIENTE 'El principal de MariaDB aparece en modo de solo lectura.' $result.Output }
    if ($result.Output -notmatch 'log_bin=1') { return New-Result PENDIENTE 'El binlog del principal está desactivado.' $result.Output }
    if ($lines -notcontains '23') { return New-Result PENDIENTE 'El esquema activo no tiene las 23 tablas esperadas.' $result.Output }
    New-Result APROBADO 'MariaDB principal acepta escritura, tiene server_id y conserva las 23 tablas del esquema híbrido.' $result.Output
}

function Test-MariaReplica {
    $sql = "SELECT CONCAT(@@hostname,'|',@@version,'|server_id=',@@server_id,'|read_only=',@@read_only); SHOW ALL SLAVES STATUS\G"
    $result = Invoke-MariaQuery $script:Config.MariaReplicaHost $sql -AllowFailure
    if ($result.Code -ne 0) {
        $fallback = Invoke-MariaQuery $script:Config.MariaReplicaHost "SELECT CONCAT(@@hostname,'|',@@version,'|server_id=',@@server_id,'|read_only=',@@read_only); SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='moodsitto';"
        if ($fallback.Output -notmatch 'read_only=1') { return New-Result PENDIENTE 'La réplica responde, pero no está protegida con read_only.' $fallback.Output }
        return New-Result BLOQUEADO 'La réplica responde en solo lectura. Para comprobar los hilos y el retraso hace falta una cuenta con REPLICA MONITOR.' $fallback.Output
    }
    # Muestra solo los campos de diagnóstico necesarios para la exposición.
    $details = ($result.Output -split "`r?`n" | Where-Object {
        $_ -match 'read_only=|^\s*(Slave_IO_Running|Slave_SQL_Running|Seconds_Behind_Master|Using_Gtid)\s*:'
    }) -join "`n"
    $healthy = $result.Output -match '(?m)^\s*Slave_IO_Running:\s*Yes\s*$' -and
        $result.Output -match '(?m)^\s*Slave_SQL_Running:\s*Yes\s*$' -and $result.Output -match 'read_only=1'
    if (-not $healthy) { return New-Result PENDIENTE 'La réplica respondió, pero su estado no coincide con la configuración esperada.' $details }
    New-Result APROBADO 'La réplica está en solo lectura y los hilos de replicación están activos.' $details
}

# Inserta un evento temporal y verifica que llegue al HP.
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
        New-Result APROBADO 'El registro sintético llegó del principal a la HP.' "correlacion_id=$id; réplica=1"
    } finally {
        if ($inserted) {
            Invoke-MariaQuery $script:Config.MariaHost "DELETE FROM auditoria_eventos WHERE correlacion_id='$id';" -AllowFailure | Out-Null
        }
    }
}

function Test-MongoTopology {
    $details = [Collections.Generic.List[string]]::new()
    $primaries = 0
    $secondaries = 0
    # El papel de cada miembro se lee en vivo porque puede cambiar después de una elección.
    foreach ($node in ($script:Config.MongoHosts -split ',')) {
        $js = 'const h=db.hello(); print(JSON.stringify({me:h.me,setName:h.setName,primary:h.primary,isWritablePrimary:h.isWritablePrimary,secondary:h.secondary,ok:h.ok}))'
        $result = Invoke-MongoEval $js (Get-MongoUri $node -Direct) -AllowFailure
        $details.Add("${node}: $($result.Output)")
        if ($result.Code -ne 0 -or $result.Output -notmatch '"setName":"rsMoodsitto"') { continue }
        if ($result.Output -match '"isWritablePrimary":true') { $primaries++ }
        if ($result.Output -match '"secondary":true') { $secondaries++ }
    }
    if ($primaries -ne 1 -or $secondaries -ne 2) { return New-Result PENDIENTE 'Falta comprobar un PRIMARY y dos SECONDARY en rsMoodsitto.' ($details -join [Environment]::NewLine) }
    New-Result APROBADO 'rsMoodsitto respondió con un PRIMARY y dos SECONDARY.' ($details -join [Environment]::NewLine)
}

# Confirma una escritura con mayoría y lee el documento en los demás miembros.
function Test-MongoReplication {
    $id = [Guid]::NewGuid().ToString()
    $uri = Get-MongoUri
    try {
        $insert = "db.auditoria_documental.insertOne({actor_id_user:null,accion:'prueba_interfaz',recurso:'presentacion',recurso_id:null,resultado:'ok',correlacion_id:'$id',metadata_segura:{datos:'sinteticos'},created_at:new Date()},{writeConcern:{w:'majority',wtimeout:10000}}); print('INSERTADO')"
        $write = Invoke-MongoEval $insert $uri
        if ($write.Output -notmatch 'INSERTADO') { throw $write.Output }
        $details = [Collections.Generic.List[string]]::new()
        $primary = (Invoke-MongoEval 'print(db.hello().me)' $uri).Output
        $otherMembers = @($script:Config.MongoHosts -split ',' | Where-Object { $_ -ne $primary })
        if ($otherMembers.Count -ne 2) { return New-Result PENDIENTE 'No se pudo identificar el miembro que recibió la escritura.' }
        foreach ($hostName in $otherMembers) {
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
    # Mantiene la revisión del modelo base separada de la tabla adicional del login.
    $maria = Invoke-MariaQuery $script:Config.MariaHost "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='moodsitto' AND table_name<>'login_intentos'; SELECT COUNT(*) FROM information_schema.statistics WHERE table_schema='moodsitto'; SELECT COUNT(*) FROM information_schema.referential_constraints WHERE constraint_schema='moodsitto';"
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

# Consulta privilegios sin mostrar las cláusulas de autenticación de SHOW GRANTS.
function Test-AuditPermissions {
    $maria = Invoke-MariaQuery $script:Config.MariaHost "SELECT TABLE_SCHEMA, PRIVILEGE_TYPE FROM information_schema.SCHEMA_PRIVILEGES WHERE GRANTEE=CONCAT(QUOTE(SUBSTRING_INDEX(CURRENT_USER(),'@',1)), '@', QUOTE(SUBSTRING_INDEX(CURRENT_USER(),'@',-1))); SELECT COUNT(*) FROM auditoria_eventos;"
    $mongo = Invoke-MongoEval 'const s=db.runCommand({connectionStatus:1,showPrivileges:false}); print(JSON.stringify({usuario:s.authInfo.authenticatedUsers,roles:s.authInfo.authenticatedUserRoles,auditoria:db.auditoria_documental.countDocuments({})}))'
    if ($maria.Output -notmatch '(?m)^moodsitto\s+SELECT\s*$' -or $mongo.Output -notmatch 'readWrite') { return New-Result PENDIENTE 'Falta comprobar acceso SQL al esquema o el rol documental de aplicación.' ("MariaDB:`n$($maria.Output)`nMongoDB:`n$($mongo.Output)") }
    New-Result APROBADO 'Las cuentas de aplicación autenticaron y pudieron consultar ambas auditorías.' ("MariaDB:`n$($maria.Output)`nMongoDB:`n$($mongo.Output)")
}

function Test-Backups {
    # systemd registra cuándo terminó el trabajo sin dar permiso de lectura sobre las copias.
    $command = 'systemctl is-active {0}.timer; systemctl show {0}.service -p Result -p ExecMainStatus -p ExecMainExitTimestamp'
    $hp = Invoke-SshCommand $script:Config.HpSsh ($command -f 'moodsitto-mariadb-backup') -AllowFailure
    $vps = Invoke-SshCommand $script:Config.VpsSsh ($command -f 'moodsitto-mongodb-backup') -AllowFailure
    $detalle = "HP/MariaDB:`n$($hp.Output)`nVPS/MongoDB:`n$($vps.Output)"
    foreach ($nodo in $hp, $vps) {
        if ($nodo.Code -ne 0) { return New-Result BLOQUEADO 'No se pudo consultar el estado de los trabajos por SSH.' $detalle }
        if ($nodo.Output -notmatch '(?m)^active\s*$' -or $nodo.Output -notmatch '(?m)^Result=success\s*$' -or
            $nodo.Output -notmatch '(?m)^ExecMainStatus=0\s*$' -or $nodo.Output -notmatch '(?m)^ExecMainExitTimestamp=\S') {
            return New-Result PENDIENTE 'Se requiere un temporizador activo y una ejecución exitosa en ambos motores.' $detalle
        }
    }
    New-Result APROBADO 'Ambos temporizadores están activos y systemd confirmó la última ejecución. Las filas de restauración verifican el contenido.' $detalle
}

function Test-MariaRestore {
    param([switch]$ApiCore)
    $esquema = if ($ApiCore) { 'apicore' } else { 'moodsitto' }
    $latest = Invoke-SshCommand $script:Config.HpSsh "set -o pipefail; sudo -n find /srv/storage/moodsitto/backups/mariadb -maxdepth 1 -type f -name '${esquema}-*.sql.gz' | sort | tail -n 1" -AllowFailure
    if ($latest.Code -ne 0) { return New-Result BLOQUEADO 'Se requiere acceso a los respaldos protegidos en el HP.' $latest.Output }
    if (-not $latest.Output) { return New-Result PENDIENTE "No se encontró un respaldo de $esquema para restaurar." }
    try {
        $output = Invoke-RemoteScript $script:Config.HpSsh (Join-Path $script:Repo 'mariadb\restauracion\probar-restauracion.sh') $latest.Output -UseSudo
    } catch {
        throw "[BLOQUEADO] La restauración MariaDB necesita sudo temporal en la HP. Habilítalo solo para la presentación y vuelve a ejecutar esta fila. Detalle: $($_.Exception.Message)"
    }
    $esperado = if ($ApiCore) { 'Restauración aislada de APIcore aprobada' } else { '23 tablas base' }
    if ($output -notmatch $esperado) { return New-Result PENDIENTE "La restauración no confirmó las tablas esperadas en $esquema." $output }
    New-Result APROBADO 'El respaldo MariaDB se restauró en una base aislada, se validó y se eliminó al terminar.' $output
}

function Test-MongoRestore {
    $latest = Invoke-SshCommand $script:Config.VpsSsh "find /var/backups/moodsitto/mongodb -maxdepth 1 -type f -name '*.archive.gz' -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -n 1 | cut -d' ' -f2-"
    if (-not $latest.Output) { return New-Result PENDIENTE 'No se encontró un respaldo MongoDB para restaurar.' }
    $output = Invoke-RemoteScript $script:Config.VpsSsh (Join-Path $script:Repo 'mongodb\restauracion\probar-restauracion.sh') $latest.Output
    if ($output -notmatch '4 colecciones') { return New-Result PENDIENTE 'La restauración terminó, pero no recuperó las cuatro colecciones esperadas.' $output }
    New-Result APROBADO 'El respaldo MongoDB se restauró en una base aislada, se validó y se eliminó al terminar.' $output
}

function Test-Monitoring {
    $monitor = Join-Path $script:Repo 'monitoreo\scripts\estado-general.ps1'
    Register-TestCommand $monitor
    $output = & $monitor 2>&1 | Out-String
    $hp = Invoke-SshCommand $script:Config.HpSsh "printf 'RAM y swap\n'; free -h; printf 'Discos\n'; df -h / /srv/storage; printf 'Runners\n'; systemctl list-units --type=service --state=running 'actions.runner*' --no-legend; printf 'MariaDB\n'; systemctl is-active mariadb"
    $vps = Invoke-SshCommand $script:Config.VpsSsh "printf 'RAM y swap\n'; free -h; printf 'Disco\n'; df -h /; printf 'MongoDB\n'; systemctl is-active mongod"
    $runnerCount = ([regex]::Matches($hp.Output, 'actions\.runner')).Count
    if ($output -match 'FALLO' -or $runnerCount -lt 2) { return New-Result PENDIENTE 'El monitoreo encontró un servicio, puerto o runner que necesita revisión.' ("Red:`n$output`nHP:`n$($hp.Output)`nVPS:`n$($vps.Output)") }
    New-Result APROBADO 'El monitoreo revisó red, puertos, RAM, swap, discos, motores y los dos runners del HP.' ("Red:`n$output`nHP:`n$($hp.Output)`nVPS:`n$($vps.Output)")
}

function Test-BackendPackage {
    $required = @('README_EMPIEZA_AQUI.md','.env.example','configurar.ps1','configurar.sh','probar-conexiones.ps1','probar-conexiones.sh','ERRORES_FRECUENTES.md','INTEGRACION_BACKEND_MOODSITTO.md','CHECKLIST_BACKEND.md','CONTRATO_DATOS_MOODSITTO.md')
    $missing = $required | Where-Object {
        $path = Join-Path $script:Repo "backend-integracion\$_"
        Register-TestCommand 'Test-Path' @($path)
        -not (Test-Path $path)
    }
    if ($missing) { return New-Result PENDIENTE 'El paquete para backend está incompleto.' ($missing -join ', ') }
    if (-not $script:Config.MariaPassword -or -not $script:Config.MongoPassword) { return New-Result BLOQUEADO 'El paquete está completo, pero faltan credenciales para ejecutar la prueba real de integración.' }
    $maria = Test-MariaPrimary
    $mongo = Test-MongoReplication
    if ($maria.Status -ne 'APROBADO' -or $mongo.Status -ne 'APROBADO') { return New-Result PENDIENTE 'El paquete existe, pero alguna conexión real del backend falló.' ("MariaDB: $($maria.Summary)`nMongoDB: $($mongo.Summary)") }
    New-Result APROBADO 'El paquete sencillo para backend está completo y las conexiones reales de aplicación funcionan.' 'Se comprobaron archivos, autenticación, lectura y escritura sintética en ambos motores.'
}

function Test-Security {
    Register-TestCommand 'git' @('-C', $script:Repo, 'ls-files')
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

# El controlador /health de APIcore ejecuta SELECT 1 por PDO.
function Test-ApiCore {
    $url = 'http://localhost:8000/health'
    try {
        Register-TestCommand 'Invoke-RestMethod' @('-Uri', $url, '-Method', 'Get', '-TimeoutSec', '8') 'GET /health ejecuta SELECT 1 en APIcore.' -PowerShell
        $response = Invoke-RestMethod -Uri $url -Method Get -TimeoutSec 8
    } catch {
        $http = $_.Exception.Response
        if ($http -and [int]$http.StatusCode -eq 503) {
            return New-Result PENDIENTE 'APIcore respondió 503. Revisa su acceso a MariaDB.' $url
        }
        return New-Result BLOQUEADO 'No se pudo consultar APIcore en el puerto local 8000. Comprueba el servidor PHP.' $url
    }
    if ($response.status -ne 'ok' -or $response.message -ne 'Server is running') {
        return New-Result PENDIENTE 'El servicio local respondió con un formato distinto al health de APIcore.' $url
    }
    New-Result APROBADO 'APIcore respondió y su conexión SQL ejecutó SELECT 1.' $url
}

# Las restauraciones se ejecutan por separado y requieren confirmación.
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
    [pscustomobject]@{ Id='restore-mongo'; Name='14B. Restauración aislada MongoDB'; Objective='Recuperar las colecciones en un espacio temporal'; Safe=$false; Confirm=$true; Action={ Test-MongoRestore } },
    [pscustomobject]@{ Id='restore-apicore'; Name='14C. Restauración aislada de APIcore'; Objective='Recuperar cuentas y recordatorios fuera de producción'; Safe=$false; Confirm=$true; Action={ Test-MariaRestore -ApiCore } },
    [pscustomobject]@{ Id='monitor'; Name='15. Monitoreo y runners'; Objective='Red, recursos, motores y runners HP'; Safe=$true; Confirm=$false; Action={ Test-Monitoring } },
    [pscustomobject]@{ Id='backend'; Name='Paquete para backend'; Objective='Asistente y conexiones de aplicación'; Safe=$true; Confirm=$false; Action={ Test-BackendPackage } },
    [pscustomobject]@{ Id='apicore'; Name='APIcore local y MariaDB'; Objective='GET /health y SELECT 1 por PDO'; Safe=$true; Confirm=$false; Action={ Test-ApiCore } },
    [pscustomobject]@{ Id='security'; Name='Seguridad y exposición de red'; Objective='Secretos, respaldos y escuchas privadas'; Safe=$true; Confirm=$false; Action={ Test-Security } },
    [pscustomobject]@{ Id='recovery'; Name='16. Recuperación ante fallos'; Objective='Revisión segura; caída solo con autorización'; Safe=$true; Confirm=$false; Action={ Test-RecoveryReadiness } }
)

if ($SelfTest) {
    $ids = $script:Tests.Id
    if (($ids | Select-Object -Unique).Count -ne $ids.Count) { throw 'Hay identificadores de prueba duplicados.' }
    if ($ids -notcontains 'apicore' -or $script:Tests.Count -lt 19) { throw 'La interfaz no contiene todas las pruebas planeadas.' }
    $script:Config.MongoPassword = 'clave sintética@'
    $script:ActiveCommands = [Collections.Generic.List[string]]::new()
    Register-TestCommand 'mongosh' @('--eval', "print('prueba')", [Uri]::EscapeDataString($script:Config.MongoPassword))
    if ($script:ActiveCommands[0] -ne "& 'mongosh' '--eval' 'print(''prueba'')' '[OCULTO]'") {
        throw 'El registro de comandos debe conservar las comillas y ocultar la contraseña.'
    }
    if ((Get-RecoveryTargets).Unit -join ',' -ne 'mariadb,mongod' -or
        (Get-RecoveryCommand Ensayar mongod 'moodsitto-recuperar-123456789abc') -notmatch '--on-active=45s .* start mongod && .* stop mongod') {
        throw 'La recuperación debe programar el arranque del motor antes de detenerlo.'
    }
    Write-Output "[OK] Interfaz válida: $($script:Tests.Count) pruebas registradas."
    exit 0
}

if ($CheckApiCore) {
    $result = Test-ApiCore
    $result | Format-List
    if ($result.Status -ne 'APROBADO') { exit 1 }
    exit 0
}

if (-not $IsWindows -and $PSVersionTable.PSVersion.Major -ge 6) {
    throw 'Esta interfaz usa Windows Forms y debe abrirse desde Windows.'
}

function Import-EnvConfig {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return $false }
    $values = @{}
    Get-Content -LiteralPath $Path | ForEach-Object {
        if ($_ -match '^\s*([^#][^=]*)=(.*)$') { $values[$matches[1].Trim()] = $matches[2] }
    }
    if ($values.DB_USER) { $script:Config.MariaUser = $values.DB_USER }
    if ($values.DB_PASS) { $script:Config.MariaPassword = $values.DB_PASS }
    if ($values.MONGODB_USER) { $script:Config.MongoUser = $values.MONGODB_USER }
    if ($values.MONGODB_PASSWORD) { $script:Config.MongoPassword = $values.MONGODB_PASSWORD }
    return (-not [string]::IsNullOrWhiteSpace($script:Config.MariaPassword) -and -not [string]::IsNullOrWhiteSpace($script:Config.MongoPassword))
}

function Initialize-SecureConfig {
    $envPath = Join-Path $script:Repo 'backend-integracion\.env'
    if (Import-EnvConfig $envPath) { return 'Credenciales locales cargadas de forma segura' }

    $mariaSecret = Join-Path $script:Repo 'secrets\windows-fixed.env'
    if (Test-Path $mariaSecret) {
        $line = Get-Content -LiteralPath $mariaSecret | Where-Object { $_ -match '^MARIADB_APP_PASSWORD=' } | Select-Object -First 1
        if ($line) { $script:Config.MariaPassword = $line.Substring($line.IndexOf('=') + 1) }
    }
    try {
        $mongoLine = & ssh -o BatchMode=yes -o ConnectTimeout=5 $script:Config.VpsSsh "grep '^MONGO_APP_PASS=' /root/.moodsitto-secrets.env" 2>$null | Select-Object -First 1
        if ($LASTEXITCODE -eq 0 -and $mongoLine) { $script:Config.MongoPassword = $mongoLine.Substring($mongoLine.IndexOf('=') + 1) }
    } catch { }

    if (-not [string]::IsNullOrWhiteSpace($script:Config.MariaPassword) -and -not [string]::IsNullOrWhiteSpace($script:Config.MongoPassword)) {
        return 'Credenciales seguras cargadas automáticamente'
    }
    return 'No se encontraron todas las credenciales; las pruebas autenticadas aparecerán BLOQUEADAS'
}

function Sync-FormConfig {
    $script:Config.HpSsh = $script:HpSshBox.Text.Trim()
    $script:Config.VpsSsh = $script:VpsSshBox.Text.Trim()
}

$script:CredentialStatus = Initialize-SecureConfig

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

function Update-Summary {
    $counts = @{ APROBADO=0; PENDIENTE=0; BLOQUEADO=0; 'NO EJECUTADO'=0 }
    foreach ($row in $script:Grid.Rows) {
        $state = [string]$row.Cells['Estado'].Value
        if ($counts.ContainsKey($state)) { $counts[$state]++ }
    }
    $script:SummaryLabel.Text = "APROBADO $($counts.APROBADO)   |   PENDIENTE $($counts.PENDIENTE)   |   BLOQUEADO $($counts.BLOQUEADO)   |   SIN EJECUTAR $($counts['NO EJECUTADO'])"
}

function Show-SelectedCommands {
    if ($script:Grid.SelectedRows.Count -eq 0) {
        $script:CommandBox.Text = 'Selecciona una prueba en la tabla.'
        return
    }
    $row = $script:Grid.SelectedRows[0]
    $heading = [string]$row.Cells['Prueba'].Value
    $body = if ($null -eq $row.Tag) { 'Ejecuta esta prueba para ver sus comandos.' }
        elseif ($row.Tag.Commands.Count -eq 0) { 'La prueba terminó antes de ejecutar comandos.' }
        else { $row.Tag.Commands -join "`r`n`r`n" }
    $script:CommandBox.Text = "$heading`r`n`r`n$body"
}

function Set-RowResult {
    param([int]$RowIndex, $Result, [string[]]$Commands)
    $row = $script:Grid.Rows[$RowIndex]
    $row.Cells['Estado'].Value = $Result.Status
    $row.Cells['Resultado'].Value = Protect-LogText $Result.Summary
    $row.Tag = [pscustomobject]@{ Commands = $Commands; Details = (Protect-LogText $Result.Details) }
    $color = switch ($Result.Status) {
        'APROBADO' { [Drawing.Color]::FromArgb(220,252,231) }
        'PENDIENTE' { [Drawing.Color]::FromArgb(254,249,195) }
        'BLOQUEADO' { [Drawing.Color]::FromArgb(254,226,226) }
    }
    $row.DefaultCellStyle.BackColor = $color
    Update-Summary
    Show-SelectedCommands
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
    $script:CommandBox.Text = "$($test.Name)`r`n`r`nEjecutando la prueba…"
    Write-Log "Iniciando: $($test.Name)"
    $script:ActiveCommands = [Collections.Generic.List[string]]::new()
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
    } finally {
        $commands = $script:ActiveCommands.ToArray()
        $script:ActiveCommands = $null
    }
    Set-RowResult $RowIndex $result $commands
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
    $lines.Add('## Comandos y detalles')
    foreach ($row in $script:Grid.Rows) {
        if ($row.Tag) {
            $lines.Add('')
            $lines.Add("### $($row.Cells['Prueba'].Value)")
            if ($row.Tag.Commands.Count -gt 0) {
                $lines.Add('```powershell')
                $lines.Add(($row.Tag.Commands -join "`n`n"))
                $lines.Add('```')
            } else {
                $lines.Add('La prueba terminó antes de ejecutar comandos.')
            }
            if ($row.Tag.Details) {
                $lines.Add('')
                $lines.Add('```text')
                $lines.Add($row.Tag.Details)
                $lines.Add('```')
            }
        }
    }
    if ($script:OperationHistory.Count -gt 0) {
        $lines.Add('')
        $lines.Add('## Operaciones de esta sesión')
        $lines.Add('```text')
        $lines.Add(($script:OperationHistory.ToArray() -join "`n`n"))
        $lines.Add('```')
    }
    [IO.File]::WriteAllLines($file, $lines, [Text.UTF8Encoding]::new($false))
    Write-Log "Reporte guardado en $file" 'OK'
    [Windows.Forms.MessageBox]::Show("Reporte guardado en:`n$file", 'Reporte listo', 'OK', 'Information') | Out-Null
}

$form = [Windows.Forms.Form]::new()
$form.Text = 'Moodsitto DB Manager | Operación y pruebas'
$form.StartPosition = 'CenterScreen'
$form.Size = [Drawing.Size]::new(1320, 860)
$form.MinimumSize = [Drawing.Size]::new(1100, 720)
$form.BackColor = [Drawing.ColorTranslator]::FromHtml('#F8FAFC')
$form.Font = [Drawing.Font]::new('Segoe UI', 10)
$form.AutoScaleMode = 'Dpi'
$blue = [Drawing.ColorTranslator]::FromHtml('#1D4ED8')
$ink = [Drawing.ColorTranslator]::FromHtml('#1E293B')
$slate = [Drawing.ColorTranslator]::FromHtml('#475569')
$green = [Drawing.ColorTranslator]::FromHtml('#047857')
$red = [Drawing.ColorTranslator]::FromHtml('#B91C1C')

$header = [Windows.Forms.Panel]::new()
$header.Dock = 'Top'
$header.Height = 86
$header.BackColor = $ink
$form.Controls.Add($header)

$title = [Windows.Forms.Label]::new()
$title.Text = 'Moodsitto DB Manager'
$title.ForeColor = [Drawing.Color]::White
$title.Font = [Drawing.Font]::new('Segoe UI Semibold', 23)
$title.AutoSize = $true
$title.Location = [Drawing.Point]::new(22, 12)
$header.Controls.Add($title)

$subtitle = [Windows.Forms.Label]::new()
$subtitle.Text = 'Pruebas y operación de la infraestructura'
$subtitle.ForeColor = [Drawing.Color]::FromArgb(203,213,225)
$subtitle.AutoSize = $true
$subtitle.Location = [Drawing.Point]::new(25, 55)
$header.Controls.Add($subtitle)

$settings = [Windows.Forms.GroupBox]::new()
$settings.Text = 'Conexiones de la presentación'
$settings.Dock = 'Top'
$settings.Height = 82
$settings.Padding = [Windows.Forms.Padding]::new(12)
$form.Controls.Add($settings)

$navigation = [Windows.Forms.TabControl]::new()
$navigation.Dock = 'Fill'
$navigation.ItemSize = [Drawing.Size]::new(177, 38)
$navigation.SizeMode = 'Fixed'
$form.Controls.Add($navigation)
$navigation.BringToFront()
$header.SendToBack()
$testPage = [Windows.Forms.TabPage]::new('Pruebas')
$localPage = [Windows.Forms.TabPage]::new('Inicio local')
$recoveryPage = [Windows.Forms.TabPage]::new('Recuperación')
$navigation.TabPages.AddRange(@($testPage, $localPage, $recoveryPage))

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
    $box.AccessibleName = $Label
    if ($Password) { $box.UseSystemPasswordChar = $true }
    $Parent.Controls.Add($box)
    $box
}

$script:HpSshBox = Add-Field $settings 'SSH de HP' 18 24 210 $script:Config.HpSsh
$script:VpsSshBox = Add-Field $settings 'SSH del VPS' 244 24 210 $script:Config.VpsSsh

$credentialLabel = [Windows.Forms.Label]::new()
$credentialLabel.Text = $script:CredentialStatus
$credentialLabel.AutoSize = $true
$credentialLabel.Font = [Drawing.Font]::new('Segoe UI Semibold', 9)
$credentialLabel.ForeColor = if ($script:CredentialStatus -like 'No se*') { [Drawing.Color]::FromArgb(185,28,28) } else { [Drawing.Color]::FromArgb(4,120,87) }
$credentialLabel.Location = [Drawing.Point]::new(480, 46)
$settings.Controls.Add($credentialLabel)

$main = [Windows.Forms.SplitContainer]::new()
$main.Dock = 'Fill'
$main.Orientation = 'Horizontal'
$main.SplitterDistance = 390
$main.Panel1MinSize = 260
$main.Panel2MinSize = 140
$testPage.Controls.Add($main)
$main.BringToFront()

$toolbar = [Windows.Forms.FlowLayoutPanel]::new()
$toolbar.Dock = 'Top'
$toolbar.Height = 92
$toolbar.Padding = [Windows.Forms.Padding]::new(8,8,0,0)
$main.Panel1.Controls.Add($toolbar)

function New-PanelButton {
    param($Parent, [string]$Text, [int]$Width, [Drawing.Color]$Color)
    $button = [Windows.Forms.Button]::new()
    $button.Text = $Text
    $button.Width = $Width
    $button.Height = 40
    $button.Margin = [Windows.Forms.Padding]::new(4, 2, 8, 4)
    $button.Cursor = [Windows.Forms.Cursors]::Hand
    $button.FlatStyle = 'Flat'
    $button.BackColor = $Color
    $button.ForeColor = [Drawing.Color]::White
    $button.FlatAppearance.BorderSize = 0
    $Parent.Controls.Add($button)
    $button
}

$runSelectedButton = New-PanelButton $toolbar 'Ejecutar seleccionada' 182 $blue
$runSafeButton = New-PanelButton $toolbar 'Ejecutar todas las seguras' 204 $green
$exportButton = New-PanelButton $toolbar 'Exportar reporte' 138 $slate
$guideButton = New-PanelButton $toolbar 'Abrir guía' 108 $slate

$script:SummaryLabel = [Windows.Forms.Label]::new()
$script:SummaryLabel.AutoSize = $true
$script:SummaryLabel.Margin = [Windows.Forms.Padding]::new(7,8,0,0)
$script:SummaryLabel.Font = [Drawing.Font]::new('Segoe UI Semibold', 10)
$toolbar.SetFlowBreak($guideButton, $true)
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
$script:Grid.GridColor = [Drawing.ColorTranslator]::FromHtml('#E2E8F0')
$script:Grid.DefaultCellStyle.Padding = [Windows.Forms.Padding]::new(6,5,6,5)
$script:Grid.DefaultCellStyle.WrapMode = 'True'
$script:Grid.DefaultCellStyle.ForeColor = $ink
$script:Grid.ColumnHeadersHeight = 36
$script:Grid.ColumnHeadersHeightSizeMode = 'DisableResizing'
$script:Grid.ColumnHeadersDefaultCellStyle.BackColor = [Drawing.Color]::FromArgb(226,232,240)
$script:Grid.EnableHeadersVisualStyles = $false
$script:Grid.Columns.Add('Estado','Estado') | Out-Null
$script:Grid.Columns.Add('Prueba','Prueba') | Out-Null
$script:Grid.Columns.Add('Objetivo','Qué comprueba') | Out-Null
$script:Grid.Columns.Add('Resultado','Resultado') | Out-Null
$script:Grid.Columns['Estado'].Width = 126
$script:Grid.Columns['Prueba'].Width = 280
$script:Grid.Columns['Objetivo'].Width = 280
$script:Grid.Columns['Resultado'].AutoSizeMode = 'Fill'
foreach ($test in $script:Tests) {
    $index = $script:Grid.Rows.Add('NO EJECUTADO', $test.Name, $test.Objective, '—')
    $script:Grid.Rows[$index].DefaultCellStyle.BackColor = if ($index % 2) { [Drawing.ColorTranslator]::FromHtml('#F1F5F9') } else { [Drawing.Color]::White }
}
$main.Panel1.Controls.Add($script:Grid)
$script:Grid.BringToFront()

$tabs = [Windows.Forms.TabControl]::new()
$tabs.Dock = 'Fill'
$commandTab = [Windows.Forms.TabPage]::new('Comandos de la prueba')
$activityTab = [Windows.Forms.TabPage]::new('Actividad')
$tabs.TabPages.AddRange(@($commandTab, $activityTab))
$main.Panel2.Controls.Add($tabs)

$script:CommandBox = [Windows.Forms.TextBox]::new()
$script:CommandBox.Multiline = $true
$script:CommandBox.ReadOnly = $true
$script:CommandBox.ScrollBars = 'Both'
$script:CommandBox.WordWrap = $false
$script:CommandBox.Dock = 'Fill'
$script:CommandBox.Font = [Drawing.Font]::new('Consolas', 10)
$commandTab.Controls.Add($script:CommandBox)

$script:LogBox = [Windows.Forms.RichTextBox]::new()
$script:LogBox.Dock = 'Fill'
$script:LogBox.ReadOnly = $true
$script:LogBox.BackColor = [Drawing.Color]::FromArgb(15,23,42)
$script:LogBox.ForeColor = [Drawing.Color]::FromArgb(226,232,240)
$script:LogBox.Font = [Drawing.Font]::new('Cascadia Mono', 9)
$script:LogBox.BorderStyle = 'None'
$activityTab.Controls.Add($script:LogBox)

function New-OperationPage {
    param($Page, [string]$Title, [string]$Description, [int]$Height)
    $Page.Padding = [Windows.Forms.Padding]::new(18, 14, 18, 16)
    $Page.BackColor = $form.BackColor
    $card = [Windows.Forms.Panel]::new()
    $card.Dock = 'Top'
    $card.Height = $Height
    $card.BackColor = [Drawing.Color]::White
    $Page.Controls.Add($card)
    $heading = [Windows.Forms.Label]::new()
    $heading.AutoSize = $true
    $heading.Location = [Drawing.Point]::new(18, 14)
    $heading.Font = [Drawing.Font]::new('Segoe UI Semibold', 16)
    $heading.ForeColor = $ink
    $heading.Text = $Title
    $card.Controls.Add($heading)
    $descriptionLabel = [Windows.Forms.Label]::new()
    $descriptionLabel.AutoSize = $true
    $descriptionLabel.Location = [Drawing.Point]::new(20, 50)
    $descriptionLabel.ForeColor = $slate
    $descriptionLabel.Text = $Description
    $card.Controls.Add($descriptionLabel)

    $evidence = [Windows.Forms.GroupBox]::new()
    $evidence.Text = 'Actividad y comandos'
    $evidence.Dock = 'Fill'
    $evidence.Padding = [Windows.Forms.Padding]::new(8)
    $Page.Controls.Add($evidence)
    $evidence.BringToFront()
    $outputBox = [Windows.Forms.TextBox]::new()
    $outputBox.Dock = 'Fill'
    $outputBox.Multiline = $true
    $outputBox.ReadOnly = $true
    $outputBox.ScrollBars = 'Both'
    $outputBox.WordWrap = $false
    $outputBox.Font = [Drawing.Font]::new('Consolas', 10)
    $outputBox.BackColor = [Drawing.Color]::White
    $evidence.Controls.Add($outputBox)
    [pscustomobject]@{ Card = $card; Output = $outputBox }
}

function New-OperationButtons {
    param($Card, [int]$Y)
    $bar = [Windows.Forms.FlowLayoutPanel]::new()
    $bar.Location = [Drawing.Point]::new(14, $Y)
    $bar.Size = [Drawing.Size]::new(960, 50)
    $Card.Controls.Add($bar)
    $bar
}

function Invoke-PanelOperation {
    param([string]$Title, $OutputBox, [scriptblock]$Operation)
    if ($script:Running) { return }
    $script:Running = $true
    $script:RunningOperation = $true
    $script:OperationLogBox = $OutputBox
    $script:ActiveCommands = [Collections.Generic.List[string]]::new()
    $OutputBox.Clear()
    $form.UseWaitCursor = $true
    try {
        Sync-FormConfig
        Write-Log $Title
        & $Operation
    } catch {
        Write-Log $_.Exception.Message 'PENDIENTE'
    } finally {
        if ($script:ActiveCommands.Count) {
            Write-Log ("`n" + ($script:ActiveCommands.ToArray() -join "`n`n")) 'COMANDOS'
        }
        $script:OperationHistory.Add($OutputBox.Text.Trim())
        $script:ActiveCommands = $null
        $script:OperationLogBox = $null
        $script:RunningOperation = $false
        $script:Running = $false
        $form.UseWaitCursor = $false
    }
}

$desktop = [Environment]::GetFolderPath('Desktop')
$localUi = New-OperationPage $localPage 'Servicios de esta computadora' 'Arranca el API y el sitio en tu computadora para la presentación.' 288
$apiPathBox = Add-Field $localUi.Card 'Carpeta del repositorio APIcore' 20 76 730 (Join-Path $desktop 'Baits-demo')
$frontPathBox = Add-Field $localUi.Card 'Carpeta del repositorio Fronted' 20 128 730 (Join-Path $desktop 'Baits-frontend')
$phpPathBox = Add-Field $localUi.Card 'Ruta de php.exe' 20 180 730 'C:\xampp\php\php.exe'
foreach ($field in @(
    @{ Box = $apiPathBox; Y = 91; Name = 'Buscar carpeta de APIcore' },
    @{ Box = $frontPathBox; Y = 143; Name = 'Buscar carpeta de Fronted' },
    @{ Box = $phpPathBox; Y = 195; Name = 'Buscar php.exe' }
)) {
    $browse = [Windows.Forms.Button]::new()
    $browse.Text = 'Examinar…'
    $browse.AccessibleName = $field.Name
    $browse.Location = [Drawing.Point]::new(762, $field.Y)
    $browse.Size = [Drawing.Size]::new(108, 32)
    $browse.Tag = $field.Box
    $browse.Add_Click({
        param($sender, $eventArgs)
        $box = $sender.Tag
        if ($box -eq $phpPathBox) {
            $picker = [Windows.Forms.OpenFileDialog]::new()
            $picker.Filter = 'PHP (php.exe)|php.exe'
            $picker.FileName = $box.Text
        } else {
            $picker = [Windows.Forms.FolderBrowserDialog]::new()
            $picker.SelectedPath = $box.Text
        }
        try {
            if ($picker.ShowDialog($form) -eq 'OK') {
                $box.Text = if ($box -eq $phpPathBox) { $picker.FileName } else { $picker.SelectedPath }
            }
        } finally { $picker.Dispose() }
    })
    $localUi.Card.Controls.Add($browse)
}
$localButtons = New-OperationButtons $localUi.Card 232
$startApiButton = New-PanelButton $localButtons 'Iniciar APIcore' 140 $blue
$startFrontButton = New-PanelButton $localButtons 'Iniciar frontend PHP' 164 $blue
$localStatusButton = New-PanelButton $localButtons 'Ver estado' 110 $slate
$browserButton = New-PanelButton $localButtons 'Abrir sitio' 105 $slate

$recoveryUi = New-OperationPage $recoveryPage 'Recuperación de servidores' 'Elige el equipo y revisa su estado antes de interrumpir el servicio.' 213
$targetLabel = [Windows.Forms.Label]::new()
$targetLabel.Location = [Drawing.Point]::new(20, 80)
$targetLabel.AutoSize = $true
$targetLabel.Text = 'Equipo y motor'
$recoveryUi.Card.Controls.Add($targetLabel)
$targetChoice = [Windows.Forms.ComboBox]::new()
$targetChoice.DropDownStyle = 'DropDownList'
$targetChoice.Location = [Drawing.Point]::new(20, 103)
$targetChoice.Width = 310
$targetChoice.AccessibleName = 'Equipo y motor'
$targetChoice.Items.AddRange(@((Get-RecoveryTargets).Name))
$targetChoice.SelectedIndex = 0
$recoveryUi.Card.Controls.Add($targetChoice)
$recoveryButtons = New-OperationButtons $recoveryUi.Card 153
$statusButton = New-PanelButton $recoveryButtons 'Ver estado' 110 $slate
$startMotorButton = New-PanelButton $recoveryButtons 'Iniciar motor' 120 $blue
$outageButton = New-PanelButton $recoveryButtons 'Ensayar caída del motor' 194 $red
$rebootButton = New-PanelButton $recoveryButtons 'Reiniciar servidor' 162 $red

$startApiButton.Add_Click({
    Invoke-PanelOperation 'Iniciar APIcore · localhost:8000' $localUi.Output {
        Start-LocalDemoService APIcore $apiPathBox.Text.Trim() $phpPathBox.Text.Trim()
    }
})
$startFrontButton.Add_Click({
    Invoke-PanelOperation 'Iniciar frontend PHP · localhost:5500' $localUi.Output {
        Start-LocalDemoService Frontend $frontPathBox.Text.Trim() $phpPathBox.Text.Trim()
    }
})
$localStatusButton.Add_Click({
    Invoke-PanelOperation 'Comprobar PHP y servicios locales' $localUi.Output {
        $php = $phpPathBox.Text.Trim()
        if (Test-Path -LiteralPath $php -PathType Leaf) {
            Register-TestCommand $php @('-v')
            Write-Log ((& $php -v | Select-Object -First 1) -join ' ')
            Register-TestCommand $php @('-m')
            $modules = & $php -m
            $missing = @('pdo_mysql', 'mbstring', 'mongodb' | Where-Object { $_ -notin $modules })
            if ($missing.Count) { Write-Log "Módulos PHP pendientes · $($missing -join ', ')" 'PENDIENTE' }
            else { Write-Log 'Módulos PHP disponibles · pdo_mysql, mbstring y mongodb' 'OK' }
        } else { Write-Log "No se encontró php.exe en $php." 'PENDIENTE' }
        Register-TestCommand 'Get-Service' @('-Name', 'MongoDB', '-ErrorAction', 'SilentlyContinue') -PowerShell
        $localMongo = Get-Service -Name MongoDB -ErrorAction SilentlyContinue
        if ($localMongo) { Write-Log "MongoDB en esta computadora · $($localMongo.Status)" }
        $result = Test-ApiCore
        Write-Log "APIcore · $($result.Summary)" $result.Status
        $url = 'http://localhost:5500/login.html'
        Register-TestCommand 'Invoke-WebRequest' @('-Uri', $url, '-TimeoutSec', '4', '-UseBasicParsing') -PowerShell
        try {
            $page = Invoke-WebRequest -Uri $url -TimeoutSec 4 -UseBasicParsing
            Write-Log "Frontend HTML · HTTP $($page.StatusCode)" 'OK'
        } catch { Write-Log 'El frontend no respondió en localhost:5500.' 'PENDIENTE' }
    }
})
$browserButton.Add_Click({ Start-Process 'http://localhost:5500/login.html' })

$statusButton.Tag = 'Estado'
$startMotorButton.Tag = 'Iniciar'
$outageButton.Tag = 'Ensayar'
$rebootButton.Tag = 'Reiniciar'
foreach ($button in $statusButton, $startMotorButton, $outageButton, $rebootButton) {
    $button.Add_Click({
        param($sender, $eventArgs)
        if ($script:Running) { return }
        Sync-FormConfig
        $target = (Get-RecoveryTargets)[$targetChoice.SelectedIndex]
        $action = [string]$sender.Tag
        if ($action -in 'Ensayar', 'Reiniciar') {
            $description = if ($action -eq 'Ensayar') {
                "Se detendrá $($target.Unit) en $($target.Name). El equipo programa el arranque del motor en 45 segundos."
            } else {
                "Se reiniciará todo el equipo $($target.Name). Se interrumpirán sus servicios y sesiones SSH."
            }
            $answer = [Windows.Forms.MessageBox]::Show($form, "$description`n`n¿Confirmas que hay autorización para hacerlo ahora?",
                'Confirmar interrupción', 'YesNo', 'Warning', 'Button2')
            if ($answer -ne 'Yes') { return }
        }
        Invoke-PanelOperation "$($sender.Text) · $($target.Name)" $recoveryUi.Output { Invoke-RecoveryAction $action $target }
    })
}

$form.Add_FormClosing({
    param($sender, $eventArgs)
    if ($script:RunningOperation) { $eventArgs.Cancel = $true }
})

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
    Show-SelectedCommands
    if ($script:Grid.SelectedRows.Count -gt 0) {
        $details = $script:Grid.SelectedRows[0].Tag.Details
        if ($details) { Write-Log $details 'EVIDENCIA' }
    }
})

Update-Summary
Show-SelectedCommands
$form.ActiveControl = $runSelectedButton
Write-Log "Interfaz lista. $script:CredentialStatus." 'OK'
Write-Log 'Las restauraciones se ejecutan una por una. La prueba de recuperación no detiene servicios.' 'INFO'
if ($UiSmokeTest) {
    # Usa la revisión local del repositorio para comprobar la vista sin depender de la red.
    $form.Add_Shown({
        Invoke-TestRow 0
        if ($script:Grid.Rows[0].Cells['Estado'].Value -ne 'APROBADO' -or
            $script:CommandBox.Text -notmatch 'validar-repositorio\.ps1') {
            $script:UiSmokeFailed = $true
        }
        $navigation.SelectedTab = $localPage
        $localStatusButton.PerformClick()
        if ($localUi.Output.Text -notmatch 'Invoke-RestMethod' -or $localUi.Output.Text -notmatch 'localhost:5500') {
            $script:UiSmokeFailed = $true
        }
        $navigation.SelectedTab = $recoveryPage
        if ($targetChoice.Items.Count -ne 2 -or -not $rebootButton.Visible -or $recoveryUi.Output.Height -lt 100) {
            $script:UiSmokeFailed = $true
        }
        # Comprueba el botón con una respuesta local para que la autoprueba funcione sin SSH.
        function script:Invoke-RecoveryAction {
            param($Mode, $SelectedTarget)
            Write-Log "Control $Mode · $($SelectedTarget.Unit)"
        }
        $targetChoice.SelectedIndex = 1
        $statusButton.PerformClick()
        if ($recoveryUi.Output.Text -notmatch 'Control Estado.*mongod') { $script:UiSmokeFailed = $true }
        $form.Close()
    })
}
[void]$form.ShowDialog()
if ($UiSmokeTest) {
    if ($script:UiSmokeFailed) { throw 'La ventana no mostró el comando de la prueba local.' }
    Write-Output '[OK] Tres secciones abiertas; prueba local, revisión de puertos y registro de comandos comprobados.'
}

