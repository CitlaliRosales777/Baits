<?php
/**
 * Arranque de la aplicación: autocarga de clases, configuración y zona horaria.
 * No tiene lógica de negocio.
 */

const CARPETAS_CLASES = ['core', 'middlewares', 'controllers', 'models', 'schemas', 'services'];

spl_autoload_register(function (string $clase): void {
    foreach (CARPETAS_CLASES as $carpeta) {
        $archivo = __DIR__ . '/' . $carpeta . '/' . $clase . '.php';
        if (is_file($archivo)) {
            require $archivo;
            return;
        }
    }
});

Config::cargar(dirname(__DIR__) . '/.env');
date_default_timezone_set(Config::get('APP_TIMEZONE', 'America/Tijuana'));

// Los errores de PHP no se muestran al cliente; van al registro del servidor.
ini_set('display_errors', '0');
error_reporting(E_ALL);
