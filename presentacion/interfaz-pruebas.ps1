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
. (Join-Path $PSScriptRoot 'accesos-panel.ps1')
. (Join-Path $PSScriptRoot 'datos-panel.ps1')

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
function Invoke-PanelUtf8Command {
    param([string]$Executable, [string[]]$Arguments)
    $previousEncoding = [Console]::OutputEncoding
    $previousErrorPreference = $ErrorActionPreference
    try {
        # Los clientes devuelven UTF-8 aunque la consola de Windows use una página OEM.
        [Console]::OutputEncoding = [Text.Encoding]::UTF8
        $ErrorActionPreference = 'Continue'
        $lines = & $Executable @Arguments 2>&1
        [pscustomobject]@{ Code = $LASTEXITCODE; Lines = $lines }
    } finally {
        $ErrorActionPreference = $previousErrorPreference
        [Console]::OutputEncoding = $previousEncoding
    }
}

function Invoke-MariaQuery {
    param(
        [string]$HostName,
        [string]$Sql,
        [string]$Database = $script:Config.MariaDatabase,
        [switch]$AllowFailure,
        [pscredential]$Credential,
        [switch]$Vertical
    )
    if (-not $Credential) { Require-Credentials MariaDB }
    $client = Require-Tool 'mariadb' 'Instala únicamente el cliente de MariaDB.'
    $oldPassword = $env:MYSQL_PWD
    $user = if ($Credential) { $Credential.UserName } else { $script:Config.MariaUser }
    try {
        $env:MYSQL_PWD = if ($Credential) { $Credential.GetNetworkCredential().Password } else { $script:Config.MariaPassword }
        $format = if ($Vertical) { @('--vertical') } else { @('--batch','--skip-column-names') }
        $args = @('--connect-timeout=6', '--default-character-set=utf8mb4') + $format + @('-h', $HostName, '-P', "$($script:Config.MariaPort)", '-u', $user)
        if ($Database) { $args += @('-D', $Database) }
        $args += @('-e', $Sql)
        Register-TestCommand $client $args 'MariaDB toma la contraseña de MYSQL_PWD.'
        $result = Invoke-PanelUtf8Command $client $args
        $output = $result.Lines
        $code = $result.Code
        if ($code -ne 0 -and -not $AllowFailure) { throw ($output -join [Environment]::NewLine) }
        $rows = ($output | Where-Object { $_ -is [string] }) -join [Environment]::NewLine
        [pscustomobject]@{ Code = $code; Output = ($output -join [Environment]::NewLine).Trim(); Rows = $rows }
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
    # Un archivo conserva las comillas y permite que mongosh espere las operaciones de la base.
    $sourceFile = Join-Path ([IO.Path]::GetTempPath()) ("moodsitto-mongo-" + [Guid]::NewGuid() + '.js')
    try {
        [IO.File]::WriteAllText($sourceFile, $JavaScript, [Text.UTF8Encoding]::new($false))
        $result = Invoke-PanelUtf8Command $mongosh @('--quiet', $Uri, '-u', $script:Config.MongoUser,
            '-p', $script:Config.MongoPassword, '--file', $sourceFile)
        $output = $result.Lines
        $code = $result.Code
    } finally {
        [IO.File]::Delete($sourceFile)
    }
    if ($code -ne 0 -and -not $AllowFailure) { throw ($output -join [Environment]::NewLine) }
    [pscustomobject]@{ Code = $code; Output = ($output -join [Environment]::NewLine).Trim() }
}

function Invoke-SshCommand {
    param([string]$Target, [string]$Command, [switch]$AllowFailure, [int]$TimeoutSeconds = 45, [string]$DisplayCommand = $Command)
    $ssh = Require-Tool 'ssh' 'Activa el cliente OpenSSH de Windows.'
    $sshArgs = @('-o', 'BatchMode=yes', '-o', 'ConnectTimeout=7', '-o', 'ServerAliveInterval=3',
        '-o', 'ServerAliveCountMax=2', '--', $Target, $Command)
    Register-TestCommand $ssh ($sshArgs[0..($sshArgs.Count-2)] + @($DisplayCommand))

    $info = [Diagnostics.ProcessStartInfo]::new()
    $info.FileName = $ssh
    # ProcessStartInfo.Arguments en PowerShell 5.1 necesita las reglas de comillas de Windows.
    $info.Arguments = ($sshArgs | ForEach-Object {
        $quoted = [regex]::Replace($_, '(\\*)"', '$1$1\"')
        $quoted = [regex]::Replace($quoted, '(\\+)$', '$1$1')
        '"' + $quoted + '"'
    }) -join ' '
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $info.StandardOutputEncoding = [Text.Encoding]::UTF8
    $info.StandardErrorEncoding = [Text.Encoding]::UTF8
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $info
    try {
        [void]$process.Start()
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        $watch = [Diagnostics.Stopwatch]::StartNew()
        while (-not $process.WaitForExit(100)) {
            if ($script:RunningOperation) { [Windows.Forms.Application]::DoEvents() }
            if ($watch.Elapsed.TotalSeconds -ge $TimeoutSeconds) {
                try { $process.Kill() } catch [InvalidOperationException] { }
                $message = "SSH a $Target superó $TimeoutSeconds s. Consulta Ver estado antes de repetir una orden."
                if (-not $AllowFailure) { throw $message }
                return [pscustomobject]@{ Code = 124; Output = $message }
            }
        }
        $code = $process.ExitCode
        $output = ($stdout.GetAwaiter().GetResult().Trim() + [Environment]::NewLine + $stderr.GetAwaiter().GetResult().Trim()).Trim()
        if ($code -ne 0 -and -not $AllowFailure) { throw $output }
        [pscustomobject]@{ Code = $code; Output = $output }
    } finally { $process.Dispose() }
}

function Invoke-RemoteScript {
    param([string]$Target, [string]$LocalScript, [string]$RemoteArgument, [switch]$UseSudo)
    $quotedArgument = "'" + $RemoteArgument.Replace("'", "'`"'`"'") + "'"
    $runner = if ($UseSudo) { "sudo -n bash -s -- $quotedArgument" } else { "bash -s -- $quotedArgument" }
    # Envía el script en UTF-8 con saltos de Linux para que Bash lea bien los acentos y el final del archivo.
    $content = [IO.File]::ReadAllText($LocalScript).Replace("`r`n", "`n")
    $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($content))
    $remote = "set -eo pipefail; printf %s '$encoded' | base64 -d | $runner"
    (Invoke-SshCommand $Target $remote -TimeoutSeconds 90 -DisplayCommand "$runner  # $LocalScript").Output
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
    $sql = "SELECT CONCAT(@@hostname,'|',@@version,'|server_id=',@@server_id,'|read_only=',@@read_only+0,'|log_bin=',@@log_bin+0); SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='moodsitto' AND table_name<>'login_intentos';"
    $result = Invoke-MariaQuery $script:Config.MariaHost $sql
    $lines = $result.Output -split "`r?`n"
    if ($result.Output -notmatch 'read_only=0') { return New-Result PENDIENTE 'El principal de MariaDB aparece en modo de solo lectura.' $result.Output }
    if ($result.Output -notmatch 'log_bin=1') { return New-Result PENDIENTE 'El binlog del principal está desactivado.' $result.Output }
    if ($lines -notcontains '23') { return New-Result PENDIENTE 'El esquema activo no tiene las 23 tablas esperadas.' $result.Output }
    New-Result APROBADO 'MariaDB principal acepta escritura, tiene server_id y conserva las 23 tablas del esquema híbrido.' $result.Output
}

function Test-MariaReplica {
    $sql = "SELECT CONCAT(@@hostname,'|',@@version,'|server_id=',@@server_id,'|read_only=',@@read_only+0) AS nodo; SHOW ALL SLAVES STATUS;"
    $monitorPath = Join-Path $env:LOCALAPPDATA 'Moodsitto\replica-monitor.credential.xml'
    $monitor = if (Test-Path -LiteralPath $monitorPath -PathType Leaf) {
        try { Import-Clixml -LiteralPath $monitorPath -ErrorAction Stop }
        catch { Write-Log 'No se pudo abrir la credencial local de monitoreo de MariaDB.' 'PENDIENTE' }
    }
    $result = if ($monitor -is [pscredential] -and $monitor.UserName -eq 'moodsitto_panel_monitor') {
        Invoke-MariaQuery $script:Config.MariaReplicaHost $sql -Database '' -Credential $monitor -AllowFailure -Vertical
    } else { Invoke-MariaQuery $script:Config.MariaReplicaHost $sql -AllowFailure -Vertical }
    if ($result.Code -ne 0) {
        $statusQuery = "SELECT CONCAT('read_only=',@@read_only+0,'|gtid_aplicado=',@@gtid_slave_pos);"
        $queryOptions = @{ AllowFailure = $true }
        $apiAccess = Get-ApiCoreAccess
        if ($apiAccess) { $queryOptions.Credential = $apiAccess.Maria; $queryOptions.Database = 'apicore' }
        $primary = Invoke-MariaQuery $script:Config.MariaHost 'SELECT @@gtid_binlog_pos;' @queryOptions
        $fallback = Invoke-MariaQuery $script:Config.MariaReplicaHost $statusQuery @queryOptions
        if ($fallback.Code -ne 0) { return New-Result BLOQUEADO 'No se pudo consultar el estado de la réplica MariaDB.' }
        if ($fallback.Output -notmatch 'read_only=1') { return New-Result PENDIENTE 'La réplica responde, pero no está protegida con read_only.' $fallback.Output }
        $gtidFormat = '[0-9]+-[0-9]+-[0-9]+(?:,[0-9]+-[0-9]+-[0-9]+)*'
        $applied = [regex]::Match($fallback.Output, "gtid_aplicado=($gtidFormat)").Groups[1].Value
        $published = [regex]::Match($primary.Output, "(?m)^\s*($gtidFormat)\s*$").Groups[1].Value
        $checkpoint = if ($primary.Code -eq 0 -and $applied -and $applied -eq $published) {
            "El HP aplicó el GTID $applied observado en el principal."
        } elseif ($primary.Code -eq 0 -and $published) {
            "GTID observado en el principal: $published. Registra otra muestra si hubo escrituras entre consultas."
        } else { 'No se pudo leer el GTID del principal.' }
        return New-Result BLOQUEADO 'Réplica accesible en solo lectura. Los hilos y el retraso requieren REPLICA MONITOR.' "read_only=1 | GTID aplicado: $applied.`n$checkpoint"
    }
    # Muestra solo los campos de diagnóstico necesarios para la exposición.
    $details = ($result.Output -split "`r?`n" | Where-Object {
        $_ -match 'read_only=|^\s*(Slave_IO_Running|Slave_SQL_Running|Seconds_Behind_Master|Using_Gtid|Last_IO_Errno|Last_SQL_Errno)\s*:'
    }) -join "`n"
    $lag = [regex]::Match($result.Output, '(?m)^\s*Seconds_Behind_Master:\s*([0-9]+)\s*$')
    $healthy = $result.Output -match '(?m)^\s*Slave_IO_Running:\s*Yes\s*$' -and
        $result.Output -match '(?m)^\s*Slave_SQL_Running:\s*Yes\s*$' -and $result.Output -match 'read_only=1' -and
        $lag.Success -and $result.Output -match '(?m)^\s*Last_IO_Errno:\s*0\s*$' -and
        $result.Output -match '(?m)^\s*Last_SQL_Errno:\s*0\s*$'
    if (-not $healthy) { return New-Result PENDIENTE 'La réplica respondió, pero su estado no coincide con la configuración esperada.' $details }
    New-Result APROBADO "Réplica en solo lectura, ambos hilos activos y retraso observado de $($lag.Groups[1].Value) s." $details
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
            $count = (Invoke-MariaQuery $script:Config.MariaReplicaHost "SELECT COUNT(*) FROM auditoria_eventos WHERE correlacion_id='$id';").Rows
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
    $counts = @($maria.Output -split "`r?`n" | Where-Object { $_ -match '^\d+$' })
    if ($counts.Count -ne 3 -or $counts[0] -ne '23' -or [int]$counts[1] -lt 1 -or [int]$counts[2] -lt 1) {
        return New-Result PENDIENTE 'MariaDB no confirmó las 23 tablas, índices y referencias esperados.' $maria.Output
    }
    $model = $mongo.Output | ConvertFrom-Json
    foreach ($name in @('catalogo_emociones','registros_emocionales','resumenes_emocionales','auditoria_documental')) {
        if ($model.colecciones -notcontains $name) { return New-Result PENDIENTE "Falta la colección $name." $mongo.Output }
    }
    if ($model.validadores -lt 1 -or $model.indices -lt 4) {
        return New-Result PENDIENTE 'MongoDB no confirmó los validadores e índices del modelo.' $mongo.Output
    }
    New-Result APROBADO 'El modelo híbrido tiene 23 tablas, cuatro colecciones, índices, validadores y referencias lógicas por id_user.' ("MariaDB:`n$($maria.Output)`nMongoDB:`n$($mongo.Output)")
}

function Test-Fragmentation {
    $validate = Get-Content -Raw (Join-Path $script:Repo 'laboratorio\reconstruccion\validar.sql')
    $result = Invoke-MariaQuery $script:Config.MariaReplicaHost $validate '' -AllowFailure
    if ($result.Code -ne 0) { return New-Result BLOQUEADO 'No se pudo consultar moodsitto_lab en la HP con la cuenta del panel.' $result.Output }
    $approved = ([regex]::Matches($result.Rows, '(?m)^(horizontal|vertical)\t[1-9][0-9]*\t[1-9][0-9]*\t1\r?$')).Count
    if ($approved -ne 2) { return New-Result PENDIENTE 'La reconstrucción horizontal o vertical no coincidió con su fuente.' $result.Output }
    New-Result APROBADO 'En la HP, UNION ALL y JOIN reconstruyeron los dos conjuntos del laboratorio con el total esperado.' $result.Rows
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
    $restore = Invoke-SshCommand $script:Config.HpSsh "sudo -n /usr/local/sbin/moodsitto-validar-respaldo $esquema" -AllowFailure -TimeoutSeconds 90
    $output = $restore.Output
    if ($restore.Code -ne 0 -and $output -match '(?i)sudo:|permission denied') {
        return New-Result BLOQUEADO 'Falta el permiso restringido de restauración en el HP.' $output
    }
    if ($restore.Code -ne 0) { return New-Result PENDIENTE "La restauración aislada de $esquema no terminó." $output }
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
    $guide = Get-Content -Raw -Encoding UTF8 (Join-Path $script:Repo 'presentacion\contingencia\CONTINGENCIA.md')
    $trial = Read-RecoveryReport MongoDB
    $replicaTrial = Read-RecoveryReport MariaDB
    $primaryTrial = Read-RecoveryReport MariaDB -WindowsFijo
    $details = "MariaDB: $($maria.Status) - $($maria.Summary)`nMongoDB: $($mongo.Status) - $($mongo.Summary)"
    if ($trial) { $details += "`nEnsayo real guardado de MongoDB: $($trial.Status) · $($trial.StartedAt)." }
    if ($replicaTrial) { $details += "`nEnsayo de caída de la réplica MariaDB en la HP: $($replicaTrial.Status) · $($replicaTrial.StartedAt)." }
    if ($primaryTrial) { $details += "`nEnsayo de caída del Windows fijo: $($primaryTrial.Status) · $($primaryTrial.StartedAt)." }
    $details += "`n`nProtocolo:`n$guide"
    if ($maria.Status -ne 'APROBADO' -or $mongo.Status -ne 'APROBADO') {
        return New-Result PENDIENTE 'Falta comprobar el estado actual de los motores.' $details
    }

    $access = Get-ApiCoreAccess
    if (-not $access) { return New-Result BLOQUEADO 'Falta el acceso de APIcore para comparar las versiones de MariaDB.' $details }
    $versions = @(foreach ($node in $script:Config.MariaHost, $script:Config.MariaReplicaHost) {
        $result = Invoke-MariaQuery $node 'SELECT VERSION();' -Database apicore -Credential $access.Maria -AllowFailure
        $match = [regex]::Match($result.Output, '(?m)^([0-9]+\.[0-9]+\.[0-9]+)(?:[-+]|$)')
        if ($result.Code -eq 0 -and $match.Success) { [version]$match.Groups[1].Value }
    })
    if ($versions.Count -ne 2) {
        return New-Result BLOQUEADO 'No se pudieron comprobar las dos versiones de MariaDB.' $details
    }
    $details = "MariaDB Windows fijo: $($versions[0]) · MariaDB HP: $($versions[1]).`n$details"
    if ($versions[0] -lt $versions[1]) {
        return New-Result BLOQUEADO 'Promoción MariaDB bloqueada: el Windows fijo sería una réplica de versión anterior al HP.' $details
    }
    if ($primaryTrial.Status -eq 'APROBADO') {
        $routePath = Join-Path $env:LOCALAPPDATA 'Moodsitto\apicore-ruta-8000.json'
        try {
            if (Test-Path -LiteralPath $routePath -PathType Leaf) {
                $route = Get-Content -LiteralPath $routePath -Raw -Encoding UTF8 | ConvertFrom-Json
                $launch = Get-Process -Id $route.LauncherId -ErrorAction SilentlyContinue
                $listeners = Get-NetTCPConnection -LocalPort 8000 -State Listen -ErrorAction SilentlyContinue
                if ($launch -and $launch.StartTime.ToUniversalTime().Ticks -eq $route.StartedUtcTicks -and
                    $route.MariaHost -eq '100.94.145.63' -and $route.MariaPort -eq 4006) {
                    foreach ($listener in $listeners) {
                        $php = Get-CimInstance Win32_Process -Filter "ProcessId=$($listener.OwningProcess)"
                        if ($php.Name -eq 'php.exe' -and $php.ParentProcessId -eq $route.LauncherId -and
                            (Test-ApiCore).Status -eq 'APROBADO') {
                            return New-Result APROBADO 'Conmutación comprobada en el ensayo y APIcore habitual conectado a MaxScale.' $details
                        }
                    }
                }
            }
        } catch {
            $details += "`nNo se pudo comprobar la ruta de la instancia habitual."
        }
        return New-Result PENDIENTE 'La conmutación real pasó en APIcore de prueba. Falta comprobar que la instancia habitual en 8000 use MaxScale.' $details
    }
    New-Result PENDIENTE 'Falta ensayar la caída del Windows fijo, una escritura de APIcore en la HP y la reincorporación del Windows fijo.' $details
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
    try {
        $access = Get-PresentationAccess
        if ($access) {
            $script:Config.MariaUser = $access.panelMaria.UserName
            $script:Config.MariaPassword = $access.panelMaria.GetNetworkCredential().Password
            $script:Config.MongoUser = $access.panelMongo.UserName
            $script:Config.MongoPassword = $access.panelMongo.GetNetworkCredential().Password
            return 'Accesos de APIcore y del panel disponibles para este usuario'
        }
    } catch {
        return 'No se pudieron abrir los accesos guardados. Vuelve a solicitarlos.'
    }
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
    $script:SummaryLabel.Text = "Aprobadas $($counts.APROBADO)     Pendientes $($counts.PENDIENTE)     Bloqueadas $($counts.BLOQUEADO)     Sin ejecutar $($counts['NO EJECUTADO'])"
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
    $row.Cells['Estado'].Style.BackColor = $color
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
$form.BackColor = [Drawing.ColorTranslator]::FromHtml('#F4F0F2')
$form.Font = [Drawing.Font]::new('Segoe UI', 10)
$form.AutoScaleMode = 'Dpi'
$blue = [Drawing.ColorTranslator]::FromHtml('#554367')
$ink = [Drawing.ColorTranslator]::FromHtml('#302940')
$slate = [Drawing.ColorTranslator]::FromHtml('#5F5269')
$soft = [Drawing.ColorTranslator]::FromHtml('#EBE3EE')
$green = [Drawing.ColorTranslator]::FromHtml('#047857')
$red = [Drawing.ColorTranslator]::FromHtml('#B91C1C')

$header = [Windows.Forms.Panel]::new()
$header.Dock = 'Top'
$header.Height = 72
$header.BackColor = $ink
$form.Controls.Add($header)

$title = [Windows.Forms.Label]::new()
$title.Text = 'Moodsitto DB Manager'
$title.ForeColor = [Drawing.Color]::White
$title.Font = [Drawing.Font]::new('Segoe UI Semibold', 19)
$title.AutoSize = $true
$title.Location = [Drawing.Point]::new(22, 8)
$header.Controls.Add($title)

$subtitle = [Windows.Forms.Label]::new()
$subtitle.Text = 'Panel de pruebas'
$subtitle.ForeColor = [Drawing.ColorTranslator]::FromHtml('#E2D6E9')
$subtitle.AutoSize = $true
$subtitle.Location = [Drawing.Point]::new(25, 43)
$header.Controls.Add($subtitle)

$settings = [Windows.Forms.GroupBox]::new()
$settings.Text = 'Conexiones de la presentación'
$settings.Dock = 'Top'
$settings.Height = 82
$settings.Padding = [Windows.Forms.Padding]::new(12)
$settings.Visible = $false
$form.Controls.Add($settings)

$navigation = [Windows.Forms.TabControl]::new()
$navigation.Dock = 'Fill'
$navigation.ItemSize = [Drawing.Size]::new(178, 40)
$navigation.SizeMode = 'Fixed'
$navigation.AccessibleName = 'Secciones del panel de pruebas'
$navigation.DrawMode = 'OwnerDrawFixed'
$navigation.Add_DrawItem({
    param($sender, $eventArgs)
    $bounds = $eventArgs.Bounds
    $selected = $eventArgs.Index -eq $sender.SelectedIndex
    $background = [Drawing.SolidBrush]::new($(if ($selected) { $soft } else { $form.BackColor }))
    $indicator = [Drawing.SolidBrush]::new($blue)
    try {
        $eventArgs.Graphics.FillRectangle($background, $bounds)
        if ($selected) { $eventArgs.Graphics.FillRectangle($indicator, $bounds.X, $bounds.Bottom - 3, $bounds.Width, 3) }
        $flags = [Windows.Forms.TextFormatFlags]'HorizontalCenter, VerticalCenter, EndEllipsis, NoPrefix'
        [Windows.Forms.TextRenderer]::DrawText($eventArgs.Graphics, $sender.TabPages[$eventArgs.Index].Text,
            $sender.Font, $bounds, $ink, $flags)
        if ($selected -and $sender.Focused) { $eventArgs.DrawFocusRectangle() }
    } finally {
        $background.Dispose()
        $indicator.Dispose()
    }
})
$form.Controls.Add($navigation)
$navigation.BringToFront()
$header.SendToBack()
$testPage = [Windows.Forms.TabPage]::new('Pruebas')
$localPage = [Windows.Forms.TabPage]::new('Inicio local')
$recoveryPage = [Windows.Forms.TabPage]::new('Recuperación')
$dataPage = [Windows.Forms.TabPage]::new('Datos de prueba')
$navigation.TabPages.AddRange(@($testPage, $localPage, $recoveryPage, $dataPage))

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
$main.SplitterWidth = 8
$main.BackColor = $form.BackColor
$testPage.Padding = [Windows.Forms.Padding]::new(16, 10, 16, 14)
$testPage.Controls.Add($main)
$main.BringToFront()

$toolbar = [Windows.Forms.FlowLayoutPanel]::new()
$toolbar.Dock = 'Top'
$toolbar.Height = 86
$toolbar.Padding = [Windows.Forms.Padding]::new(0,5,0,0)
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
    $secondary = $Color -eq $slate
    $button.BackColor = if ($secondary) { $soft } else { $Color }
    $button.ForeColor = if ($secondary) { $ink } else { [Drawing.Color]::White }
    $button.FlatAppearance.BorderSize = 0
    $Parent.Controls.Add($button)
    $button
}

$connectionsButton = New-PanelButton $header 'Mostrar conexiones' 161 $slate
$connectionsButton.Anchor = 'Top, Right'
$connectionsButton.Location = [Drawing.Point]::new(($header.ClientSize.Width - 184), 16)
$connectionsButton.AccessibleDescription = 'Muestra u oculta los destinos SSH y el estado de los accesos.'
$connectionsButton.Add_Click({
    $settings.Visible = -not $settings.Visible
    $connectionsButton.Text = if ($settings.Visible) { 'Ocultar conexiones' } else { 'Mostrar conexiones' }
})

$runSelectedButton = New-PanelButton $toolbar 'Ejecutar seleccionada' 182 $blue
$runSafeButton = New-PanelButton $toolbar 'Ejecutar todas las seguras' 204 $green
$exportButton = New-PanelButton $toolbar 'Exportar reporte' 138 $slate
$guideButton = New-PanelButton $toolbar 'Abrir guía' 108 $slate

$script:SummaryLabel = [Windows.Forms.Label]::new()
$script:SummaryLabel.AutoSize = $true
$script:SummaryLabel.Margin = [Windows.Forms.Padding]::new(7,8,0,0)
$script:SummaryLabel.Font = [Drawing.Font]::new('Segoe UI Semibold', 10)
$script:SummaryLabel.ForeColor = $slate
$toolbar.SetFlowBreak($guideButton, $true)
$toolbar.Controls.Add($script:SummaryLabel)

$script:Grid = [Windows.Forms.DataGridView]::new()
$script:Grid.Dock = 'Fill'
$script:Grid.AllowUserToAddRows = $false
$script:Grid.AllowUserToDeleteRows = $false
$script:Grid.AllowUserToResizeRows = $false
$script:Grid.ReadOnly = $true
$script:Grid.AccessibleName = 'Pruebas de infraestructura y resultados'
$script:Grid.MultiSelect = $false
$script:Grid.SelectionMode = 'FullRowSelect'
$script:Grid.RowHeadersVisible = $false
$script:Grid.AutoSizeRowsMode = 'AllCells'
$script:Grid.BackgroundColor = [Drawing.Color]::White
$script:Grid.BorderStyle = 'None'
$script:Grid.GridColor = [Drawing.ColorTranslator]::FromHtml('#E8E0E9')
$script:Grid.CellBorderStyle = 'SingleHorizontal'
$script:Grid.DefaultCellStyle.Padding = [Windows.Forms.Padding]::new(6,5,6,5)
$script:Grid.DefaultCellStyle.WrapMode = 'True'
$script:Grid.DefaultCellStyle.ForeColor = $ink
$script:Grid.DefaultCellStyle.SelectionBackColor = $blue
$script:Grid.DefaultCellStyle.SelectionForeColor = [Drawing.Color]::White
$script:Grid.ColumnHeadersHeight = 36
$script:Grid.ColumnHeadersHeightSizeMode = 'DisableResizing'
$script:Grid.ColumnHeadersDefaultCellStyle.BackColor = $soft
$script:Grid.ColumnHeadersDefaultCellStyle.ForeColor = $ink
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
    if ($index % 2) { $script:Grid.Rows[$index].DefaultCellStyle.BackColor = [Drawing.ColorTranslator]::FromHtml('#F8F5F8') }
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
$script:LogBox.BackColor = $ink
$script:LogBox.ForeColor = [Drawing.ColorTranslator]::FromHtml('#F3EDF5')
$script:LogBox.Font = [Drawing.Font]::new('Cascadia Mono', 9)
$script:LogBox.BorderStyle = 'None'
$activityTab.Controls.Add($script:LogBox)

function New-OperationPage {
    param($Page, [string]$Title, [string]$Description, [int]$Height, [string]$EvidenceTitle = 'Actividad y comandos')
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
    $evidence.Text = $EvidenceTitle
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
$localUi = New-OperationPage $localPage 'Servicios de esta computadora' 'Prepara PHP y los accesos antes de arrancar APIcore y el frontend.' 339
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
$setupButtons = New-OperationButtons $localUi.Card 282
$installMongoButton = New-PanelButton $setupButtons 'Instalar MongoDB para PHP' 215 $blue
$requestAccessButton = New-PanelButton $setupButtons 'Solicitar accesos' 145 $slate
$receiveAccessButton = New-PanelButton $setupButtons 'Recibir accesos' 138 $slate

$dataUi = New-OperationPage $dataPage 'Datos de prueba' 'Registra una emoción o un recordatorio con la cuenta de ensayo.' 295 'Evidencia de la operación'
$manageCatalog = New-PanelButton $dataUi.Card 'Gestionar cartas' 145 $blue
$manageCatalog.Anchor = 'Top, Right'
$manageCatalog.Location = [Drawing.Point]::new(($dataUi.Card.ClientSize.Width - 165), 22)
$manageCatalog.AccessibleDescription = 'Crea, edita, desactiva o reactiva cartas del catálogo de Mis emociones.'
$dataEvidence = [Windows.Forms.TableLayoutPanel]::new()
$dataEvidence.Dock = 'Fill'
$dataEvidence.ColumnCount = 2
$dataEvidence.RowCount = 2
[void]$dataEvidence.ColumnStyles.Add([Windows.Forms.ColumnStyle]::new('Percent', 53))
[void]$dataEvidence.ColumnStyles.Add([Windows.Forms.ColumnStyle]::new('Percent', 47))
[void]$dataEvidence.RowStyles.Add([Windows.Forms.RowStyle]::new('Absolute', 29))
[void]$dataEvidence.RowStyles.Add([Windows.Forms.RowStyle]::new('Percent', 100))
$evidenceContainer = $dataUi.Output.Parent
$queryBox = [Windows.Forms.TextBox]::new()
$queryBox.AccessibleName = 'Consulta de la base de datos'
$queryBox.Dock = 'Fill'
$queryBox.Multiline = $true
$queryBox.ReadOnly = $true
$queryBox.ScrollBars = 'Both'
$queryBox.WordWrap = $false
$queryBox.Font = $dataUi.Output.Font
$queryBox.BackColor = [Drawing.ColorTranslator]::FromHtml('#F7F3F8')
$queryBox.Text = 'Aquí aparecerá la consulta al guardar o leer un dato.'
$queryBox.Margin = [Windows.Forms.Padding]::new(3, 0, 7, 3)
$dataUi.Output.AccessibleName = 'Resultados de las consultas reales'
$dataUi.Output.WordWrap = $true
$dataUi.Output.ScrollBars = 'Vertical'
$dataUi.Output.Font = $form.Font
$dataUi.Output.Margin = [Windows.Forms.Padding]::new(7, 0, 3, 3)
$evidenceLabels = @('Consulta SQL o MongoDB', 'Respuesta y actividad')
for ($column = 0; $column -lt $evidenceLabels.Count; $column++) {
    $label = [Windows.Forms.Label]::new()
    $label.Text = $evidenceLabels[$column]
    $label.Font = [Drawing.Font]::new('Segoe UI Semibold', 10)
    $label.ForeColor = $ink
    $label.TextAlign = 'MiddleLeft'
    $label.Dock = 'Fill'
    $label.Margin = [Windows.Forms.Padding]::new($(if ($column -eq 0) { 3 } else { 7 }), 0, 0, 0)
    $dataEvidence.Controls.Add($label, $column, 0)
}
$dataEvidence.Controls.Add($queryBox, 0, 1)
$dataEvidence.Controls.Add($dataUi.Output, 1, 1)
$evidenceContainer.Controls.Add($dataEvidence)
$dataForms = [Windows.Forms.TableLayoutPanel]::new()
$dataForms.Dock = 'Bottom'
$dataForms.Height = 211
$dataForms.Padding = [Windows.Forms.Padding]::new(14, 0, 14, 16)
$dataForms.ColumnCount = 2
$dataForms.RowCount = 1
[void]$dataForms.ColumnStyles.Add([Windows.Forms.ColumnStyle]::new('Percent', 50))
[void]$dataForms.ColumnStyles.Add([Windows.Forms.ColumnStyle]::new('Percent', 50))
[void]$dataForms.RowStyles.Add([Windows.Forms.RowStyle]::new('Percent', 100))
$dataUi.Card.Controls.Add($dataForms)
$emotionGroup = [Windows.Forms.GroupBox]::new()
$emotionGroup.Text = 'Registrar emoción · MongoDB'
$emotionGroup.Size = [Drawing.Size]::new(440, 195)
$reminderGroup = [Windows.Forms.GroupBox]::new()
$reminderGroup.Text = 'Registrar recordatorio · MariaDB'
$reminderGroup.Size = [Drawing.Size]::new(440, 195)
foreach ($group in @($emotionGroup, $reminderGroup)) {
    $group.Dock = 'Fill'
    $group.ForeColor = $ink
    $group.Margin = [Windows.Forms.Padding]::new(6, 0, 6, 0)
}

function Add-DataControl {
    param($Parent, $Control, [string]$Caption, [int]$X, [int]$Y, [int]$Width)
    $label = [Windows.Forms.Label]::new()
    $label.Text = $Caption
    $label.AutoSize = $true
    $label.Location = [Drawing.Point]::new($X, $Y)
    $Parent.Controls.Add($label)
    $Control.AccessibleName = $Caption
    $Control.Location = [Drawing.Point]::new($X, $Y + 20)
    $Control.Width = $Width
    $Parent.Controls.Add($Control)
    $Control
}

$emotionNames = [ordered]@{ 'Alegría' = 'Alegría'; 'Paz' = 'Paz'; 'Tristeza' = 'Troste'; 'Enojo' = 'Enojao'; 'Miedo' = 'Miedo'; 'Poder' = 'Poder' }
$emotionChoice = Add-DataControl $emotionGroup ([Windows.Forms.ComboBox]::new()) 'Emoción del registro' 14 25 233
$emotionChoice.DropDownStyle = 'DropDown'
$emotionChoice.MaxLength = 80
$emotionChoice.Items.AddRange([object[]]@($emotionNames.Keys))
$emotionChoice.SelectedIndex = 0
$intensity = Add-DataControl $emotionGroup ([Windows.Forms.NumericUpDown]::new()) 'Intensidad (1 a 10)' 268 25 155
$intensity.Minimum = 1
$intensity.Maximum = 10
$intensity.Value = 5
$emotionNote = Add-Field $emotionGroup 'Nota ficticia (opcional)' 14 78 409 ''
$emotionNote.MaxLength = 200
$saveEmotion = New-PanelButton $emotionGroup 'Guardar emoción' 135 $blue
$saveEmotion.Location = [Drawing.Point]::new(14, 143)
$listEmotions = New-PanelButton $emotionGroup 'Consultar registros' 144 $slate
$listEmotions.Location = [Drawing.Point]::new(160, 143)

$reminderName = Add-Field $reminderGroup 'Nombre del recordatorio' 14 25 409 ''
$reminderName.MaxLength = 100
$reminderDate = Add-DataControl $reminderGroup ([Windows.Forms.DateTimePicker]::new()) 'Fecha' 14 78 218
$reminderDate.Format = 'Short'
$reminderTime = Add-DataControl $reminderGroup ([Windows.Forms.DateTimePicker]::new()) 'Hora' 250 78 173
$reminderTime.Format = 'Custom'
$reminderTime.CustomFormat = 'HH:mm'
$reminderTime.ShowUpDown = $true
$saveReminder = New-PanelButton $reminderGroup 'Guardar recordatorio' 170 $blue
$saveReminder.Location = [Drawing.Point]::new(14, 143)
$listReminders = New-PanelButton $reminderGroup 'Consultar recordatorios' 185 $slate
$listReminders.Location = [Drawing.Point]::new(196, 143)
foreach ($control in @($intensity, $emotionNote, $reminderName, $reminderTime)) {
    $control.Anchor = 'Top, Left, Right'
}
$dataForms.Controls.Add($emotionGroup, 0, 0)
$dataForms.Controls.Add($reminderGroup, 1, 0)

$recoveryUi = New-OperationPage $recoveryPage 'Recuperación de servidores' 'Sigue los cambios de equipo durante un ensayo real.' 440
$targetLabel = [Windows.Forms.Label]::new()
$targetLabel.Location = [Drawing.Point]::new(20, 80)
$targetLabel.AutoSize = $true
$targetLabel.Text = 'Equipo para ejecutar acciones'
$recoveryUi.Card.Controls.Add($targetLabel)
$targetChoice = [Windows.Forms.ComboBox]::new()
$targetChoice.DropDownStyle = 'DropDownList'
$targetChoice.Location = [Drawing.Point]::new(20, 103)
$targetChoice.Width = 310
$targetChoice.AccessibleName = 'Equipo para ejecutar acciones'
$targetChoice.Items.AddRange(@((Get-RecoveryTargets).Name))
$targetChoice.SelectedIndex = 1
$recoveryUi.Card.Controls.Add($targetChoice)
$windowsTrialButton = New-PanelButton $recoveryUi.Card 'Ver caída del Windows fijo' 215 $slate
$windowsTrialButton.Location = [Drawing.Point]::new(350, 96)
$liveMariaButton = New-PanelButton $recoveryUi.Card 'Seguir MariaDB en vivo' 200 $blue
$liveMariaButton.Location = [Drawing.Point]::new(578, 96)
$recoveryButtons = New-OperationButtons $recoveryUi.Card 144
$statusButton = New-PanelButton $recoveryButtons 'Ver estado' 110 $slate
$startMotorButton = New-PanelButton $recoveryButtons 'Iniciar motor' 120 $blue
$outageButton = New-PanelButton $recoveryButtons 'Ensayar caída del motor' 194 $red
$rebootButton = New-PanelButton $recoveryButtons 'Reiniciar servidor' 162 $red

$timelineLabel = [Windows.Forms.Label]::new()
$timelineLabel.Location = [Drawing.Point]::new(20, 201)
$timelineLabel.AutoSize = $true
$timelineLabel.Font = [Drawing.Font]::new('Segoe UI Semibold', 11)
$timelineLabel.Text = 'Último ensayo'
$recoveryUi.Card.Controls.Add($timelineLabel)

$timeline = [Windows.Forms.ListView]::new()
$timeline.Location = [Drawing.Point]::new(20, 230)
$timeline.Size = [Drawing.Size]::new(925, 148)
$timeline.Anchor = 'Top, Left, Right'
$timeline.AccessibleName = 'Cambios de nodo y tiempos observados durante el ensayo'
$timeline.View = 'Details'
$timeline.FullRowSelect = $true
$timeline.GridLines = $true
$timeline.HeaderStyle = 'Nonclickable'
[void]$timeline.Columns.Add('Tiempo', 90)
[void]$timeline.Columns.Add('Evento observado', 315)
[void]$timeline.Columns.Add('Nodo', 295)
$timeline.ForeColor = $ink
$recoveryUi.Card.Controls.Add($timeline)
$timeline.Visible = $false

function New-RecoveryNodeCard {
    param([string]$Caption, [int]$X)
    $card = [Windows.Forms.Panel]::new()
    $card.Location = [Drawing.Point]::new($X, 0)
    $card.Size = [Drawing.Size]::new(282, 77)
    $card.BorderStyle = 'FixedSingle'
    $label = [Windows.Forms.Label]::new()
    $label.Location = [Drawing.Point]::new(11, 5)
    $label.AutoSize = $true
    $label.Text = $Caption
    $card.Controls.Add($label)
    $name = [Windows.Forms.Label]::new()
    $name.Location = [Drawing.Point]::new(11, 23)
    $name.Size = [Drawing.Size]::new(256, 24)
    $name.AutoEllipsis = $true
    $name.Font = [Drawing.Font]::new('Segoe UI Semibold', 13)
    $card.Controls.Add($name)
    $status = [Windows.Forms.Label]::new()
    $status.Location = [Drawing.Point]::new(12, 50)
    $status.AutoSize = $true
    $card.Controls.Add($status)
    $card.AccessibleName = $Caption
    [pscustomobject]@{ Panel = $card; Caption = $label; Name = $name; Status = $status }
}

$recoveryMap = [Windows.Forms.Panel]::new()
$recoveryMap.Location = [Drawing.Point]::new(20, 230)
$recoveryMap.Size = [Drawing.Size]::new(925, 148)
$recoveryUi.Card.Controls.Add($recoveryMap)
$recoveryTargetCard = New-RecoveryNodeCard 'Equipo del ensayo' 0
$recoveryWriterCard = New-RecoveryNodeCard 'Equipo que recibe escrituras' 300
$recoveryMap.Controls.Add($recoveryTargetCard.Panel)
$recoveryMap.Controls.Add($recoveryWriterCard.Panel)
$recoveryStage = [Windows.Forms.Label]::new()
$recoveryStage.Location = [Drawing.Point]::new(0, 83)
$recoveryStage.Size = [Drawing.Size]::new(850, 24)
$recoveryStage.AutoEllipsis = $true
$recoveryStage.Font = [Drawing.Font]::new('Segoe UI Semibold', 10)
$recoveryMap.Controls.Add($recoveryStage)
$previousStepButton = New-PanelButton $recoveryMap 'Anterior' 100 $slate
$nextStepButton = New-PanelButton $recoveryMap 'Siguiente' 100 $blue
$previousStepButton.Location = [Drawing.Point]::new(0, 111)
$nextStepButton.Location = [Drawing.Point]::new(111, 111)
$previousStepButton.Height = $nextStepButton.Height = 33
$changeRecoveryViewButton = New-PanelButton $recoveryUi.Card 'Ver eventos' 124 $slate
$changeRecoveryViewButton.Location = [Drawing.Point]::new(659, 195)
$changeRecoveryViewButton.Height = 28

$script:RecoveryReport = $null
$script:RecoveryStep = -1
$script:MariaRecoveryWatch = $null
$mariaWatchTimer = [Windows.Forms.Timer]::new()
$mariaWatchTimer.Interval = 750

function Show-RecoveryFrame {
    param($Frame)
    $recoveryTargetCard.Name.Text = if ($frame.Target) { $frame.Target } else { 'Sin datos' }
    $recoveryTargetCard.Status.Text = $frame.TargetState
    $recoveryTargetCard.Panel.BackColor = if ($frame.TargetState -in 'Motor detenido', 'Puerto sin respuesta') {
        [Drawing.ColorTranslator]::FromHtml('#FEE2E2')
    } else { [Drawing.ColorTranslator]::FromHtml('#F1F5F9') }
    $recoveryWriterCard.Name.Text = if ($frame.Writer) { $frame.Writer } else { 'Sin primario confirmado' }
    $recoveryWriterCard.Status.Text = $frame.WriterState
    $recoveryWriterCard.Panel.BackColor = if ($frame.Writer) {
        [Drawing.ColorTranslator]::FromHtml('#DCFCE7')
    } else { [Drawing.ColorTranslator]::FromHtml('#F1F5F9') }
}

function Set-RecoveryStep {
    param([int]$Index)
    $report = $script:RecoveryReport
    $count = if ($report) { @($report.Events).Count } else { 0 }
    $script:RecoveryStep = if ($count) { [Math]::Max(0, [Math]::Min($Index, $count - 1)) } else { -1 }
    $step = $script:RecoveryStep
    Show-RecoveryFrame (Get-RecoveryFrame $report $step)
    $recoveryStage.Text = if ($count) {
        $event = $report.Events[$step]
        $time = if ($null -eq $event.Seconds) { 'Antes de la caída' } else { '{0:0.00} s' -f $event.Seconds }
        "Paso $($step + 1) de $count · $($event.Name) · $time"
    } else { 'Todavía no hay eventos para mostrar.' }
    $saved = $report.Status -ne 'EN CURSO'
    $previousStepButton.Enabled = $saved -and $step -gt 0
    $nextStepButton.Enabled = $saved -and $step -ge 0 -and $step -lt ($count - 1)
    $recoveryMap.Refresh()
}

$previousStepButton.Add_Click({ Set-RecoveryStep ($script:RecoveryStep - 1) })
$nextStepButton.Add_Click({ Set-RecoveryStep ($script:RecoveryStep + 1) })
$changeRecoveryViewButton.Add_Click({
    $showEvents = $recoveryMap.Visible
    $recoveryMap.Visible = -not $showEvents
    $timeline.Visible = $showEvents
    $changeRecoveryViewButton.Text = if ($showEvents) { 'Ver cambio' } else { 'Ver eventos' }
})

function Stop-MariaRecoveryWatch {
    $mariaWatchTimer.Stop()
    if ($script:MariaRecoveryWatch) {
        Close-MariaRecoveryProbe $script:MariaRecoveryWatch.Probe
        $script:MariaRecoveryWatch = $null
    }
    $liveMariaButton.Text = 'Seguir MariaDB en vivo'
    $recoveryTargetCard.Caption.Text = 'Equipo del ensayo'
    $previousStepButton.Visible = $nextStepButton.Visible = $changeRecoveryViewButton.Visible = $true
}

$recoveryResult = [Windows.Forms.Label]::new()
$recoveryResult.Location = [Drawing.Point]::new(20, 383)
$recoveryResult.Size = [Drawing.Size]::new(910, 24)
$recoveryResult.Font = [Drawing.Font]::new('Segoe UI Semibold', 10)
$recoveryUi.Card.Controls.Add($recoveryResult)
$recoveryTopology = [Windows.Forms.Label]::new()
$recoveryTopology.Location = [Drawing.Point]::new(20, 409)
$recoveryTopology.Size = [Drawing.Size]::new(915, 22)
$recoveryTopology.Anchor = 'Top, Left, Right'
$recoveryTopology.AutoEllipsis = $true
$recoveryUi.Card.Controls.Add($recoveryTopology)

function Show-RecoveryReport {
    param($Report, [switch]$Follow)
    Stop-MariaRecoveryWatch
    $script:RecoveryReport = $Report
    if ($Follow) { Set-RecoveryStep (@($Report.Events).Count - 1) }
    else {
        $recoveryMap.Visible = $true
        $timeline.Visible = $false
        $changeRecoveryViewButton.Text = 'Ver eventos'
        Set-RecoveryStep 0
    }
    $timeline.BeginUpdate()
    try {
        $timeline.Items.Clear()
        $timelineLabel.Text = if ($Report) { "Ensayo real · $($Report.StartedAt) · tiempo desde que terminó la orden de parada" } else { 'Último ensayo' }
        $recoveryResult.Text = if ($Report) { "Resultado: $($Report.Status)" } else { 'Todavía no hay un ensayo guardado para este motor.' }
        $recoveryResult.ForeColor = if ($Report.Status -eq 'APROBADO') { $green } else { $ink }
        $recoveryTopology.Text = if ($Report.Topology) { "Topología al finalizar: $($Report.Topology)" } else { '' }
        if ($Report.Failure) { $recoveryTopology.Text = $Report.Failure }
        foreach ($event in $Report.Events) {
            $time = if ($null -eq $event.Seconds) { 'Antes' } else { '{0:0.0} s' -f $event.Seconds }
            $nodeText = switch ($event.Node) {
                '100.94.145.63:27017' { 'VPS · 100.94.145.63' }
                '100.89.172.17:27017' { 'Windows fijo · 100.89.172.17' }
                '100.86.5.50:27017' { 'Laptop · 100.86.5.50' }
                default { $event.Node }
            }
            $item = [Windows.Forms.ListViewItem]::new($time)
            [void]$item.SubItems.Add($event.Name)
            [void]$item.SubItems.Add($nodeText)
            [void]$timeline.Items.Add($item)
        }
    } finally { $timeline.EndUpdate() }
    $timeline.Refresh()
    $recoveryResult.Refresh()
    $recoveryTopology.Refresh()
}

function Show-SelectedRecoveryReport {
    $target = (Get-RecoveryTargets)[$targetChoice.SelectedIndex]
    try { Show-RecoveryReport (Read-RecoveryReport $target.Engine) }
    catch {
        Show-RecoveryReport $null
        $recoveryResult.Text = 'No se pudo leer el informe guardado.'
    }
}

$targetChoice.Add_SelectedIndexChanged({ if (-not $script:RunningOperation) { Show-SelectedRecoveryReport } })
$windowsTrialButton.Add_Click({
    if ($script:Running) { return }
    try { Show-RecoveryReport (Read-RecoveryReport MariaDB -WindowsFijo) }
    catch {
        Show-RecoveryReport $null
        $recoveryResult.Text = 'No se pudo leer el informe del Windows fijo.'
    }
})
$liveMariaButton.Add_Click({
    if ($script:Running) { return }
    if ($mariaWatchTimer.Enabled) {
        Show-RecoveryReport $script:RecoveryReport
        return
    }
    try {
        $access = Get-ApiCoreAccess
        if (-not $access) { throw 'Recibe los accesos de APIcore en Inicio local antes de seguir MariaDB.' }
        $client = Require-Tool 'mariadb' 'Instala el cliente de MariaDB.'
        $script:MariaRecoveryWatch = @{
            Client = $client; Credential = $access.Maria; Probe = $null; LastWriter = ''; Change = ''
        }
        $recoveryMap.Visible = $true
        $timeline.Visible = $false
        $previousStepButton.Visible = $nextStepButton.Visible = $changeRecoveryViewButton.Visible = $false
        $liveMariaButton.Text = 'Dejar de seguir'
        $timelineLabel.Text = 'MariaDB en vivo'
        $recoveryTargetCard.Caption.Text = 'Equipo observado'
        $recoveryStage.Text = 'Consultando el Windows fijo, la HP y MaxScale…'
        $recoveryResult.Text = ''
        $recoveryTopology.Text = ''
        Show-RecoveryFrame @{ Target = 'Windows fijo'; TargetState = 'Consultando'; Writer = ''; WriterState = 'Consultando MaxScale' }
        $mariaWatchTimer.Start()
    } catch {
        Stop-MariaRecoveryWatch
        $recoveryResult.ForeColor = $ink
        $recoveryResult.Text = Protect-LogText $_.Exception.Message
    }
})
$mariaWatchTimer.Add_Tick({
    $watch = $script:MariaRecoveryWatch
    if (-not $watch) { return }
    try {
        if (-not $watch.Probe) {
            $watch.Probe = Start-MariaRecoveryProbe $watch.Client $watch.Credential $script:Config.MariaHost $script:Config.MariaReplicaHost
            return
        }
        $probe = $watch.Probe
        $pending = $probe.Connections.Values | Where-Object { -not $_.Task.IsCompleted }
        if (($pending -or -not $probe.Output.IsCompleted -or -not $probe.Process.HasExited) -and
            $probe.Clock.ElapsedMilliseconds -lt 4000) { return }
        $offline = @(foreach ($name in $probe.Connections.Keys) {
            $connection = $probe.Connections[$name]
            if ($connection.Task.Status -ne 'RanToCompletion' -or -not $connection.Socket.Connected) { $name }
        })
        $writer = if ($probe.Process.HasExited -and $probe.Process.ExitCode -eq 0 -and $probe.Output.IsCompleted) {
            switch ($probe.Output.GetAwaiter().GetResult().Trim()) {
                '1|0' { 'Windows fijo' }
                '2|0' { 'HP' }
            }
        }
        Close-MariaRecoveryProbe $probe
        $watch.Probe = $null
        if ($writer) {
            if ($watch.LastWriter -and $watch.LastWriter -ne $writer) { $watch.Change = "$($watch.LastWriter) → $writer" }
            $watch.LastWriter = $writer
        }
        $target = if ($offline.Count) { $offline[0] } else { 'Windows fijo' }
        $targetState = if ($offline.Count) { 'Puerto sin respuesta' } else { 'Puerto MariaDB accesible' }
        $writerState = if ($writer) { 'Primario confirmado por MaxScale' }
            elseif ($offline -contains 'VPS · MaxScale') { 'No se puede consultar MaxScale' }
            else { 'MaxScale aún no confirma el primario' }
        Show-RecoveryFrame @{ Target = $target; TargetState = $targetState; Writer = $writer; WriterState = $writerState }
        $recoveryStage.Text = "Última consulta · $(Get-Date -Format 'HH:mm:ss')"
        $recoveryResult.ForeColor = $ink
        $recoveryResult.Text = if ($watch.Change) { "Cambio observado · $($watch.Change)" }
            elseif ($offline.Count -and $writer) { "Primario disponible · $writer" }
            else { '' }
        $recoveryTopology.Text = (@(foreach ($name in $probe.Connections.Keys) {
            $portState = if ($name -in $offline) { 'sin respuesta' } else { 'responde' }
            "$name $portState"
        }) -join '  |  ')
    } catch {
        Stop-MariaRecoveryWatch
        $recoveryResult.ForeColor = $ink
        $recoveryResult.Text = 'Se interrumpió la consulta. Pulsa Seguir MariaDB en vivo para intentarlo de nuevo.'
    }
})
Show-SelectedRecoveryReport

function Add-PanelEmotionOption {
    param([string]$Label)
    if ($Label -and $Label -notin $emotionChoice.Items) { [void]$emotionChoice.Items.Add($Label) }
}

$manageCatalog.Add_Click({
    if ($script:Running) { return }
    $catalogo = [Collections.Generic.List[object]]::new()
    $lectura = @{ Confirmada = $false }
    Invoke-PanelOperation 'Consultar catálogo de cartas en MongoDB' $dataUi.Output {
        $queryBox.Text = 'db.catalogo_emociones.find({ nivel: "central" }).sort({ nombre: 1, codigo: 1 });'
        foreach ($card in @(Get-PanelCatalogCards)) { $catalogo.Add($card) }
        $lectura.Confirmada = $true
        Write-Log "MongoDB devolvió $($catalogo.Count) cartas." 'OK'
    }
    if (-not $lectura.Confirmada) { return }
    $iconKeys = @($script:PanelCatalogIcons.Keys)
    $iconSize = 64
    try {
        $iconSprite = [Drawing.Bitmap]::new((Join-Path $script:Repo 'presentacion\recursos\iconos-cartas.png'))
    } catch {
        [void][Windows.Forms.MessageBox]::Show($form, 'Falta el archivo de vistas previas del catálogo.',
            'Gestionar cartas', 'OK', 'Warning')
        return
    }

    $editor = [Windows.Forms.Form]::new()
    $editor.Text = 'Gestionar cartas de emoción'
    $editor.StartPosition = 'CenterParent'
    $editor.FormBorderStyle = 'FixedDialog'
    $editor.MaximizeBox = $false
    $editor.MinimizeBox = $false
    $editor.ClientSize = [Drawing.Size]::new(560, 448)
    $editor.Font = $form.Font
    $editor.BackColor = [Drawing.Color]::White
    $editor.ForeColor = $ink
    $cardChoice = Add-DataControl $editor ([Windows.Forms.ComboBox]::new()) 'Carta' 18 16 270
    $cardChoice.DropDownStyle = 'DropDownList'
    [void]$cardChoice.Items.Add('Nueva carta')
    foreach ($card in $catalogo) {
        $label = if ($card.activo) { $card.nombre } else { "$($card.nombre) · Desactivada" }
        [void]$cardChoice.Items.Add($label)
    }
    $cardIcon = Add-DataControl $editor ([Windows.Forms.ComboBox]::new()) 'Icono' 305 16 190
    $cardIcon.DropDownStyle = 'DropDownList'
    $cardIcon.Items.AddRange([object[]]@($script:PanelCatalogIcons.Values))
    $iconPreview = [Windows.Forms.PictureBox]::new()
    $iconPreview.Bounds = [Drawing.Rectangle]::new(506, 29, 36, 36)
    $iconPreview.BackColor = $soft
    $iconPreview.SizeMode = 'Zoom'
    $iconPreview.AccessibleName = 'Vista previa del icono'
    $editor.Controls.Add($iconPreview)
    $cardIcon.Add_SelectedIndexChanged({
        param($sender, $eventArgs)
        if ($sender.SelectedIndex -lt 0) { return }
        $area = [Drawing.Rectangle]::new(($sender.SelectedIndex * $iconSize), 0, $iconSize, $iconSize)
        $previousImage = $iconPreview.Image
        $iconPreview.Image = $iconSprite.Clone($area, $iconSprite.PixelFormat)
        if ($previousImage) { $previousImage.Dispose() }
        $iconPreview.AccessibleDescription = [string]$sender.SelectedItem
    }.GetNewClosure())
    $cardName = Add-Field $editor 'Nombre' 18 69 367 ''
    $cardName.MaxLength = 80
    $cardColor = Add-Field $editor 'Color hexadecimal' 402 69 106 '#D4A8E8'
    $cardColor.MaxLength = 7
    $colorPreview = [Windows.Forms.Panel]::new()
    $colorPreview.Bounds = [Drawing.Rectangle]::new(516, 89, 26, 25)
    $colorPreview.BorderStyle = 'FixedSingle'
    $editor.Controls.Add($colorPreview)
    $cardColor.Add_TextChanged({
        param($sender, $eventArgs)
        $colorPreview.BackColor = if ($sender.Text -match '^#[0-9A-Fa-f]{6}$') {
            [Drawing.ColorTranslator]::FromHtml($sender.Text)
        } else { [Drawing.Color]::White }
    }.GetNewClosure())
    $colorPreview.BackColor = [Drawing.ColorTranslator]::FromHtml($cardColor.Text)
    $cardDescription = Add-Field $editor 'Descripción' 18 123 524 ''
    $cardDescription.MaxLength = 1000
    $cardDetails = Add-DataControl $editor ([Windows.Forms.TextBox]::new()) 'Matices opcionales (uno por línea)' 18 177 524
    $cardDetails.Multiline = $true
    $cardDetails.ScrollBars = 'Vertical'
    $cardDetails.Height = 88
    $cardDetails.MaxLength = 2000
    $formatHint = [Windows.Forms.Label]::new()
    $formatHint.Text = 'Formato: Matiz | Detalle | Detalle. Ejemplo: Asombro | Algo inesperado'
    $formatHint.AutoSize = $true
    $formatHint.Location = [Drawing.Point]::new(18, 293)
    $editor.Controls.Add($formatHint)
    $cardActive = [Windows.Forms.CheckBox]::new()
    $cardActive.Text = 'Mostrar carta en Mis emociones'
    $cardActive.AccessibleDescription = 'Al desactivarla, sus registros siguen disponibles en el historial.'
    $cardActive.AutoSize = $true
    $cardActive.Location = [Drawing.Point]::new(18, 322)
    $editor.Controls.Add($cardActive)
    $cardStatus = [Windows.Forms.Label]::new()
    $cardStatus.Location = [Drawing.Point]::new(18, 350)
    $cardStatus.Size = [Drawing.Size]::new(524, 43)
    $cardStatus.ForeColor = [Drawing.Color]::DarkRed
    $editor.Controls.Add($cardStatus)
    $cancelCard = New-PanelButton $editor 'Cancelar' 112 $slate
    $cancelCard.Location = [Drawing.Point]::new(261, 393)
    $cancelCard.DialogResult = 'Cancel'
    $editor.CancelButton = $cancelCard
    $saveCard = New-PanelButton $editor 'Guardar carta' 155 $green
    $saveCard.Location = [Drawing.Point]::new(387, 393)
    $editor.AcceptButton = $saveCard

    $cardChoice.Add_SelectedIndexChanged({
        param($sender, $eventArgs)
        $selected = if ($sender.SelectedIndex -gt 0) { $catalogo[$sender.SelectedIndex - 1] }
        $cardName.Text = [string]$selected.nombre
        $cardDescription.Text = [string]$selected.descripcion
        $cardColor.Text = if ($selected.color) { $selected.color } else { '#D4A8E8' }
        $cardIcon.SelectedIndex = [Math]::Max(0, [Array]::IndexOf($iconKeys, $selected.icono))
        $cardDetails.Lines = [string[]]@(foreach ($matiz in $selected.matices) {
            (@($matiz.nombre) + @($matiz.detalles)) -join ' | '
        })
        $cardActive.Checked = -not $selected -or $selected.activo
        $cardActive.Enabled = $null -ne $selected
        $cardStatus.Text = ''
    }.GetNewClosure())
    $cardChoice.SelectedIndex = 0

    $saveCard.Add_Click({
        Invoke-PanelOperation 'Guardar carta en el catálogo de MongoDB' $dataUi.Output {
            $cardStatus.Text = ''
            try {
                $card = New-PanelCatalogCard $cardName.Text $cardDescription.Text $cardColor.Text $cardDetails.Text $iconKeys[$cardIcon.SelectedIndex]
                $selected = if ($cardChoice.SelectedIndex -gt 0) { $catalogo[$cardChoice.SelectedIndex - 1] }
                $card.activo = $cardActive.Checked
                $consulta = if ($selected) {
                    @'
moodsitto.catalogo_emociones

db.catalogo_emociones.updateOne(
  { codigo: carta.codigo, nivel: "central", updated_at: revisionLeida },
  { $set: cambiosConFecha },
  { writeConcern: { w: "majority", wtimeout: 5000 } }
);

db.catalogo_emociones.findOne({ codigo: carta.codigo, nivel: "central" });
'@
                } else {
                    @'
moodsitto.catalogo_emociones

db.catalogo_emociones.updateOne(
  { codigo: carta.codigo },
  { $setOnInsert: cartaConFechas },
  { upsert: true, writeConcern: { w: "majority", wtimeout: 5000 } }
);

db.catalogo_emociones.findOne({ codigo: carta.codigo });
'@
                }
                $queryBox.Text = $consulta -replace "`r?`n", "`r`n"
                $saved = Save-PanelCatalogCard $card $selected
                $expectedCode = if ($selected) { $selected.codigo } else { $card.codigo }
                if ($saved.codigo -cne $expectedCode -or $saved.nombre -cne $card.nombre -or
                    $saved.activo -ne $card.activo -or $saved.icono -cne $card.icono) {
                    throw 'No se pudo confirmar la lectura de la carta.'
                }
                $estado = if ($saved.activo) { 'activa' } else { 'desactivada' }
                Write-Log "Carta guardada y leída de MongoDB · $($saved.nombre) · $estado" 'OK'
                if ($saved.activo) { Add-PanelEmotionOption $saved.nombre }
                $editor.DialogResult = 'OK'
            } catch {
                $cardStatus.Text = $_.Exception.Message
                throw
            }
        }
    })
    try { [void]$editor.ShowDialog($form) }
    finally {
        if ($iconPreview.Image) { $iconPreview.Image.Dispose() }
        $iconSprite.Dispose()
        $editor.Dispose()
    }
})

$saveEmotion.Add_Click({
    Invoke-PanelOperation 'Guardar emoción en MongoDB' $dataUi.Output {
        $label = $emotionChoice.Text.Trim()
        if (-not $label) { throw 'Elige o escribe la emoción del registro de ensayo.' }
        $knownLabel = $emotionChoice.Items | Where-Object { $_ -eq $label } | Select-Object -First 1
        if ($knownLabel) { $label = $knownLabel }
        $core = if ($emotionNames.Contains($label)) { $emotionNames[$label] } else { $label }
        $entry = @{
            core = $core; intensity = [int]$intensity.Value
            note = $emotionNote.Text.Trim(); subs = @(); fine = @()
        }
        $started = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
        $queryBox.Text = Get-PanelDataQuery emociones -Write
        $id = Save-PanelDataEntry emociones @{ group = @($entry) }
        $queryBox.Text = Get-PanelDataQuery emociones -Write -RecordId $id
        Add-PanelEmotionOption $label
        $emotionNote.Clear()
        Write-Log 'APIcore confirmó el guardado de la emoción en MongoDB.' 'OK'
        $readBack = @(Invoke-PanelData GET '/tablero/emociones' | Where-Object { $_.t -ge $started } | ForEach-Object { $_.group } |
            Where-Object { $_.core -ceq $entry.core -and $_.intensity -eq $entry.intensity -and $_.note -ceq $entry.note })
        if ($readBack.Count) { Write-Log "Lectura confirmada · $label · intensidad $($entry.intensity)." 'OK' }
        else { Write-Log 'El guardado respondió. Todavía no se pudo confirmar la lectura.' 'PENDIENTE' }
    }
})
$listEmotions.Add_Click({
    Invoke-PanelOperation 'Consultar emociones en MongoDB' $dataUi.Output {
        $queryBox.Text = Get-PanelDataQuery emociones
        $records = @(Invoke-PanelData GET '/tablero/emociones')
        if (-not $records.Count) { Write-Log 'Todavía no hay emociones en la cuenta de prueba.'; return }
        $shown = 0
        foreach ($record in $records) {
            $shown++
            foreach ($entry in $record.group) {
                $label = ($emotionNames.Keys | Where-Object { $emotionNames[$_] -ceq $entry.core } | Select-Object -First 1)
                if (-not $label) { $label = [string]$entry.core }
                Add-PanelEmotionOption $label
                if ($shown -le 20) {
                    $when = [DateTimeOffset]::FromUnixTimeMilliseconds($record.t).ToLocalTime().ToString('dd/MM/yyyy HH:mm')
                    Write-Log "$when · $label · intensidad $($entry.intensity) · $($entry.note)"
                }
            }
        }
    }
})
$saveReminder.Add_Click({
    Invoke-PanelOperation 'Guardar recordatorio en MariaDB' $dataUi.Output {
        $name = $reminderName.Text.Trim()
        if (-not $name) { throw 'Escribe un nombre ficticio para el recordatorio.' }
        $day = $reminderDate.Value.ToString('yyyy-MM-dd')
        $entry = @{
            nombre = $name; hora = $reminderTime.Value.ToString('HH:mm'); tipo = 'actividad'
            repeticion = 'una'; inicio = $day; fin = $day; diasSemana = @(); completados = @()
        }
        $queryBox.Text = Get-PanelDataQuery recordatorios -Write
        $id = Save-PanelDataEntry recordatorios $entry
        $queryBox.Text = Get-PanelDataQuery recordatorios -Write -RecordId $id
        $reminderName.Clear()
        Write-Log 'APIcore confirmó el guardado del recordatorio en MariaDB.' 'OK'
        $readBack = Invoke-PanelData GET '/tablero/recordatorios' | Where-Object id -eq $id | Select-Object -First 1
        if ($readBack) { Write-Log "Lectura confirmada · $($readBack.nombre) · $($readBack.inicio) $($readBack.hora)." 'OK' }
        else { Write-Log 'El guardado respondió. Todavía no se pudo confirmar la lectura.' 'PENDIENTE' }
    }
})
$listReminders.Add_Click({
    Invoke-PanelOperation 'Consultar recordatorios en MariaDB' $dataUi.Output {
        $queryBox.Text = Get-PanelDataQuery recordatorios
        $records = @(Invoke-PanelData GET '/tablero/recordatorios')
        if (-not $records.Count) { Write-Log 'Todavía no hay recordatorios en la cuenta de prueba.'; return }
        foreach ($record in ($records | Sort-Object inicio, hora -Descending | Select-Object -First 20)) {
            Write-Log "$($record.inicio) $($record.hora) · $($record.nombre)"
        }
    }
})

$startApiButton.Add_Click({
    Invoke-PanelOperation 'Iniciar APIcore · localhost:8000' $localUi.Output {
        Start-LocalDemoService APIcore $apiPathBox.Text.Trim() $phpPathBox.Text.Trim()
    }
})
$installMongoButton.Add_Click({
    Invoke-PanelOperation 'Preparar MongoDB para el PHP seleccionado' $localUi.Output {
        $installer = Join-Path $script:Repo 'presentacion\instalar-mongodb-php.ps1'
        $php = $phpPathBox.Text.Trim()
        Register-TestCommand $installer @('-Php', $php) -PowerShell
        & $installer -Php $php 6>&1 | ForEach-Object { Write-Log ([string]$_) }
    }
})
$requestAccessButton.Add_Click({
    Invoke-PanelOperation 'Solicitar accesos cifrados al Windows fijo' $localUi.Output {
        if (Get-Item -LiteralPath $script:PairFile -ErrorAction SilentlyContinue) {
            $saved = Import-Clixml -LiteralPath $script:PairFile
            $code = $saved.Id
        } else { $code = New-PresentationRequest }
        [Windows.Forms.Clipboard]::SetText($code)
        Write-Log 'La solicitud se copió al portapapeles. Pega ese código para que se envíe el paquete a esta laptop.' 'OK'
    }
})
$receiveAccessButton.Add_Click({
    Invoke-PanelOperation 'Recibir accesos cifrados en esta laptop' $localUi.Output {
        Receive-PresentationAccess
        $script:CredentialStatus = Initialize-SecureConfig
        $credentialLabel.Text = $script:CredentialStatus
        $credentialLabel.ForeColor = $green
        Write-Log 'Accesos guardados para este usuario de Windows. Ya puedes iniciar APIcore y ejecutar las pruebas.' 'OK'
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
        try {
            if (Get-ApiCoreAccess) { Write-Log 'Acceso de APIcore listo.' 'OK' }
            else { Write-Log 'APIcore requiere los accesos. Usa Solicitar accesos y Recibir accesos.' 'PENDIENTE' }
        } catch { Write-Log 'El acceso de APIcore guardado no se pudo abrir.' 'PENDIENTE' }
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
        if ($mariaWatchTimer.Enabled) { Show-SelectedRecoveryReport }
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
        Invoke-PanelOperation "$($sender.Text) · $($target.Name)" $recoveryUi.Output {
            if ($action -ne 'Ensayar') {
                Invoke-RecoveryAction $action $target
                return
            }
            $report = [pscustomobject]@{
                Engine = $target.Engine
                Target = $target.Name
                StartedAt = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
                Status = 'EN CURSO'
                Topology = ''
                Failure = ''
                Events = @()
            }
            $targetChoice.Enabled = $false
            try {
                Invoke-RecoveryAction $action $target -Observe {
                    param($Event, $Node, $Seconds, $Result)
                    if ($Result) {
                        $report.Status = $Result.Status
                        $report.Topology = $Result.Topology
                    } else {
                        $report.Events += [pscustomobject]@{ Name = $Event; Node = $Node; Seconds = $Seconds }
                    }
                    Show-RecoveryReport $report -Follow
                    try { Save-RecoveryReport $report }
                    catch { Write-Log 'El informe se muestra en pantalla, pero no se pudo guardar.' 'PENDIENTE' }
                }
            } catch {
                if ($report.Events.Count) {
                    $report.Status = 'PENDIENTE'
                    $report.Failure = Protect-LogText $_.Exception.Message
                    Show-RecoveryReport $report -Follow
                    try { Save-RecoveryReport $report }
                    catch { Write-Log 'No se pudo guardar el informe de recuperación.' 'PENDIENTE' }
                }
                throw
            } finally { $targetChoice.Enabled = $true }
        }
    })
}

$form.Add_FormClosing({
    param($sender, $eventArgs)
    if ($script:RunningOperation) { $eventArgs.Cancel = $true }
    else {
        Stop-MariaRecoveryWatch
        $mariaWatchTimer.Dispose()
    }
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
        $connectionsButton.PerformClick()
        if (-not $settings.Visible) { $script:UiSmokeFailed = $true }
        $connectionsButton.PerformClick()
        if ($settings.Visible) { $script:UiSmokeFailed = $true }
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
        $navigation.SelectedTab = $dataPage
        if (-not $saveEmotion.Visible -or -not $saveReminder.Visible -or -not $queryBox.Visible -or -not $manageCatalog.Visible -or
            $emotionChoice.Items.Count -ne 6 -or $emotionChoice.DropDownStyle -ne 'DropDown' -or $dataUi.Output.Height -lt 65) {
            $script:UiSmokeFailed = $true
        }
        $navigation.SelectedTab = $recoveryPage
        if ($targetChoice.Items.Count -ne 2 -or -not $rebootButton.Visible -or $recoveryUi.Output.Height -lt 65 -or
            $recoveryButtons.Bounds.IntersectsWith($changeRecoveryViewButton.Bounds) -or
            $recoveryButtons.Bounds.IntersectsWith($timelineLabel.Bounds)) {
            Write-Output "Controles de recuperación incompletos. Altura de actividad: $($recoveryUi.Output.Height)."
            $script:UiSmokeFailed = $true
        }
        # Comprueba el botón con una respuesta local para que la autoprueba funcione sin SSH.
        function script:Invoke-RecoveryAction {
            param($Mode, $SelectedTarget, $Observe)
            Write-Log "Control $Mode · $($SelectedTarget.Unit)"
        }
        $targetChoice.SelectedIndex = 1
        $statusButton.PerformClick()
        if ($recoveryUi.Output.Text -notmatch 'Control Estado.*mongod') { $script:UiSmokeFailed = $true }
        if ($recoveryResult.Text -eq '') { $script:UiSmokeFailed = $true }
        $saved = Read-RecoveryReport MongoDB
        if ($saved -and ($timeline.Items.Count -ne $saved.Events.Count -or
                $recoveryResult.Text -notlike "*$($saved.Status)" -or
                ($saved.Topology -and $recoveryTopology.Text -notlike "*$($saved.Topology)"))) {
            Write-Output "El informe guardado no coincide con la vista. Filas visibles: $($timeline.Items.Count)."
            $script:UiSmokeFailed = $true
        }
        $windowsTrialButton.PerformClick()
        $windowsSaved = Read-RecoveryReport MariaDB -WindowsFijo
        if ($windowsSaved -and ($timeline.Items.Count -ne $windowsSaved.Events.Count -or
                $recoveryResult.Text -notlike "*$($windowsSaved.Status)")) {
            $script:UiSmokeFailed = $true
        }
        if ($windowsSaved.Status -eq 'APROBADO') {
            if ($recoveryWriterCard.Name.Text -ne 'Windows fijo') { $script:UiSmokeFailed = $true }
            $nextStepButton.PerformClick()
            if ($recoveryTargetCard.Status.Text -ne 'Motor detenido' -or $recoveryWriterCard.Name.Text -ne 'Sin primario confirmado') {
                $script:UiSmokeFailed = $true
            }
            $nextStepButton.PerformClick()
            if ($recoveryWriterCard.Name.Text -ne 'HP' -or $recoveryWriterCard.Status.Text -ne 'Nuevo primario') {
                $script:UiSmokeFailed = $true
            }
            $nextStepButton.PerformClick()
            if ($recoveryWriterCard.Status.Text -ne 'Escritura confirmada') { $script:UiSmokeFailed = $true }
            $previousStepButton.PerformClick()
            if ($recoveryWriterCard.Status.Text -ne 'Nuevo primario') { $script:UiSmokeFailed = $true }
            $changeRecoveryViewButton.PerformClick()
            if (-not $timeline.Visible -or $recoveryMap.Visible) { $script:UiSmokeFailed = $true }
            $changeRecoveryViewButton.PerformClick()
            if ($recoveryWriterCard.Name.Text -ne 'HP' -or -not $recoveryMap.Visible) { $script:UiSmokeFailed = $true }
        }
        $form.Close()
    })
}
[void]$form.ShowDialog()
if ($UiSmokeTest) {
    if ($script:UiSmokeFailed) { throw 'La interfaz no pasó la autoprueba.' }
    Write-Output '[OK] Cuatro secciones abiertas; prueba local, formulario de datos y recuperación comprobados.'
}

