# Conexión correcta detrás de APIcore

El flujo obligatorio del proyecto es:

```text
Cliente o frontend
       |
       v
    APIcore
       |
       v
Backend Moodsitto
       |
       +-- MariaDB
       +-- MongoDB
```

DB Manager no implementa rutas, autenticación de APIcore ni lógica del backend. Su entrega termina en dejar los motores disponibles, crear usuarios de aplicación con permisos mínimos y proporcionar las variables de conexión.

## Quién necesita Tailscale

Solo el equipo donde se ejecute el proceso que realmente abre la conexión a MariaDB y MongoDB. Si el backend se despliega en un servidor conectado a Tailscale, los desarrolladores, APIcore, frontend y usuarios finales no necesitan conectarse a la red privada.

Si un compañero ejecuta el backend directamente en su computadora, esa computadora sí necesita Tailscale. Publicar los puertos 3306 o 27017 para evitarlo no es una opción segura y contradice la infraestructura solicitada.

## Entrega de DB Manager

- Direcciones privadas y nombres de las bases.
- Usuario MariaDB `moodsitto_app` con permisos de aplicación.
- Usuario MongoDB `moodsitto_app` con rol limitado a `moodsitto`.
- Plantilla `.env.example` sin secretos.
- Asistente para crear un `.env` local protegido.
- Prueba automática de autenticación, lectura y escritura sintética.
- Contrato de tablas, colecciones y relación por `id_user`.

Las credenciales se entregan por un canal privado únicamente a la persona responsable de configurar el entorno donde corre el backend. No se colocan en APIcore, frontend, GitHub ni archivos compartidos.

## Responsabilidad del equipo backend/APIcore

El equipo debe conectar APIcore con sus rutas backend y decidir dónde desplegar ambos servicios. El backend debe leer las variables entregadas por DB Manager, validar el usuario autenticado por APIcore y aplicar autorización por `id_user` antes de consultar o modificar datos.

El repositorio observado no contiene la implementación de APIcore, por lo que su contrato de cabeceras, tokens y rutas debe ser confirmado por el equipo responsable. DB Manager no lo inventa ni lo modifica.

