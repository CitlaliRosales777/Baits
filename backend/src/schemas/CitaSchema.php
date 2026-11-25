<?php
/**
 * Reglas de las citas médicas. El médico, el lugar y el área se mandan por id;
 * los ids válidos salen de GET /doctores, GET /lugares y GET /areas.
 */
class CitaSchema extends BaseSchema
{
    private const CAMPOS = [
        'id_doctor'   => ['tipo' => 'id',        'obligatorio' => true],
        'id_location' => ['tipo' => 'id',        'obligatorio' => true],
        'id_area'     => ['tipo' => 'id',        'obligatorio' => true],
        'fecha'       => ['tipo' => 'fechahora', 'obligatorio' => true],
        'descripcion' => ['tipo' => 'texto',     'max' => 1000],
        'completado'  => ['tipo' => 'booleano'],
    ];

    /** POST /citas. Una cita nueva siempre empieza pendiente. */
    public static function crear(array $datos): array
    {
        $reglas = self::CAMPOS;
        unset($reglas['completado']);
        return self::validar($reglas, $datos);
    }

    /** PUT /citas/{id} */
    public static function reemplazar(array $datos): array
    {
        return self::validar(self::CAMPOS, $datos);
    }

    /** PATCH /citas/{id} */
    public static function parcial(array $datos): array
    {
        $limpio = self::validar(self::CAMPOS, $datos, true);
        if ($limpio === []) {
            throw self::fallo('No se envió ningún campo para actualizar');
        }
        return $limpio;
    }

    /** Parámetros de GET /citas: los mismos que recordatorios (desde, hasta, page, size). */
    public static function consulta(array $q): array
    {
        return RecordatorioSchema::consulta($q);
    }
}
