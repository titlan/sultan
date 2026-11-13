#!/bin/bash
# ADMRufu COMPLETO desde cero - instalador para titlan/sultan
# Uso en una maquina LIMPIA (Ubuntu 20.04/22.04/24.04, como root):
#   curl -fsSL https://raw.githubusercontent.com/titlan/sultan/main/install.sh | sudo bash
#   o: wget -qO install.sh https://raw.githubusercontent.com/titlan/sultan/main/install.sh && sudo bash install.sh
#
# Que hace:
#  1. Instala dependencias (curl, wget, xz-utils, jq, lsof, screen, figlet, lolcat, nodejs, uuid-runtime)
#  2. Descarga el ADMRufu original 2022-04-11 desde NetVPS/Multi-Script (R9/ADMRufu.tar.xz)
#     y verifica su sha256. Ese tar trae el binario install/dns-server (ELF Go, SlowDNS),
#     que NO se sube a este repo porque GitHub no acepta binarios en push-files.
#  3. Extrae en /etc/ADMRufu y crea los comandos menu / adm / ADMRufu.
#  4. Encima pone los archivos ACTUALIZADOS de este repo (titlan/sultan):
#     V2Ray con Xray-core oficial, SSH SHA512/systemctl, proxy WebSocket con Node 18/20/22
#     y menu_inst.sh con el estado de OVER WEBSOCKET leido del servicio nodews.*
#  5. Parchea el menu para que la config de V2Ray sea /usr/local/etc/xray/config.json
#     (la original /etc/v2ray/config.json ya no existe con Xray oficial).
#
# Despues de instalar, escribe `menu` y:
#   3 PREPARACION DEL SISTEMA -> 4 V2RAY (instalar Xray) -> 2 ADMINISTRAR CUENTAS (V2ray)
#   3 PREPARACION DEL SISTEMA -> 5 OVER WEBSOCKET (proxy WS con Node)
#   1 ADMINISTRAR CUENTAS (SSH/DROPBEAR)
# No instala V2Ray, SSH ni WebSocket por si solo: eso se hace desde el menu, como en el original.
set -e

ADM_TAR_URL="https://raw.githubusercontent.com/NetVPS/Multi-Script/main/R9/ADMRufu.tar.xz"
ADM_TAR_SHA256="a5f16791f6ebb9babc54578783698ae6828afb8e64b2b5f6492c83b61a1e3343"
SULTAN_RAW="https://raw.githubusercontent.com/titlan/sultan/main"
ADMRUFU_DIR="/etc/ADMRufu"

[[ $EUID -eq 0 ]] || { echo "Ejecuta como root (sudo bash install.sh)"; exit 1; }

echo "=== ADMRufu completo (original + actualizado) - titlan/sultan ==="
echo
echo -ne "Digite su slogan (nombre que se vera en el menu): " && read -r slogan
[[ -z "$slogan" ]] && slogan="Muse IA"
echo "Slogan: $slogan"
echo

if [[ -d "$ADMRUFU_DIR" ]]; then
  BACKUP="/root/admrufu-backup-$(date +%Y%m%d-%H%M)"
  echo "Ya existe $ADMRUFU_DIR, lo guardo en $BACKUP"
  mkdir -p "$BACKUP"
  cp -a "$ADMRUFU_DIR" "$BACKUP/ADMRufu"
fi

echo "--- Zona horaria: America/Mexico_City ---"
timedatectl set-timezone America/Mexico_City 2>/dev/null || ln -sf /usr/share/zoneinfo/America/Mexico_City /etc/localtime
echo "Fecha/hora ahora: $(date '+%d/%m/%Y %H:%M:%S %Z')"

echo "--- SSH: activar login con contrasena (AWS/Lightsail lo trae en no) ---"
# Las imagenes Ubuntu de AWS/Lightsail traen PasswordAuthentication no en
# /etc/ssh/sshd_config.d/60-cloudimg-settings.conf, y en sshd_config gana el
# PRIMER valor, asi que un archivo 60/99 con 'yes' despues no sirve: hay que
# editar el archivo que gana. Sin esto, los usuarios SSH del menu no pueden
# entrar con contrasena (ni HTTP Injector/Custom) aunque la contrasena este bien.
if [[ -f /etc/ssh/sshd_config.d/60-cloudimg-settings.conf ]]; then
  sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config.d/60-cloudimg-settings.conf
fi
sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config 2>/dev/null || true
# Por si no existe ninguna linea, dejar una que cargue primero.
echo "PasswordAuthentication yes" > /etc/ssh/sshd_config.d/00-password-auth.conf
systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null || true
sshd -T 2>/dev/null | grep -i passwordauthentication || echo "No se pudo verificar sshd -T"

echo "--- Instalando dependencias ---"
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y software-properties-common
add-apt-repository -y universe 2>/dev/null || true
apt-get update -y
apt-get install -y curl wget xz-utils jq lsof screen figlet nodejs python3 uuid-runtime openssl socat netcat-openbsd iproute2
# lolcat: en Ubuntu 22.04 el paquete a veces no esta, y el menu fallaba
# con 'lolcat: command not found'. Probar apt, luego gem, luego un shim.
if ! apt-get install -y lolcat 2>/dev/null; then
  if apt-get install -y ruby 2>/dev/null && gem install lolcat 2>/dev/null; then
    echo "lolcat instalado con gem."
  else
    printf '#!/bin/sh\nexec cat\n' > /usr/local/bin/lolcat
    chmod +x /usr/local/bin/lolcat
    echo "lolcat no disponible, se puso un shim que solo imprime sin colores."
  fi
