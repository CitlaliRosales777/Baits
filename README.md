# Moodsitto DB Manager

Infraestructura híbrida de Moodsitto con MariaDB y MongoDB Community. Parte de la infraestructura está desplegada y comprobada; cada afirmación se limita a las pruebas registradas.

## Estado real al 19 de noviembre de 2026

- **APROBADO:** MariaDB 11.4.3 principal en `desktop-smecf2n`; esquema híbrido de 23 tablas; usuarios mínimos y laboratorio validado.
- **APROBADO:** MariaDB 11.8.6 ligera en HP; respaldo/restauración de 23 tablas y runners protegidos activos.
- **APROBADO:** MariaDB replica por GTID hacia HP; hilos IO/SQL activos, retraso 0 y escritura/eliminación sintética verificadas.
- **APROBADO:** MongoDB 8.0 con VPS PRIMARY prioridad 2, Windows fijo SECONDARY prioridad 1 y laptop SECONDARY prioridad 0; cuatro colecciones, escritura mayoritaria, réplica, respaldo y restauración comprobados.
- **PENDIENTE:** prueba autenticada del asistente backend con credenciales entregadas al equipo y copia cifrada fuera del HP.

Consulte [el inventario real](docs/INVENTARIO_REAL.md), [la arquitectura](docs/arquitectura/ARQUITECTURA.md), [el estado de aceptación](docs/pruebas/ESTADO_ACEPTACION.md) y [la guía de presentación](presentacion/GUIA_DEMO.md).

## Estructura

- `mariadb/`: esquema híbrido, replicación, seguridad, configuración, respaldo y restauración.
- `mongodb/`: colecciones, replica set, seguridad, configuración, respaldo y restauración.
- `despliegue/`: procedimientos por equipo; requieren ejecución administrativa explícita.
- `laboratorio/`: fragmentación separada de los datos operativos.
- `monitoreo/`: diagnóstico ligero desde Windows.
- `presentacion/`: preflight, demostración y contingencia.
- `backend-integracion/`: asistente guiado y verificadores para backend.
- `tests/`: validaciones estáticas y pruebas no destructivas.

## Seguridad

No hay credenciales reales en Git. Copie plantillas `.env.example` a `.env` localmente. Los servicios escuchan en localhost y direcciones Tailscale confirmadas, con reglas por origen. Nunca publique `secrets/`, archivos `.env`, keyfiles o respaldos.

