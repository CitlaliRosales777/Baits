<?php
declare(strict_types=1);

require __DIR__ . '/../src/helpers.php';
require __DIR__ . '/../src/db.php';
require __DIR__ . '/../src/seguridad.php';
require __DIR__ . '/../src/auth.php';

header('X-Content-Type-Options: nosniff');
header('X-Frame-Options: DENY');
header('Referrer-Policy: no-referrer');
header("Content-Security-Policy: default-src 'none'; frame-ancestors 'none'");
header('Cache-Control: no-store');

$https = !empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off';
ini_set('session.use_strict_mode', '1');
session_set_cookie_params(['httponly' => true, 'samesite' => 'Lax', 'secure' => $https]);
session_start();

$ahora = time();
if (isset($_SESSION['ultima_actividad']) && $ahora - $_SESSION['ultima_actividad'] > 1800) {
    $_SESSION = [];
    session_regenerate_id(true);
}
$_SESSION['ultima_actividad'] = $ahora;

$metodo = $_SERVER['REQUEST_METHOD'];
$ruta = rtrim((string) parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH), '/');
if ($ruta === '') {
    $ruta = '/';
}

try {
    if ($metodo === 'GET' && $ruta === '/api/healthcheck') {
        responder(200, ['status' => 'ok']);
    }
    if ($metodo === 'POST' && $ruta === '/api/register') {
        registrar_usuario(conectar_bd(), leer_entrada());
    }
    if ($metodo === 'POST' && $ruta === '/api/login') {
        iniciar_sesion(conectar_bd(), leer_entrada());
    }
    if ($metodo === 'GET' && $ruta === '/api/me') {
        perfil_actual(conectar_bd());
    }
    if ($metodo === 'POST' && $ruta === '/api/logout') {
        cerrar_sesion();
    }
    responder(404, ['error' => 'Ruta no encontrada']);
} catch (Throwable $e) {
    error_log($e->getMessage());
    responder(500, ['error' => 'Error interno del servidor']);
}