<?php
class RecordatorioController
{
    public function listar(Request $req): Response
    {
        $q = RecordatorioSchema::consulta($req->consulta);
        $idUser = (int) $req->usuario['id_user'];
        $modelo = new RecordatorioModel();

        $filas = $modelo->listar($idUser, $q['desde'], $q['hastaExclusivo'], $q['tamano'], ($q['pagina'] - 1) * $q['tamano']);
        return Response::lista(array_map([$this, 'formatear'], $filas), [
            'page'  => $q['pagina'],
            'size'  => $q['tamano'],
            'total' => $modelo->contar($idUser, $q['desde'], $q['hastaExclusivo']),
        ]);
    }

    public function ver(Request $req): Response
    {
        return Response::ok($this->formatear($this->buscar($req)));
    }

    public function crear(Request $req): Response
    {
        $datos  = RecordatorioSchema::crear($req->cuerpo());
        $modelo = new RecordatorioModel();
        $id = $modelo->crear(
            (int) $req->usuario['id_user'],
            $datos['tipo'],
            $datos['contenido'],
            $datos['fecha'],
            $modelo->idEstado('pendiente')
        );
        return Response::creado($id, $req->url("/recordatorios/$id"));
    }

    public function reemplazar(Request $req): Response
    {
        return $this->guardar($req, RecordatorioSchema::reemplazar($req->cuerpo()));
    }

    public function actualizar(Request $req): Response
    {
        return $this->guardar($req, RecordatorioSchema::parcial($req->cuerpo()));
    }

    public function eliminar(Request $req): Response
    {
        $borrado = (new RecordatorioModel())->eliminar((int) $req->usuario['id_user'], $req->parametros['id']);
        if (!$borrado) {
            throw new HttpException(404, 'Recordatorio no encontrado');
        }
        return Response::mensaje('Recordatorio eliminado');
    }

    private function guardar(Request $req, array $datos): Response
    {
        $this->buscar($req); // 404 si no existe o es de otro usuario
        $modelo = new RecordatorioModel();

        $campos = [];
        foreach (['contenido', 'fecha'] as $campo) {
            if (isset($datos[$campo])) {
                $campos[$campo] = $datos[$campo];
            }
        }
        if (isset($datos['completado'])) {
            $campos['id_estado'] = $modelo->idEstado($datos['completado'] ? 'completado' : 'pendiente');
        }
        $modelo->actualizar((int) $req->usuario['id_user'], $req->parametros['id'], $campos);

        return Response::ok($this->formatear($this->buscar($req)));
    }

    private function buscar(Request $req): array
    {
        $fila = (new RecordatorioModel())->porId((int) $req->usuario['id_user'], $req->parametros['id']);
        if ($fila === null) {
            throw new HttpException(404, 'Recordatorio no encontrado');
        }
        return $fila;
    }

    private function formatear(array $fila): array
    {
        return [
            'id_recordatorio' => (int) $fila['id_recordatorio'],
            'contenido'       => $fila['contenido'],
            'fecha'           => $fila['fecha'],
            'tipo'            => $fila['tipo'],
            'estado'          => $fila['estado'],
            'completado'      => $fila['estado'] === 'completado',
            'created_at'      => $fila['created_at'],
        ];
    }
}
