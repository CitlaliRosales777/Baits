$ErrorActionPreference = 'Stop'
$Repo = Split-Path -Parent $PSScriptRoot
$Source = Join-Path $Repo 'bd-moodsitto.sql'
$TargetDir = Join-Path $Repo 'mariadb\estructura'
$Target = Join-Path $TargetDir '01-esquema-hibrido.sql'

$lines = Get-Content -LiteralPath $Source
$result = [System.Collections.Generic.List[string]]::new()
$skip = $false
foreach ($line in $lines) {
    if ($line -eq '-- PARTE 6. EMOCIONES') {
        $skip = $true
        $result.Add('-- PARTE 6. EMOCIONES: almacenadas en MongoDB')
        $result.Add('-- Las colecciones se crean con mongodb/colecciones/01-modelo-hibrido.js.')
        $result.Add('-- users.id_user se conserva como referencia lógica, sin FK entre motores.')
        $result.Add('')
        continue
    }
    if ($skip -and $line -eq '-- PARTE 7. AVISOS Y PROTECCIÓN DE DATOS') {
        $skip = $false
    }
    if (-not $skip) {
        $result.Add($line.Replace('2026-11-09-v2-clean', '2026-11-19-v3-hibrido'))
    }
}

$result[0] = '-- MOODSITTO v3 HÍBRIDO | MariaDB 11.4+ | INSTALACIÓN LIMPIA ÚNICAMENTE'
New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
[IO.File]::WriteAllLines($Target, $result, [Text.UTF8Encoding]::new($false))
Write-Output $Target
