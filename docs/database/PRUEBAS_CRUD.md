# Pruebas CRUD e integridad

La guía vigente y los comandos completos están en `PRUEBAS_BD.md`.

El runner aislado aplica V001–V003 y S001–S002, ejecuta preflight y pruebas, y elimina sus recursos. La ejecución del 4 de noviembre de 2026 aprobó:

- 23 tablas, 42 claves foráneas, 3 migraciones e InnoDB;
- altas de usuario, cita, diagnóstico, médico/especialidad, seguimiento, medicamento, horarios múltiples, tomas y recordatorio;
- lectura relacional, cumplimiento, actualización, borrado controlado y `ROLLBACK`;
- rechazo de duplicados, FK y `CHECK` inválidos, confirmación incoherente y jerarquía emocional inválida.

Resultado: PASS. Evidencia: `evidencias/mariadb-test-2026-11-04.txt`.

No se probó concurrencia multisesión. Backend deberá definir control optimista o bloqueo explícito para operaciones críticas y convertir cero filas afectadas en “no encontrado” o conflicto según el contrato.
