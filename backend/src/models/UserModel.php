<?php
class UserModel extends BaseModel
{
    private const PUBLICAS = 'id_user, name, lastname1, lastname2, date_b, phone, emer_phone, mail, created_at';
    private const EDITABLES = ['name', 'lastname1', 'lastname2', 'date_b', 'phone', 'emer_phone'];

    public function porId(int $id): ?array
    {
        return $this->uno(
            'SELECT ' . self::PUBLICAS . ' FROM users WHERE id_user = :id AND activo = 1 AND deleted_at IS NULL',
            ['id' => $id]
        );
    }

    /** Incluye el hash de la contraseña: solo lo usa el login. */
    public function porMail(string $mail): ?array
    {
        return $this->uno(
            'SELECT id_user, passw, activo FROM users WHERE mail = :mail AND deleted_at IS NULL',
            ['mail' => $mail]
        );
    }

    public function existeMail(string $mail): bool
    {
        return $this->uno('SELECT id_user FROM users WHERE mail = :mail', ['mail' => $mail]) !== null;
    }

    public function crear(array $d, string $hashClave): int
    {
        $this->ejecutar(
            'INSERT INTO users (name, lastname1, lastname2, date_b, phone, emer_phone, mail, passw)
             VALUES (:name, :lastname1, :lastname2, :date_b, :phone, :emer_phone, :mail, :passw)',
            [
                'name'       => $d['name'],
                'lastname1'  => $d['lastname1'],
                'lastname2'  => $d['lastname2'] ?? null,
                'date_b'     => $d['date_b'],
                'phone'      => $d['phone'],
                'emer_phone' => $d['emer_phone'] ?? null,
                'mail'       => $d['mail'],
                'passw'      => $hashClave,
            ]
        );
        return $this->ultimoId();
    }

    public function actualizar(int $id, array $campos): void
    {
        $asignaciones = [];
        $parametros = ['id' => $id];
        foreach ($campos as $columna => $valor) {
            if (in_array($columna, self::EDITABLES, true)) {
                $asignaciones[] = "$columna = :$columna";
                $parametros[$columna] = $valor;
            }
        }
        if ($asignaciones === []) {
            return;
        }
        $this->ejecutar('UPDATE users SET ' . implode(', ', $asignaciones) . ' WHERE id_user = :id', $parametros);
    }

    /** Borrado lógico: la cuenta deja de funcionar pero se conserva el historial. */
    public function eliminar(int $id, string $ahora): void
    {
        $this->ejecutar(
            'UPDATE users SET activo = 0, deleted_at = :ahora WHERE id_user = :id AND deleted_at IS NULL',
            ['ahora' => $ahora, 'id' => $id]
        );
    }
}
