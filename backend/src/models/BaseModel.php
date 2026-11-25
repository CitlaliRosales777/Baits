<?php
/** Utilidades comunes de los modelos. Los modelos son los únicos que escriben SQL. */
abstract class BaseModel
{
    protected PDO $db;
    private array $estados = [];

    public function __construct()
    {
        $this->db = Database::conexion();
    }

    /** Busca el id de un estado ('pendiente', 'completado') en el catálogo. */
    public function idEstado(string $nombre): int
    {
        if (!isset($this->estados[$nombre])) {
            $fila = $this->uno('SELECT id_estado FROM estado WHERE estado = :nombre', ['nombre' => $nombre]);
            if ($fila === null) {
                throw new RuntimeException("Falta el estado '$nombre' en la tabla estado");
            }
            $this->estados[$nombre] = (int) $fila['id_estado'];
        }
        return $this->estados[$nombre];
    }

    protected function ejecutar(string $sql, array $parametros = []): PDOStatement
    {
        $consulta = $this->db->prepare($sql);
        foreach ($parametros as $nombre => $valor) {
            $tipo = is_int($valor) ? PDO::PARAM_INT : (is_null($valor) ? PDO::PARAM_NULL : PDO::PARAM_STR);
            $consulta->bindValue(':' . $nombre, $valor, $tipo);
        }
        $consulta->execute();
        return $consulta;
    }

    protected function uno(string $sql, array $parametros = []): ?array
    {
        $fila = $this->ejecutar($sql, $parametros)->fetch();
        return $fila === false ? null : $fila;
    }

    protected function todos(string $sql, array $parametros = []): array
    {
        return $this->ejecutar($sql, $parametros)->fetchAll();
    }

    protected function ultimoId(): int
    {
        return (int) $this->db->lastInsertId();
    }
}
