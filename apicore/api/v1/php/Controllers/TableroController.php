<?php
declare(strict_types=1);

namespace Apicore\Controllers;

use Apicore\Core\UnauthorizedError;
use Apicore\Services\DatosTablero;
use ValueError;

final class TableroController extends BaseController
{
    private function usuario(): int
    {
        // El dueño se obtiene del token que validó APIcore, nunca del formulario.
        $id = filter_var($this->authUser['sub'] ?? null, FILTER_VALIDATE_INT, ['options' => ['min_range' => 1]]);
        if ($id === false) {
            throw new UnauthorizedError();
        }
        return $id;
    }

    private function clave(string $id): string
    {
        // La misma clave permite repetir un envío sin crear otro registro.
        if (!preg_match('/^[a-f0-9]{8}(?:-[a-f0-9]{4}){3}-[a-f0-9]{12}$/D', $id)) {
            throw new ValueError('Identificador de registro inválido');
        }
        return $id;
    }

    public function recordatorios(): array
    {
        return DatosTablero::recordatorios($this->usuario());
    }

    public function guardarRecordatorio(string $id, array $datos): void
    {
        DatosTablero::guardarRecordatorio($this->usuario(), $this->clave($id), $datos);
    }

    public function eliminarRecordatorio(string $id): void
    {
        DatosTablero::eliminarRecordatorio($this->usuario(), $this->clave($id));
    }

    public function emociones(): array
    {
        return DatosTablero::emociones($this->usuario());
    }

    public function catalogoEmociones(): array
    {
        $this->usuario();
        return DatosTablero::catalogoEmociones();
    }

    public function guardarEmocion(string $id, array $datos): void
    {
        DatosTablero::guardarEmocion($this->usuario(), $this->clave($id), $datos);
    }
}
