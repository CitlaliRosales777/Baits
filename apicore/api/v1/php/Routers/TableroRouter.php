<?php
declare(strict_types=1);

namespace Apicore\Routers;

use Apicore\Controllers\TableroController;
use Apicore\Core\Response;
use Apicore\Core\Router;

final class TableroRouter
{
    public static function register(Router $router): void
    {
        // Estas rutas pasan por la autenticación de APIcore antes de leer o guardar datos.
        $router->addRoute('GET', '/tablero/recordatorios', TableroController::class,
            static fn (TableroController $c): Response => new Response(200, ['data' => $c->recordatorios()]));
        $router->addRoute('PUT', '/tablero/recordatorios/{id}', TableroController::class,
            static function (TableroController $c, array $params, string $body): Response {
                $c->guardarRecordatorio($params['id'], Router::jsonObject($body));
                return new Response(200, ['status' => 'ok']);
            });
        $router->addRoute('DELETE', '/tablero/recordatorios/{id}', TableroController::class,
            static function (TableroController $c, array $params): Response {
                $c->eliminarRecordatorio($params['id']);
                return new Response(200, ['status' => 'ok']);
            });
        $router->addRoute('GET', '/tablero/emociones', TableroController::class,
            static fn (TableroController $c): Response => new Response(200, ['data' => $c->emociones()]));
        $router->addRoute('PUT', '/tablero/emociones/{id}', TableroController::class,
            static function (TableroController $c, array $params, string $body): Response {
                $c->guardarEmocion($params['id'], Router::jsonObject($body));
                return new Response(200, ['status' => 'ok']);
            });
    }
}
