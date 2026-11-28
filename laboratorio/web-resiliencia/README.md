# Moodsitto Resilience Lab

Panel didáctico para presentar un replica set de MongoDB, ejecutar CRUD con `writeConcern: majority` y demostrar tolerancia a fallos con recuperación automática.

## Inicio

Copia `.env.example` como `.env`, configura las credenciales del replica set y después ejecuta:

```powershell
npm install
npm start
```

Abre `http://localhost:4173`. La aplicación no genera estados ni datos ficticios: si un nodo, agente o MongoDB no responde, se muestra como no disponible.

## Qué demuestra

- Caída de un secundario sin perder disponibilidad.
- Elección de un nuevo primario después de un fallo.
- Reintento de una escritura durante el failover.
- Bloqueo seguro de escrituras al perder quorum.
- Recuperación y resincronización del nodo.
- CRUD real con confirmación por mayoría.
- Conectividad privada independiente de la red local.

## Cambio automático de red

La solución no utiliza direcciones de Wi-Fi como `192.168.x.x`. Utiliza Tailscale:

1. Cada equipo conserva una IP `100.x.x.x` estable.
2. MagicDNS permite usar `lvltechmx`, `desktop-smecf2n` y `desktop-0ddrldi`.
3. Tailscale y MongoDB se configuran con inicio automático.
4. Windows activa el modo desatendido para conservar Tailscale incluso sin una sesión iniciada.
5. El agente se reinicia automáticamente después de un reinicio o cambio de red.
6. El driver de MongoDB recibe los tres nombres y descubre el primario disponible.

Después de cambiar de Wi-Fi o usar un hotspot, Tailscale reconstruye el túnel. No es necesario modificar la web ni la cadena de conexión.

Para comprobarlo en Windows:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\verify-mobility.ps1
```

## Activar el modo real

### 1. Configurar variables

Copia `.env.example` como `.env`, crea un usuario MongoDB exclusivo para el laboratorio y completa `MONGO_URI`. Usa un token aleatorio largo y el mismo token en los tres agentes.

Mantén inicialmente:

```dotenv
ALLOW_LIVE_CHAOS=false
ALLOW_QUORUM_TESTS=false
```

Esto permite validar topología y CRUD sin autorizar apagados.

### 2. Preparar nodos Windows

En cada nodo Windows, abre PowerShell como administrador desde la raíz del proyecto:

```powershell
.\scripts\configure-node-windows.ps1 -AgentToken "TOKEN-LARGO-COMPARTIDO"
```

El script configura:

- Tailscale y MongoDB con inicio automático.
- Modo desatendido de Tailscale para seguir conectado tras cerrar sesión o reiniciar.
- Una tarea elevada para el agente del laboratorio.
- Reinicio del agente si falla.
- Firewall del puerto `4318` limitado al rango de Tailscale.

Para equipos confiables que deban quedar disponibles permanentemente, revisa también la expiración de clave desde la consola administrativa de Tailscale. No la desactives en dispositivos que no controles.

### 3. Preparar el nodo Linux

Con Node.js instalado:

```bash
sudo LAB_AGENT_TOKEN="REEMPLAZA_POR_UN_TOKEN_ALEATORIO" bash scripts/configure-node-linux.sh
```

### 4. Validar antes de permitir caos

Comprueba desde el panel que:

- Los tres agentes responden.
- Existe un PRIMARY y dos SECONDARY.
- El CRUD confirma escrituras.
- Los nodos se resuelven por MagicDNS.

Después habilita una prueba real a la vez:

```dotenv
ALLOW_LIVE_CHAOS=true
```

`ALLOW_QUORUM_TESTS` debe permanecer en `false` para una exposición normal. La recuperación automática se controla con `AUTO_RECOVERY_SECONDS`.

## Seguridad

- El navegador nunca recibe credenciales de MongoDB ni el token de agentes.
- El agente solo acepta `status`, `start`, `stop` y `restart` para MongoDB.
- No existe ejecución remota de comandos arbitrarios.
- El puerto del agente se limita a Tailscale.
- Las pruebas reales están deshabilitadas por defecto.
- La pérdida real de quorum tiene un bloqueo independiente.

## Comandos

```powershell
npm run dev     # desarrollo con recarga del servidor
npm start       # servidor normal
npm test        # pruebas del orquestador
npm run agent   # agente local (requiere agent/.env)
```

## Estructura

```text
public/        interfaz de presentación
src/           API, CRUD, orquestador y cliente MongoDB
agent/         agente restringido para cada nodo
scripts/       instalación automática y prueba de movilidad
test/          pruebas del estado del laboratorio
```
