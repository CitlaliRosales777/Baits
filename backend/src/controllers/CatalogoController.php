<?php
/**
 * Listas para llenar los <select> del formulario de citas.
 * No reciben datos, así que no necesitan schema.
 */
class CatalogoController
{
    public function doctores(Request $req): Response
    {
        $filas = (new CatalogoModel())->doctores();
        return Response::ok(array_map(fn ($f) => [
            'id_doctor'    => (int) $f['id_doctor'],
            'nombre'       => $f['nombre'],
            'telefono'     => $f['num_tel'],
            'area'         => ['id' => (int) $f['id_area'], 'nombre' => $f['area']],
            'especialidad' => $f['especialidad'],
            'id_location'  => $f['id_location'] === null ? null : (int) $f['id_location'],
        ], $filas));
    }

    public function areas(Request $req): Response
    {
        $filas = (new CatalogoModel())->areas();
        return Response::ok(array_map(fn ($f) => [
            'id_area'     => (int) $f['id_area'],
            'nombre'      => $f['nombre'],
            'descripcion' => $f['descripcion'],
        ], $filas));
    }

    public function lugares(Request $req): Response
    {
        $filas = (new CatalogoModel())->lugares();
        return Response::ok(array_map(fn ($f) => [
            'id_location' => (int) $f['id_location'],
            'direccion'   => $f['direccion'],
            'cp'          => $f['cp'],
            'descripcion' => $f['descripcion'],
        ], $filas));
    }
}
