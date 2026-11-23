<?php
class UserController
{
    public function registrar(Request $req): Response
    {
        $datos  = UserSchema::registro($req->cuerpo());
        $modelo = new UserModel();

        if ($modelo->existeMail($datos['mail'])) {
            throw new HttpException(409, 'Ya existe una cuenta con ese correo');
        }
        try {
            $id = $modelo->crear($datos, password_hash($datos['passw'], PASSWORD_DEFAULT));
        } catch (PDOException $e) {
            if (Database::esDuplicado($e)) {
                throw new HttpException(409, 'Ya existe una cuenta con ese correo');
            }
            throw $e;
        }
        return Response::creado($id, $req->url("/users/$id"));
    }

    public function ver(Request $req): Response
    {
        return Response::ok($this->cargar($this->propio($req)));
    }

    public function reemplazar(Request $req): Response
    {
        $id = $this->propio($req);
        (new UserModel())->actualizar($id, UserSchema::perfilCompleto($req->cuerpo()));
        return Response::ok($this->cargar($id));
    }

    public function actualizar(Request $req): Response
    {
        $id = $this->propio($req);
        (new UserModel())->actualizar($id, UserSchema::perfilParcial($req->cuerpo()));
        return Response::ok($this->cargar($id));
    }

    public function eliminar(Request $req): Response
    {
        $id = $this->propio($req);
        $ahora = TokenService::ahora();
        (new UserModel())->eliminar($id, $ahora);
        (new TokenModel())->revocarDeUsuario($id, $ahora);
        return Response::mensaje('Cuenta eliminada');
    }

    /** Cada usuario solo puede tocar su propia cuenta (el esquema no tiene roles). */
    private function propio(Request $req): int
    {
        $id = $req->parametros['id'];
        if ($id !== (int) $req->usuario['id_user']) {
            throw new HttpException(403, 'No tienes permiso para acceder a este usuario');
        }
        return $id;
    }

    private function cargar(int $id): array
    {
        $usuario = (new UserModel())->porId($id);
        if ($usuario === null) {
            throw new HttpException(404, 'Usuario no encontrado');
        }
        $usuario['id_user'] = (int) $usuario['id_user'];
        return $usuario;
    }
}
