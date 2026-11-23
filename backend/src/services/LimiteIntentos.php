<?php
/**
 * Bloqueo por intentos fallidos de login: 5 fallos en 15 minutos bloquean
 * esa combinación IP + correo (se puede cambiar en el .env).
 */
class LimiteIntentos
{
    private IntentoModel $modelo;
    private int $maximo;
    private int $ventana; // segundos

    public function __construct()
    {
        $this->modelo  = new IntentoModel();
        $this->maximo  = Config::entero('LOGIN_MAX_ATTEMPTS', 5);
        $this->ventana = Config::entero('LOGIN_BLOCK_MINUTES', 15) * 60;
    }

    public static function clave(string $ip, string $mail): string
    {
        return hash('sha256', $ip . '|' . strtolower($mail));
    }

    /** Lanza 429 si la clave ya está bloqueada. */
    public function verificar(string $clave): void
    {
        $resumen = $this->modelo->resumen($clave, date('Y-m-d H:i:s', time() - $this->ventana));
        if ($resumen['total'] < $this->maximo) {
            return;
        }
        $espera = max(1, strtotime($resumen['primero']) + $this->ventana - time());
        $minutos = (int) ceil($espera / 60);
        throw new HttpException(
            429,
            "Demasiados intentos fallidos. Intenta de nuevo en $minutos minuto(s)",
            ['Retry-After' => (string) $espera]
        );
    }

    public function fallo(string $clave): void
    {
        $this->modelo->registrar($clave, date('Y-m-d H:i:s'));
        $this->modelo->borrarAntiguos(date('Y-m-d H:i:s', time() - 86400));
    }

    public function exito(string $clave): void
    {
        $this->modelo->limpiar($clave);
    }
}
