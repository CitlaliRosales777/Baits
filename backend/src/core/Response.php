<?php
/** Respuesta HTTP en JSON. Todas las respuestas de la API salen por aquí. */
class Response
{
    public function __construct(
        public int $codigo,
        public ?array $cuerpo = null,
        public array $cabeceras = []
    ) {
    }

    public static function ok(array $datos, int $codigo = 200): self
    {
        return new self($codigo, ['status' => 'ok', 'data' => $datos]);
    }

    public static function lista(array $datos, array $meta): self
    {
        return new self(200, ['status' => 'ok', 'data' => $datos, 'meta' => $meta]);
    }

    public static function mensaje(string $mensaje, int $codigo = 200): self
    {
        return new self($codigo, ['status' => 'ok', 'message' => $mensaje]);
    }

    public static function creado(int $id, string $ubicacion): self
    {
        return new self(201, ['status' => 'ok', 'ID' => $id], ['Location' => $ubicacion]);
    }

    public static function error(string $mensaje, int $codigo, array $cabeceras = []): self
    {
        return new self($codigo, ['error' => $mensaje], $cabeceras);
    }

    public static function sinContenido(array $cabeceras = []): self
    {
        return new self(204, null, $cabeceras);
    }

    public function conCabecera(string $nombre, string $valor): self
    {
        $this->cabeceras[$nombre] = $valor;
        return $this;
    }

    public function enviar(string $metodo): void
    {
        http_response_code($this->codigo);

        header('X-Content-Type-Options: nosniff');
        header('X-Frame-Options: DENY');
        header('Referrer-Policy: no-referrer');
        header("Content-Security-Policy: default-src 'none'; frame-ancestors 'none'");
        header('Cache-Control: no-store');
        foreach ($this->cabeceras as $nombre => $valor) {
            header("$nombre: $valor");
        }

        if ($this->cuerpo === null || $this->codigo === 204) {
            return;
        }
        header('Content-Type: application/json; charset=utf-8');
        if ($metodo !== 'HEAD') {
            echo json_encode(
                $this->cuerpo,
                JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_INVALID_UTF8_SUBSTITUTE
            );
        }
    }
}
