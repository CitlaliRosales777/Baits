# El panel usa destinos conocidos. Las acciones de recuperación afectan solo al equipo seleccionado.
function Get-RecoveryTargets {
    @(
        [pscustomobject]@{ Name = 'HP · réplica MariaDB'; Ssh = $script:Config.HpSsh; Unit = 'mariadb'; Engine = 'MariaDB' }
        [pscustomobject]@{ Name = 'VPS · miembro MongoDB'; Ssh = $script:Config.VpsSsh; Unit = 'mongod'; Engine = 'MongoDB' }
    )
}

function Read-RecoveryReport {
    param([ValidateSet('MongoDB','MariaDB')][string]$Engine, [switch]$WindowsFijo)
    $suffix = if ($WindowsFijo) { 'MariaDB-WindowsFijo' } else { $Engine }
    $path = Join-Path $env:LOCALAPPDATA "Moodsitto\recuperacion-$suffix.json"
    if (Test-Path -LiteralPath $path -PathType Leaf) {
        $report = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($report.Engine -ne $Engine -or -not $report.StartedAt) { throw 'El informe de recuperación guardado no es válido.' }
        if ($WindowsFijo -and $report.Scenario -ne 'WindowsFijo') { throw 'El informe no corresponde a la caída del Windows fijo.' }
        $report
    }
}

function Get-RecoveryNodeLabel {
    param([string]$Node)
    switch -Regex ($Node) {
        '100\.89\.172\.17|Windows fijo' { 'Windows fijo'; break }
        '100\.112\.196\.81|\bHP\b' { 'HP'; break }
        '100\.94\.145\.63|\bVPS\b' { 'VPS'; break }
        '100\.86\.5\.50|Laptop' { 'Laptop'; break }
        default { $Node }
    }
}

function Get-RecoveryFrame {
    param($Report, [int]$Index)
    $interruption = $Report.Events | Where-Object Name -eq 'Motor detenido' | Select-Object -First 1
    $target = Get-RecoveryNodeLabel $interruption.Node
    if (-not $target) { $target = Get-RecoveryNodeLabel $Report.Target }
    $writer = ''
    $targetState = 'Sin confirmar'
    $writerState = 'Sin confirmar'
    for ($i = 0; $i -le $Index; $i++) {
        $event = $Report.Events[$i]
        $node = Get-RecoveryNodeLabel $event.Node
        switch -Regex ($event.Name) {
            '^Primario inicial$' {
                $writer = $node
                $writerState = 'Primario inicial'
                $targetState = 'En ejecución'
            }
            '^Motor detenido$' {
                $targetState = 'Motor detenido'
                if ($writer -eq $node) {
                    $writer = ''
                    $writerState = 'Esperando un primario'
                }
            }
            '^Nuevo primario detectado$' {
                $writer = $node
                $writerState = 'Nuevo primario'
            }
            '^(Primera escritura confirmada|Escritura confirmada)' {
                $writer = $node
                $writerState = 'Escritura confirmada'
            }
            '^Escritura de prueba revertida$' {
                $writer = $node
                $writerState = 'Escritura comprobada y revertida'
            }
            '^Motor activo de nuevo$' { $targetState = 'Motor de nuevo en ejecución' }
            '^Reintegración verificada' { $targetState = 'Reincorporado como réplica' }
            '^Retorno planificado completado$' {
                $writer = $node
                $writerState = 'Primario tras el retorno'
                if ($target -eq $node) { $targetState = 'En ejecución' }
            }
        }
    }
    [pscustomobject]@{ Target = $target; TargetState = $targetState; Writer = $writer; WriterState = $writerState }
}

