<?php
declare(strict_types=1);

namespace Apicore\Services;

use Apicore\Core\Database;
use Apicore\Core\ServiceUnavailableError;
use Apicore\Schemas\TableroSchema;
use MongoDB\BSON\UTCDateTime;
use MongoDB\Driver\BulkWrite;
use MongoDB\Driver\Exception\Exception as MongoError;
use MongoDB\Driver\Manager;
use MongoDB\Driver\Query;
use MongoDB\Driver\WriteConcern;
use PDOException;

final class DatosTablero
{
    private const HISTORIAL = 'moodsitto.historial_emociones_apicore';
    private const CATALOGO = 'moodsitto.catalogo_emociones';

    public static function recordatorios(int $usuario): array
    {
        // La cuenta de APIcore solo lee recordatorios del dueño del token.
        $filas = self::sql(
            'SELECT recordatorio_id, detalle FROM tablero_recordatorios WHERE user_id = ? ORDER BY creado_at, recordatorio_id',
            [$usuario]
        )->fetchAll();
        return array_map(static fn (array $fila): array =>
            ['id' => $fila['recordatorio_id']] + json_decode($fila['detalle'], true, 512, JSON_THROW_ON_ERROR),
            $filas
        );
    }

    public static function guardarRecordatorio(int $usuario, string $id, array $dato): void
    {
        $detalle = json_encode(TableroSchema::recordatorio($dato), JSON_THROW_ON_ERROR | JSON_UNESCAPED_UNICODE);
        // Esta clave compuesta permite repetir el envío y evita tocar filas de otras cuentas.
        self::sql(
            'INSERT INTO tablero_recordatorios (user_id, recordatorio_id, detalle) VALUES (?, ?, ?)
             ON DUPLICATE KEY UPDATE detalle = VALUES(detalle)',
            [$usuario, $id, $detalle]
        );
    }

    public static function eliminarRecordatorio(int $usuario, string $id): void
    {
        self::sql('DELETE FROM tablero_recordatorios WHERE user_id = ? AND recordatorio_id = ?', [$usuario, $id]);
    }

    private static function sql(string $consulta, array $valores): \PDOStatement
    {
        try {
            $stmt = Database::connection()->prepare($consulta);
            $stmt->execute($valores);
            return $stmt;
        } catch (PDOException) {
            throw new ServiceUnavailableError('No se pudo consultar la tabla de recordatorios en MariaDB');
        }
    }

    private static function mongo(): Manager
    {
        $uri = getenv('MOODSITTO_MONGO_URI');
        if (!extension_loaded('mongodb') || $uri === false || $uri === '') {
            throw new ServiceUnavailableError('Falta configurar MongoDB en APIcore');
        }
        // La URI privada solo se lee desde el entorno de PHP.
        return new Manager($uri, ['serverSelectionTimeoutMS' => 4000, 'connectTimeoutMS' => 3000]);
    }

    public static function catalogoEmociones(): array
    {
        try {
            $cursor = self::mongo()->executeQuery(self::CATALOGO, new Query(
                ['nivel' => 'central', 'activo' => true],
                [
                    'projection' => ['_id' => 0, 'codigo' => 1, 'nombre' => 1, 'descripcion' => 1,
                        'color' => 1, 'icono' => 1, 'clave_registro' => 1, 'matices' => 1],
                    'sort' => ['orden' => 1, 'nombre' => 1, 'codigo' => 1],
                ]
            ));
            $cursor->setTypeMap(['root' => 'array', 'document' => 'array', 'array' => 'array']);
            return $cursor->toArray();
        } catch (MongoError) {
            throw new ServiceUnavailableError('No se pudo leer el catálogo de emociones de MongoDB');
        }
    }

    public static function emociones(int $usuario): array
    {
        try {
            $cursor = self::mongo()->executeQuery(self::HISTORIAL, new Query(
                ['apicore_user_id' => $usuario],
                ['sort' => ['creado_at' => -1, 'registro_id' => -1], 'limit' => 100]
            ));
            $cursor->setTypeMap(['root' => 'array', 'document' => 'array', 'array' => 'array']);
            $historial = [];
            foreach ($cursor as $fila) {
                $historial[] = [
                    't' => (int) (string) $fila['creado_at'],
                    'group' => $fila['grupo'],
                ];
            }
            return $historial;
        } catch (MongoError) {
            throw new ServiceUnavailableError('No se pudo leer el historial de MongoDB');
        }
    }

    public static function guardarEmocion(int $usuario, string $id, array $dato): void
    {
        $grupo = TableroSchema::emociones($dato);
        try {
            $cambios = new BulkWrite();
            // La clave del registro se combina con la cuenta. Un reintento conserva el primer envío.
            $cambios->update(
                ['apicore_user_id' => $usuario, 'registro_id' => $id],
                ['$setOnInsert' => ['creado_at' => new UTCDateTime(), 'grupo' => $grupo]],
                ['upsert' => true]
            );
            self::mongo()->executeBulkWrite(self::HISTORIAL, $cambios, [
                'writeConcern' => new WriteConcern('majority', 5000),
            ]);
        } catch (MongoError) {
            throw new ServiceUnavailableError('MongoDB no confirmó el guardado con mayoría');
        }
    }
}
