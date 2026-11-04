# Pruebas CRUD e integridad

## Ejecución

```powershell
& .\databases\mariadb\tests\run-tests.ps1
```

El runner levanta MariaDB 11.4 sin publicar puertos, genera un proyecto y volumen exclusivos por ejecución, crea una contraseña efímera, aplica migraciones/semillas, ejecuta las pruebas y elimina el entorno. No se conecta a bases compartidas y dos ejecuciones no comparten nombres ni volúmenes.

## Cobertura automatizada

| Operación/regla | Entidades | Resultado del 3-nov-2026 |
|---|---|---|
| CREATE | usuario, cita, medicamento, recordatorio, diagnóstico, seguimiento emocional | PASS |
| READ con JOIN | usuario + seguimiento + conjunto + emoción específica | PASS |
| UPDATE | teléfono de usuario y lectura posterior | PASS |
| DELETE controlado | recordatorio sin dependencias hijas | PASS |
| FK inexistente | seguimiento con usuario/emoción inexistentes | Rechazado, PASS |
| UNIQUE | segundo usuario con mismo correo | Rechazado, PASS |
| CHECK/NOT NULL | medicamento con cantidad cero y compuesto sin vía | Rechazados, PASS |
| UNIQUE compuesto | mismo nombre y vía de administración | Rechazado, PASS |
| Integridad al borrar | usuario con registros dependientes | Rechazado, PASS |
| Transacción | todas las operaciones CRUD | `ROLLBACK`, PASS |
| Instalación limpia | 20 tablas, 33 FK, 2 migraciones, InnoDB | PASS |

Las semillas cubren los catálogos y la jerarquía de emociones. Los CRUD de emociones se ejercen mediante la creación y consulta de `trackeo_emo`; las entidades principales solicitadas quedan cubiertas por una escritura válida y/o su uso relacional.

## Registros inexistentes y nulos

- Un `UPDATE`/`DELETE` por PK inexistente afecta cero filas; APIcore debe convertir ese resultado en “no encontrado”, no en éxito silencioso.
- Las FK obligatorias son `NOT NULL`; MariaDB rechaza registros incompletos.
- Ubicación del usuario/doctor y cita del recordatorio permanecen opcionales por diseño.

## Simultaneidad

InnoDB ofrece aislamiento transaccional y bloqueo por fila, pero no se ejecutó una prueba automatizada de dos sesiones concurrentes. Antes de producción debe definirse la política de APIcore para conflictos (por ejemplo, control optimista con versión o `SELECT ... FOR UPDATE` en operaciones críticas). No se afirma que exista control de concurrencia de negocio.

## Repetibilidad

El runner destruye únicamente el proyecto Compose con sufijo aleatorio que creó esa ejecución. Cada ejecución parte de cero. Los datos de cada prueba se revierten, y las semillas son ficticias.

