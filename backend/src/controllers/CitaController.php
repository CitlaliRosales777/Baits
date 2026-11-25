<?php
/**
 * Citas médicas del usuario que inició sesión.
 * Pedir una cita de otra persona da 404, igual que en recordatorios,
 * para no revelar si existe.
 */
class CitaController
{
    public function listar(Request $req): Response
    {
        $q = CitaSchema::consulta($req->consulta);
        $idUser = (int) $req->usuario['id_user'];
        $modelo = new CitaModel();

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
        $datos  = CitaSchema::crear($req->cuerpo());
        $modelo = new CitaModel();
        $this->revisarReferencias($modelo, $datos);

        $datos['id_estado'] = $modelo->idEstado('pendiente');
        $id = $modelo->crear((int) $req->usuario['id_user'], $datos);
        return Response::creado($id, $req->url("/citas/$id"));
    }

    public function reemplazar(Request $req): Response
    {
        $datos = CitaSchema::reemplazar($req->cuerpo());
        // PUT reemplaza todo: si no mandan descripción, se borra la que había
        $datos['descripcion'] ??= null;
        return $this->guardar($req, $datos);
    }

    public function actualizar(Request $req): Response
    {
        return $this->guardar($req, CitaSchema::parcial($req->cuerpo()));
    }

    public function eliminar(Request $req): Response
    {
        try {
            $borrado = (new CitaModel())->eliminar((int) $req->usuario['id_user'], $req->parametros['id']);
        } catch (PDOException $e) {
            // 1451: la base no deja borrar una cita que todavía tiene recordatorios
            if ((int) ($e->errorInfo[1] ?? 0) === 1451) {
                throw new HttpException(409, 'La cita tiene recordatorios; bórralos primero');
            }
            throw $e;
        }
        if (!$borrado) {
            throw new HttpException(404, 'Cita no encontrada');
        }
        return Response::mensaje('Cita eliminada');
    }

    private function guardar(Request $req, array $datos): Response
    {
        $this->buscar($req); // 404 si no existe o es de otro usuario
        $modelo = new CitaModel();
        $this->revisarReferencias($modelo, $datos);

        if (array_key_exists('completado', $datos)) {
            $datos['id_estado'] = $modelo->idEstado($datos['completado'] ? 'completado' : 'pendiente');
            unset($datos['completado']);
        }
        $modelo->actualizar((int) $req->usuario['id_user'], $req->parametros['id'], $datos);

        return Response::ok($this->formatear($this->buscar($req)));
    }

    /** 400 claro si el médico, el lugar o el área no existen, en vez de un error de la base. */
    private function revisarReferencias(CitaModel $modelo, array $datos): void
    {
        $nombres = ['id_doctor' => 'El médico', 'id_location' => 'El lugar', 'id_area' => 'El área'];
        $faltante = $modelo->referenciaFaltante($datos);
        if ($faltante !== null) {
            throw new HttpException(400, "{$nombres[$faltante]} con ese id no existe ($faltante)");
        }
    }

    private function buscar(Request $req): array
    {
        $fila = (new CitaModel())->porId((int) $req->usuario['id_user'], $req->parametros['id']);
        if ($fila === null) {
            throw new HttpException(404, 'Cita no encontrada');
        }
        return $fila;
    }

    private function formatear(array $fila): array
    {
        return [
            'id_cita'     => (int) $fila['id_cita'],
            'fecha'       => $fila['fecha'],
            'descripcion' => $fila['descripcion'],
            'doctor'      => ['id' => (int) $fila['id_doctor'],   'nombre' => $fila['doctor']],
            'area'        => ['id' => (int) $fila['id_area'],     'nombre' => $fila['area']],
            'lugar'       => ['id' => (int) $fila['id_location'], 'direccion' => $fila['lugar']],
            'estado'      => $fila['estado'],
            'completado'  => $fila['estado'] === 'completado',
        ];
    }
}
