# Prototipo Durus

`model.py` demuestra objetos persistentes, encapsulamiento, una relación por alcanzabilidad (`root -> profiles -> events`) y una transacción local con `commit()`. `EmotionEvent` y `UserProfile` heredan de `Persistent`; se pueden agregar subclases para demostrar polimorfismo sin alterar el almacenamiento relacional.

Durus no implementa ODL ni OQL como estándares nativos. El esquema se expresa en clases Python y las consultas se realizan navegando/filtrando objetos; cualquier ejemplo “OQL” en la documentación es solo una equivalencia conceptual.

No se instaló ni ejecutó Durus en este entorno. Antes de la demostración, cree un entorno virtual aislado, instale una versión aprobada por el docente y ejecute el archivo solo con datos sintéticos. El archivo `*.durus` generado no debe confirmarse en Git.

