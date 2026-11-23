<?php
/**
 * Lee la configuración. Las variables de entorno reales tienen prioridad
 * sobre el archivo .env (así en el hosting se puede configurar sin subir el .env).
 */
class Config
{
    private static array $valores = [];

    public static function cargar(string $rutaEnv): void
    {
        self::$valores = [];
        if (!is_readable($rutaEnv)) {
            return;
        }
        foreach (file($rutaEnv, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES) as $linea) {
            $linea = trim($linea);
            if ($linea === '' || $linea[0] === '#' || !str_contains($linea, '=')) {
                continue;
            }
            [$clave, $valor] = explode('=', $linea, 2);
            self::$valores[trim($clave)] = trim(trim($valor), "\"'");
        }
    }

    public static function get(string $clave, ?string $defecto = null): ?string
    {
        $real = getenv($clave);
        if ($real !== false && $real !== '') {
            return $real;
        }
        return self::$valores[$clave] ?? $defecto;
    }

    public static function requerida(string $clave): string
    {
        $valor = self::get($clave);
        if ($valor === null || $valor === '') {
            throw new RuntimeException("Falta la variable de configuración $clave");
        }
        return $valor;
    }

    public static function entero(string $clave, int $defecto): int
    {
        $valor = self::get($clave);
        return ($valor !== null && ctype_digit($valor)) ? (int) $valor : $defecto;
    }
}
