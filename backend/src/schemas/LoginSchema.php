<?php
class LoginSchema extends BaseSchema
{
    public static function credenciales(array $datos): array
    {
        return self::validar([
            'mail'  => ['tipo' => 'correo',     'obligatorio' => true],
            'passw' => ['tipo' => 'claveLogin', 'obligatorio' => true],
        ], $datos);
    }
}
