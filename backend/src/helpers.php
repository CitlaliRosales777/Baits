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
    $crudo = (string) file_get_contents('php://input', false, null, 0, 20001);
    if (strlen($crudo) > 20000) {
        responder(413, ['error' => 'Peticion demasiado grande']);
    }
    $json = json_decode($crudo, true);
    if (is_array($json)) {
        return $json;
    }
    return $_POST;
}