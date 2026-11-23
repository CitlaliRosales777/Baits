<?php
/** Revisa el token Bearer y deja el usuario en la petición. Solo se usa en rutas protegidas. */
class AuthMiddleware
{
    public function manejar(Request $req, callable $siguiente): Response
    {
        $token = $req->bearer();
        if ($token === null) {
            throw new HttpException(401, 'Falta la cabecera Authorization: Bearer <token>', ['WWW-Authenticate' => 'Bearer']);
        }

        $hash = TokenService::hash($token);
        $usuario = (new TokenModel())->buscarVigente($hash, TokenService::ahora());
        if ($usuario === null) {
            throw new HttpException(401, 'Token inválido o vencido', ['WWW-Authenticate' => 'Bearer']);
        }

        $req->usuario = $usuario;
        $req->tokenHash = $hash;
        return $siguiente($req);
    }
}
