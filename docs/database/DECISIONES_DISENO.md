# Decisiones de diseño

## Compatibilidad antes que renombrado

Se mantienen tablas y columnas del archivo original, incluidas abreviaturas, porque los formularios ya usan `name`, `lastname1`, `date_b`, `mail` y `passw`. APIcore deberá aislar esta nomenclatura mediante su capa de persistencia. Un cambio a nombres uniformes requiere versionar el contrato y una migración coordinada.

## Migración limpia y actualización heredada separadas

`V001` y `V002` construyen una instancia nueva y verificable. No se automatiza un `ALTER` sobre una base heredada porque hacer obligatorias columnas con valores nulos o agregar unicidad con duplicados puede perder datos. `P001__legacy_read_only_audit.sql` produce los hallazgos necesarios para diseñar esa actualización sobre una copia respaldada.

## Integridad y borrado

- Las relaciones clínicas y de usuario usan `RESTRICT`: no se borra un padre con historial dependiente.
- Una ubicación opcional usa `SET NULL` al borrarse.
- Al borrar una cita, su recordatorio general puede sobrevivir con `id_cita = NULL`; la eliminación de la cita sigue restringida si existe información que no permita esa transición.
- El borrado desde UI debería ser lógico para entidades clínicas. El esquema actual conserva compatibilidad y no incorpora columnas nuevas de soft delete sin contrato de APIcore.

## Identificadores y tipos

Los identificadores son `INT UNSIGNED`, suficientes para el alcance académico. Fechas de eventos usan `DATETIME`; el seguimiento conserva `DATE` + `TIME` por compatibilidad. APIcore debe definir una zona horaria de negocio y convertir entradas de forma consistente.

## Jerarquía emocional

Se conserva `emocion_conjunto` aunque sea redundante. Las FK garantizan existencia, y una terna `UNIQUE` evita duplicados, pero la pertenencia entre sus tres niveles requiere validación transaccional. Una futura versión puede reemplazarla por la emoción específica, desde la cual se reconstruye la jerarquía.

## Índices

Se priorizan las rutas esperadas de dashboard e historial: usuario/fecha, doctor/fecha, estado/fecha y emoción/fecha. No se agregan índices a cada columna por defecto; deben revisarse con `EXPLAIN` y volumen representativo.

## Credenciales y documentos

`passw` contiene exclusivamente un hash generado por APIcore con un algoritmo adaptativo. La base nunca recibe la contraseña en texto plano para persistencia. `documento` contiene una referencia opaca, no una ruta pública ni el archivo médico; el acceso se autoriza en APIcore.

## Datos de prueba

Las semillas son sintéticas y explícitamente no clínicas. Los usuarios transaccionales de prueba usan `.invalid` y todas sus operaciones se revierten con `ROLLBACK`.

