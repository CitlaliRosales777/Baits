<?php
declare(strict_types=1);

function usuario_actual(): int
{
    $id = $_SESSION['id_user'] ?? null;
    if (!is_int($id)) {
        responder(401, ['error' => 'Inicia sesion primero']);
    }
    return $id;
}

function fecha_valida(string $fecha): bool
{
    $dt = DateTime::createFromFormat('!Y-m-d', $fecha);
    return $dt !== false && $dt->format('Y-m-d') === $fecha;
}

function momento_valido(string $fecha, string $hora): ?string
{
    if (!preg_match('/^([01][0-9]|2[0-3]):([0-5][0-9])(:[0-5][0-9])?$/', $hora)) {
        return null;
    }
    if (!fecha_valida($fecha)) {
        return null;
    }
    return $fecha . ' ' . substr($hora, 0, 5) . ':00';
}

function crear_recordatorio(PDO $bd, array $entrada): void
{
    $id_user = usuario_actual();
    $contenido = texto($entrada, 'contenido');
    $momento = momento_valido(texto($entrada, 'fecha'), texto($entrada, 'hora'));

    if ($contenido === '' || mb_strlen($contenido) > 200) {
        responder(422, ['error' => 'El nombre del recordatorio es obligatorio (maximo 200 caracteres)']);
    }
    if ($momento === null) {
        responder(422, ['error' => 'Fecha u hora no validas']);
    }

    $st = $bd->prepare(
        "INSERT INTO recordatorios (id_user, tipo, contenido, id_estado, fecha)
         VALUES (:u, 'general', :c, (SELECT id_estado FROM estado WHERE estado = 'pendiente'), :f)"
    );
    $st->execute([':u' => $id_user, ':c' => $contenido, ':f' => $momento]);
    responder(201, ['mensaje' => 'Recordatorio creado', 'id_recordatorio' => (int) $bd->lastInsertId()]);
}

function listar_recordatorios(PDO $bd): void
{
    $id_user = usuario_actual();
    $desde = isset($_GET['desde']) && is_string($_GET['desde']) ? $_GET['desde'] : date('Y-m-d');
    $hasta = isset($_GET['hasta']) && is_string($_GET['hasta']) ? $_GET['hasta'] : $desde;

    if (!fecha_valida($desde) || !fecha_valida($hasta) || $hasta < $desde) {
        responder(422, ['error' => 'Rango de fechas no valido']);
    }
    $limite = (new DateTime($desde))->modify('+62 days')->format('Y-m-d');
    if ($hasta > $limite) {
        responder(422, ['error' => 'El rango maximo es de 62 dias']);
    }
    $fin = (new DateTime($hasta))->modify('+1 day')->format('Y-m-d');

    $st = $bd->prepare(
        'SELECT r.id_recordatorio, r.tipo, r.contenido, r.fecha, e.estado
         FROM recordatorios r
         JOIN estado e ON e.id_estado = r.id_estado
         WHERE r.id_user = :u AND r.fecha >= :desde AND r.fecha < :fin
         ORDER BY r.fecha, r.id_recordatorio'
    );
    $st->execute([':u' => $id_user, ':desde' => $desde, ':fin' => $fin]);

    $filas = [];
    foreach ($st->fetchAll() as $f) {
        $filas[] = [
            'id_recordatorio' => (int) $f['id_recordatorio'],
            'tipo' => $f['tipo'],
            'contenido' => $f['contenido'],
            'fecha' => $f['fecha'],
            'estado' => $f['estado'],
            'completado' => $f['estado'] === 'completado',
        ];
    }
    responder(200, ['recordatorios' => $filas]);
}

function marcar_recordatorio(PDO $bd, int $id, array $entrada): void
{
    $id_user = usuario_actual();
    if (!isset($entrada['completado']) || !is_bool($entrada['completado'])) {
        responder(422, ['error' => 'Manda completado: true o false']);
    }
    $completado = $entrada['completado'];

    $st = $bd->prepare('SELECT id_recordatorio FROM recordatorios WHERE id_recordatorio = :id AND id_user = :u');
    $st->execute([':id' => $id, ':u' => $id_user]);
    if (!$st->fetch()) {
        responder(404, ['error' => 'Recordatorio no encontrado']);
    }

    $st = $bd->prepare(
        'UPDATE recordatorios
         SET id_estado = (SELECT id_estado FROM estado WHERE estado = :e)
         WHERE id_recordatorio = :id AND id_user = :u'
    );
    $st->execute([':e' => $completado ? 'completado' : 'pendiente', ':id' => $id, ':u' => $id_user]);
    responder(200, ['mensaje' => 'Recordatorio actualizado', 'completado' => $completado]);
}

function eliminar_recordatorio(PDO $bd, int $id): void
{
    $id_user = usuario_actual();
    $st = $bd->prepare('DELETE FROM recordatorios WHERE id_recordatorio = :id AND id_user = :u');
    $st->execute([':id' => $id, ':u' => $id_user]);
    if ($st->rowCount() === 0) {
        responder(404, ['error' => 'Recordatorio no encontrado']);
    }
    responder(200, ['mensaje' => 'Recordatorio eliminado']);
}