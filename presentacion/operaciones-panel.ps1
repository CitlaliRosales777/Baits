# El panel usa destinos conocidos. Las acciones de recuperación afectan solo al equipo seleccionado.
function Get-RecoveryTargets {
    @(
        [pscustomobject]@{ Name = 'HP · réplica MariaDB'; Ssh = $script:Config.HpSsh; Unit = 'mariadb'; Engine = 'MariaDB' }
        [pscustomobject]@{ Name = 'VPS · miembro MongoDB'; Ssh = $script:Config.VpsSsh; Unit = 'mongod'; Engine = 'MongoDB' }
    )
}

function Get-RecoveryCommand {
    param([ValidateSet('Estado','Iniciar','Ensayar','Reiniciar')][string]$Action, [ValidateSet('mariadb','mongod')][string]$Unit, [string]$TimerUnit)
    # Programa el arranque antes de detener el motor para que vuelva aunque se corte el SSH.
    switch ($Action) {
        'Estado' { "systemctl is-active $Unit" }
        'Iniciar' { "sudo -n /usr/bin/systemctl start $Unit" }
        'Ensayar' {
            if ($TimerUnit -notmatch '^moodsitto-recuperar-[0-9a-f]{12}$') { throw 'Identificador inválido de la prueba.' }
            "sudo -n /usr/bin/systemd-run --unit=$TimerUnit --on-active=45s --timer-property=AccuracySec=1s /usr/bin/systemctl start $Unit && sudo -n /usr/bin/systemctl stop $Unit"
        }
        'Reiniciar' { 'sudo -n /usr/bin/systemctl --no-block reboot' }
    }
}

function Invoke-RecoveryChange {
    param($Target, [string]$Command, [switch]$RebootsHost)
    $access = Invoke-SshCommand $Target.Ssh 'sudo -n -v' -AllowFailure
    if ($access.Code -eq 0) {
        $result = Invoke-SshCommand $Target.Ssh $Command -AllowFailure:$RebootsHost
        if ($result.Code -ne 0 -and $result.Code -ne 255) { throw $result.Output }
        return
    }
    if ($access.Code -eq 255) { throw $access.Output }
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
    param([ValidateSet('Estado','Iniciar','Ensayar','Reiniciar')][string]$Action, $Target)
    $initial = Invoke-SshCommand $Target.Ssh (Get-RecoveryCommand Estado $Target.Unit) -AllowFailure
    if ($Action -eq 'Estado') {
        if ($initial.Code -eq 255) { throw $initial.Output }
        Write-Log "$($Target.Name) · $($initial.Output)"
        return
    }
    if ($Action -eq 'Iniciar') {
        Invoke-RecoveryChange $Target (Get-RecoveryCommand Iniciar $Target.Unit)
        $started = Invoke-SshCommand $Target.Ssh (Get-RecoveryCommand Estado $Target.Unit)
        Write-Log "$($Target.Name) · $($started.Output)" 'OK'
        return
    }

    if ($initial.Code -ne 0 -or $initial.Output -ne 'active') { throw 'El motor del equipo elegido debe estar activo antes del ensayo.' }
    if ($Target.Engine -eq 'MongoDB') { $check = Test-MongoTopology }
    else { $check = Test-MariaPrimary }
    if ($check.Status -ne 'APROBADO') { throw "Comprobación previa: $($check.Summary)" }
    Write-Log "Comprobación previa aprobada · $($check.Summary)" 'OK'

    $continuity = $false
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
        # Con el motor fuera, comprueba que el otro lado sigue respondiendo.
        try {
            if ($Target.Engine -eq 'MongoDB') {
                $id = [Guid]::NewGuid().ToString()
                # La elección puede tardar varios segundos. Espera al nuevo principal antes de guardar.
                do {
                    $election = Invoke-MongoEval 'print(db.hello().isWritablePrimary)' -AllowFailure
                    if ($election.Code -eq 0 -and $election.Output -eq 'true') { break }
                    Start-Sleep -Seconds 2
                } while ($watch.Elapsed.TotalSeconds -lt 24)
                if ($election.Code -ne 0 -or $election.Output -ne 'true') { throw 'MongoDB todavía no confirmó un principal durante la ventana del ensayo.' }
                try {
                    $write = "const h=db.hello(); const r=db.auditoria_documental.insertOne({actor_id_user:null,accion:'prueba_recuperacion',recurso:'presentacion',recurso_id:null,resultado:'ok',correlacion_id:'$id',metadata_segura:{datos:'sinteticos'},created_at:new Date()},{writeConcern:{w:'majority',wtimeout:5000}}); print(JSON.stringify({principal:h.primary,confirmada:r.acknowledged}))"
                    $primary = Invoke-MongoEval $write
                    $continuity = $primary.Output -match '"confirmada":true'
                    if (-not $continuity) { throw 'MongoDB no confirmó la escritura de prueba.' }
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
                if ($write.Output -ne '1') { throw 'MariaDB principal no confirmó la escritura de prueba.' }
                $continuity = $true
                Write-Log 'MariaDB principal aceptó una escritura de prueba. La transacción se revirtió.' 'OK'
            }
        } catch {
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
    Write-Log "Motor activo en $($watch.Elapsed.TotalSeconds.ToString('0.0')) s." 'OK'
    do {
        if ($Target.Engine -eq 'MongoDB') { $check = Test-MongoTopology }
        else { $check = Test-MariaReplica }
        if ($check.Status -ne 'PENDIENTE' -or $watch.Elapsed.TotalSeconds -ge 120) { break }
        Start-Sleep -Seconds 3
        [Windows.Forms.Application]::DoEvents()
    } while ($true)
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
    if (Test-TcpPort 'localhost' $start.Port -TimeoutMs 500) {
        Write-Log "El puerto $($start.Port) ya está en uso. Pulsa Ver estado para comprobar qué servicio responde." 'PENDIENTE'
        return
    }
    Register-TestCommand $start.File $start.Arguments
    $quoted = $start.Arguments | ForEach-Object { if ($_ -match '\s') { '"{0}"' -f $_ } else { $_ } }
    # APIcore abre la consola donde el usuario puede ingresar las claves de aplicación sin mostrarlas en el panel.
    Start-Process -FilePath $start.File -ArgumentList ($quoted -join ' ') -WindowStyle Normal
    Write-Log "$Service · ventana de arranque abierta. Usa Ver estado para comprobar el puerto."
}
