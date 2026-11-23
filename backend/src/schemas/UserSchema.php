<?php
class UserSchema extends BaseSchema
{
    private const PERFIL = [
        'name'       => ['tipo' => 'nombre',   'max' => 100, 'obligatorio' => true],
        'lastname1'  => ['tipo' => 'nombre',   'max' => 100, 'obligatorio' => true],
        'lastname2'  => ['tipo' => 'nombre',   'max' => 100],
        'date_b'     => ['tipo' => 'fecha',    'obligatorio' => true],
        'phone'      => ['tipo' => 'telefono', 'obligatorio' => true],
        'emer_phone' => ['tipo' => 'telefono'],
    ];

    /** POST /users */
    public static function registro(array $datos): array
    {
        return self::validar(self::PERFIL + [
            'mail'  => ['tipo' => 'correo', 'obligatorio' => true],
            'passw' => ['tipo' => 'clave',  'obligatorio' => true],
        ], $datos);
    }

    /** PUT /users/{id}: reemplaza todo el perfil (los opcionales que no vengan quedan vacíos). */
    public static function perfilCompleto(array $datos): array
    {
        $limpio = self::validar(self::PERFIL, $datos);
        return $limpio + ['lastname2' => null, 'emer_phone' => null];
    }

    /** PATCH /users/{id}: solo los campos que vengan. */
    public static function perfilParcial(array $datos): array
    {
        $limpio = self::validar(self::PERFIL, $datos, true);
        if ($limpio === []) {
            throw self::fallo('No se envió ningún campo para actualizar');
        }
        return $limpio;
    }
}
