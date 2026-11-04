# Prototipo Durus

`model.py` demuestra objetos persistentes, encapsulamiento, una relación por alcanzabilidad (`root -> profiles -> events`) y una transacción local con `commit()`. `EmotionEvent` y `UserProfile` heredan de `Persistent`; se pueden agregar subclases para demostrar polimorfismo sin alterar el almacenamiento relacional.

Durus no implementa ODL ni OQL como estándares nativos. El esquema se expresa en clases Python y las consultas se realizan navegando/filtrando objetos; cualquier ejemplo “OQL” en la documentación es solo una equivalencia conceptual.

El prototipo se ejecutó correctamente con Python 3.10 y Durus instalado dentro de un contenedor desechable; confirmó persistencia, `commit()`, lectura del evento y cierre del `FileStorage` sin excepción. Para la demostración formal, cree un entorno virtual aislado, fije una versión aprobada por el docente y use solo datos sintéticos. El archivo `*.durus` generado no debe confirmarse en Git.

