# Respaldo y recuperación

MariaDB se respalda con `mariadb-backup` o `mariadb-dump --single-transaction` según disponibilidad. MongoDB se respalda desde un secundario con `mongodump --archive --gzip --oplog`. Los scripts usan retención configurable y fallan ante errores.

En el HP, el destino previsto es `/srv/storage/moodsitto/backups/`. Debe existir además una copia cifrada fuera del HP; la clave no se guarda junto al respaldo. Una réplica no es un respaldo.

Toda restauración se realiza primero en puerto/directorio aislado, valida conteos y consultas, documenta hash/tamaño/fecha y elimina solo datos sintéticos autorizados. No se restaura encima de producción sin ventana, respaldo previo y aprobación.

