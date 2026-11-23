<?php
class TokenModel extends BaseModel
{
    public function crear(int $idUser, string $hash, string $expiraAt, string $ahora): void
    {
        $this->ejecutar(
            'INSERT INTO api_tokens (id_user, token_hash, creado_at, expira_at)
             VALUES (:id_user, :hash, :ahora, :expira)',
            ['id_user' => $idUser, 'hash' => $hash, 'ahora' => $ahora, 'expira' => $expiraAt]
        );
    }

    public function buscarVigente(string $hash, string $ahora): ?array
    {
        return $this->uno(
            'SELECT u.id_user, u.name, u.mail
               FROM api_tokens t
               JOIN users u ON u.id_user = t.id_user
              WHERE t.token_hash = :hash
                AND t.revocado_at IS NULL
                AND t.expira_at > :ahora
                AND u.activo = 1
                AND u.deleted_at IS NULL',
            ['hash' => $hash, 'ahora' => $ahora]
        );
    }

    public function revocar(string $hash, string $ahora): void
    {
        $this->ejecutar(
            'UPDATE api_tokens SET revocado_at = :ahora WHERE token_hash = :hash AND revocado_at IS NULL',
            ['ahora' => $ahora, 'hash' => $hash]
        );
    }

    public function revocarDeUsuario(int $idUser, string $ahora): void
    {
        $this->ejecutar(
            'UPDATE api_tokens SET revocado_at = :ahora WHERE id_user = :id AND revocado_at IS NULL',
            ['ahora' => $ahora, 'id' => $idUser]
        );
    }

    public function borrarVencidos(string $antesDe): void
    {
        $this->ejecutar('DELETE FROM api_tokens WHERE expira_at < :antes', ['antes' => $antesDe]);
    }
}
