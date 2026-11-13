# ADMRufu actualizado — titlan/sultan

ADMRufu original (2022-04-11, @Rufu99) + archivos actualizados por Muse para David.

## Instalador completo desde cero (maquina limpia)

```bash
curl -fsSL https://raw.githubusercontent.com/titlan/sultan/main/install.sh | sudo bash
```

O:

```bash
wget -qO install.sh https://raw.githubusercontent.com/titlan/sultan/main/install.sh
sudo bash install.sh
```

El `install.sh`:
1. Instala dependencias (curl, wget, xz-utils, jq, lsof, screen, figlet, lolcat, nodejs, uuid-runtime).
2. Descarga el ADMRufu original desde `NetVPS/Multi-Script` (`R9/ADMRufu.tar.xz`, sha256 verificado) y lo extrae en `/etc/ADMRufu`.
3. Encima pone los archivos actualizados de este repo y parchea el menu para Xray.
4. Crea los comandos `menu`, `adm` y `ADMRufu`.

Despues: escribe `menu` y ve a `3 PREPARACION DEL SISTEMA -> 4 V2RAY` para instalar Xray.

> El binario `install/dns-server` (ELF Go, SlowDNS) viene en el tar original de NetVPS, no se sube a este repo porque GitHub no acepta binarios en push-files. Si NetVPS borra ese tar, el instalador fallara en el paso 2.

## Actualizar un ADMRufu ya instalado

```bash
sudo bash instalar-actualizacion.sh
```

Hace backup en `/root/admrufu-backup-YYYYMMDD-HHMM/` y copia los archivos nuevos a `/etc/ADMRufu/install/` y `/etc/ADMRufu/menu_inst.sh`.

## Que se actualizo

| Archivo | Cambio |
|---|---|
| `install/v2ray.sh` | Xray-core oficial (XTLS/Xray-install). El original bajaba de rudi9999/ADMRufu, que hoy es 404, y de multi.netlify.app. Config `/usr/local/etc/xray/config.json`, VMess+WS en 8443. |
| `install/userV2ray.sh` | Fecha `%Y-%m-%d` (antes `%y-%m-%d` rompia el calculo de dias), conteo de clientes arreglado, alterId 0. |
| `install/userSSH`, `install/dropbear.sh`, `install/ssl.sh` | Siempre SHA512, systemctl con fallback a service. |
| `install/WS-Proxy.js` | Reescrito para Node 18/20/22: variables declaradas, puertos con parseInt, manejo de errores, timeout 5 min, log con fecha. Misma conducta: responde HTTP 101 y reenvia al destino. Probado: banner 101 + eco reenviado. |
| `install/ws-cdn.sh` | Deteccion de Node arreglada, instala nodejs si falta, `systemctl daemon-reload`, verifica que el servicio quedo active, corrige el bug de `stop_ws()`. Ahora puede redirigir a SSH 22, Dropbear o Xray 8443. |
| `menu_inst.sh` | `[5] OVER WEBSOCKET` ahora lee su estado del servicio `nodews.*` con systemctl. Antes lo leia del nombre del proceso node y casi siempre quedaba en [OFF]. |

Uso del WebSocket: menu principal -> `3 PREPARACION DEL SISTEMA` -> `[5] OVER WEBSOCKET` -> `1 INICIAR/AGREGAR PROXY WS CDN`.

## Que NO se actualizo

- `install/cert.sh` — generador de dominio/certificado SSL, obsoleto: la comparacion de IP usa `bc` (no viene instalado), el cert externo tiene un bug (falta `nano` para la clave), ZeroSSL ya pide EAB, y el generador de sub-dominios depende de una API key de Cloudflare del autor.
- SlowDNS (`dns-server`, binario de 2022) y los proxies SOCKS en Python (`PDirect.py` etc., Python 2).
- El menu principal (`menu`) solo se parchea en la ruta de config de V2Ray; el resto queda original, incluida su API key de Cloudflare.
