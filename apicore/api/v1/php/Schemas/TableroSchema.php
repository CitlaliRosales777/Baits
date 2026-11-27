<?php
declare(strict_types=1);

namespace Apicore\Schemas;

use DateTimeImmutable;
use ValueError;

final class TableroSchema
{
    private static function texto(mixed $valor, int $maximo, bool $vacio = false): string
    {
        if (!is_string($valor) || mb_strlen($valor) > $maximo || (!$vacio && trim($valor) === '')) {
            throw new ValueError('Un campo de texto está vacío o es demasiado largo');
        }
        return trim($valor);
    }

    private static function fecha(mixed $valor): string
    {
        if (!is_string($valor) || !preg_match('/^\d{4}-\d{2}-\d{2}$/D', $valor)) {
            throw new ValueError('La fecha debe tener el formato año-mes-día');
        }
        $fecha = DateTimeImmutable::createFromFormat('!Y-m-d', $valor);
        if (!$fecha || $fecha->format('Y-m-d') !== $valor) {
            throw new ValueError('La fecha no es válida');
        }
        return $valor;
    }

    private static function lista(mixed $valor, int $maximo): array
    {
        if (!is_array($valor) || count($valor) > $maximo) {
            throw new ValueError('La lista incluye demasiados elementos o tiene un formato inválido');
        }
        return array_values($valor);
    }

    public static function recordatorio(array $dato): array
    {
        // Conserva las reglas de repetición y el avance por día del calendario.
        $inicio = self::fecha($dato['inicio'] ?? null);
        $fin = self::fecha($dato['fin'] ?? null);
        $hora = $dato['hora'] ?? null;
        $tipo = $dato['tipo'] ?? null;
        $repeticion = $dato['repeticion'] ?? null;
        if ($fin < $inicio || !is_string($hora) || !preg_match('/^(?:[01]\d|2[0-3]):[0-5]\d$/D', $hora)
            || !in_array($tipo, ['medicamento', 'cita', 'actividad', 'otro'], true)
            || !in_array($repeticion, ['una', 'diaria', 'semanal'], true)
            || ($repeticion === 'una' && $fin !== $inicio)) {
            throw new ValueError('Horario, tipo o repetición inválidos');
        }
        $dias = self::lista($dato['diasSemana'] ?? [], 7);
        foreach ($dias as $dia) {
            if (!is_int($dia) || $dia < 1 || $dia > 7) {
                throw new ValueError('Día de la semana inválido');
            }
        }
        if ($repeticion === 'semanal' && $dias === []) {
            throw new ValueError('Selecciona al menos un día de la semana');
        }
        $completados = array_map(static fn (mixed $fecha): string => self::fecha($fecha),
            self::lista($dato['completados'] ?? [], 3660));
        foreach ($completados as $fecha) {
            if ($fecha < $inicio || $fecha > $fin) {
                throw new ValueError('Un día marcado está fuera del periodo del recordatorio');
            }
        }
        return [
            'nombre' => self::texto($dato['nombre'] ?? null, 100),
            'dosis' => self::texto($dato['dosis'] ?? '', 50, true),
            'hora' => $hora, 'tipo' => $tipo, 'repeticion' => $repeticion,
            'inicio' => $inicio, 'fin' => $fin, 'diasSemana' => array_values(array_unique($dias)),
            'completados' => array_values(array_unique($completados)),
        ];
    }

    public static function emociones(array $dato): array
    {
        // Valida el grupo que se muestra junto en el historial de emociones.
        $grupo = self::lista($dato['group'] ?? null, 20);
        if ($grupo === []) {
            throw new ValueError('Selecciona al menos una emoción');
        }
        return array_map(static function (mixed $entrada): array {
            if (!is_array($entrada) || !is_int($entrada['intensity'] ?? null)
                || $entrada['intensity'] < 1 || $entrada['intensity'] > 10) {
                throw new ValueError('La intensidad debe ser un número entre 1 y 10');
            }
            $etiquetas = static fn (mixed $lista): array => array_map(
                static fn (mixed $texto): string => self::texto($texto, 80), self::lista($lista, 20)
            );
            return [
                'core' => self::texto($entrada['core'] ?? null, 80),
                'subs' => $etiquetas($entrada['subs'] ?? []),
                'fine' => $etiquetas($entrada['fine'] ?? []),
                'note' => self::texto($entrada['note'] ?? '', 4000, true),
                'intensity' => $entrada['intensity'],
            ];
        }, $grupo);
    }
}
