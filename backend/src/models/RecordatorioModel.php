<?php
class RecordatorioModel extends BaseModel
{
    private const SELECCION = 'SELECT r.id_recordatorio, r.tipo, r.contenido, r.fecha, r.created_at, e.estado
                                 FROM recordatorios r
                                 JOIN estado e ON e.id_estado = r.id_estado';

    public function crear(int $idUser, string $tipo, string $contenido, string $fecha, int $idEstado): int
    {
        $this->ejecutar(
            'INSERT INTO recordatorios (id_user, tipo, contenido, id_estado, fecha)
             VALUES (:id_user, :tipo, :contenido, :id_estado, :fecha)',
            ['id_user' => $idUser, 'tipo' => $tipo, 'contenido' => $contenido, 'id_estado' => $idEstado, 'fecha' => $fecha]
        );
        return $this->ultimoId();
    }

    /** Siempre filtra por el dueño: un usuario nunca ve registros de otro. */
    public function porId(int $idUser, int $id): ?array
    {
        return $this->uno(
            self::SELECCION . ' WHERE r.id_recordatorio = :id AND r.id_user = :id_user',
            ['id' => $id, 'id_user' => $idUser]
        );
    }

    public function listar(int $idUser, ?string $desde, ?string $hastaExclusivo, int $limite, int $salto): array
    {
        [$filtro, $parametros] = $this->filtro($idUser, $desde, $hastaExclusivo);
        return $this->todos(
            self::SELECCION . " WHERE $filtro ORDER BY r.fecha ASC, r.id_recordatorio ASC LIMIT :limite OFFSET :salto",
            $parametros + ['limite' => $limite, 'salto' => $salto]
        );
    }

    public function contar(int $idUser, ?string $desde, ?string $hastaExclusivo): int
    {
        [$filtro, $parametros] = $this->filtro($idUser, $desde, $hastaExclusivo);
        $fila = $this->uno("SELECT COUNT(*) AS total FROM recordatorios r WHERE $filtro", $parametros);
        return (int) $fila['total'];
    }

    public function actualizar(int $idUser, int $id, array $campos): void
    {
        $permitidos = ['contenido', 'fecha', 'id_estado'];
        $asignaciones = [];
        $parametros = ['id' => $id, 'id_user' => $idUser];
        foreach ($campos as $columna => $valor) {
            if (in_array($columna, $permitidos, true)) {
                $asignaciones[] = "$columna = :$columna";
                $parametros[$columna] = $valor;
            }
        }
        if ($asignaciones === []) {
            return;
        }
        $this->ejecutar(
            'UPDATE recordatorios SET ' . implode(', ', $asignaciones) . ' WHERE id_recordatorio = :id AND id_user = :id_user',
            $parametros
        );
    }

    public function eliminar(int $idUser, int $id): bool
    {
        $consulta = $this->ejecutar(
            'DELETE FROM recordatorios WHERE id_recordatorio = :id AND id_user = :id_user',
            ['id' => $id, 'id_user' => $idUser]
        );
        return $consulta->rowCount() > 0;
    }

    private function filtro(int $idUser, ?string $desde, ?string $hastaExclusivo): array
    {
        $filtro = 'r.id_user = :id_user';
        $parametros = ['id_user' => $idUser];
        if ($desde !== null) {
            $filtro .= ' AND r.fecha >= :desde';
            $parametros['desde'] = $desde . ' 00:00:00';
        }
        if ($hastaExclusivo !== null) {
            $filtro .= ' AND r.fecha < :hasta';
            $parametros['hasta'] = $hastaExclusivo . ' 00:00:00';
        }
        return [$filtro, $parametros];
    }
}
