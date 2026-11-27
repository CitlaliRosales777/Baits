# Valida archivos obligatorios, tablas base y nombres de archivos sensibles rastreados.
$ErrorActionPreference='Stop'
$Repo=Split-Path -Parent $PSScriptRoot
$required=@(
 'backend-integracion\README_EMPIEZA_AQUI.md','backend-integracion\.env.example',
 'backend-integracion\configurar.ps1','backend-integracion\configurar.sh',
 'backend-integracion\probar-conexiones.ps1','backend-integracion\probar-conexiones.sh',
 'backend-integracion\ERRORES_FRECUENTES.md','backend-integracion\INTEGRACION_BACKEND_MOODSITTO.md',
 'backend-integracion\CHECKLIST_BACKEND.md','backend-integracion\CONTRATO_DATOS_MOODSITTO.md',
 'backend-integracion\ARQUITECTURA_APICORE.md',
 'mariadb\estructura\03-login-intentos.sql',
 'mariadb\estructura\04-esquema-apicore.sql','mariadb\estructura\verificar-apicore.sql',
 'backend-integracion\apicore.env.example',
 'mariadb\estructura\01-esquema-hibrido.sql','mongodb\colecciones\01-modelo-hibrido.js',
 'presentacion\interfaz-pruebas.ps1','presentacion\operaciones-panel.ps1',
 'presentacion\instalar-mongodb-php.ps1',
 'presentacion\INICIAR-PRUEBAS.cmd','presentacion\GUIA_DEMO.md'
)
foreach($f in $required){if(-not(Test-Path (Join-Path $Repo $f))){throw "Falta $f"}}
$tables=(Select-String -LiteralPath (Join-Path $Repo 'mariadb\estructura\01-esquema-hibrido.sql') -Pattern '^CREATE TABLE').Count
if($tables -ne 23){throw "Se esperaban 23 tablas; hay $tables"}
$trackedSecrets=git -C $Repo ls-files | Select-String -Pattern '(^|/)(\.env|.*\.key|.*\.pem|mongodb-keyfile)$'
if($trackedSecrets){throw "Posibles secretos versionados: $trackedSecrets"}
Write-Output '[OK] Archivos obligatorios'
Write-Output '[OK] 23 tablas híbridas'
Write-Output '[OK] Sin archivos de secretos rastreados'
