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

Las sesiones usan una cookie segura. En JavaScript, cuando el frontend esté en el mismo dominio, se pueden llamar las rutas relativas:

```javascript
const respuesta = await fetch('/api/login', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ mail: correo, passw: contrasena })
});
const datos = await respuesta.json();
```

Las rutas de emociones, citas y medicamentos todavía no están completas en la rama backend. MongoDB sigue privado y no debe conectarse desde el navegador ni desde las computadoras del equipo.

