# Entrega general del DB Manager

Punto de entrada para el equipo Baits. Rama: `feature/db-manager`. El archivo original `bd-moodsitto.sql`, Frontend y Backend permanecen sin modificaciones.

## Estado inicial y final

| Aspecto | Inicial | Entregado |
|---|---|---|
| Esquema | Script monolítico con 20 tablas. | 3 migraciones reproducibles y 23 tablas de dominio. |
| Integridad | 33 FK, nulos amplios y pocas restricciones. | 42 FK, `NOT NULL`, `UNIQUE`, `CHECK`, políticas de borrado e índices. |
| Medicamentos | Un horario por medicamento, sin tomas. | Múltiples horarios, fechas, unidad y checklist histórico. |
| Emociones | Terna redundante sin coherencia garantizada; intensidad ligada a catálogos. | FK compuestas para jerarquía e intensidad registrada por evento. |
| Médicos | Una especialidad. | Relación de varias especialidades conservando compatibilidad. |
| Reportes | Sin consultas preparadas. | Consultas de frecuencia, porcentajes, promedios y tendencias. |
| Pruebas | No existían. | Runner aislado, semillas y 22 comprobaciones CRUD/integridad. |

## Tablas agregadas

- `medicamento_horario`: programaciones múltiples y vigencia.
- `toma_medicamento`: dosis programadas, confirmadas, omitidas o canceladas.
- `doctor_especialidad`: relación muchos-a-muchos.

Las 20 tablas originales se conservan. `medicamento`, `recordatorios`, `trackeo_emo` y las tablas emocionales reciben extensiones compatibles mediante `V003`.

## Migraciones

1. `V001__create_database.sql`: base, codificación y ledger.
2. `V002__create_relational_model.sql`: 20 tablas originales endurecidas.
3. `V003__complete_db_manager_model.sql`: horarios, tomas, especialidades, recordatorios e integridad emocional.

Una instalación heredada requiere respaldo, restauración aislada y `preflight/P001__legacy_read_only_audit.sql`; no se debe aplicar `V002` sobre tablas existentes.

## Consultas disponibles

- `emotional_tracking.sql`: registro, historial, filtros y últimos eventos.
- `emotional_reports.sql`: 12 resultados estadísticos/descriptivos.
- `medications.sql`: tratamientos, horarios, checklist y cumplimiento.
- `appointments_doctors.sql`: citas, cancelación y directorio profesional.
- `reminders.sql`: pendientes, vencidos, medicamentos y citas.
- `dashboard_history.sql`: consultas resumidas históricas.

## Pruebas

Ejecutadas en MariaDB 11.4 el 4 de noviembre de 2026. Resultado: PASS para 23 tablas, 42 FK, 3 migraciones, CRUD, transacciones, jerarquía emocional, horarios múltiples, tomas y cumplimiento. Consulte `PRUEBAS_BD.md` y `evidencias/mariadb-test-2026-11-04.txt`.

## Funcionalidades soportadas

Seguimiento e historial emocional; datos para reportes; tratamientos y múltiples horarios; checklist de tomas; citas; médicos y especialidades; recordatorios persistidos; diagnósticos y perfil. No se implementan interfaces, endpoints, PDF ni entrega de notificaciones.

## Instrucciones por rol

- Backend/APIcore: `INTEGRACION_BACKEND.md`; parametrizar SQL, aplicar autorización y transacciones.
- Frontend/UX/UI: `GUIA_DATOS_FRONTEND.md`; consumir Backend, no MariaDB.
- QA: `PRUEBAS_BD.md`; reproducir en Docker aislado y verificar errores esperados.
- DevOps: `SEGURIDAD_RESPALDOS.md`, `databases/mariadb/README.md`; revisar secretos, permisos, respaldo y restauración.
- Product Manager: aprobar clasificación emocional, catálogos de estado y políticas de historial.

## Matriz de responsabilidades

| Entregable | DB Manager | Backend | Frontend/UX | QA | DevOps |
|---|---:|---:|---:|---:|---:|
| Modelo, migraciones, restricciones | Responsable | Consulta | Informado | Verifica | Ejecuta/revisa |
| Consultas y datos para reportes | Responsable | Integra | Presenta | Verifica | — |
| Autenticación, endpoints y PDF | Documenta datos | Responsable | Consume | Prueba | Despliega |
| Interfaces y flujos | Informa campos | Provee contrato | Responsable | Prueba | — |
| Pruebas SQL | Implementa | Apoya contrato | — | Reproduce | Automatiza cuando se autorice |
| Notificaciones | Persiste programación | Responsable | Presenta | Prueba | Opera |
| Respaldos, restauración y secretos | Documenta | Usa configuración | — | Verifica | Responsable |

## Limitaciones y riesgos

- No se probó una actualización heredada con datos reales.
- Catálogos compartidos de estado requieren definición por módulo.
- No hay contrato REST/OpenAPI acordado.
- Faltan concurrencia, carga, retención y borrado lógico.
- SQL Server, Spider/FederatedX y distribución son diseños pendientes, no resultados verificados.
- Los datos personales y emocionales requieren TLS, mínimo privilegio, respaldo cifrado y control de acceso.

## Enlaces

- Auditoría: `AUDITORIA_BD.md`
- Modelo: `DIAGRAMA_ER.md`, `DICCIONARIO_DATOS.md`, `DECISIONES_DISENO.md`
- Reportes: `CONSULTAS_REPORTES.md`
- Integración: `INTEGRACION_BACKEND.md`, `GUIA_DATOS_FRONTEND.md`
- Operación: `PRUEBAS_BD.md`, `SEGURIDAD_RESPALDOS.md`
- Estado final: `INFORME_DB_MANAGER.md`
