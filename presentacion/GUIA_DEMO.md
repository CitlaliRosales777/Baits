# Presentación de Moodsitto desde la laptop

La laptop `DESKTOP-0DDRLDI` ejecuta el frontend, APIcore y la consola de pruebas. APIcore PHP se conecta por Tailscale a la base `apicore` en el Windows fijo. El HP recibe la réplica asíncrona de MariaDB. MongoDB usa `rsMoodsitto` en VPS, fijo y laptop. El frontend de `Fronted` usa APIcore para iniciar sesión y leer el perfil. APIcore guarda los recordatorios en MariaDB y las emociones en MongoDB. Cada cuenta consulta sus propios datos.

## 1. Preparar la laptop

Abre PowerShell y verifica la red y el PHP que ya incluye XAMPP.

```powershell
tailscale ip -4
Test-NetConnection 100.89.172.17 -Port 3306
Get-Service MongoDB
$php = 'C:\xampp\php\php.exe'
& $php -v
& $php --ini
& $php -m | Select-String '^(pdo_mysql|mbstring|mongodb)$'
```

Espera la IP de la laptop `100.86.5.50`, `TcpTestSucceeded : True`, MongoDB `Running` y los tres módulos PHP. Si falta `mongodb`, revisa la versión, arquitectura, Thread Safety y compilador con `& $php -i | Select-String "Architecture|Thread Safety|Compiler|PHP Extension Build"`. Copia la DLL compatible desde [las descargas oficiales del controlador PHP](https://pecl.php.net/package/mongodb) a `C:\xampp\php\ext`, agrega `extension=mongodb` al archivo que indica `--ini` y vuelve a ejecutar `& $php -m`. Para la consola de DB Manager también necesitas Git, cliente MariaDB, `mongosh` y OpenSSH según la prueba. APIcore usa el MariaDB remoto a través de PDO.

Si aún no tienes las copias del repositorio, clona las tres ramas en carpetas separadas del Escritorio. Si ya existen, actualízalas desde su rama con `git pull --ff-only` y conserva tus cambios locales.

```powershell
$escritorio = [Environment]::GetFolderPath('Desktop')
git clone --branch api-citas https://github.com/CitlaliRosales777/Baits.git (Join-Path $escritorio 'Baits-demo')
git clone --branch Fronted https://github.com/CitlaliRosales777/Baits.git (Join-Path $escritorio 'Baits-frontend')
git clone --branch db-manager https://github.com/CitlaliRosales777/Baits.git (Join-Path $escritorio 'Baits-db-manager')
```

Si **Ver estado** dice que falta MongoDB en PHP, ejecuta el asistente desde tu copia de `db-manager`. Elige la DLL de PHP.net según tu versión de XAMPP, la prueba y guarda una copia de `php.ini` antes de modificarlo.

```powershell
$repo = Join-Path ([Environment]::GetFolderPath('Desktop')) 'Baits-db-manager'
powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo 'presentacion\instalar-mongodb-php.ps1')
```

## 2. Arrancar APIcore y el frontend local

En la primera ventana de PowerShell, ejecuta el arranque. Los dos cuadros de entrada están ocultos. El primero pide la clave de MariaDB de `apicore_app` que ya utilizabas. El segundo pide la de MongoDB de `apicore_emociones`, que DB Manager entrega por el canal privado. En el Windows fijo, la cuenta que la guardó puede recuperarla desde `%LOCALAPPDATA%\Moodsitto\apicore-emociones.credential.xml`. Ingresa cada contraseña cuando aparezca su aviso.

```powershell
$escritorio = [Environment]::GetFolderPath('Desktop')
& (Join-Path $escritorio 'Baits-db-manager\presentacion\iniciar-apicore.ps1')
```

Deja esa ventana abierta. [APIcore /health](http://localhost:8000/health) debe devolver HTTP 200 y `"status":"ok"`. El controlador ejecuta `SELECT 1` por PDO. Un 503 indica que PHP responde, pero su conexión SQL falló. Al terminar, cierra esa ventana para liberar las variables de la sesión.

En una segunda ventana, sirve el frontend de `Fronted`. Su carpeta contiene el tablero y el cliente de APIcore.

```powershell
$escritorio = [Environment]::GetFolderPath('Desktop')
& 'C:\xampp\php\php.exe' -S localhost:5500 -t (Join-Path $escritorio 'Baits-frontend\fronted\fronted')
```

Para la presentación, abre [el inicio de sesión local](http://localhost:5500/login.html) y usa la cuenta de prueba `demo@test.com`. La contraseña está en la ficha local `evidencias-locales/ACCESO_DEMO.md`, excluida de Git. La ficha se entrega por separado.

Si quieres mostrar el registro, abre [Registro local](http://localhost:5500/registro.html) y crea otra cuenta ficticia. Comprueba que el login abra el tablero y que «Mi perfil» muestre los datos de APIcore. `fix-front-login` está reservado para probar el backend PHP de Moodsitto en el puerto 8001.

En el tablero, crea un recordatorio, recarga la página, márcalo como hecho y vuelve a recargar. En «Seguimiento emocional», registra una emoción con una nota ficticia y comprueba que siga en el historial al volver a iniciar sesión. Con otra cuenta, verifica que sus listas estén separadas. Los datos guardados únicamente en el navegador por versiones anteriores no se migran automáticamente.

## 3. Ejecutar las pruebas de DB Manager

En una tercera ventana, abre el panel o ejecuta únicamente el control de APIcore.

```powershell
$escritorio = [Environment]::GetFolderPath('Desktop')
Set-Location (Join-Path $escritorio 'Baits-db-manager')
& .\presentacion\INICIAR-PRUEBAS.cmd
# Comprobación de APIcore sin abrir la ventana gráfica
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\presentacion\interfaz-pruebas.ps1 -CheckApiCore
```

El panel carga las credenciales de aplicación desde `backend-integracion/.env` cuando está configurado. Usa el [asistente de integración](../backend-integracion/README_EMPIEZA_AQUI.md) antes de la exposición. La clave de `apicore_app` se usa en PHP. El panel usa las cuentas de aplicación de `moodsitto` para sus consultas directas. Inventario, monitoreo y respaldos requieren acceso SSH autorizado. Las cuentas con acceso al estado de réplica y a las restauraciones deben prepararse antes de la clase.

| Orden | Prueba del panel | Qué demuestra |
|---|---|---|
| 1 | Conectividad e inventario | Alcance de los equipos, puertos y recursos desde la laptop. |
| 2 | APIcore local y MariaDB | La ruta HTTP responde y PDO ejecuta una consulta SQL. |
| 3 | MariaDB principal, réplica y evento ficticio | Binlog del principal, hilos de réplica y llegada de un registro identificado al HP. |
| 4 | Replica set y escritura con mayoría | Rol de cada miembro y lectura del mismo documento en los secundarios. El rol principal puede cambiar tras una elección. |
| 5 | Modelo híbrido, fragmentación y auditoría | Tablas, colecciones, reconstrucción del laboratorio y acceso a auditorías. |
| 6 | Respaldos, restauraciones y monitoreo | Programación, copias encontradas, recuperación en el espacio de prueba y estado de los servicios. |

Ejecuta las pruebas en orden y exporta el reporte a `evidencias-locales/`. El conjunto **Ejecutar todas las seguras** incluye escrituras sintéticas y la reconstrucción del laboratorio. Las restauraciones se lanzan por separado con confirmación. El panel marca **BLOQUEADO** cuando faltan credenciales, permisos o el servicio necesario.

Después de ejecutar una prueba, selecciónala en la tabla y abre **Comandos de la prueba**. Ahí se muestran las consultas SQL y de MongoDB, las llamadas por SSH o el script que se ejecutó, según la prueba. **Actividad** muestra los resultados y errores. El reporte incluye ambos y oculta las contraseñas.

### Arrancar desde la ventana

En **Inicio local**, revisa las rutas de los repositorios y de `php.exe`. Pulsa **Iniciar APIcore** para abrir la consola de PHP. Si solicita claves, escríbelas en esa consola. Pulsa **Iniciar frontend PHP** y después **Ver estado** para comprobar los módulos de XAMPP, `/health` en el puerto 8000 y el inicio de sesión en el puerto 5500. **Abrir sitio** abre el frontend local. Para cerrar un servidor local durante la presentación, usa **Ctrl+C** en su consola de arranque.

## 4. Explicar y verificar una falla

En **Recuperación** puedes usar **Ver estado**, **Iniciar motor**, **Ensayar caída del motor** y **Reiniciar servidor** en el HP y el VPS. Si el HP pide autorización, el panel abre una terminal SSH para `sudo`. Las acciones de interrupción requieren confirmación durante la presentación.

- **Ensayar caída del motor** programa el arranque del servicio en 45 segundos, lo detiene y comprueba qué ocurre mientras está fuera. MariaDB verifica una escritura en el principal mientras la réplica está detenida. MongoDB espera un principal y prueba una escritura con confirmación por mayoría. Al volver el servicio, el panel consulta nuevamente la topología y registra el tiempo.
- **Reiniciar servidor** verifica que el motor se inicie con el sistema. Después compara el identificador de arranque y espera al servicio. El encendido de un equipo que quedó totalmente apagado requiere acceso físico o administración remota de hardware.
- En **Actividad y comandos** puedes seguir la operación y copiar lo que ejecutó. Exporta el reporte desde **Pruebas** para conservar esa evidencia.

- **MariaDB.** Si cae el HP, el principal puede seguir escribiendo. Si cae el principal, las escrituras esperan su recuperación o una promoción manual tras revisar GTID. La réplica asíncrona podría quedar por detrás. Para comprobar un registro creado por APIcore, compara en ambos nodos el `UserId` de la cuenta ficticia con una cuenta autorizada para leer `apicore`. La prueba automática de replicación del panel usa `moodsitto.auditoria_eventos`.
- **MongoDB.** Dos votos de tres conservan la mayoría si queda un nodo elegible. Con un solo miembro, se pierde el principal para escrituras. En una prueba autorizada, captura roles y salud antes de la caída, durante la elección y al volver a conectar el miembro.
- **Restauración.** Recupera una copia en un espacio de prueba y consulta un registro conocido. Registra la fecha de la copia y cuánto tarda en volver la lectura. El respaldo programado del HP cubre `moodsitto` y `apicore` por separado. La fila 14C del panel comprueba las tablas de APIcore cuando hay acceso autorizado en el HP. El respaldo del VPS incluye la colección del historial de emociones. La caída controlada queda pendiente de un ensayo autorizado.

Revisa el [estado de aceptación](../docs/pruebas/ESTADO_ACEPTACION.md), el [plan de respaldo y recuperación](../docs/recuperacion/PLAN_RECUPERACION.md) y el [protocolo de contingencia](contingencia/CONTINGENCIA.md) antes de iniciar una interrupción.
