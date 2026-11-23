<?php
/** Datos de la petición HTTP. Solo datos: no escribe nada ni toca la base. */
class Request
{
    public const MAX_CUERPO = 20000; // bytes

    public array $parametros = [];   // {id} de la ruta
    public ?array $usuario = null;   // lo llena AuthMiddleware
    public ?string $tokenHash = null;
    private ?array $cuerpoLeido = null;

    public function __construct(
        public readonly string $metodo,
        public readonly string $ruta,
        public readonly string $base,
        public readonly array $consulta,
        public readonly array $cabeceras,   // nombres en minúsculas
        public readonly string $ip,
        private readonly string $tipoContenido
    ) {
    }

    public static function desdeGlobales(): self
    {
        $metodo = strtoupper($_SERVER['REQUEST_METHOD'] ?? 'GET');
        $ruta   = rawurldecode(parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH) ?: '/');

        // Si la API vive en una subcarpeta del hosting, esa carpeta no cuenta como ruta.
        $script = str_replace('\\', '/', $_SERVER['SCRIPT_NAME'] ?? '');
        $base = '';
        if (basename($script) === 'index.php') {
            $base = rtrim(str_replace('\\', '/', dirname($script)), '/');
            if ($base === '.') {
                $base = '';
            }
        }
        if ($base !== '' && str_starts_with($ruta, $base)) {
            $ruta = substr($ruta, strlen($base));
        }
        if (str_starts_with($ruta, '/index.php')) {
            $ruta = substr($ruta, strlen('/index.php'));
        }
        $ruta = '/' . trim($ruta, '/');

        $cabeceras = [];
        foreach ($_SERVER as $nombre => $valor) {
            if (str_starts_with($nombre, 'HTTP_')) {
                $cabeceras[strtolower(str_replace('_', '-', substr($nombre, 5)))] = (string) $valor;
            }
        }
        if (!isset($cabeceras['authorization'])) {
            $cabeceras['authorization'] = $_SERVER['REDIRECT_HTTP_AUTHORIZATION']
                ?? (function_exists('apache_request_headers') ? (apache_request_headers()['Authorization'] ?? '') : '');
        }

        return new self(
            $metodo,
            $ruta,
            $base,
            $_GET,
            $cabeceras,
            $_SERVER['REMOTE_ADDR'] ?? '0.0.0.0',
            strtolower($_SERVER['CONTENT_TYPE'] ?? '')
        );
    }

    /** Cuerpo de la petición como arreglo. Acepta JSON o formulario. */
    public function cuerpo(): array
    {
        if ($this->cuerpoLeido !== null) {
            return $this->cuerpoLeido;
        }

        if ((int) ($_SERVER['CONTENT_LENGTH'] ?? 0) > self::MAX_CUERPO) {
            throw new HttpException(413, 'El cuerpo de la petición supera los ' . self::MAX_CUERPO . ' bytes');
        }
        $crudo = file_get_contents('php://input', false, null, 0, self::MAX_CUERPO + 1);
        if (strlen($crudo) > self::MAX_CUERPO) {
            throw new HttpException(413, 'El cuerpo de la petición supera los ' . self::MAX_CUERPO . ' bytes');
        }

        if (str_contains($this->tipoContenido, 'application/x-www-form-urlencoded')) {
            return $this->cuerpoLeido = $_POST;
        }
        if (trim($crudo) === '') {
            return $this->cuerpoLeido = [];
        }

        $datos = json_decode($crudo, true, 16);
        if (!is_array($datos) || ($datos !== [] && array_is_list($datos))) {
            throw new HttpException(400, 'El cuerpo debe ser un objeto JSON válido');
        }
        return $this->cuerpoLeido = $datos;
    }

    public function bearer(): ?string
    {
        $cabecera = $this->cabeceras['authorization'] ?? '';
        return preg_match('/^Bearer\s+(\S+)$/i', $cabecera, $m) ? $m[1] : null;
    }

    /** Dirección completa de un recurso, respetando la subcarpeta del hosting. */
    public function url(string $ruta): string
    {
        return $this->base . $ruta;
    }
}
