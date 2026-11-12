# ADMRufu — actualizado solo V2Ray y SSH (2026-11-12)

Actualización del ADMRufu original (versión 2022-04-11, @Rufu99,
bajado de `NetVPS/Multi-Script/main/R9/ADMRufu.tar.xz`).
**Solo se tocaron V2Ray y SSH.** El resto del panel queda igual.

## Qué estaba roto

### V2Ray — roto, no instalaba
- `ins_v2r()` hacía `source <(curl ... rudi9999/ADMRufu/main/Utils/v2ray/v2ray.sh)` —
  esa URL hoy da **404**.
- `removeV2Ray()` usaba `multi.netlify.app/go.sh` y `pip uninstall v2ray_util`
  (multi-v2ray, abandonado).
- El config era `/etc/v2ray/config.json`, ruta vieja. El V2Ray/Xray actual
  usa `/usr/local/etc/xray/config.json` y el servicio `xray`.
- `port()`, `address()`, `host()`, `path()` hacían
  `jq ... < $temp >> $config` — append, duplicaba el JSON y lo rompía.
- `newuser()` en `userV2ray.sh` usaba `$users` sin definirlo, y la fecha
  era `date '+%y-%m-%d'` (año de 2 dígitos), lo que rompía el cálculo
  de días restantes.

### SSH — funcionaba, pero con cosas viejas
- `add_user()` tenía una rama para Ubuntu 16 con `openssl passwd -1` (MD5).
- Usaba `service ssh/dropbear/stunnel4 restart` en lugar de `systemctl`.

## Qué se cambió

| Archivo | Cambio |
|---|---|
| `install/v2ray.sh` | Instala **Xray-core oficial** (XTLS/Xray-install), mismo protocolo VMess. Config `/usr/local/etc/xray/config.json`, puerto 8443, WS path `/v2ray`. `restart()` con `systemctl restart xray`. `removeV2Ray()` con desinstalador oficial. `alterId` se fija en 0 (obsoleto). `v2ray_tls()` usa cert de `/etc/ADMRufu/source/cert` si existe. |
| `install/userV2ray.sh` | Fecha `+%Y-%m-%d`. `newuser()` calcula el total de clientes antes de agregar. UUID con `uuidgen` o `/proc/sys/kernel/random/uuid`. Link vmess con los campos reales del config nuevo. |
| `install/userSSH` | Siempre `openssl passwd -6` (SHA512). `service` → `systemctl` con fallback. Fecha de creación con año de 4 dígitos. |
| `install/dropbear.sh` | `systemctl` en lugar de `service`. |
| `install/ssl.sh` | `systemctl` para stunnel4. El cert autofirmado sigue siendo solo para pruebas. |

Los archivos `.orig` son los originales de 2022, para comparar.

## Cómo instalarlo en el VPS

```bash
# Sube esta carpeta al VPS, por ejemplo a /root/admrufu-actualizado/
sudo bash instalar-actualizacion.sh
```

Hace backup en `/root/admrufu-backup-YYYYMMDD-HHMM/`, copia los 5 archivos
a `/etc/ADMRufu/install/`, y parchea `/etc/ADMRufu/menu` para que
`$config` apunte a `/usr/local/etc/xray/config.json`.

Después, en el menú de ADMRufu:
1. Instala Xray desde el menú V2Ray (opción INSTALL).
2. Crea usuarios V2Ray como antes — el link `vmess://` sale igual.
3. SSH sigue igual.

## Verificado

- `bash -n` OK en los 5 archivos actualizados.
- Lógica `jq` probada con un config de ejemplo: cambio de puerto
  8443 → 8444 y agregar un usuario en el índice correcto funcionan.

## No tocado

OpenVPN, Squid, SlowDNS, WebSocket proxy, limitador, etc. siguen
en su versión 2022. Si quieres, se actualizan aparte.
