<?php
declare(strict_types=1);

const MAX_INTENTOS = 5;
const VENTANA_SEGUNDOS = 900;

function ruta_intentos(string $mail): string
{
    $dir = __DIR__ . '/../storage/intentos';
    if (!is_dir($dir)) {
        mkdir($dir, 0700, true);
    }
    $ip = $_SERVER['REMOTE_ADDR'] ?? 'desconocida';
    return $dir . '/' . hash('sha256', $ip . '|' . $mail) . '.json';
}

function leer_intentos(string $mail): array
{
    $ruta = ruta_intentos($mail);
    if (!is_file($ruta)) {
        return [];
    }
    $datos = json_decode((string) file_get_contents($ruta), true);
    if (!is_array($datos)) {
        return [];
    }
    $limite = time() - VENTANA_SEGUNDOS;
    return array_values(array_filter($datos, fn($t) => is_int($t) && $t > $limite));
}

function revisar_bloqueo(string $mail): void
{
    if (count(leer_intentos($mail)) >= MAX_INTENTOS) {
        header('Retry-After: ' . VENTANA_SEGUNDOS);
        responder(429, ['error' => 'Demasiados intentos. Espera unos minutos e intenta de nuevo']);
    }
}

function registrar_fallo(string $mail): void
{
    $intentos = leer_intentos($mail);
    $intentos[] = time();
    file_put_contents(ruta_intentos($mail), json_encode($intentos), LOCK_EX);
}

function limpiar_fallos(string $mail): void
{
    $ruta = ruta_intentos($mail);
    if (is_file($ruta)) {
        unlink($ruta);
    }
}