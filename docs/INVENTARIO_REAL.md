# Inventario real

Fecha: 2026-11-19 (America/Tijuana). Fuente: comandos ejecutados desde `desktop-smecf2n`. Los valores no observados se marcan como bloqueados; no se infieren.

## Red privada observada

| MagicDNS | Tailscale IPv4 | SO anunciado | Estado observado | Rol por confirmar |
|---|---:|---|---|---|
| `desktop-smecf2n` | `100.89.172.17` | Windows | activo | Windows fijo confirmado |
| `desktop-0ddrldi` | `100.86.5.50` | Windows | activo, ping directo ~1 ms | laptop confirmada |
| `lvltechmx` | `100.94.145.63` | Ubuntu 24.04.4 | activo; SSH autorizado | VPS |
| `ubuntu-hp` | `100.112.196.81` | Ubuntu 26.04.1 | activo; SSH autorizado | HP Ubuntu |

También aparecieron un Android y un iPhone desconectados; quedan fuera de alcance.

## Equipo local `desktop-smecf2n`

- Windows 11 Pro 10.0.26300, x64.
- AMD64 Family 25 Model 80, ~3.9 GHz. El número de núcleos no se obtuvo con suficiente fiabilidad.
- RAM física total: 28,566 MB; disponible durante el inventario: 10,568 MB.
- Discos: C: 355.6 GB libres; D: 209.6 GB; E: 664.2 GB; F: 1.798 TB.
- Tailscale: `100.89.172.17`.
- Herramientas encontradas en PATH: Python, Node y Bash.
- Instalado: MariaDB 11.4.3 y MongoDB 8.0.23; ambos servicios automáticos.
- Escuchas verificadas exclusivamente en `127.0.0.1` y `100.89.172.17` para 3306/27017.

## Acceso remoto comprobado

| Equipo | Tailscale | SSH/WinRM | Bases de datos | Resultado |
|---|---|---|---|---|
| `desktop-0ddrldi` | APROBADO | administración remota cerrada; instalación local ejecutada | MongoDB 8.0.23 SECONDARY prioridad 0 | APROBADO |
| `lvltechmx` | APROBADO | SSH `root` autorizado | MongoDB 8.0.38 activo en 27017 Tailscale | APROBADO |
| `ubuntu-hp` | APROBADO | SSH `fredy` y sudo temporal | MariaDB 11.8.6 activo en 3306 Tailscale | APROBADO |

El acceso inicial falló con el usuario supuesto; después se localizaron identidades existentes autorizadas. Tailscale conectado no equivale por sí mismo a acceso administrativo.

## Recursos Ubuntu verificados

- VPS: 2 CPU, 3.8 GiB RAM, 6 GiB swap, 27 GB libres en `/`; Docker/RustDesk existentes preservados.
- HP: 4 CPU, 3.3 GiB RAM, ~1.5 GiB disponible después de MariaDB; NVMe con 127 GB libres y HDD `/srv/storage` con 633 GB libres.
- Los runners `tec-2022-transportesjulian` y `tec-2022-municipalos` permanecieron `active` antes y después de instalar MariaDB. También existen otros runners no modificados.

## Bloqueos y siguiente acción segura

1. Cambiar la contraseña débil de `fredy`, expuesta durante la sesión. El sudo temporal ya fue retirado.
2. Entregar credenciales de aplicación mediante canal seguro y ejecutar el verificador backend desde el entorno del equipo.
3. Implementar y comprobar una copia cifrada fuera del HP.

