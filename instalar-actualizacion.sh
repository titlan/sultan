#!/bin/bash
# ADMRufu actualizado - instalador de la actualizacion (V2Ray + SSH + WebSocket)
# Uso en el VPS donde YA esta instalado ADMRufu:
#   1. Sube esta carpeta a /root/admrufu-actualizado/
#   2. sudo bash instalar-actualizacion.sh
# Hace backup de los archivos viejos en /root/admrufu-backup-YYYYMMDD-HHMM/
# y copia los nuevos a /etc/ADMRufu/install/ y /etc/ADMRufu/menu_inst.sh,
# parcheando el menu para que $config apunte a /usr/local/etc/xray/config.json.
set -e
SRC="$(cd "$(dirname "$0")" && pwd)"
DST="/etc/ADMRufu/install"
MENU="/etc/ADMRufu/menu"
MENU_INST="/etc/ADMRufu/menu_inst.sh"
BACKUP="/root/admrufu-backup-$(date +%Y%m%d-%H%M)"

[[ $EUID -eq 0 ]] || { echo "Ejecuta como root"; exit 1; }
[[ -d "$DST" ]] || { echo "No existe $DST. Instala ADMRufu primero."; exit 1; }

mkdir -p "$BACKUP"
for f in v2ray.sh userV2ray.sh userSSH dropbear.sh ssl.sh ws-cdn.sh WS-Proxy.js; do
  [[ -e "$DST/$f" ]] && cp -a "$DST/$f" "$BACKUP/$f"
done
[[ -e "$ADMRUFU_DIR/menu" ]] && cp -a "$ADMRUFU_DIR/menu" "$BACKUP/menu-fixed" 2>/dev/null || true
[[ -e "$MENU" ]] && cp -a "$MENU" "$BACKUP/menu"
[[ -e "$MENU_INST" ]] && cp -a "$MENU_INST" "$BACKUP/menu_inst.sh"
echo "Backup en $BACKUP"

cp -a "$SRC/install/v2ray.sh" "$DST/v2ray.sh"
cp -a "$SRC/install/userV2ray.sh" "$DST/userV2ray.sh"
cp -a "$SRC/install/userSSH" "$DST/userSSH"
cp -a "$SRC/install/dropbear.sh" "$DST/dropbear.sh"
cp -a "$SRC/install/ssl.sh" "$DST/ssl.sh"
cp -a "$SRC/install/ws-cdn.sh" "$DST/ws-cdn.sh"
cp -a "$SRC/install/WS-Proxy.js" "$DST/WS-Proxy.js"
chmod +x "$DST/v2ray.sh" "$DST/userV2ray.sh" "$DST/userSSH" "$DST/dropbear.sh" "$DST/ssl.sh" "$DST/ws-cdn.sh"
cp -a "$SRC/menu" "/etc/ADMRufu/menu"
chmod +x "/etc/ADMRufu/menu"
rm -f "/etc/ADMRufu/tmp/MEUIPADM"
cp -a "$SRC/menu_inst.sh" "$MENU_INST"
chmod +x "$MENU_INST"

# Parchear el menu: config viejo /etc/v2ray/config.json -> Xray nuevo
if [[ -e "$MENU" ]] && grep -q '/etc/v2ray/config.json' "$MENU"; then
  sed -i 's|/etc/v2ray/config.json|/usr/local/etc/xray/config.json|g; s|/etc/v2ray/temp.json|/usr/local/etc/xray/temp.json|g' "$MENU"
  echo "Menu parcheado: config ahora es /usr/local/etc/xray/config.json"
else
  echo "Menu sin la ruta vieja, no se parcheo nada."
fi

for f in v2ray.sh userV2ray.sh userSSH dropbear.sh ssl.sh ws-cdn.sh; do
  bash -n "$DST/$f" && echo "OK $f"
done
bash -n "$MENU_INST" && echo "OK menu_inst.sh"
bash -n "/etc/ADMRufu/menu" && echo "OK menu (IP/hora/lolcat arreglados)"
node --check "$DST/WS-Proxy.js" 2>/dev/null && echo "OK WS-Proxy.js" || echo "Node no disponible aqui, WS-Proxy.js se verifica en el VPS"

echo
echo "Listo. Ahora en el menu de ADMRufu:"
echo "  1. Instala Xray desde el menu V2Ray (opcion INSTALL)"
echo "  2. Crea usuarios V2Ray como antes, el link vmess sale igual"
echo "  3. SSH sigue igual, con contrasena SHA512 y systemctl"
echo "  4. WebSocket: menu principal -> 3 PREPARACION DEL SISTEMA -> [5] OVER WEBSOCKET"
echo "     Elige el puerto a redirigir (SSH/Dropbear/Xray) y el puerto WS, y"
echo "     queda el servicio nodews.<puerto> corriendo. Se ve [ON] en el menu."
echo "Si algo falla, restaura con: cp -a $BACKUP/* $DST/"
