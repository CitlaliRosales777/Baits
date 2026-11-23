<?php
class AuthController
{
    public function login(Request $req): Response
    {
        $datos  = LoginSchema::credenciales($req->cuerpo());
        $limite = new LimiteIntentos();
        $clave  = LimiteIntentos::clave($req->ip, $datos['mail']);

        $limite->verificar($clave);

        $usuario = (new UserModel())->porMail($datos['mail']);
        // Si el correo no existe se compara contra un hash falso, para que tarde lo mismo.
        $hash = $usuario['passw'] ?? password_hash('sin-usuario', PASSWORD_DEFAULT);
        $correcta = password_verify($datos['passw'], $hash);

        if ($usuario === null || !$correcta || (int) $usuario['activo'] !== 1) {
            $limite->fallo($clave);
            throw new HttpException(401, 'Correo o contraseña incorrectos');
        }

        $limite->exito($clave);
        $acceso = TokenService::emitir((int) $usuario['id_user']);

        return Response::ok([
            'token'      => $acceso['token'],
            'token_type' => 'Bearer',
            'expires_at' => $acceso['expira_at'],
            'id_user'    => (int) $usuario['id_user'],
        ]);
    }

    public function logout(Request $req): Response
    {
        TokenService::revocar($req->tokenHash);
        return Response::mensaje('Sesión cerrada');
    }
}
