# Sultan — V2Ray VLESS + Stunnel4/SSH

## Créditos (léelo primero)

Este trabajo **no es original mío**.

- **Instalador V2Ray VLESS:** proyecto **V2Ray VLESS Server Manager**, autor **Humran13**, Copyright (c) 2026 Humran13, licencia **MIT**.
  - Repo original: https://github.com/Humran13/V2Ray-VLESS-Server
  - Licencia MIT original en `LICENSE`, sin cambios.
- **Menú `sultan-menu.sh`:** escrito por Muse para este repo, en español. Usa el manager `vless` del proyecto original para los usuarios V2Ray, y añade Stunnel4 + usuarios SSH.
- **Núcleo:** Xray-core oficial (XTLS/Xray-core), que descarga el instalador con verificación de checksum.

Lo único que cambió respecto al original:
- Las URLs del instalador y del actualizador apuntan a **este repo** (`titlan/sultan`) en vez de a `Humran13/V2Ray-VLESS-Server`.
- Se añadió `sultan-menu.sh` (menú en español, Stunnel4 + SSH).
- Este README está en español.

## Qué instala

VLESS sobre Xray-core, con 11 perfiles: REALITY, TLS + XHTTP / WebSocket / gRPC / HTTPUpgrade / mKCP / Hysteria, etc.

Para VLESS + WebSocket, elige el **perfil 5: TLS + WebSocket**. Necesita dominio.

## Instalación (Ubuntu 18.04–26.04, como root)

```bash
curl -fsSL https://raw.githubusercontent.com/titlan/sultan/main/install.sh | sudo bash
```

El instalador te pregunta el perfil, el puerto y, si es TLS, el dominio. Al final te da el link `vless://` del primer usuario.

Después, el manager es:

```bash
sudo vless
```

Ahí ya puedes crear usuarios V2Ray, ver links y QR, etc.

## Menú en español: V2Ray + SSH/Stunnel4

```bash
sudo cp sultan-menu.sh /usr/local/sbin/sultan-menu
sudo chmod +x /usr/local/sbin/sultan-menu
sudo sultan-menu
```

Opciones:

| # | Qué hace |
|---|---|
| 1 | Crear usuario V2Ray |
| 2 | Eliminar usuario V2Ray |
| 3 | Listar usuarios V2Ray |
| 4 | Mostrar link VLESS de un usuario |
| 5 | Crear usuario SSH (para Stunnel4) |
| 6 | Eliminar usuario SSH |
| 7 | Listar usuarios SSH |
| 8 | Instalar Stunnel4 en el 443 con HAProxy (2 dominios) |
| 9 | Ver estado (V2Ray / Stunnel4 / HAProxy / puertos) |

## Stunnel4 en el puerto 443, con 2 dominios

La opción 8 del menú hace esto, porque V2Ray y Stunnel no pueden escuchar los dos en el 443:

- Te pide **2 dominios**, los dos con registro A a la IP de tu VPS:
  - **Dominio V2Ray**, ej. `vpn-midominio.duckdns.org`
  - **Dominio SSH**, ej. `ssh-midominio.duckdns.org`
- Mueve los perfiles V2Ray a interno **8443** (en `state.json`, y luego `vless repair` regenera la config).
- Instala **HAProxy** en el **443**, que reparte por SNI:
  - SNI = dominio V2Ray → V2Ray en `127.0.0.1:8443`
  - SNI = dominio SSH → Stunnel4 en `127.0.0.1:8444` → SSH en `127.0.0.1:22`
- Instala **Stunnel4**, con certificado Let's Encrypt para el dominio SSH (o reutiliza uno que ya exista).
- Deja un hook de renovación del certificado que reinicia Stunnel4 y HAProxy.

Después de instalarlo, crea el usuario SSH con la opción 5 del menú.

**En ANUBIS:**
- VLESS: dominio V2Ray, puerto **443**, SNI = dominio V2Ray. Ojo: el link `vless://` que muestra el manager dirá puerto 8443, porque ese es el puerto interno; en ANUBIS pon **443** a mano.
- SSH + SSL/TLS: host = dominio SSH, puerto **443**, usuario y contraseña SSH, SNI = dominio SSH, SSL/TLS activado.

## Archivos

- `install.sh` — instalador (original Humran13, con URLs a este repo)
- `bin/vless` — manager V2Ray (original)
- `lib/` — módulos del manager (original)
- `sultan-menu.sh` — menú en español V2Ray + SSH/Stunnel4 (nuevo)
- `LICENSE` — MIT, Humran13
- `VERSION`, `CHANGELOG.md` — del proyecto original

## Requisitos

- Ubuntu 18.04+, root, puertos 80 y 443 libres al instalar
- Dominio apuntando al VPS (para perfiles TLS y para Stunnel4)
- Si no tienes dominio, elige un perfil REALITY en el instalador
