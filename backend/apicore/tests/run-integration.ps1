[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$composeFile = Join-Path $PSScriptRoot '..\docker-compose.test.yml'
$runSuffix = [guid]::NewGuid().ToString('N').Substring(0, 12)
$projectName = "moodsitto-apicore-tests-$runSuffix"
$rootPassword = [guid]::NewGuid().ToString('N')
$appPassword = [guid]::NewGuid().ToString('N')
$apiSecret = [guid]::NewGuid().ToString('N') + [guid]::NewGuid().ToString('N')

$env:MOODSITTO_TEST_ROOT_PASSWORD = $rootPassword
$env:MOODSITTO_TEST_APP_PASSWORD = $appPassword
$env:MOODSITTO_TEST_API_SECRET = $apiSecret

function Invoke-SqlFile {
    param([Parameter(Mandatory)][string]$ContainerPath)
    & docker compose -p $projectName -f $composeFile exec -T `
        -e "MYSQL_PWD=$rootPassword" mariadb `
        sh -lc "mariadb --user=root --show-warnings < '$ContainerPath'"
    if ($LASTEXITCODE -ne 0) { throw "Falló SQL: $ContainerPath" }
}

try {
    & docker compose -p $projectName -f $composeFile up --detach --wait mariadb
    if ($LASTEXITCODE -ne 0) { throw 'MariaDB no alcanzó estado saludable.' }

    Get-ChildItem (Join-Path $PSScriptRoot '..\..\..\databases\mariadb\migrations\*.sql') |
        Sort-Object Name |
        ForEach-Object { Invoke-SqlFile "/database/migrations/$($_.Name)" }
    Get-ChildItem (Join-Path $PSScriptRoot '..\..\..\databases\mariadb\seeds\*.sql') |
        Sort-Object Name |
        ForEach-Object { Invoke-SqlFile "/database/seeds/$($_.Name)" }
    Invoke-SqlFile '/api-tests/fixtures.sql'

    $grantSql = @"
CREATE USER 'moodsitto_api'@'%' IDENTIFIED BY '$appPassword';
GRANT SELECT, INSERT, UPDATE, DELETE ON moodsitto.* TO 'moodsitto_api'@'%';
FLUSH PRIVILEGES;
"@
    & docker compose -p $projectName -f $composeFile exec -T `
        -e "MYSQL_PWD=$rootPassword" mariadb `
        mariadb --user=root --execute $grantSql
    if ($LASTEXITCODE -ne 0) { throw 'No fue posible crear el usuario de aplicación.' }

    & docker compose -p $projectName -f $composeFile up --detach --build --wait api
    if ($LASTEXITCODE -ne 0) { throw 'APIcore no alcanzó estado saludable.' }

    & docker compose -p $projectName -f $composeFile exec -T api python /tests/e2e.py
    if ($LASTEXITCODE -ne 0) {
        & docker compose -p $projectName -f $composeFile logs --no-color api
        throw 'Falló la prueba E2E de APIcore.'
    }

    Write-Output 'PASS: integración APIcore + MariaDB completada.'
}
finally {
    & docker compose -p $projectName -f $composeFile down --volumes --remove-orphans
    Remove-Item Env:\MOODSITTO_TEST_ROOT_PASSWORD -ErrorAction SilentlyContinue
    Remove-Item Env:\MOODSITTO_TEST_APP_PASSWORD -ErrorAction SilentlyContinue
    Remove-Item Env:\MOODSITTO_TEST_API_SECRET -ErrorAction SilentlyContinue
}

