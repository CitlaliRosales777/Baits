<?php
class RecordatorioSchema extends BaseSchema
{
    private const CAMPOS = [
        'contenido'  => ['tipo' => 'texto',     'max' => 500, 'obligatorio' => true],
        'fecha'      => ['tipo' => 'fechahora', 'obligatorio' => true],
        'completado' => ['tipo' => 'booleano'],
    ];

    /** POST /recordatorios. Por ahora solo existe el tipo 'general'. */
    public static function crear(array $datos): array
    {
        $limpio = self::validar([
            'contenido' => self::CAMPOS['contenido'],
            'fecha'     => self::CAMPOS['fecha'],
            'tipo'      => ['tipo' => 'enum', 'valores' => ['general']],
        ], $datos);
        $limpio['tipo'] = $limpio['tipo'] ?? 'general';
        return $limpio;
    }

    /** PUT /recordatorios/{id} */
    public static function reemplazar(array $datos): array
    {
        return self::validar(self::CAMPOS, $datos);
    }

    /** PATCH /recordatorios/{id} */
    public static function parcial(array $datos): array
    {
        $limpio = self::validar(self::CAMPOS, $datos, true);
        if ($limpio === []) {
            throw self::fallo('No se envió ningún campo para actualizar');
        }
        return $limpio;
    }

    /** Parámetros de GET /recordatorios: desde, hasta, page, size. */
    public static function consulta(array $q): array
    {
        $filtros = self::validar([
            'desde' => ['tipo' => 'dia'],
            'hasta' => ['tipo' => 'dia'],
        ], array_intersect_key($q, ['desde' => 1, 'hasta' => 1]));
        $desde = $filtros['desde'] ?? null;
        $hasta = $filtros['hasta'] ?? null;

        if ($desde !== null && $hasta !== null) {
            $dias = (new DateTime($desde))->diff(new DateTime($hasta));
            if ($dias->invert) {
                throw self::fallo("'hasta' no puede ser anterior a 'desde'");
            }
            if ($dias->days > 62) {
                throw self::fallo("El rango entre 'desde' y 'hasta' no puede pasar de 62 días");
            }
        }

        $pagina = $q['page'] ?? '1';
        if (!is_string($pagina) || !ctype_digit($pagina) || (int) $pagina < 1) {
            throw self::fallo("El parámetro 'page' debe ser un entero mayor o igual a 1");
        }
        $tamano = $q['size'] ?? '50';
        if (!is_string($tamano) || !ctype_digit($tamano) || (int) $tamano < 1 || (int) $tamano > 100) {
            throw self::fallo("El parámetro 'size' debe ser un entero entre 1 y 100");
        }

        return [
            'desde'          => $desde,
            'hastaExclusivo' => $hasta === null ? null : (new DateTime($hasta))->modify('+1 day')->format('Y-m-d'),
            'pagina'         => (int) $pagina,
            'tamano'         => (int) $tamano,
        ];
    }
}
