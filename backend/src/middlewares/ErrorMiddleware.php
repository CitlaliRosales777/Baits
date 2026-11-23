<?php
/** Convierte cualquier error en una respuesta JSON. El detalle técnico solo va al registro. */
class ErrorMiddleware
{
    public function manejar(Request $req, callable $siguiente): Response
    {
        try {
            return $siguiente($req);
        } catch (HttpException $e) {
            return Response::error($e->getMessage(), $e->codigo, $e->cabeceras);
        } catch (Throwable $e) {
            error_log(get_class($e) . ': ' . $e->getMessage() . ' en ' . $e->getFile() . ':' . $e->getLine());
            return Response::error('Error interno del servidor', 500);
        }
    }
}
