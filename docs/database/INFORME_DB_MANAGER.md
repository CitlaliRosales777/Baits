# Informe final del DB Manager — Moodsitto

Fecha: 4 de noviembre de 2026
Rama: `feature/db-manager`
Fuente original: `bd-moodsitto.sql`, conservada intacta

## Resumen

Se auditó el esquema original de 20 tablas y se creó una entrega MariaDB reproducible, compatible y exclusiva del rol DB Manager. El resultado agrega horarios múltiples, checklist de tomas, especialidades múltiples, intensidad por seguimiento, integridad jerárquica, consultas de reportes, datos sintéticos, pruebas aisladas y documentación para cada rol. No se modificaron Frontend ni Backend/APIcore.

## Estado inicial

El repositorio contenía un frontend estático y `bd-moodsitto.sql`. No había migraciones, semillas completas, pruebas automatizadas, consultas de reportes, roles mínimos, respaldo documentado ni guías de integración por rol. El script original define 20 tablas y 33 FK, con relaciones de dominio opcionales, un solo horario por medicamento, ausencia de tomas y redundancia emocional no validada.

## Implementado

- V001: base `moodsitto`, `utf8mb4` y ledger.
- V002: las 20 tablas originales con InnoDB, obligatoriedad, unicidad, `CHECK`, políticas de borrado e índices.
- V003: `medicamento_horario`, `toma_medicamento`, `doctor_especialidad`, vigencia de tratamientos, recordatorios vinculados, intensidad del evento y FK compuestas emocionales.
- 23 tablas de dominio y 42 claves foráneas.
- Semillas sintéticas de catálogos y flujos completos.
- Consultas para seguimiento, reportes, medicamentos, tomas, citas, médicos y recordatorios.
- Roles de referencia, preflight heredado, respaldo/restauración y runner Docker aislado.
- Auditoría, ER, diccionario, decisiones, guías Backend/Frontend/QA/DevOps y entrega general.

## Verificado

MariaDB 11.4 ejecutó satisfactoriamente V001–V003, S001–S002, preflight, 22 comprobaciones CRUD/integridad y aserciones de reportes. Se verificaron InnoDB, conteos de tablas/FK/migraciones, transacciones, horarios múltiples, estados de toma, prevención de duplicados, cumplimiento, totales, frecuencias, porcentajes, promedios, periodos vacíos, especialidades y rechazo de jerarquía emocional inválida. El entorno eliminó contenedor, red y volumen al finalizar.

Evidencia: `evidencias/mariadb-test-2026-11-04.txt`.

## Consultas disponibles

- `emotional_tracking.sql`: alta, historial, periodo, emoción, intensidad y recientes.
- `emotional_reports.sql`: totales, frecuencia absoluta/relativa, porcentajes, promedio, categoría, evolución y comparación.
- `medications.sql`: activos, finalizados, horarios, checklist, historial, cumplimiento y transiciones.
- `appointments_doctors.sql`: próximas, historial, filtros, alta, edición, cancelación y especialidades.
- `reminders.sql`: pendientes, vencidos, medicamentos y citas.

## Reglas relevantes

- Una toma se identifica por horario + instante programado.
- Llegar al horario nunca confirma una toma.
- `tomada` exige hora efectiva; omitida/pendiente/cancelada no la admiten.
- Cumplimiento = tomadas / (tomadas + omitidas); pendientes y canceladas se muestran aparte.
- Las FK compuestas impiden mezclar niveles emocionales.
- Los promedios usan `intensidad.valor` registrado en el evento, no IDs ni categorías.
- Las consultas se restringen al usuario autorizado y se parametrizan desde Backend.

## Pendiente

- Backend: contratos REST/OpenAPI, autenticación/autorización, transacciones de servicio, documentos, notificaciones y zona horaria.
- Frontend/UX: interfaces, validaciones visuales y clasificación emocional definitiva.
- Product Manager: estados por entidad, retención, borrado lógico y reglas de historial.
- QA: contratos integrados, concurrencia y carga.
- DevOps: revisión humana, gestión de secretos, TLS, despliegue, respaldo/restauración periódica y automatización autorizada.
- Base heredada: diseñar upgrade específico después de auditar una copia real.

## Bloqueado/no comprobado

- Migración in-place: no se proporcionó base heredada con datos.
- SQL Server, Spider/FederatedX, nodos distribuidos y fallos de red: no existe infraestructura disponible dentro del alcance.
- Durus y APIcore multibase: no autorizados para implementación por este rol.
- Integración Frontend/Backend: depende de otros integrantes.

## Seguridad

No se incorporaron credenciales reales ni información médica real. La aplicación normal no debe usar `root`. Los datos personales, emocionales y clínicos requieren TLS, mínimos privilegios, respaldo cifrado, control de acceso, auditoría y política de retención. `passw` almacena exclusivamente hash; `documento` es una referencia opaca a almacenamiento privado.

## Reproducción

```powershell
git switch feature/db-manager
& .\databases\mariadb\tests\run-tests.ps1
```

Resultado esperado:

```text
PASS schema: 23 tables, 42 FKs, 3 migrations, all InnoDB
PASS CRUD/integrity: transaction will be rolled back
PASS reports: totals, frequency, percentage, averages, empty periods and compliance
PASS: migraciones, datos sintéticos y pruebas SQL completados.
```

## Entrega a DevOps

La rama se publica mediante el PR #1 hacia `main`. No se encontró `.github/CODEOWNERS` ni una persona identificada explícitamente como responsable DevOps; no se solicitó revisión al azar. El PR debe permanecer abierto, sin aprobación propia ni fusión, hasta revisión humana.
