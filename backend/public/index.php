<?php
// Punto de entrada único. Toda petición pasa por aquí (ver .htaccess).
require dirname(__DIR__) . '/src/arranque.php';

(new Aplicacion())->ejecutar();
