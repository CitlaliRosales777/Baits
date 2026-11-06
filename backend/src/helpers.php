<?php
declare(strict_types=1);

function responder(int $codigo, array $datos): void
{
    http_response_code($codigo);
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode($datos, JSON_UNESCAPED_UNICODE);
    exit;
}

function leer_entrada(): array
{
    $crudo = file_get_contents('php://input');
    $json = json_decode($crudo === false ? '' : $crudo, true);
    if (is_array($json)) {
        return $json;
    }
    return $_POST;
}