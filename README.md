# sultan — XHTTP Installer en español

Instalador automático de **VLESS + XHTTP + TLS** en Ubuntu, con relay
gratuito en Vercel o Netlify. Mensajes y preguntas traducidos al español.

## Créditos — léelo primero

Este trabajo **no es original mío**. Es una copia/traducción del proyecto:

- **Proyecto original:** XHTTP-Installer
- **Autor / creador:** **@avaco_cloud**
- **Copyright:** Copyright (C) 2025 avaco_cloud
- **Repo original:** https://github.com/avacocloud/XHTTP-Installer
- **Telegram del autor:** https://t.me/avaco_cloud
- **Licencia:** GNU General Public License v3.0 (GPL-3.0) — ver `LICENSE`
- **Aviso de atribución:** ver `NOTICE` (sin cambios)

La redistribución exige conservar el aviso de copyright, el enlace al
repo original, la referencia al autor y el archivo `NOTICE` sin cambios.
Quitar o reemplazar la atribución es una violación de la licencia.

Lo único que cambió aquí es:
- los mensajes y preguntas del instalador, traducidos al español,
- las URLs del repo, que ahora apuntan a esta copia (`titlan/sultan`),
- y un menú extra, `xhttp-menu.sh` (ver abajo).

El código, la licencia y los créditos originales están intactos.

## Instalación

En un VPS Ubuntu 20.04+ como root, con dominio apuntando al VPS
y los puertos 80 y 443 libres:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/titlan/sultan/main/install.sh)
```

O directo:

```bash
git clone https://github.com/titlan/sultan.git
cd sultan
sudo bash Deploy-Ubuntu.sh
```

El instalador pide: plataforma de relay (Vercel o Netlify), dominio,
correo (para Let's Encrypt), puerto Xray (443 por defecto), path del
relay (`/api` por defecto) y token de la plataforma. Al final genera
un link `vless://...` con `type=xhttp`.

## Menú extra: `xhttp-menu.sh`

Menú en español, agregado en esta copia, para después de instalar:

```bash
sudo cp xhttp-menu.sh /usr/local/sbin/xhttp-menu
sudo chmod +x /usr/local/sbin/xhttp-menu
sudo xhttp-menu
```

Opciones:
1. Crear usuario VLESS (genera UUID)
2. Eliminar usuario
3. Listar usuarios
4. Generar solo UUID
5. Configurar relay / path / SNI
6. Ver estado de Xray
7. Instalar Stunnel4 + Certbot (443, sin chocar con Xray) — usa HAProxy
   en 443 y rutas por SNI: XHTTP a Xray en 127.0.0.1:8443, SSH a
   Stunnel4 en 127.0.0.1:8444 → SSH 22. Necesita dos subdominios.
8. Ver estado de Xray / HAProxy / Stunnel4

## Archivos

- `Deploy-Ubuntu.sh` — instalador principal, traducido al español
- `install.sh` — bootstrap: clona este repo y lanza el instalador
- `deploy/vercel/` y `deploy/netlify/` — relay (código del proyecto original)
- `xhttp-menu.sh` — menú extra en español
- `LICENSE` — GPL-3.0, del proyecto original, sin cambios
- `NOTICE` — atribución al autor, sin cambios
- `README_FA.md` — README original en persa
- `README_EN.md` — README original en inglés
- `PANEL_FEATURES.md` — estado del panel web (en desarrollo, del original)
- `SECURITY.md` — del proyecto original

No se incluyeron las plantillas de landing con imágenes ni el panel
completo, que están en el repo original. El relay y el instalador sí
están completos aquí.

## Requisitos

- Ubuntu 20.04+, root
- Dominio con registro A apuntando al VPS
- Puertos 80 y 443 libres
- Token de Vercel o de Netlify
