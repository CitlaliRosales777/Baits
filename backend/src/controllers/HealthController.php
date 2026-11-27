<?php
class HealthController
{
    public function ver(Request $req): Response
    {
        if (!Database::responde()) {
            // Un 503 también indica que las tablas de inicio de sesión aún no están listas.
            return Response::error('No está disponible la base de datos o falta preparar el inicio de sesión', 503);
        }
        return Response::ok([
            'servicio'      => 'moodsitto',
            'base_de_datos' => 'ok',
            'hora'          => date('c'),
        ]);
    }
}
