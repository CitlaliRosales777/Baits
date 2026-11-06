<?php
declare(strict_types=1);

function texto(array $entrada, string $campo): string
{
    $valor = $entrada[$campo] ?? '';
    return is_string($valor) ? trim($valor) : '';
}

function registrar_usuario(PDO $bd, array $entrada): void
{
    $name = texto($entrada, 'name');
    $lastname1 = texto($entrada, 'lastname1');
    $lastname2 = texto($entrada, 'lastname2');
    $date_b = texto($entrada, 'date_b');
    $phone = texto($entrada, 'phone');
    $emer_phone = texto($entrada, 'emer_phone');
    $mail = strtolower(texto($entrada, 'mail'));
    $passw = is_string($entrada['passw'] ?? null) ? $entrada['passw'] : '';

    if ($name === '' || $lastname1 === '' || $date_b === '' || $phone === '' || $mail === '' || $passw === '') {
        responder(422, ['error' => 'Faltan campos obligatorios']);
    }
    if (mb_strlen($name) > 100 || mb_strlen($lastname1) > 100 || mb_strlen($lastname2) > 100) {
        responder(422, ['error' => 'Nombre o apellidos demasiado largos']);
    }
    if (!filter_var($mail, FILTER_VALIDATE_EMAIL) || strlen($mail) > 254) {
        responder(422, ['error' => 'Correo no valido']);
    }
    $fecha = DateTime::createFromFormat('Y-m-d', $date_b);
    if (!$fecha || $fecha->format('Y-m-d') !== $date_b || $fecha > new DateTime('today')) {
        responder(422, ['error' => 'Fecha de nacimiento no valida']);
    }
    $patronTel = '/^[0-9+\- ]{7,15}$/';
    if (!preg_match($patronTel, $phone) || ($emer_phone !== '' && !preg_match($patronTel, $emer_phone))) {
        responder(422, ['error' => 'Telefono no valido']);
    }
    if (strlen($passw) < 8 || strlen($passw) > 72) {
        responder(422, ['error' => 'La contrasena debe tener entre 8 y 72 caracteres']);
    }

    $hash = password_hash($passw, PASSWORD_DEFAULT);
    try {
        $st = $bd->prepare(
            'INSERT INTO users (name, lastname1, lastname2, date_b, phone, emer_phone, mail, passw)
             VALUES (:name, :lastname1, :lastname2, :date_b, :phone, :emer_phone, :mail, :passw)'
        );
        $st->execute([
            ':name' => $name,
            ':lastname1' => $lastname1,
            ':lastname2' => $lastname2 !== '' ? $lastname2 : null,
            ':date_b' => $date_b,
            ':phone' => $phone,
            ':emer_phone' => $emer_phone !== '' ? $emer_phone : null,
            ':mail' => $mail,
            ':passw' => $hash,
        ]);
    } catch (PDOException $e) {
        if ((int) ($e->errorInfo[1] ?? 0) === 1062) {
            responder(409, ['error' => 'Ese correo ya esta registrado']);
        }
        throw $e;
    }
    responder(201, ['mensaje' => 'Cuenta creada', 'id_user' => (int) $bd->lastInsertId()]);
}

function iniciar_sesion(PDO $bd, array $entrada): void
{
    $mail = strtolower(texto($entrada, 'mail'));
    $passw = is_string($entrada['passw'] ?? null) ? $entrada['passw'] : '';
    if ($mail === '' || $passw === '') {
        responder(422, ['error' => 'Escribe tu correo y tu contrasena']);
    }

    $st = $bd->prepare('SELECT id_user, name, passw FROM users WHERE mail = :mail');
    $st->execute([':mail' => $mail]);
    $usuario = $st->fetch();

    $hash = $usuario ? $usuario['passw'] : password_hash('relleno', PASSWORD_DEFAULT);
    $correcto = password_verify($passw, $hash);
    if (!$usuario || !$correcto) {
        responder(401, ['error' => 'Correo o contrasena incorrectos']);
    }

    session_regenerate_id(true);
    $_SESSION['id_user'] = (int) $usuario['id_user'];
    responder(200, ['mensaje' => 'Sesion iniciada', 'id_user' => (int) $usuario['id_user'], 'name' => $usuario['name']]);
}

function perfil_actual(PDO $bd): void
{
    $id = $_SESSION['id_user'] ?? null;
    if (!is_int($id)) {
        responder(401, ['error' => 'Inicia sesion primero']);
    }
    $st = $bd->prepare('SELECT id_user, name, lastname1, lastname2, mail FROM users WHERE id_user = :id');
    $st->execute([':id' => $id]);
    $usuario = $st->fetch();
    if (!$usuario) {
        responder(401, ['error' => 'Inicia sesion primero']);
    }
    responder(200, ['usuario' => $usuario]);
}

function cerrar_sesion(): void
{
    $_SESSION = [];
    session_destroy();
    responder(200, ['mensaje' => 'Sesion cerrada']);
}