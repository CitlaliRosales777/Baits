<?php
/** Catálogos compartidos que se usan al crear una cita: médicos, áreas y lugares. Solo lectura. */
class CatalogoModel extends BaseModel
{
    public function doctores(): array
    {
        return $this->todos(
            "SELECT d.id_doctor, CONCAT_WS(' ', d.nombre, d.apellido_p, d.apellido_m) AS nombre,
                    d.num_tel, d.id_area, a.nombre_area AS area, es.especialidad, d.id_location
               FROM doctors d
               JOIN area a          ON a.id_area = d.id_area
               JOIN especialidad es ON es.id_especialidad = d.id_especialidad
              ORDER BY d.nombre, d.apellido_p"
        );
    }

    public function areas(): array
    {
        return $this->todos('SELECT id_area, nombre_area AS nombre, descripcion FROM area ORDER BY nombre_area');
    }

    public function lugares(): array
    {
        return $this->todos(
            "SELECT id_location, CONCAT_WS(', ', CONCAT_WS(' ', calle, num_ext), colonia) AS direccion, cp, descripcion
               FROM location
              ORDER BY colonia, calle"
        );
    }
}
