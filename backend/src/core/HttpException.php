<?php
/** Error que ya trae su código HTTP y su mensaje para el cliente. */
class HttpException extends RuntimeException
{
    public function __construct(
        public readonly int $codigo,
        string $mensaje,
        public readonly array $cabeceras = []
    ) {
        parent::__construct($mensaje, $codigo);
    }
}
