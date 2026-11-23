<?php
/** Conexión única a MySQL con PDO. Solo se conecta cuando alguien la pide. */
class Database
{
    private static ?PDO $pdo = null;

    public static function conexion(): PDO
    {
        if (self::$pdo !== null) {
            return self::$pdo;
        }

        $opciones = [
            PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES   => false,
        ];

        $dsn = Config::get('DB_DSN'); // solo para pruebas automáticas
        if ($dsn !== null) {
            self::$pdo = new PDO($dsn, null, null, $opciones);
            return self::$pdo;
        }

        $host   = Config::get('DB_HOST', '127.0.0.1');
        $puerto = Config::entero('DB_PORT', 3306);
        $nombre = Config::requerida('DB_NAME');
        $dsn    = "mysql:host=$host;port=$puerto;dbname=$nombre;charset=utf8mb4";

        self::$pdo = new PDO($dsn, Config::requerida('DB_USER'), Config::requerida('DB_PASS'), $opciones);
        // Que MySQL use la misma zona horaria que PHP para los campos con fecha por defecto.
        self::$pdo->exec("SET time_zone = '" . (new DateTime('now'))->format('P') . "'");
        return self::$pdo;
    }

    public static function responde(): bool
    {
        try {
            self::conexion()->query('SELECT 1');
            return true;
        } catch (Throwable $e) {
            error_log('Base de datos no disponible: ' . $e->getMessage());
            return false;
        }
    }

    /** Detecta el error de "valor repetido" en una columna UNIQUE. */
    public static function esDuplicado(PDOException $e): bool
    {
        $codigoDriver = (int) ($e->errorInfo[1] ?? 0);
        return $codigoDriver === 1062 || $codigoDriver === 19; // 19: SQLite (pruebas)
    }
}
