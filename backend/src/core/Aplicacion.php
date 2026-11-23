<?php
/**
 * Arma el recorrido de cada petición:
 *   Cors -> Error -> (Auth si la ruta lo pide) -> controlador
 */
class Aplicacion
{
    public function ejecutar(): void
    {
        $metodo = strtoupper($_SERVER['REQUEST_METHOD'] ?? 'GET');
        try {
            $peticion = Request::desdeGlobales();

            $router = new Router();
            (require dirname(__DIR__) . '/routers/rutas.php')($router);

            $nucleo = function (Request $req) use ($router): Response {
                $ruta = $router->resolver($req->metodo, $req->ruta);
                if (isset($ruta['opciones'])) {
                    return Response::sinContenido(['Allow' => $ruta['opciones']]);
                }

                $req->parametros = $ruta['parametros'];
                $destino = function (Request $r) use ($ruta): Response {
                    return (new $ruta['clase']())->{$ruta['accion']}($r);
                };
                return $ruta['protegida']
                    ? (new AuthMiddleware())->manejar($req, $destino)
                    : $destino($req);
            };

            $cors  = new CorsMiddleware();
            $error = new ErrorMiddleware();
            $respuesta = $cors->manejar($peticion, fn (Request $r) => $error->manejar($r, $nucleo));
        } catch (Throwable $e) {
            // Falló algo antes de armar la petición (por ejemplo, la configuración).
            error_log('Error de arranque: ' . $e->getMessage());
            $respuesta = Response::error('Error interno del servidor', 500);
        }
        $respuesta->enviar($metodo);
    }
}
