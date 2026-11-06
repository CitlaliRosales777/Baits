# Backend Moodsitto (API en PHP)

## Rutas
- GET  /api/healthcheck : comprueba que la API esta viva
- POST /api/register    : crea una cuenta (name, lastname1, lastname2, date_b, phone, emer_phone, mail, passw)
- POST /api/login       : inicia sesion (mail, passw)
- GET  /api/me          : datos del usuario con sesion iniciada
- POST /api/logout      : cierra la sesion

## Como correrla
1. Crear una base de datos con las tablas location y users (migracion V002 de databases/mariadb en la rama feature/db-manager).
2. Crear un usuario de base de datos con SELECT, INSERT, UPDATE y DELETE solo sobre esa base. No usar root.
3. Copiar backend/.env.example a backend/.env y poner los datos reales. El archivo .env nunca se sube a Git.
4. Desde la raiz del repositorio: php -S localhost:8000 -t backend/public backend/public/index.php

## Seguridad aplicada
- Contrasenas con password_hash (nunca en texto plano).
- Consultas parametrizadas con PDO.
- El id_user sale de la sesion, no de lo que manda el cliente.
- Los errores de SQL no se muestran al usuario.
- Mensaje de login igual si falla el correo o la contrasena.

## Pendiente
- CORS y limite de intentos de login.
- Rutas de emociones, medicamentos y citas.
- Docker.