fi
command -v lolcat >/dev/null && echo "lolcat: $(command -v lolcat)" || echo "lolcat: no disponible (el menu ya no lo necesita)"
command -v figlet >/dev/null || apt-get install -y figlet

echo "--- Descargando ADMRufu original (NetVPS, 2022-04-11) ---"
cd /tmp
rm -f ADMRufu.tar.xz
wget -q "$ADM_TAR_URL" -O ADMRufu.tar.xz
echo "$ADM_TAR_SHA256  ADMRufu.tar.xz" | sha256sum -c -
mkdir -p /etc
tar -xf ADMRufu.tar.xz -C /etc
rm -f ADMRufu.tar.xz
chmod -R 755 "$ADMRUFU_DIR"
# El tar trae /tmp/MEUIPADM con la IP vieja del autor (149.28.255.220).
# Si no se borra, el menu muestra esa IP siempre. Borrarlo.
rm -f "$ADMRUFU_DIR/tmp/MEUIPADM"
echo "ADMRufu original en $ADMRUFU_DIR, version: $(cat $ADMRUFU_DIR/vercion 2>/dev/null || echo '?')"

echo "--- Aplicando archivos actualizados de titlan/sultan ---"
# 7 archivos actualizados + menu_inst.sh, todos de este mismo repo
for f in install/v2ray.sh install/userV2ray.sh install/userSSH install/dropbear.sh install/ssl.sh install/ws-cdn.sh install/WS-Proxy.js menu_inst.sh menu; do
  echo "  $f"
  wget -q "$SULTAN_RAW/$f" -O "$ADMRUFU_DIR/$f"
done
chmod +x "$ADMRUFU_DIR/menu"
chmod +x "$ADMRUFU_DIR/install/v2ray.sh" "$ADMRUFU_DIR/install/userV2ray.sh" "$ADMRUFU_DIR/install/userSSH" "$ADMRUFU_DIR/install/dropbear.sh" "$ADMRUFU_DIR/install/ssl.sh" "$ADMRUFU_DIR/install/ws-cdn.sh" "$ADMRUFU_DIR/menu_inst.sh"
# dns-server binario: viene en el tar original, dejarlo ejecutable
chmod +x "$ADMRUFU_DIR/install/dns-server" 2>/dev/null || true

echo "--- Parcheando menu: config V2Ray -> Xray oficial ---"
if grep -q '/etc/v2ray/config.json' "$ADMRUFU_DIR/menu"; then
  sed -i 's|/etc/v2ray/config.json|/usr/local/etc/xray/config.json|g; s|/etc/v2ray/temp.json|/usr/local/etc/xray/temp.json|g' "$ADMRUFU_DIR/menu"
  echo "Menu parcheado."
fi

echo "--- Verificando archivos actualizados ---"
for f in install/v2ray.sh install/userV2ray.sh install/userSSH install/dropbear.sh install/ssl.sh install/ws-cdn.sh menu_inst.sh menu; do
  bash -n "$ADMRUFU_DIR/$f" && echo "OK $f"
done
node --check "$ADMRUFU_DIR/install/WS-Proxy.js" && echo "OK install/WS-Proxy.js"

echo "--- Creando comandos menu / adm / ADMRufu ---"
rm -f /usr/bin/menu /usr/bin/adm /usr/bin/ADMRufu
echo "$slogan" > "$ADMRUFU_DIR/tmp/message.txt"
echo "${ADMRUFU_DIR}/menu" > /usr/bin/menu && chmod +x /usr/bin/menu
echo "${ADMRUFU_DIR}/menu" > /usr/bin/adm && chmod +x /usr/bin/adm
echo "${ADMRUFU_DIR}/menu" > /usr/bin/ADMRufu && chmod +x /usr/bin/ADMRufu
[[ -z $(echo $PATH | grep "/usr/games") ]] && echo 'if [[ $(echo $PATH|grep "/usr/games") = "" ]]; then PATH=$PATH:/usr/games; fi' >>/etc/bash.bashrc
grep -q 'chekup.sh' /etc/bash.bashrc 2>/dev/null || echo '[[ $UID = 0 ]] && screen -dmS up /etc/ADMRufu/chekup.sh' >>/etc/bash.bashrc

echo
echo "=== Listo ==="
echo "Escribe:  menu"
echo
echo "Para empezar, en el menu:"
echo "  3 PREPARACION DEL SISTEMA -> 4 V2RAY  (instala Xray-core oficial)"
echo "  2 ADMINISTRAR CUENTAS (V2ray)         (crea usuarios VMess)"
echo "  3 PREPARACION DEL SISTEMA -> 5 OVER WEBSOCKET  (proxy WS con Node)"
echo "  1 ADMINISTRAR CUENTAS (SSH/DROPBEAR)  (usuarios SSH, SHA512)"
echo
echo "Actualizado en este instalador vs el original 2022:"
echo "  - V2Ray: Xray-core oficial (el original bajaba de rudi9999, que ya es 404)"
echo "  - SSH: siempre SHA512, systemctl en vez de service"
echo "  - WebSocket: WS-Proxy.js para Node 18/20/22, estado [ON]/[OFF] real en el menu"
echo "  - No actualizado: cert.sh (generador SSL, obsoleto), SlowDNS, SOCKS Python (Python 2)"
