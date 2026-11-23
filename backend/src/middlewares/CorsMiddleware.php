<?php
/**
 * Permisos para que el frontend, aunque esté en otra dirección, pueda llamar a la API.
 * CORS_ALLOW_ORIGIN en el .env: "*" (por defecto) o una lista separada por comas.
 */
class CorsMiddleware
{
    public function manejar(Request $req, callable $siguiente): Response
    {
        $respuesta = $siguiente($req);

        $permitido = trim(Config::get('CORS_ALLOW_ORIGIN', '*'));
        if ($permitido === '*') {
            $respuesta->conCabecera('Access-Control-Allow-Origin', '*');
        } else {
            $origen = $req->cabeceras['origin'] ?? '';
            $lista = array_map('trim', explode(',', $permitido));
            if ($origen !== '' && in_array($origen, $lista, true)) {
                $respuesta->conCabecera('Access-Control-Allow-Origin', $origen);
            }
            $respuesta->conCabecera('Vary', 'Origin');
        }
        $respuesta->conCabecera('Access-Control-Allow-Methods', 'GET, POST, PUT, PATCH, DELETE, HEAD, OPTIONS');
        $respuesta->conCabecera('Access-Control-Allow-Headers', 'Content-Type, Authorization');
        $respuesta->conCabecera('Access-Control-Max-Age', '86400');

        return $respuesta;
    }
}
