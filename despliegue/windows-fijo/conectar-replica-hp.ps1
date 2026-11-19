$ErrorActionPreference='Stop'
$Repo=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$secretFile=Join-Path $Repo 'secrets\windows-fixed.env'
$cfg=@{}
Get-Content -LiteralPath $secretFile|ForEach-Object{if($_ -match '^([^=]+)=(.*)$'){$cfg[$matches[1]]=$matches[2]}}
$password=$cfg.MARIADB_REPL_PASSWORD
if(-not $password){throw 'Falta MARIADB_REPL_PASSWORD'}
$sql="STOP SLAVE; RESET SLAVE ALL; CHANGE MASTER TO MASTER_HOST='100.89.172.17', MASTER_PORT=3306, MASTER_USER='moodsitto_repl', MASTER_PASSWORD='$password', MASTER_USE_GTID=slave_pos; START SLAVE;"
$sql | ssh -i "$env:USERPROFILE\.ssh\id_ed25519" fredy@100.112.196.81 'sudo -n mariadb'
$password=$null; $sql=$null; $cfg.Clear()
if($LASTEXITCODE -ne 0){throw 'Falló CHANGE MASTER'}
Start-Sleep -Seconds 3
ssh -i "$env:USERPROFILE\.ssh\id_ed25519" fredy@100.112.196.81 "sudo -n mariadb -e 'SHOW ALL SLAVES STATUS\G'" |
    Select-String 'Slave_IO_Running:|Slave_SQL_Running:|Seconds_Behind_Master:|Last_IO_Error:|Last_SQL_Error:|Gtid_IO_Pos:'
