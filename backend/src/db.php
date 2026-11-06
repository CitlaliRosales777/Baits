<?php
declare(strict_types=1);

function cargar_env(string $ruta): array
{
    $datos = [];
    if (!is_file($ruta)) {
        return $datos;
    }
    foreach (file($ruta, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES) as $linea) {
        $linea = trim($linea);
        if ($linea === '' || $linea[0] === '#' || strpos($linea, '=') === false) {
            continue;
        }
        [$clave, $valor] = explode('=', $linea, 2);
        $datos[trim($clave)] = trim($valor);
    }
    return $datos;
}

function conectar_bd(): PDO
{
    $env = cargar_env(__DIR__ . '/../.env');
    $dsn = 'mysql:host=' . ($env['DB_HOST'] ?? 'localhost')
        . ';dbname=' . ($env['DB_NAME'] ?? '')
        . ';charset=utf8mb4';
    return new PDO($dsn, $env['DB_USER'] ?? '', $env['DB_PASS'] ?? '', [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        PDO::ATTR_EMULATE_PREPARES => false,
    ]);
}