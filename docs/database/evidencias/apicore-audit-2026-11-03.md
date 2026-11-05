# Evidencia de revisión estática de APIcore

Repositorio: `https://github.com/xtbt/apicore`
Rama: `main`
Commit: `923fbe5358ec72882af54bef9e567d0dda5b6374`
Fecha del commit: 30 de octubre de 2026, 18:03:36 -07:00
Fecha de revisión: 3 de noviembre de 2026

## Archivos de aplicación revisados

- Python: `main.py`, `core/Database.py`, `models/BaseModel.py`, `models/Mood.py`.
- PHP: `index.php`, `config/headers.php`, `core/Database.php` y cuatro modelos CRUD.
- README, lista de archivos versionados y plantillas en `temp/`.

## Resultados comprobables

- Rutas Python: healthcheck y CRUD de `/moods`.
- Rutas PHP: healthcheck (con otra grafía) y CRUD de `/moods`.
- Base configurada: `apitest`; tabla esperada: `moods`; campos: `MoodId`, `MoodName`, `MoodStatus`.
- No se encontraron contratos Moodsitto para usuarios, autenticación, jerarquía emocional, seguimiento, medicamentos, citas, recordatorios o diagnósticos.
- Las dos conexiones contienen usuario/contraseña administrativos hardcodeados.
- No se encontró autenticación/autorización.
- PHP configura CORS `*` y devuelve el cuerpo de solicitudes en respuestas debug; Python devuelve texto de excepciones.
- El repositorio versiona 1,335 archivos bajo `venv/` y 642 artefactos `__pycache__`/`.pyc` (las categorías se solapan).
- Existe un `.env` versionado, pero estaba vacío en el commit revisado; no se imprimieron ni almacenaron valores secretos.

La revisión fue de solo lectura sobre un clon temporal. No se alteró ni ejecutó el repositorio APIcore contra la base Moodsitto.
