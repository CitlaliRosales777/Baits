$ErrorActionPreference = 'Stop'
$Here = $PSScriptRoot
$EnvFile = Join-Path $Here '.env'
if (-not (Test-Path $EnvFile)) { throw 'Falta .env. Ejecuta primero configurar.ps1.' }

$cfg = @{}
Get-Content $EnvFile | ForEach-Object {
    if ($_ -match '^\s*([^#][^=]*)=(.*)$') { $cfg[$matches[1].Trim()] = $matches[2] }
}
function Ok([string]$Text) { Write-Output "[OK] $Text" }
function Tcp([string]$HostName, [int]$Port) {
    $client = [Net.Sockets.TcpClient]::new()
    try { $task=$client.ConnectAsync($HostName,$Port); return $task.Wait(4000) -and $client.Connected }
    finally { $client.Dispose() }
}

if (-not (Get-Command tailscale -ErrorAction SilentlyContinue)) { throw 'No tienes Tailscale instalado.' }
& tailscale status | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'No tienes acceso a Tailscale.' }
Ok 'Conectividad Tailscale'

if (-not (Tcp $cfg.DB_HOST ([int]$cfg.DB_PORT))) { throw 'Servidor MariaDB no responde. Solicita autorización de tu IP Tailscale.' }
Ok 'Servidor MariaDB accesible'
$maria = Get-Command mariadb -ErrorAction SilentlyContinue
if (-not $maria) {
    $maria = Get-ChildItem -Path "$env:ProgramFiles\MariaDB *\bin\mariadb.exe" -File -ErrorAction SilentlyContinue |
        Sort-Object FullName -Descending | Select-Object -First 1
}
if (-not $maria) { throw 'Falta el cliente mariadb; instala solo el cliente, no el servidor.' }
$env:MYSQL_PWD = $cfg.DB_PASS
$corr = [Guid]::NewGuid().ToString()
$sql = "START TRANSACTION; INSERT INTO auditoria_eventos(actor_id_user,accion,recurso,resultado,correlacion_id) VALUES(NULL,'prueba_integracion','backend','ok','$corr'); SELECT COUNT(*) FROM auditoria_eventos WHERE correlacion_id='$corr'; ROLLBACK;"
$mariaPath = if ($maria.Source) { $maria.Source } else { $maria.FullName }
$result = & $mariaPath -h $cfg.DB_HOST -P $cfg.DB_PORT -u $cfg.DB_USER -D $cfg.DB_NAME -NBe $sql 2>&1
$code = $LASTEXITCODE
Remove-Item Env:MYSQL_PWD
if ($code -ne 0 -or $result[-1] -ne '1') { throw "Falló autenticación/prueba MariaDB: $result" }
Ok 'Autenticación MariaDB'
Ok 'Base de datos relacional'
Ok 'Lectura y escritura sintética MariaDB'

$firstMongo = ($cfg.MONGODB_HOSTS -split ',')[0] -replace ':.*$',''
if (-not (Tcp $firstMongo 27017)) { throw 'Servidor MongoDB no responde.' }
Ok 'Servidor MongoDB accesible'
$mongosh = Get-Command mongosh -ErrorAction SilentlyContinue
if (-not $mongosh) { throw 'Falta mongosh; instala solo MongoDB Shell, no el servidor.' }
$mcorr = [Guid]::NewGuid().ToString()
$uri = "mongodb://$($cfg.MONGODB_HOSTS)/$($cfg.MONGODB_DATABASE)?replicaSet=$($cfg.MONGODB_REPLICA_SET)&authSource=$($cfg.MONGODB_AUTH_SOURCE)&retryWrites=true&w=majority"
$js = "const c='$mcorr'; const h=db.hello(); if(h.setName!='$($cfg.MONGODB_REPLICA_SET)') throw new Error('Replica set incorrecto'); db.auditoria_documental.insertOne({actor_id_user:null,accion:'prueba_integracion',recurso:'backend',recurso_id:null,resultado:'ok',correlacion_id:c,metadata_segura:{datos:'sinteticos'},created_at:new Date()}); if(db.auditoria_documental.countDocuments({correlacion_id:c})!==1) throw new Error('Lectura fallida'); db.auditoria_documental.deleteOne({correlacion_id:c}); print('TEST_OK');"
$result = & $mongosh.Source --quiet $uri -u $cfg.MONGODB_USER -p $cfg.MONGODB_PASSWORD --eval $js 2>&1
if ($LASTEXITCODE -ne 0 -or $result[-1] -ne 'TEST_OK') { throw "Falló autenticación/prueba MongoDB: $result" }
Ok 'Autenticación MongoDB'
Ok 'Replica set identificado'
Ok 'Base de datos documental'
Ok 'Lectura y escritura sintética MongoDB'
Ok 'Permisos de aplicación'
Ok 'Integración preparada'

