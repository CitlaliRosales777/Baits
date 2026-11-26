# Arquitectura objetivo y límites

## Topología

| Nodo | Servicio | Rol |
|---|---|---|
| Windows fijo (`desktop-smecf2n`) | MariaDB | principal de escritura, `server_id=1` |
| HP Ubuntu (`ubuntu-hp`) | MariaDB | réplica GTID, `read_only`, configuración de 3.3 GiB |
| VPS (`lvltechmx`) | MongoDB | miembro preferido, prioridad 2 |
| Windows fijo | MongoDB | secundario elegible, prioridad 1 |
| Laptop Windows | MongoDB | secundario con datos, prioridad 0 |

Toda comunicación usa direcciones Tailscale. Antes de aplicar configuraciones deben sustituirse marcadores y comprobar que cada `bindIp`/`bind-address` corresponde al equipo correcto. No se abre 3306 ni 27017 a Internet.

MariaDB replica de forma asíncrona: puede existir retraso y pérdida de las últimas transacciones si se promueve una réplica desactualizada. La promoción es manual. MongoDB usa `rsMoodsitto` y escrituras importantes con `w: "majority"`; con tres votos requiere dos miembros disponibles. La laptop temporal reduce la disponibilidad cuando está apagada.

## Modelo híbrido

MariaDB conserva identidad, sesiones/tokens, citas, medicamentos, recordatorios y datos relacionales. MongoDB contiene `catalogo_emociones`, `registros_emocionales`, `resumenes_emocionales` y `auditoria_documental`.

`users.id_user` se copia como entero `id_user` en documentos MongoDB. No existe una clave foránea entre motores: el backend debe autenticar al usuario, usar el identificador de la sesión y filtrar siempre por `id_user`. Una operación que cruza motores usa idempotencia y compensación; no se declara transacción distribuida.

## Contrato backend observado

Revisión de las siete ramas remotas de `CitlaliRosales777/Baits`.

| Rama revisada | Contenido relevante |
|---|---|
| `main` y `Pruebas` (`12f2f12`) | Mismo commit con el esquema SQL de referencia. |
| `Fronted` (`fcfa904`) | Interfaz y JavaScript del cliente. El acceso a bases corresponde a los servicios del servidor. |
| `Terre-Devo-front` (`35cb87c`) | Diseño y prototipo HTML de seguimiento. |
| `backend-moodsitto` (`5fb72ca`) | PHP/PDO MySQL, perfil, recordatorios, login con Bearer y persistencia en `api_tokens` y `login_intentos`. |
| `api-citas` (`1b2b419`) | Incorpora APIcore PHP/Python y amplía el backend Moodsitto con citas y catálogos. El cliente incluido usa el contrato de autenticación de APIcore. |
| `db-manager` (`3c2eb2f`, base de esta revisión) | Esquema híbrido, catálogos de estados, configuración y operación de MariaDB y MongoDB. |

Ambas ramas backend leen `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER` y `DB_PASS`. El backend de citas consulta `citas_medicas`, `doctors`, `area`, `location`, `especialidad` y `estado`. Requiere catálogos poblados para crear citas. Los catálogos de ejemplo de esa rama son para pruebas.

El esquema híbrido base conserva 23 tablas. La [migración de intentos de login](../../mariadb/estructura/03-login-intentos.sql) añade la tabla complementaria que esperan ambos backends. MongoDB está previsto para el seguimiento emocional del modelo híbrido. El módulo `moods` de APIcore usa su propio SQL. La integración entre servicios, tokens e identidades se describe en [APIcore y Moodsitto](../../backend-integracion/ARQUITECTURA_APICORE.md).

