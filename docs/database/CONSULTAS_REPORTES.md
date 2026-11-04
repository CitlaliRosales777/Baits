# Consultas de reportes emocionales

La implementación está en `databases/mariadb/queries/emotional_reports.sql`. Todas las consultas reciben `id_user`, `fecha_inicio` y `fecha_fin` como parámetros enlazados. Backend obtiene `id_user` de la sesión autorizada; nunca debe aceptar que un usuario consulte el identificador de otra cuenta.

## Salidas

| Consulta | Columnas principales | Significado |
|---|---|---|
| Total | `total_registros` | Cantidad de seguimientos del periodo. Devuelve `0` sin datos. |
| Frecuencias | `emocion`, `frecuencia_absoluta`, `frecuencia_relativa`, `porcentaje` | Distribución por emoción específica. |
| Intensidad | `intensidad_promedio` | Media de `intensidad.valor`; devuelve `NULL` sin registros. |
| Más frecuente | `emocion`, `frecuencia` | Primera emoción por frecuencia; empate alfabético. Sin datos no devuelve fila. |
| Categorías | `categoria`, `total`, `porcentaje` | Distribución por emoción central. |
| Evolución diaria | `periodo`, `total`, `intensidad_promedio` | Un punto por día con registros. |
| Evolución semanal | `periodo_iso`, fechas, total, promedio | Agrupación ISO, lunes como inicio. |
| Evolución mensual | `periodo`, `total`, `intensidad_promedio` | Agrupación `AAAA-MM`. |
| Tendencia | fecha, hora, emoción, categoría, intensidad, contexto | Serie cronológica para gráficas o PDF. |
| Comparación | `periodo`, `total`, `intensidad_promedio` | Resumen descriptivo de periodos A y B. |

## Reglas estadísticas

- Solo se promedia `intensidad.valor`, nunca identificadores ni categorías nominales.
- `NULLIF` evita divisiones entre cero.
- Un día sin registros no se inventa: Backend puede completar el calendario con cero al preparar una gráfica.
- Los porcentajes se calculan sobre los registros autorizados del periodo solicitado.
- Los registros incompletos no existen en el modelo nuevo porque usuario, emoción e intensidad son obligatorios. Una base heredada debe pasar el preflight antes de migrarse.
- Los resultados son descriptivos y no constituyen diagnóstico ni interpretación clínica.
- Backend debe validar `fecha_inicio <= fecha_fin`, zona horaria y límites razonables del periodo.

## Filtros y uso

Para historial y filtros individuales se usa `emotional_tracking.sql`: periodo, emoción específica, rango de intensidad y últimos registros. Los archivos contienen `?` deliberadamente; no deben reemplazarse concatenando texto recibido del cliente.