function Start-MariaRecoveryProbe {
    param([string]$Client, [pscredential]$Credential, [string]$WindowsHost, [string]$ReplicaHost)
    # La disponibilidad de cada puerto se mide por separado del rol observado a través de MaxScale.
    $info = [Diagnostics.ProcessStartInfo]::new()
    $info.FileName = $Client
    $info.Arguments = '--connect-timeout=2 --batch --skip-column-names -h 100.94.145.63 -P 4006 -u apicore_app -D apicore -e "SELECT CONCAT(@@server_id,CHAR(124),IF(@@read_only,1,0));"'
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $info.EnvironmentVariables['MYSQL_PWD'] = $Credential.GetNetworkCredential().Password

    $destinations = [ordered]@{
        'Windows fijo' = @{ Host = $WindowsHost; Port = 3306 }
        'HP' = @{ Host = $ReplicaHost; Port = 3306 }
        'VPS · MaxScale' = @{ Host = '100.94.145.63'; Port = 4006 }
    }
    $connections = [ordered]@{}
    $process = $null
    try {
        foreach ($name in $destinations.Keys) {
            $destination = $destinations[$name]
            $socket = [Net.Sockets.TcpClient]::new()
            $connections[$name] = @{ Socket = $socket; Task = $null }
            $connections[$name].Task = $socket.ConnectAsync([Net.IPAddress]::Parse($destination.Host), $destination.Port)
        }
        $process = [Diagnostics.Process]::Start($info)
        [pscustomobject]@{
            Process = $process
            Output = $process.StandardOutput.ReadToEndAsync()
            Errors = $process.StandardError.ReadToEndAsync()
            Connections = $connections
            Clock = [Diagnostics.Stopwatch]::StartNew()
        }
    } catch {
        foreach ($connection in $connections.Values) { $connection.Socket.Dispose() }
        if ($process) { $process.Dispose() }
        throw
    } finally {
        $info.EnvironmentVariables.Remove('MYSQL_PWD')
    }
}

function Close-MariaRecoveryProbe {
    param($Probe)
    if (-not $Probe) { return }
    foreach ($connection in $Probe.Connections.Values) { $connection.Socket.Dispose() }
    try {
        if (-not $Probe.Process.HasExited) { $Probe.Process.Kill() }
    } catch [InvalidOperationException] {
        # El proceso puede terminar entre HasExited y Kill.
    } finally { $Probe.Process.Dispose() }
}

function Save-RecoveryReport {
    param($Report)
    $engine = [string]$Report.Engine
    if ($engine -notin 'MongoDB', 'MariaDB') { throw 'Motor de recuperación no válido.' }
    $folder = Join-Path $env:LOCALAPPDATA 'Moodsitto'
    [void][IO.Directory]::CreateDirectory($folder)
    $path = Join-Path $folder "recuperacion-$engine.json"
    $temp = "$path.$([Guid]::NewGuid().ToString('N')).tmp"
    $json = $Report | ConvertTo-Json -Depth 6
    try {
        [IO.File]::WriteAllText($temp, $json, [Text.UTF8Encoding]::new($false))
        if ([IO.File]::Exists($path)) { [IO.File]::Replace($temp, $path, "$temp.bak") }
        else { [IO.File]::Move($temp, $path) }
    } finally {
        if ([IO.File]::Exists($temp)) { [IO.File]::Delete($temp) }
        if ([IO.File]::Exists("$temp.bak")) { [IO.File]::Delete("$temp.bak") }
    }
}

function Get-RecoveryTopologySummary {
    param([string]$Details)
    $roles = foreach ($line in ($Details -split '\r?\n')) {
        $parts = $line -split ': ', 2
        if ($parts.Count -ne 2 -or $parts[1] -notmatch '^\{') { continue }
        $status = $parts[1] | ConvertFrom-Json
        $role = if ($status.isWritablePrimary) { 'Primario' } elseif ($status.secondary) { 'Secundario' } else { 'Rol sin confirmar' }
        "$($parts[0]) $role"
    }
    $roles -join '  |  '
}

function Get-RecoveryCommand {
    param([ValidateSet('Estado','Iniciar','Ensayar','Reiniciar')][string]$Action, [ValidateSet('mariadb','mongod')][string]$Unit, [string]$TimerUnit)
    # Programa el arranque antes de detener el motor para que vuelva aunque se corte el SSH.
    switch ($Action) {
        'Estado' { "systemctl is-active $Unit" }
        'Iniciar' { "sudo -n /usr/bin/systemctl --no-block start $Unit" }
        'Ensayar' {
            if ($TimerUnit -notmatch '^moodsitto-recuperar-[0-9a-f]{12}$') { throw 'Identificador inválido de la prueba.' }
            "sudo -n /usr/bin/systemd-run --unit=$TimerUnit --on-active=45s --timer-property=AccuracySec=1s /usr/bin/systemctl start $Unit && sudo -n /usr/bin/systemctl stop $Unit"
        }
        'Reiniciar' { 'sudo -n /usr/bin/systemctl --no-block reboot' }
    }
}

