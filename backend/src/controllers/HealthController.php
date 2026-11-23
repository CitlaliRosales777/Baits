<?php
class HealthController
{
    public function ver(Request $req): Response
    {
        if (!Database::responde()) {
            return Response::error('Base de datos no disponible', 503);
        }
        return Response::ok([
            'servicio'      => 'moodsitto',
            'base_de_datos' => 'ok',
            'hora'          => date('c'),
        ]);
    }
}
