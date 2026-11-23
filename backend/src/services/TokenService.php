<?php
/**
 * Tokens de acceso. El token real solo lo ve el cliente una vez;
 * en la base se guarda únicamente su hash SHA-256.
 */
class TokenService
{
    public static function ahora(): string
    {
        return date('Y-m-d H:i:s');
    }

    public static function hash(string $token): string
    {
        return hash('sha256', $token);
    }

    /** @return array{token:string, expira_at:string} */
    public static function emitir(int $idUser): array
    {
        $token = bin2hex(random_bytes(32));
        $minutos = Config::entero('TOKEN_LIFETIME_MINUTES', 60);
        $expira = date('Y-m-d H:i:s', time() + $minutos * 60);

        $modelo = new TokenModel();
        $modelo->crear($idUser, self::hash($token), $expira, self::ahora());
        $modelo->borrarVencidos(date('Y-m-d H:i:s', time() - 86400));

        return ['token' => $token, 'expira_at' => $expira];
    }

    public static function revocar(string $hash): void
    {
        (new TokenModel())->revocar($hash, self::ahora());
    }
}
