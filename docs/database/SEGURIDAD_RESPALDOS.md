# Seguridad, respaldo y restauración

## Acceso mínimo

`databases/mariadb/security/roles.sql` define tres roles sin credenciales:

- aplicación: DML (`SELECT/INSERT/UPDATE/DELETE`);
- solo lectura: `SELECT` para soporte autorizado;
- migración: DDL/DML sobre la base, asignado temporalmente.

Las cuentas se crean fuera de Git con secretos aleatorios almacenados en el gestor del entorno. APIcore no usa `root`. La conexión debe exigir TLS fuera de la máquina local.

## Configuración de APIcore

Variables esperadas (nombres por acordar): host, puerto, base, usuario, secreto y modo TLS. Solo `.env.example` puede versionarse; `.env` está ignorado. Nunca registrar URI completa, contraseña, hash de usuario, documento ni consulta con datos médicos.

## Protección de datos

- Clasificar identidad, contacto, dirección, salud y emociones como sensibles.
- Cifrar discos/volúmenes y respaldos; restringir claves por ambiente.
- Aplicar autorización por usuario y rol en APIcore, además de permisos SQL.
- Usar consultas preparadas y límites de tamaño.
- Definir retención, rectificación, exportación y borrado conforme a la normativa aplicable antes de producción.
- Mantener documentos en almacenamiento privado; la BD guarda una referencia opaca.
- Las demostraciones y respaldos de prueba usan exclusivamente datos sintéticos.

## Respaldo lógico de desarrollo

Ejemplo, con credenciales entregadas de forma segura por el entorno (no escritas en la línea de comandos compartida):

```powershell
$dumpFile = 'moodsitto-dev-YYYYMMDD.sql'
mariadb-dump --single-transaction --routines --triggers --events `
  --databases moodsitto --result-file=$dumpFile
if ($LASTEXITCODE -ne 0) { throw 'Falló mariadb-dump' }

gzip --force --keep $dumpFile
if ($LASTEXITCODE -ne 0) { throw 'Falló gzip' }

Get-FileHash "$dumpFile.gz" -Algorithm SHA256
```

`--result-file` evita que PowerShell transforme la salida y `gzip` lee directamente el archivo. Esto es seguro tanto en Windows PowerShell 5.1 como en PowerShell 7; no use `| gzip > archivo.gz` para datos binarios.

El archivo debe cifrarse, comprobarse con hash, guardarse fuera del repositorio y someterse a retención. Para producción se requiere además respaldo físico/binlogs según RPO/RTO definidos por DevOps.

## Restauración verificada

1. Crear una instancia aislada y vacía con la misma versión de MariaDB.
2. Verificar hash, descifrar y descomprimir el respaldo.
3. Importar con una cuenta de restauración temporal.
4. Ejecutar las consultas estructurales de `00_schema_assertions.sql` adaptadas a la versión respaldada.
5. Comprobar conteos, FK y una muestra sintética/autorizada.
6. Registrar duración, errores y versión; destruir de forma segura la copia temporal.

Nunca probar una restauración encima de la única copia ni de la base compartida. Un respaldo no se considera válido hasta completar una restauración de ensayo.

## Revisión de secretos

La búsqueda del repositorio solo encontró nombres de campos/inputs de contraseña y hashes ficticios no utilizables. Antes del PR y en CI debe repetirse un escaneo de secretos y revisarse el historial completo.
