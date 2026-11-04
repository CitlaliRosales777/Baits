# Nodo SQL Server propuesto

`V001__clinical_node.sql` crea un nodo clínico independiente para una demostración multibase. No se ejecutó porque este entorno no dispone de una instancia SQL Server ni SSMS.

La referencia `maria_user_id` no es una FK distribuida: SQL Server solo puede validarla contra `user_reference` local. APIcore debe confirmar el usuario en MariaDB, insertar la referencia de forma idempotente y luego escribir la nota. Si falla el segundo paso, registra/reintenta o compensa; no debe afirmar atomicidad distribuida.

Prueba manual prevista:

1. Crear una base de desarrollo vacía en SQL Server.
2. Ejecutar el script con una cuenta de migración.
3. Insertar una referencia ficticia y una nota ficticia.
4. Consultar ambas tablas desde SSMS/DBeaver.
5. Detener SQL Server, verificar que APIcore mantiene disponibles los flujos exclusivos de MariaDB y devuelve un error controlado para el nodo clínico.
6. Reiniciar, reintentar una operación con la misma clave de idempotencia y comprobar que no se duplica.

