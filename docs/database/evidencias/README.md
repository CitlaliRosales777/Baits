# Evidencias reproducibles

- `mariadb-test-2026-11-03.txt`: salida real de una instalación limpia y pruebas en MariaDB 11.4 mediante Docker. No contiene credenciales ni datos reales.
- `apicore-audit-2026-11-03.md`: revisión estática del commit exacto proporcionado; los valores de `.env` no se copiaron ni expusieron.
- `apicore-integration-test-2026-11-04.txt`: construcción y prueba E2E real de APIcore contra MariaDB con secretos efímeros y datos sintéticos.

No se incluyen capturas de ejecución integrada de APIcore, SQL Server ni nodos distribuidos porque esos entornos no estuvieron disponibles. Durus solo se validó en un contenedor efímero, sin evidencia gráfica. Las capturas futuras deben corresponder a ejecuciones reales y omitir secretos/datos personales.

