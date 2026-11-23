<?php
/** Intentos fallidos de login (tabla login_intentos, ver sql/extras.sql). */
class IntentoModel extends BaseModel
{
    /** @return array{total:int, primero:?string} */
    public function resumen(string $clave, string $desde): array
    {
        $fila = $this->uno(
            'SELECT COUNT(*) AS total, MIN(creado_at) AS primero
               FROM login_intentos WHERE clave = :clave AND creado_at >= :desde',
            ['clave' => $clave, 'desde' => $desde]
        );
        return ['total' => (int) $fila['total'], 'primero' => $fila['primero']];
    }

    public function registrar(string $clave, string $ahora): void
    {
        $this->ejecutar(
            'INSERT INTO login_intentos (clave, creado_at) VALUES (:clave, :ahora)',
            ['clave' => $clave, 'ahora' => $ahora]
        );
    }

    public function limpiar(string $clave): void
    {
        $this->ejecutar('DELETE FROM login_intentos WHERE clave = :clave', ['clave' => $clave]);
    }

    public function borrarAntiguos(string $antesDe): void
    {
        $this->ejecutar('DELETE FROM login_intentos WHERE creado_at < :antes', ['antes' => $antesDe]);
    }
}
