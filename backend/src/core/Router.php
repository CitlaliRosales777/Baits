<?php
/** Guarda las rutas y busca cuál atiende cada petición. No ejecuta nada. */
class Router
{
    private array $rutas = [];

    /** Ejemplo de patrón: /users/{id}  (los {parametros} son números enteros). */
    public function agregar(string $metodo, string $patron, string $clase, string $accion, bool $protegida = true): void
    {
        $regex = '';
        foreach (preg_split('/(\{\w+\})/', $patron, -1, PREG_SPLIT_DELIM_CAPTURE) as $trozo) {
            $regex .= preg_match('/^\{(\w+)\}$/', $trozo, $m)
                ? '(?P<' . $m[1] . '>[0-9]{1,18})'
                : preg_quote($trozo, '#');
        }
        $this->rutas[] = [
            'metodo'    => $metodo,
            'regex'     => '#^' . $regex . '$#',
            'clase'     => $clase,
            'accion'    => $accion,
            'protegida' => $protegida,
        ];
    }

    /**
     * Devuelve la ruta que atiende la petición o lanza 404 / 405.
     * Para OPTIONS devuelve solo los métodos permitidos.
     */
    public function resolver(string $metodo, string $ruta): array
    {
        $permitidos = [];
        foreach ($this->rutas as $r) {
            if (!preg_match($r['regex'], $ruta, $m)) {
                continue;
            }
            $permitidos[] = $r['metodo'];
            if ($metodo === $r['metodo'] || ($metodo === 'HEAD' && $r['metodo'] === 'GET')) {
                $parametros = [];
                foreach ($m as $nombre => $valor) {
                    if (is_string($nombre)) {
                        $parametros[$nombre] = (int) $valor;
                    }
                }
                return $r + ['parametros' => $parametros];
            }
        }

        if ($permitidos === []) {
            throw new HttpException(404, 'Ruta no encontrada');
        }
        if (in_array('GET', $permitidos, true)) {
            $permitidos[] = 'HEAD';
        }
        $permitidos[] = 'OPTIONS';
        $allow = implode(', ', array_unique($permitidos));

        if ($metodo === 'OPTIONS') {
            return ['opciones' => $allow];
        }
        throw new HttpException(405, 'Método no permitido para esta ruta', ['Allow' => $allow]);
    }
}
