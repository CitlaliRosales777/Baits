-- Carga los estados que usa el backend al crear y completar recordatorios.
USE moodsitto;
INSERT INTO estado (estado,descripcion) VALUES
  ('pendiente','Recordatorio por atender'),
  ('completado','Recordatorio realizado')
ON DUPLICATE KEY UPDATE descripcion=VALUES(descripcion);
