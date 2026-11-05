# Pruebas de base de datos

## Ejecución reproducible

Requisitos: Docker Desktop o Engine, Compose v2 y PowerShell.

```powershell
& .\databases\mariadb\tests\run-tests.ps1
```

El runner crea un proyecto Compose y una contraseña efímeros, no publica puertos, aplica las migraciones y semillas en orden, ejecuta el preflight y las pruebas SQL, y elimina contenedor, red y volumen incluso si una prueba falla.

## Cobertura verificada

Ejecución del 4 de noviembre de 2026 con MariaDB 11.4:

- 23 tablas de dominio, 42 claves foráneas y 3 migraciones.
- Todas las tablas con InnoDB.
- Preflight sin nulos, duplicados ni jerarquías inconsistentes en la instalación limpia.
- `INSERT`, `SELECT` con `JOIN`, `UPDATE`, `DELETE` controlado y `ROLLBACK`.
- Rechazo de correo y compuesto duplicados, FK inválida, cantidad cero y vía nula.
- Múltiples horarios por medicamento.
- Tomas confirmada, omitida y pendiente.
- Rechazo de toma duplicada y confirmación sin hora efectiva.
- Cálculo de cumplimiento con tomadas y omitidas como denominador.
- Totales, frecuencia, porcentaje, promedio emocional y periodo sin datos.
- Rechazo de una combinación emocional jerárquicamente inválida.
- Relación de médicos con especialidades.

Resultado: **PASS**. Evidencia: `evidencias/mariadb-test-2026-11-04.txt`.

## Pruebas pendientes

- Actualización in-place de una base heredada real; no se proporcionó una copia con datos.
- Concurrencia multisesión y pruebas de carga.
- Restauración desde respaldo en infraestructura del equipo.
- SQL Server, Spider/FederatedX y nodos distribuidos; no están disponibles.
- Contratos reales de Backend y Frontend; pertenecen a otros roles.

## Resultado esperado

```text
PASS schema: 23 tables, 42 FKs, 3 migrations, all InnoDB
PASS CRUD/integrity: transaction will be rolled back
PASS reports: totals, frequency, percentage, averages, empty periods and compliance
PASS: migraciones, datos sintéticos y pruebas SQL completados.
```

No ejecute estas pruebas contra una base compartida: crean y eliminan datos de demostración y procedimientos temporales de aserción.
