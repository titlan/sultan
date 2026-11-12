#!/bin/bash
# ADMRufu actualizado - instalador de la actualizacion (V2Ray + SSH)
# Uso en el VPS donde YA esta instalado ADMRufu:
#   1. Sube esta carpeta a /root/admrufu-actualizado/
#   2. sudo bash instalar-actualizacion.sh
# Hace backup de los archivos viejos en /root/admrufu-backup-YYYYMMDD-HHMM/
# y copia los nuevos a /etc/ADMRufu/install/, parcheando el menu para
# que $config apunte a /usr/local/etc/xray/config.json.
set -e
SRC="$(cd "$(dirname "$0")" && pwd)"
DST="/etc/ADMRufu/install"
MENU="/etc/ADMRufu/menu"
BACKUP="/root/admrufu-backup-$(date +%Y%m%d-%H%M)"

[[ $EUID -eq 0 ]] || { echo "Ejecuta como root"; exit 1; }
[[ -d "$DST" ]] || { echo "No existe $DST. Instala ADMRufu primero."; exit 1; }

mkdir -p "$BACKUP"
for f in v2ray.sh userV2ray.sh userSSH dropbear.sh ssl.sh; do
  [[ -e "$DST/$f" ]] && cp -a "$DST/$f" "$BACKUP/$f"
done
[[ -e "$MENU" ]] && cp -a "$MENU" "$BACKUP/menu"
echo "Backup en $BACKUP"

cp -a "$SRC/install/v2ray.sh" "$DST/v2ray.sh"
cp -a "$SRC/install/userV2ray.sh" "$DST/userV2ray.sh"
cp -a "$SRC/install/userSSH" "$DST/userSSH"
cp -a "$SRC/install/dropbear.sh" "$DST/dropbear.sh"
cp -a "$SRC/install/ssl.sh" "$DST/ssl.sh"
chmod +x "$DST/v2ray.sh" "$DST/userV2ray.sh" "$DST/userSSH" "$DST/dropbear.sh" "$DST/ssl.sh"

# Parchear el menu: config viejo /etc/v2ray/config.json -> Xray nuevo
if [[ -e "$MENU" ]] && grep -q '/etc/v2ray/config.json' "$MENU"; then
  sed -i 's|/etc/v2ray/config.json|/usr/local/etc/xray/config.json|g; s|/etc/v2ray/temp.json|/usr/local/etc/xray/temp.json|g' "$MENU"
  echo "Menu parcheado: config ahora es /usr/local/etc/xray/config.json"
else
  echo "Menu sin la ruta vieja, no se parcheo nada."
fi

for f in v2ray.sh userV2ray.sh userSSH dropbear.sh ssl.sh; do
  bash -n "$DST/$f" && echo "OK $f"
done

echo
echo "Listo. Ahora en el menu de ADMRufu:"
echo "  1. Instala Xray desde el menu V2Ray (opcion INSTALL)"
echo "  2. Crea usuarios V2Ray como antes, el link vmess sale igual"
echo "  3. SSH sigue igual, con contrasena SHA512 y systemctl"
echo "Si algo falla, restaura con: cp -a $BACKUP/* $DST/"
