<?php
/**
 * SQL de la tabla citas_medicas. Cada consulta filtra por id_user:
 * un usuario nunca ve ni toca las citas de otro.
 */
class CitaModel extends BaseModel
{
    /** Trae la cita con los nombres del médico, área, lugar y estado ya resueltos. */
    private const SELECCION = "SELECT c.id_cita, c.fecha, c.descripcion,
                                      c.id_doctor, CONCAT_WS(' ', d.nombre, d.apellido_p, d.apellido_m) AS doctor,
                                      c.id_area, a.nombre_area AS area,
                                      c.id_location, CONCAT_WS(', ', CONCAT_WS(' ', l.calle, l.num_ext), l.colonia) AS lugar,
                                      e.estado
                                 FROM citas_medicas c
                                 JOIN doctors  d ON d.id_doctor   = c.id_doctor
                                 JOIN area     a ON a.id_area     = c.id_area
                                 JOIN location l ON l.id_location = c.id_location
                                 JOIN estado   e ON e.id_estado   = c.id_estado";

    private const COLUMNAS = ['id_doctor', 'id_location', 'id_area', 'fecha', 'descripcion', 'id_estado'];

    public function crear(int $idUser, array $campos): int
    {
        $campos = array_intersect_key($campos, array_flip(self::COLUMNAS));
        $columnas = array_keys($campos);
        $this->ejecutar(
            'INSERT INTO citas_medicas (id_user, ' . implode(', ', $columnas) . ')
             VALUES (:id_user, :' . implode(', :', $columnas) . ')',
            ['id_user' => $idUser] + $campos
        );
        return $this->ultimoId();
    }

    public function porId(int $idUser, int $id): ?array
    {
        return $this->uno(
            self::SELECCION . ' WHERE c.id_cita = :id AND c.id_user = :id_user',
            ['id' => $id, 'id_user' => $idUser]
        );
    }

    public function listar(int $idUser, ?string $desde, ?string $hastaExclusivo, int $limite, int $salto): array
    {
        [$filtro, $parametros] = $this->filtro($idUser, $desde, $hastaExclusivo);
        return $this->todos(
            self::SELECCION . " WHERE $filtro ORDER BY c.fecha ASC, c.id_cita ASC LIMIT :limite OFFSET :salto",
            $parametros + ['limite' => $limite, 'salto' => $salto]
        );
    }

    public function contar(int $idUser, ?string $desde, ?string $hastaExclusivo): int
    {
        [$filtro, $parametros] = $this->filtro($idUser, $desde, $hastaExclusivo);
        $fila = $this->uno("SELECT COUNT(*) AS total FROM citas_medicas c WHERE $filtro", $parametros);
        return (int) $fila['total'];
    }

    public function actualizar(int $idUser, int $id, array $campos): void
    {
        $campos = array_intersect_key($campos, array_flip(self::COLUMNAS));
        if ($campos === []) {
            return;
        }
        $asignaciones = array_map(fn ($columna) => "$columna = :$columna", array_keys($campos));
        $this->ejecutar(
            'UPDATE citas_medicas SET ' . implode(', ', $asignaciones) . ' WHERE id_cita = :id AND id_user = :id_user',
            $campos + ['id' => $id, 'id_user' => $idUser]
        );
    }

    /** Devuelve false si la cita no existe o es de otro usuario. */
    public function eliminar(int $idUser, int $id): bool
    {
        $consulta = $this->ejecutar(
            'DELETE FROM citas_medicas WHERE id_cita = :id AND id_user = :id_user',
            ['id' => $id, 'id_user' => $idUser]
        );
        return $consulta->rowCount() > 0;
    }

    /**
     * Revisa que el médico, el lugar y el área existan antes de guardar.
     * Devuelve el nombre del primer campo que no existe, o null si todos existen.
     */
    public function referenciaFaltante(array $campos): ?string
    {
        $tablas = [
            'id_doctor'   => 'SELECT 1 FROM doctors  WHERE id_doctor   = :id',
            'id_location' => 'SELECT 1 FROM location WHERE id_location = :id',
            'id_area'     => 'SELECT 1 FROM area     WHERE id_area     = :id',
        ];
        foreach ($tablas as $campo => $sql) {
            if (isset($campos[$campo]) && $this->uno($sql, ['id' => $campos[$campo]]) === null) {
                return $campo;
            }
        }
        return null;
    }

    private function filtro(int $idUser, ?string $desde, ?string $hastaExclusivo): array
    {
        $filtro = 'c.id_user = :id_user';
        $parametros = ['id_user' => $idUser];
        if ($desde !== null) {
            $filtro .= ' AND c.fecha >= :desde';
            $parametros['desde'] = $desde . ' 00:00:00';
        }
        if ($hastaExclusivo !== null) {
            $filtro .= ' AND c.fecha < :hasta';
            $parametros['hasta'] = $hastaExclusivo . ' 00:00:00';
        }
        return [$filtro, $parametros];
    }
}
