<?php
/**
 * Todas las rutas de la API en un solo lugar.
 * agregar(método, ruta, controlador, acción, protegida)
 * protegida = true exige un token Bearer válido (es el valor por defecto).
 */
return function (Router $r): void {
    // Estado del servicio
    $r->agregar('GET', '/health', HealthController::class, 'ver', false);

    // Sesión
    $r->agregar('POST', '/auth/login',  AuthController::class, 'login', false);
    $r->agregar('POST', '/auth/logout', AuthController::class, 'logout');

    // Usuarios (el registro es público)
    $r->agregar('POST',   '/users',      UserController::class, 'registrar', false);
    $r->agregar('GET',    '/users/{id}', UserController::class, 'ver');
    $r->agregar('PUT',    '/users/{id}', UserController::class, 'reemplazar');
    $r->agregar('PATCH',  '/users/{id}', UserController::class, 'actualizar');
    $r->agregar('DELETE', '/users/{id}', UserController::class, 'eliminar');

    // Recordatorios
    $r->agregar('GET',    '/recordatorios',      RecordatorioController::class, 'listar');
    $r->agregar('POST',   '/recordatorios',      RecordatorioController::class, 'crear');
    $r->agregar('GET',    '/recordatorios/{id}', RecordatorioController::class, 'ver');
    $r->agregar('PUT',    '/recordatorios/{id}', RecordatorioController::class, 'reemplazar');
    $r->agregar('PATCH',  '/recordatorios/{id}', RecordatorioController::class, 'actualizar');
    $r->agregar('DELETE', '/recordatorios/{id}', RecordatorioController::class, 'eliminar');
};
