USE moodsitto;
INSERT INTO estado (estado,descripcion) VALUES
  ('pendiente','Recordatorio por atender'),
  ('completado','Recordatorio realizado')
ON DUPLICATE KEY UPDATE descripcion=VALUES(descripcion);
