# Auditoría histórica de APIcore

Fuente inspeccionada: [`xtbt/apicore`](https://github.com/xtbt/apicore), `main` en `923fbe5358ec72882af54bef9e567d0dda5b6374` (30 de octubre de 2026).

El repositorio externo contenía demostraciones Python/PHP para un CRUD plano de `apitest.moods`. No incluía las entidades Moodsitto, autenticación, autorización ni contratos para seguimiento emocional, medicamentos, tomas, citas o recordatorios. También se observaron conexiones administrativas incrustadas, CORS amplio y respuestas con detalles internos; estos hallazgos deben corregirse en el repositorio y por el responsable de Backend.

Esta rama **no modifica ni implementa APIcore**. El contrato vigente para desarrollar su persistencia está en `INTEGRACION_BACKEND.md`, las consultas parametrizables en `databases/mariadb/queries/` y los datos requeridos por interfaz en `GUIA_DATOS_FRONTEND.md`.

Pendientes de Backend: acordar OpenAPI/DTO, autenticación, autorización por usuario, zona horaria, errores, documentos, notificaciones y pruebas de contrato. Backend nunca debe conectarse como `root` ni concatenar valores del cliente en SQL.
