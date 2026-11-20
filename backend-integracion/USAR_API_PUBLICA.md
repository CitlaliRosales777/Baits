# Usar Moodsitto sin Tailscale

El backend está disponible en:

`https://api.lvltechmx.com`

Para comprobarlo en Windows, ejecuta:

```powershell
.\probar-api-publica.ps1
```

No necesitas instalar MariaDB, MongoDB, Tailscale ni clientes de base de datos. Tampoco necesitas las contraseñas de los motores. La API se conecta internamente con una cuenta propia de permisos mínimos.

Rutas disponibles actualmente:

- `GET /api/healthcheck`
- `POST /api/register`
- `POST /api/login`
- `GET /api/me`
- `POST /api/logout`
- `GET /api/recordatorios`
- `POST /api/recordatorios`
- `PATCH /api/recordatorios/{id}`
- `DELETE /api/recordatorios/{id}`

La web no se despliega en el VPS. Durante el desarrollo, levántala con un servidor local en `http://localhost` o `http://127.0.0.1`; no abras el HTML directamente con `file://`.

Las sesiones usan una cookie segura. Para llamar la API desde el frontend local se debe usar la URL completa y `credentials: 'include'`:

```javascript
const respuesta = await fetch('https://api.lvltechmx.com/api/login', {
  method: 'POST',
  credentials: 'include',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ mail: correo, passw: contrasena })
});
const datos = await respuesta.json();
```

La API autoriza orígenes locales `localhost` y `127.0.0.1` para desarrollo. Las rutas de emociones, citas y medicamentos todavía no están completas en la rama backend. MongoDB sigue privado y no debe conectarse desde el navegador ni desde las computadoras del equipo.

