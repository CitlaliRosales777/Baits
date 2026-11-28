# Ejecutar el panel de pruebas de Moodsitto

## Abrir el panel

En la laptop `DESKTOP-0DDRLDI`, abre Tailscale y comprueba que esté conectado. Después, haz doble clic en [INICIAR-PRUEBAS.cmd](INICIAR-PRUEBAS.cmd), dentro de la carpeta `Baits-db-manager\presentacion`. El lanzador abre la ventana de pruebas con Windows PowerShell.

También puedes abrirlo desde PowerShell:

```powershell
$carpeta = Join-Path ([Environment]::GetFolderPath('Desktop')) 'Baits-db-manager\presentacion'
Set-Location -LiteralPath $carpeta
.\INICIAR-PRUEBAS.cmd
```

Si guardaste `Baits-db-manager` en otra ubicación, abre su carpeta `presentacion` y ejecuta el mismo archivo desde allí.

Pulsa **Mostrar conexiones** en la cabecera para ver los destinos SSH y el estado de los accesos.

## Iniciar APIcore y el sitio local

1. En el panel, abre **Inicio local**.
2. En **Carpeta del repositorio APIcore**, elige la carpeta raíz de `Baits-demo`, la que contiene `apicore`. En esta laptop, el clon dentro del proyecto está en `C:\Users\kdl_m\OneDrive\Documentos2\ChatGPT\moodsito proyecto\Baits-demo`.
3. En **Ruta de php.exe**, comprueba que diga `C:\xampp\php\php.exe`. Pulsa **Ver estado** para comprobar que PHP carga `pdo_mysql`, `mbstring` y `mongodb`. Si falta `mongodb`, usa **Instalar MongoDB para PHP**.
4. Si es la primera vez que usas el panel con esa cuenta de Windows, pulsa **Solicitar accesos**. Pasa el código de solicitud al responsable del Windows fijo. Cuando envíe el paquete cifrado, pulsa **Recibir accesos**. Si el panel ya indica que los accesos están disponibles, sigue al paso siguiente.
5. Pulsa **Iniciar APIcore** y deja abierta la consola de PHP. Comprueba que [APIcore /health](http://localhost:8000/health) devuelva HTTP `200`.
6. Para abrir el sitio, configura la carpeta del repositorio del frontend, pulsa **Iniciar frontend PHP** y luego **Abrir sitio**. El inicio de sesión está en [localhost:5500](http://localhost:5500/login.html).

## Guardar y consultar datos de prueba

Para guardar una emoción de ensayo, abre **Datos de prueba** con APIcore activo en el puerto `8000`. Elige o escribe una emoción, indica la intensidad y pulsa **Guardar emoción**. Puedes añadir una nota ficticia. También puedes guardar un recordatorio con fecha y hora. Al guardar, el panel muestra la respuesta de APIcore e intenta leer el registro de nuevo. Los botones **Consultar** recuperan los registros de la cuenta ficticia del panel, incluso después de reabrirlo con la misma cuenta de Windows.

En **Evidencia de la operación**, la columna **Consulta SQL o MongoDB** muestra la operación y **Respuesta y actividad** muestra el resultado real. MariaDB muestra su SQL preparado con parámetros `?`. MongoDB muestra el equivalente en `mongosh` de la operación del controlador PHP.

## Gestionar cartas del catálogo

1. Abre **Datos de prueba → Gestionar cartas**. Elige **Nueva carta** para crearla o selecciona una existente para editarla.
2. Escribe el nombre y la descripción. Elige un **Icono** y revisa la vista previa. Puedes elegir el color con un valor hexadecimal como `#D4A8E8`.
3. Si quieres añadir matices, escribe uno por línea. Los detalles son opcionales y se separan con `|`. Una línea de ejemplo es `Asombro | Algo inesperado | Algo me dejó sin palabras`.
4. Para desactivar una carta existente, desmarca **Mostrar carta en Mis emociones**. Puedes volver a marcarla para reactivarla. Los registros anteriores conservan lo que se guardó originalmente.
5. Pulsa **Guardar carta**. El panel escribe en `moodsitto.catalogo_emociones` con confirmación por mayoría y muestra la consulta de comprobación. Al volver a [Mis emociones](http://localhost:5500/trackingmazz0o.html), la página consulta las cartas activas.

En una instalación nueva, prepara el catálogo con `mongodb/colecciones/01-modelo-hibrido.js` y carga las seis cartas iniciales ejecutando `mongodb/colecciones/05-cargar-cartas-iniciales.js` con `mongosh` desde la raíz del repositorio. Si la cuenta de APIcore ya existía, un administrador de MongoDB aplica una vez `mongodb/colecciones/04-permiso-catalogo-apicore.js`. APIcore lee el catálogo y el panel lo publica con su propia cuenta de MongoDB.

## Consultar el ensayo real de MongoDB

En **Recuperación**, selecciona **VPS · miembro MongoDB**. La vista carga el último ensayo guardado para esta cuenta en esta laptop. En la línea de tiempo verás el primario inicial, el nodo que tomó el relevo, la primera escritura confirmada por mayoría, el regreso del servicio y la reintegración del VPS. Debajo aparecen el resultado y los roles observados al finalizar.

Usa **Siguiente** y **Anterior** para mostrar qué equipo se detuvo y cuál recibió las escrituras en cada paso. **Ver eventos** abre la lista completa con los tiempos. El recorrido de un ensayo guardado solo muestra evidencia ya recopilada.

Para observar MariaDB en tiempo real, pulsa **Seguir MariaDB en vivo**. La vista indica si responden los puertos del Windows fijo, la HP y MaxScale, y muestra qué primario confirma MaxScale. Si falla solo la HP mientras es réplica, el primario puede seguir disponible. Si cae la conexión a MaxScale, el panel indica que no puede confirmar el primario a través del proxy. Si MaxScale identifica otro primario, el panel muestra ambos nombres en **Cambio observado**. El botón **Dejar de seguir** detiene las consultas. Este modo solo lee el estado.

En el ensayo aprobado, el Windows fijo confirmó la escritura a los **2.4 s** y el VPS volvió a integrarse como secundario a los **34.9 s**. El panel mide esos tiempos desde que termina la orden de parada.

## Repetir el ensayo en vivo

1. En **Pruebas**, ejecuta la comprobación de topología de MongoDB. Confirma que el VPS es el primario y que el Windows fijo y la laptop aparecen como secundarios. Deja los tres equipos conectados a Tailscale.
2. En **Recuperación**, selecciona **VPS · miembro MongoDB** y pulsa **Ver estado**. Comprueba que el motor responde.
3. Con autorización para interrumpir MongoDB, pulsa **Ensayar caída del motor** y confirma. Este ensayo requiere que el VPS sea el primario. Si el Windows fijo sigue como primario, usa el resultado guardado para la exposición.
4. Sigue la línea de tiempo hasta que el panel confirme la topología final. El ensayo programa el arranque del servicio antes de detenerlo. Usa **Actividad y comandos** para revisar los detalles.

Antes de exponer, abre **Inicio local → Ver estado**. Si cerraste la laptop, reiniciaste Windows o terminaste las consolas de PHP, vuelve a iniciar APIcore y el frontend y comprueba los puertos `8000` y `5500`.

En **Pruebas**, vuelve a ejecutar las filas que muestren resultados anteriores. Las tres restauraciones aisladas **14A**, **14B** y **14C** se ejecutan por separado. Cada una comprueba una copia real en una base temporal y elimina esa base al terminar. La prueba de fragmentación consulta los datos ficticios de `moodsitto_lab` en la HP.

El ensayo de la HP comprueba que el Windows fijo sigue escribiendo cuando se detiene la réplica. Para ver el ensayo en el sentido contrario, abre **Recuperación → Ver caída del Windows fijo**. El informe guardado muestra cuándo la HP asumió el rol de primario, cuándo APIcore confirmó una escritura y cuándo volvió el Windows fijo. Ese ensayo usó la instancia de APIcore en el puerto `8002`, conectada a MaxScale.

La instancia habitual de APIcore en `8000` usa MaxScale en esta laptop. Puedes comprobarla en **Inicio local → Ver estado** y la ruta en la fila **Recuperación ante fallos**. Si reinicias APIcore, vuelve a iniciar sesión en el frontend.

Para las demás pruebas y la exportación de evidencias, consulta la [guía completa de presentación](GUIA_DEMO.md).
