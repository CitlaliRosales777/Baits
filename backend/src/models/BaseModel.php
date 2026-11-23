<?php
/** Utilidades comunes de los modelos. Los modelos son los únicos que escriben SQL. */
abstract class BaseModel
{
    protected PDO $db;

    public function __construct()
    {
        $this->db = Database::conexion();
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
