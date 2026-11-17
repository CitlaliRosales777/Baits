# Backend Moodsitto (API en PHP)

Todas las rutas responden JSON. La sesion va en una cookie (HttpOnly, SameSite=Lax), asi que el frontend y la API deben salir de la misma direccion (con Docker: http://localhost:8080).

## Rutas
| Metodo y ruta | Que hace | Datos que recibe |
|---|---|---|
| GET /api/healthcheck | Revisa que la API este viva | nada |
| POST /api/register | Crea una cuenta | name, lastname1, lastname2 (opcional), date_b (YYYY-MM-DD), phone, emer_phone (opcional), mail, passw (8 a 72 caracteres) |
| POST /api/login | Inicia sesion | mail, passw |
| GET /api/me | Datos del usuario con sesion | nada. Devuelve id_user, name, lastname1, lastname2, mail, phone, date_b |
| POST /api/logout | Cierra la sesion | nada |
| GET /api/recordatorios | Lista los recordatorios del usuario | ?desde=YYYY-MM-DD&hasta=YYYY-MM-DD (maximo 62 dias) |
| POST /api/recordatorios | Crea un recordatorio | contenido (maximo 200 caracteres), fecha (YYYY-MM-DD), hora (HH:MM) |
| PATCH /api/recordatorios/{id} | Marca como completado o pendiente | {"completado": true} o {"completado": false} |
| DELETE /api/recordatorios/{id} | Borra un recordatorio | nada |

## Codigos de respuesta
- 200 o 201: bien.
- 401: falta iniciar sesion, o correo o contrasena incorrectos.
- 404: ruta o recordatorio que no existe (o que es de otra persona).
- 409: el correo ya esta registrado.
- 413: peticion demasiado grande.
- 422: datos no validos.
- 429: demasiados intentos de login (5 fallos bloquean 15 minutos).
- 500: error interno (el detalle solo queda en el log del servidor).

## Ejemplo para conectar el frontend
```js
const r = await fetch("/api/login", {
  method: "POST",
  headers: { "Content-Type": "application/json" },
  body: JSON.stringify({ mail: correo, passw: contrasena })
});
const datos = await r.json();
```

## Decisiones que el equipo debe confirmar
- Los recordatorios se guardan con tipo "general". La base exige que un recordatorio de tipo "cita" o "medicamento" este ligado a una cita (citas_medicas) o a un horario de medicamento (medicamento_horario), y esas pantallas todavia no existen. El selector "Medicamento / Cita medica" del dashboard no se puede guardar por ahora.
- Los estados "pendiente" y "completado" se siembran en docker/db/02-catalogos.sql. El equipo debe acordar los estados definitivos.
- La fecha y la hora se guardan tal como las manda el frontend, sin conversion de zona horaria. Falta acordar la zona horaria.

## Seguridad aplicada
- Contrasenas con password_hash. Nunca en texto plano.
- Consultas parametrizadas con PDO.
- El id del usuario sale de la sesion, no de lo que manda el cliente. Cada persona solo ve y modifica lo suyo.
- Los errores de SQL no se muestran al usuario.
- Mensaje de login igual si falla el correo o la contrasena.
- Limite de intentos de login, sesion que expira a los 30 minutos y cabeceras de seguridad.
- La API se conecta con un usuario de permisos minimos, no con root.

## Pendiente
- Rutas de emociones, medicamentos y citas.
- Conectar los formularios del frontend.