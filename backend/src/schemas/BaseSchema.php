<?php
/**
 * Validación de datos de entrada. Los schemas no tocan la base de datos:
 * reciben un arreglo, lo revisan y devuelven los valores ya limpios
 * o lanzan un error 400 con el motivo.
 */
abstract class BaseSchema
{
    /**
     * @param array $reglas  campo => ['tipo' => ..., 'max' => ..., 'obligatorio' => bool]
     * @param bool  $parcial true en PATCH: los campos que no vienen se ignoran
     */
    protected static function validar(array $reglas, array $datos, bool $parcial = false): array
    {
        $limpio = [];
        foreach ($reglas as $campo => $regla) {
            $obligatorio = $regla['obligatorio'] ?? false;

            if (!array_key_exists($campo, $datos)) {
                if ($obligatorio && !$parcial) {
                    throw self::fallo("El campo '$campo' es obligatorio");
                }
                continue;
            }

            $valor = $datos[$campo];
            if ($valor === null || $valor === '') {
                if ($obligatorio) {
                    throw self::fallo("El campo '$campo' no puede estar vacío");
                }
                $limpio[$campo] = null;
                continue;
            }
            $limpio[$campo] = self::convertir($campo, $valor, $regla);
        }
        return $limpio;
    }

    protected static function fallo(string $mensaje): HttpException
    {
        return new HttpException(400, $mensaje);
    }

    private static function convertir(string $campo, mixed $valor, array $regla): mixed
    {
        $tipo = $regla['tipo'];

        if ($tipo === 'booleano') {
            if (!is_bool($valor)) {
                throw self::fallo("El campo '$campo' debe ser true o false");
            }
            return $valor;
        }

        if ($tipo === 'id') {      // identificador de otra tabla: entero positivo (5, no "5")
            if (!is_int($valor) || $valor < 1) {
                throw self::fallo("El campo '$campo' debe ser un número entero mayor a 0");
            }
            return $valor;
        }

        if (!is_string($valor)) {
            throw self::fallo("El campo '$campo' debe enviarse como texto");
        }
        if (!mb_check_encoding($valor, 'UTF-8')) {
            throw self::fallo("El campo '$campo' tiene caracteres no válidos");
        }

        switch ($tipo) {
            case 'nombre':
            case 'texto':
                $valor = trim($valor);
                $largo = mb_strlen($valor);
                if ($largo < 1) {
                    throw self::fallo("El campo '$campo' no puede estar vacío");
                }
                if ($largo > $regla['max']) {
                    throw self::fallo("El campo '$campo' admite máximo {$regla['max']} caracteres");
                }
                if ($tipo === 'nombre' && !preg_match('/^[\p{L}\p{M}][\p{L}\p{M}\s.\'-]*$/u', $valor)) {
                    throw self::fallo("El campo '$campo' solo admite letras, espacios, punto, apóstrofo y guion");
                }
                return $valor;

            case 'telefono':
                $limpio = preg_replace('/[\s\-().]/', '', $valor);
                if (!preg_match('/^\+?[0-9]{7,14}$/', $limpio)) {
                    throw self::fallo("El campo '$campo' debe tener entre 7 y 14 dígitos (puede iniciar con +)");
                }
                return $limpio;

            case 'correo':
                $valor = strtolower(trim($valor));
                if (strlen($valor) > 254 || !filter_var($valor, FILTER_VALIDATE_EMAIL)) {
                    throw self::fallo("El campo '$campo' no tiene formato de correo válido");
                }
                return $valor;

            case 'clave':
                if (strlen($valor) < 8 || strlen($valor) > 72) {
                    throw self::fallo("El campo '$campo' debe tener entre 8 y 72 caracteres");
                }
                return $valor;

            case 'claveLogin':
                if (strlen($valor) > 72) {
                    throw self::fallo("El campo '$campo' tiene un formato no válido");
                }
                return $valor;

            case 'fecha':      // fecha de nacimiento: no puede ser futura
            case 'dia':        // día cualquiera, para filtros
                $fecha = DateTime::createFromFormat('!Y-m-d', $valor);
                if (!$fecha || $fecha->format('Y-m-d') !== $valor) {
                    throw self::fallo("El campo '$campo' debe tener formato AAAA-MM-DD y ser una fecha real");
                }
                if ((int) $fecha->format('Y') < 1900) {
                    throw self::fallo("El campo '$campo' no puede ser anterior a 1900");
                }
                if ($tipo === 'fecha' && $fecha > new DateTime('today')) {
                    throw self::fallo("El campo '$campo' no puede ser una fecha futura");
                }
                return $valor;

            case 'fechahora':
                foreach (['Y-m-d H:i:s', 'Y-m-d H:i', 'Y-m-d\TH:i:s', 'Y-m-d\TH:i'] as $formato) {
                    $fecha = DateTime::createFromFormat('!' . $formato, $valor);
                    if ($fecha && $fecha->format($formato) === $valor) {
                        return $fecha->format('Y-m-d H:i:s');
                    }
                }
                throw self::fallo("El campo '$campo' debe tener formato AAAA-MM-DD HH:MM");

            case 'enum':
                if (!in_array($valor, $regla['valores'], true)) {
                    throw self::fallo("El campo '$campo' debe ser uno de: " . implode(', ', $regla['valores']));
                }
                return $valor;
        }
        throw new LogicException("Tipo de validación desconocido: $tipo");
    }
}
