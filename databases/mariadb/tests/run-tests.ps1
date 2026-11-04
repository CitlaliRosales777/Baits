[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$composeFile = Join-Path $PSScriptRoot '..\docker-compose.test.yml'
$projectName = 'moodsitto-db-tests'
$testPassword = [guid]::NewGuid().ToString('N')
$env:MOODSITTO_TEST_ROOT_PASSWORD = $testPassword

function Invoke-ComposeSqlFile {
    param([Parameter(Mandatory)][string]$ContainerPath)

    & docker compose -p $projectName -f $composeFile exec -T `
        -e "MYSQL_PWD=$testPassword" mariadb `
        sh -lc "mariadb --user=root --show-warnings < '$ContainerPath'"
    if ($LASTEXITCODE -ne 0) {
        throw "Falló el archivo SQL: $ContainerPath"
    }
}

try {
    & docker compose -p $projectName -f $composeFile down --volumes --remove-orphans
    & docker compose -p $projectName -f $composeFile up --detach --wait
    if ($LASTEXITCODE -ne 0) { throw 'MariaDB no alcanzó un estado saludable.' }

    Get-ChildItem (Join-Path $PSScriptRoot '..\migrations\*.sql') |
        Sort-Object Name |
        ForEach-Object { Invoke-ComposeSqlFile "/workspace/migrations/$($_.Name)" }

    Get-ChildItem (Join-Path $PSScriptRoot '..\seeds\*.sql') |
        Sort-Object Name |
        ForEach-Object { Invoke-ComposeSqlFile "/workspace/seeds/$($_.Name)" }

    Get-ChildItem (Join-Path $PSScriptRoot '*.sql') |
        Sort-Object Name |
        ForEach-Object { Invoke-ComposeSqlFile "/workspace/tests/$($_.Name)" }

    Write-Output 'PASS: migraciones, datos sintéticos y pruebas SQL completados.'
}
finally {
    & docker compose -p $projectName -f $composeFile down --volumes --remove-orphans
    Remove-Item Env:\MOODSITTO_TEST_ROOT_PASSWORD -ErrorAction SilentlyContinue
}

