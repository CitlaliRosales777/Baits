# Cómo probar el frontend con el backend de Moodsitto

Esta rama usa directamente el backend PHP de Moodsitto para sus pruebas de desarrollo. Arráncalo desde su repositorio con `php -S localhost:8001 -t backend/public` y configura el acceso a `moodsitto` y sus tablas de login.

La presentación con APIcore usa el frontend de `Fronted` y APIcore de `api-citas` en el puerto 8000. Las cuentas y los tokens pertenecen a su propio servicio.