function Invoke-RecoveryChange {
    param($Target, [string]$Command, [switch]$RebootsHost)
    $access = Invoke-SshCommand $Target.Ssh 'sudo -n -v' -AllowFailure -TimeoutSeconds 12
    if ($access.Code -eq 0) {
        $result = Invoke-SshCommand $Target.Ssh $Command -AllowFailure:$RebootsHost
        if ($result.Code -ne 0 -and $result.Code -ne 255) { throw $result.Output }
        return
    }
    if ($access.Code -in 124, 255) { throw $access.Output }
    # En el HP, sudo puede pedir la clave en una terminal propia. El panel nunca la recibe.
    $ssh = Require-Tool 'ssh' 'Activa el cliente OpenSSH de Windows.'
    if ($Target.Ssh -notmatch '^[a-zA-Z0-9_.-]+@[a-zA-Z0-9_.-]+$') { throw 'El destino SSH debe tener el formato usuario@equipo.' }
    $remote = "sudo -v && $Command"
    Register-TestCommand $ssh @('-t','-o','BatchMode=yes','--',$Target.Ssh,$remote)
    Write-Log 'Autoriza sudo en la terminal SSH que se abre para continuar.'
    $process = Start-Process $ssh -ArgumentList "-t -o BatchMode=yes -- $($Target.Ssh) `"$remote`"" -WindowStyle Normal -PassThru
    $timer = [Diagnostics.Stopwatch]::StartNew()
    try {
        while (-not $process.WaitForExit(200)) {
            [Windows.Forms.Application]::DoEvents()
            if ($timer.Elapsed.TotalSeconds -ge 90) {
                $process.Kill()
                throw 'Se agotó la espera de autorización en la terminal SSH.'
            }
        }
        if ($process.ExitCode -ne 0 -and (-not $RebootsHost -or $process.ExitCode -ne 255)) {
            throw "El comando SSH terminó con código $($process.ExitCode). Revisa la autorización de sudo."
        }
    } finally { $process.Dispose() }
}

function Invoke-RecoveryAction {
    param([ValidateSet('Estado','Iniciar','Ensayar','Reiniciar')][string]$Action, $Target, [scriptblock]$Observe = {})
    $initial = Invoke-SshCommand $Target.Ssh (Get-RecoveryCommand Estado $Target.Unit) -AllowFailure -TimeoutSeconds 12
    if ($Action -eq 'Estado') {
        if ($initial.Code -in 124, 255) { throw $initial.Output }
        Write-Log "$($Target.Name) · $($initial.Output)"
        return
    }
    if ($Action -eq 'Iniciar') {
        if ($initial.Code -in 124, 255) { throw $initial.Output }
        if ($initial.Code -eq 0 -and $initial.Output -eq 'active') {
            Write-Log "$($Target.Name) · el motor ya está activo." 'OK'
            return
        }
        if ($initial.Output -ne 'activating') {
            Invoke-RecoveryChange $Target (Get-RecoveryCommand Iniciar $Target.Unit)
        }
        Write-Log 'Esperando la confirmación de arranque del motor.'
        $startup = [Diagnostics.Stopwatch]::StartNew()
        do {
            $started = Invoke-SshCommand $Target.Ssh (Get-RecoveryCommand Estado $Target.Unit) -AllowFailure -TimeoutSeconds 8
            if ($started.Code -eq 0 -and $started.Output -eq 'active') {
                Write-Log "$($Target.Name) · motor activo." 'OK'
                return
            }
            if ($started.Code -in 124, 255) { throw $started.Output }
            if ($started.Output -eq 'failed') { throw "$($Target.Name) · el motor reporta un fallo de arranque." }
            [Windows.Forms.Application]::DoEvents()
            Start-Sleep -Milliseconds 250
        } while ($startup.Elapsed.TotalSeconds -lt 20)
        throw "$($Target.Name) · arranque sin confirmar. Último estado: $($started.Output). Usa Ver estado para comprobarlo."
    }

    if ($initial.Code -ne 0 -or $initial.Output -ne 'active') { throw 'El motor del equipo elegido debe estar activo antes del ensayo.' }
    if ($Target.Engine -eq 'MongoDB') { $check = Test-MongoTopology }
    else { $check = Test-MariaPrimary }
    if ($check.Status -ne 'APROBADO') { throw "Comprobación previa: $($check.Summary)" }
    Write-Log "Comprobación previa aprobada · $($check.Summary)" 'OK'

    $continuity = $false
    $originalPrimary = $null
    if ($Target.Engine -eq 'MongoDB' -and $Action -eq 'Ensayar') {
        $hello = (Invoke-MongoEval 'const h=db.hello(); print(JSON.stringify({primary:h.primary,hosts:h.hosts}))').Output | ConvertFrom-Json
        $targetHost = ($Target.Ssh -split '@', 2)[1]
        $targetMember = "${targetHost}:27017"
        if ($hello.primary -ne $targetMember) {
            throw "El VPS es secundario en este momento. Primario actual: $($hello.primary). Este ensayo requiere detener el primario."
        }
        if (@($hello.hosts | Where-Object { $_ -ne $targetMember }).Count -lt 1) {
            throw 'MongoDB no anuncia un secundario elegible para asumir el rol de primario.'
        }
        $originalPrimary = $hello.primary
        & $Observe 'Primario inicial' $originalPrimary $null
    } elseif ($Target.Engine -eq 'MariaDB' -and $Action -eq 'Ensayar') {
        & $Observe 'Primario inicial' "$($script:Config.MariaHost) · Windows fijo" $null
    }
    if ($Action -eq 'Reiniciar') {
        $enabled = Invoke-SshCommand $Target.Ssh "systemctl is-enabled $($Target.Unit)" -AllowFailure
        if ($enabled.Code -ne 0 -or $enabled.Output -ne 'enabled') {
            throw 'El motor debe iniciar con el sistema antes de ensayar el reinicio del equipo.'
        }
        $previousBoot = (Invoke-SshCommand $Target.Ssh 'cat /proc/sys/kernel/random/boot_id').Output
        Invoke-RecoveryChange $Target (Get-RecoveryCommand Reiniciar $Target.Unit) -RebootsHost
        $watch = [Diagnostics.Stopwatch]::StartNew()
    } else {
        $timerUnit = 'moodsitto-recuperar-' + [Guid]::NewGuid().ToString('N').Substring(0, 12)
        Invoke-RecoveryChange $Target (Get-RecoveryCommand Ensayar $Target.Unit $timerUnit)
        $watch = [Diagnostics.Stopwatch]::StartNew()
        $stopped = Invoke-SshCommand $Target.Ssh (Get-RecoveryCommand Estado $Target.Unit) -AllowFailure
        if ($stopped.Output -ne 'inactive') { throw "No se confirmó la detención del motor. Estado: $($stopped.Output)" }
        Write-Log 'Motor detenido. Arranque automático programado.'
        & $Observe 'Motor detenido' $Target.Name $watch.Elapsed.TotalSeconds
        # Con el motor fuera, comprueba que el otro lado sigue respondiendo.
        try {
            if ($Target.Engine -eq 'MongoDB') {
                $id = [Guid]::NewGuid().ToString()
                # La elección puede tardar varios segundos. Espera al nuevo principal antes de guardar.
                do {
                    $election = Invoke-MongoEval 'const h=db.hello(); if(h.isWritablePrimary) print(h.me)' -AllowFailure
                    if ($election.Code -eq 0 -and $election.Output -and $election.Output -ne $originalPrimary) { break }
                    Start-Sleep -Seconds 2
                } while ($watch.Elapsed.TotalSeconds -lt 24)
                if ($election.Code -ne 0 -or -not $election.Output -or $election.Output -eq $originalPrimary) { throw 'MongoDB todavía no confirmó un nuevo primario durante el ensayo.' }
                & $Observe 'Nuevo primario detectado' $election.Output $watch.Elapsed.TotalSeconds
                try {
                    $write = "const h=db.hello(); const r=db.auditoria_documental.insertOne({actor_id_user:null,accion:'prueba_recuperacion',recurso:'presentacion',recurso_id:null,resultado:'ok',correlacion_id:'$id',metadata_segura:{datos:'sinteticos'},created_at:new Date()},{writeConcern:{w:'majority',wtimeout:5000}}); print(JSON.stringify({principal:h.primary,confirmada:r.acknowledged}))"
                    $primary = Invoke-MongoEval $write
                    $written = $primary.Output | ConvertFrom-Json
                    $writeElapsed = $watch.Elapsed.TotalSeconds
                    $targetState = Invoke-SshCommand $Target.Ssh (Get-RecoveryCommand Estado $Target.Unit) -AllowFailure
                    $continuity = $written.confirmada -and $written.principal -and $written.principal -ne $originalPrimary
                    $continuity = $continuity -and $targetState.Output -eq 'inactive'
                    if (-not $continuity) { throw 'MongoDB no confirmó la escritura de prueba.' }
                    & $Observe 'Primera escritura confirmada por mayoría' $written.principal $writeElapsed
                    Write-Log "Escritura con mayoría durante la caída · $($primary.Output)" 'OK'
                } finally {
                    Invoke-MongoEval "db.auditoria_documental.deleteOne({correlacion_id:'$id'},{writeConcern:{w:'majority',wtimeout:5000}})" -AllowFailure | Out-Null
                }
            } else {
                $principal = Test-MariaPrimary
                Write-Log "MariaDB principal durante la caída · $($principal.Status). $($principal.Summary)"
                $id = [Guid]::NewGuid().ToString()
                $sql = "START TRANSACTION; INSERT INTO auditoria_eventos(actor_id_user,accion,recurso,resultado,correlacion_id) VALUES(NULL,'prueba_recuperacion','presentacion','ok','$id'); SELECT ROW_COUNT(); ROLLBACK;"
                $write = Invoke-MariaQuery $script:Config.MariaHost $sql
                if ($write.Rows -ne '1') { throw 'MariaDB principal no confirmó la escritura de prueba.' }
                $writeElapsed = $watch.Elapsed.TotalSeconds
                $targetState = Invoke-SshCommand $Target.Ssh (Get-RecoveryCommand Estado $Target.Unit) -AllowFailure
                if ($targetState.Output -ne 'inactive') { throw 'La HP ya no estaba detenida cuando se comprobó la escritura.' }
                $continuity = $true
                & $Observe 'Escritura de prueba revertida' "$($script:Config.MariaHost) · mismo primario" $writeElapsed
                Write-Log 'MariaDB principal aceptó una escritura de prueba. La transacción se revirtió.' 'OK'
            }
        } catch {
            & $Observe 'Escritura de prueba no confirmada' $Target.Name $watch.Elapsed.TotalSeconds
            Write-Log "El servicio alterno todavía no respondió · $($_.Exception.Message)" 'PENDIENTE'
        }
    }

    $returned = $false
    while ($watch.Elapsed.TotalSeconds -lt 120) {
        Start-Sleep -Seconds 3
        [Windows.Forms.Application]::DoEvents()
        if ($Action -eq 'Reiniciar') {
            $boot = Invoke-SshCommand $Target.Ssh 'cat /proc/sys/kernel/random/boot_id' -AllowFailure
            if ($boot.Code -ne 0 -or $boot.Output -eq $previousBoot) { continue }
        }
        $state = Invoke-SshCommand $Target.Ssh (Get-RecoveryCommand Estado $Target.Unit) -AllowFailure
        if ($state.Code -eq 0 -and $state.Output -eq 'active') { $returned = $true; break }
    }
    if (-not $returned) { throw 'No se confirmó que el motor volviera dentro de dos minutos. Consulta el estado o usa Iniciar motor.' }
    if ($Action -eq 'Ensayar') { & $Observe 'Motor activo de nuevo' $Target.Name $watch.Elapsed.TotalSeconds }
    Write-Log "Motor activo en $($watch.Elapsed.TotalSeconds.ToString('0.0')) s." 'OK'
    do {
        if ($Target.Engine -eq 'MongoDB') { $check = Test-MongoTopology }
        else { $check = Test-MariaReplica }
        if ($check.Status -ne 'PENDIENTE' -or $watch.Elapsed.TotalSeconds -ge 120) { break }
        Start-Sleep -Seconds 3
        [Windows.Forms.Application]::DoEvents()
    } while ($true)
    if ($Action -eq 'Ensayar' -and $check.Status -eq 'APROBADO') {
        & $Observe 'Reintegración verificada' $Target.Name $watch.Elapsed.TotalSeconds
    } elseif ($Action -eq 'Ensayar') {
        & $Observe 'Reintegración pendiente de verificar' $Target.Name $watch.Elapsed.TotalSeconds
    }
    if ($Action -eq 'Ensayar') {
        $outcome = if ($check.Status -eq 'APROBADO' -and $continuity) { 'APROBADO' } else { 'PENDIENTE' }
        $topology = if ($Target.Engine -eq 'MongoDB') { Get-RecoveryTopologySummary $check.Details } else { $check.Summary }
        & $Observe 'Resultado final' $Target.Name $watch.Elapsed.TotalSeconds @{ Status = $outcome; Topology = $topology }
    }
    Write-Log "$($check.Status) · $($check.Summary)" $check.Status
    if ($check.Details) { Write-Log $check.Details 'DETALLE' }
    if ($check.Status -ne 'APROBADO') { Write-Log 'Resultado del ensayo · falta comprobar el estado de toda la réplica.' 'PENDIENTE' }
    elseif ($Action -eq 'Reiniciar') { Write-Log 'Resultado del ensayo · reinicio y recuperación verificados.' 'OK' }
    elseif ($continuity) { Write-Log 'Resultado del ensayo · escritura durante la caída y recuperación verificadas.' 'OK' }
    else { Write-Log 'Resultado del ensayo · el motor volvió. La escritura durante la caída queda pendiente.' 'PENDIENTE' }
}

function Get-LocalStartConfiguration {
    param([ValidateSet('APIcore','Frontend')][string]$Service, [string]$RepoPath, [string]$Php)
    if (-not (Test-Path -LiteralPath $Php -PathType Leaf)) { throw "No se encontró php.exe en $Php." }
    $Php = (Resolve-Path -LiteralPath $Php).Path
    if ($Service -eq 'APIcore') {
        $entry = Join-Path $RepoPath 'apicore\api\v1\php\index.php'
        $launcher = Join-Path $PSScriptRoot 'iniciar-apicore.ps1'
        $arguments = @('-NoProfile','-ExecutionPolicy','Bypass','-NoExit','-File', $launcher, '-RepoApiCore', $RepoPath, '-Php', $Php)
        $file = Join-Path $PSHOME 'powershell.exe'
        if (-not (Test-Path -LiteralPath $file)) { $file = (Get-Command powershell.exe).Source }
        $port = 8000
    } else {
        $root = Join-Path $RepoPath 'fronted\fronted'
        $entry = Join-Path $root 'login.html'
        $arguments = @('-S','localhost:5500','-t',$root)
        $file = $Php
        $port = 5500
    }
    if (-not (Test-Path -LiteralPath $entry -PathType Leaf)) { throw "No se encuentra $entry. Selecciona la copia correspondiente del repositorio." }
    [pscustomobject]@{ File = $file; Arguments = $arguments; Port = $port; Php = $Php }
}

function Start-LocalDemoService {
    param([string]$Service, [string]$RepoPath, [string]$Php)
    $start = Get-LocalStartConfiguration $Service $RepoPath $Php
    # PHP puede escuchar en ::1. Consulta ambos tipos de socket antes de abrir otra instancia.
    $localListeners = [Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties().GetActiveTcpListeners() | Where-Object {
        $_.Port -eq $start.Port -and ([Net.IPAddress]::IsLoopback($_.Address) -or
            $_.Address -in @([Net.IPAddress]::Any, [Net.IPAddress]::IPv6Any))
    }
    if ($localListeners) {
        Write-Log "El puerto $($start.Port) ya está en uso. Pulsa Ver estado para comprobar qué servicio responde." 'PENDIENTE'
        return
    }
    if ($Service -eq 'APIcore') {
        if ((& $start.Php -m) -notcontains 'mongodb') { throw 'Pulsa Instalar MongoDB para PHP antes de iniciar APIcore.' }
        if (-not (Get-ApiCoreAccess)) { throw 'Pulsa Solicitar accesos y luego Recibir accesos en esta pestaña.' }
    }
    Register-TestCommand $start.File $start.Arguments
    $quoted = $start.Arguments | ForEach-Object { if ($_ -match '\s') { '"{0}"' -f $_ } else { $_ } }
    # APIcore abre la consola donde el usuario puede ingresar las claves de aplicación sin mostrarlas en el panel.
    Start-Process -FilePath $start.File -ArgumentList ($quoted -join ' ') -WindowStyle Normal
    Write-Log "$Service · ventana de arranque abierta. Usa Ver estado para comprobar el puerto."
}
