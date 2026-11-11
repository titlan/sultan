#!/usr/bin/env bash
# =============================================================
#  Menú XHTTP / VLESS — para avacocloud/XHTTP-Installer
#  Basado en Xray /usr/local/etc/xray/config.json
#  Copyright original del instalador: avaco_cloud, GPL-3.0
#  Este menú es un agregado nuevo, en español.
#  Uso: sudo bash xhttp-menu.sh  (o: sudo xhttp-menu)
# =============================================================
set -u

CONFIG="/usr/local/etc/xray/config.json"
INFO_FILE="/etc/xray/xhttp-menu.info"
# INFO_FILE guarda: RELAY=dominio-del-relay (ej. tu-sitio.netlify.app)
#                   PATH=/api  (o el path que usaste)
#                   SNI=dominio-del-servidor (si es distinto)

verde() { echo -e "\033[1;32m$*\033[0m"; }
rojo()  { echo -e "\033[1;31m$*\033[0m"; }
amarillo(){ echo -e "\033[1;33m$*\033[0m"; }
cyan()  { echo -e "\033[1;36m$*\033[0m"; }

if [[ $EUID -ne 0 ]]; then
  rojo "Ejecuta como root: sudo bash xhttp-menu.sh"
  exit 1
fi

for cmd in jq uuidgen; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Instalando $cmd..."
    apt-get update -qq && apt-get install -y -qq "$cmd" >/dev/null 2>&1 || true
  fi
done

if [[ ! -f "$CONFIG" ]]; then
  rojo "No encontré $CONFIG"
  echo "Primero instala XHTTP con el instalador de avacocloud, y luego usa este menú."
  exit 1
fi

# Lee relay/path del config si no hay INFO_FILE
leer_datos() {
  RELAY=""
  RUTA=""
  SNI=""
  if [[ -f "$INFO_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$INFO_FILE"
  fi
  # Intentar deducir del config.json de Xray
  if [[ -z "${RUTA:-}" ]]; then
    RUTA=$(jq -r '.inbounds[0].streamSettings.xhttpSettings.path // "/api"' "$CONFIG" 2>/dev/null)
  fi
  if [[ -z "${SNI:-}" ]]; then
    SNI=$(jq -r '.inbounds[0].streamSettings.tlsSettings.serverName // empty' "$CONFIG" 2>/dev/null)
  fi
  if [[ -z "${RELAY:-}" ]]; then
    RELAY="${SNI:-}"
  fi
}

guardar_datos() {
  mkdir -p "$(dirname "$INFO_FILE")"
  cat > "$INFO_FILE" <<EOF
RELAY="$RELAY"
PATH="$RUTA"
SNI="$SNI"
EOF
}

configurar_datos() {
  leer_datos
  echo ""
  cyan "== Configurar datos del relay =="
  echo "Relay es el dominio que ven los clientes, ej: tu-sitio.netlify.app"
  echo "o tu dominio con Vercel. Si lo dejas vacío, uso el SNI del servidor."
  read -rp "Relay / dominio público [$RELAY]: " r; [[ -n "$r" ]] && RELAY="$r"
  read -rp "Path XHTTP [$RUTA]: " p; [[ -n "$p" ]] && RUTA="$p"
  read -rp "SNI / dominio del servidor [$SNI]: " s; [[ -n "$s" ]] && SNI="$s"
  guardar_datos
  verde "Guardado en $INFO_FILE"
}

listar() {
  echo ""
  cyan "== Usuarios VLESS =="
  local n
  n=$(jq -r '.inbounds[0].settings.clients | length' "$CONFIG" 2>/dev/null || echo 0)
  if [[ "$n" == "0" || -z "$n" ]]; then
    amarillo "No hay usuarios."
    return
  fi
  jq -r '.inbounds[0].settings.clients[] | "\(.email // "sin-nombre")  |  \(.id)"' "$CONFIG"
  echo ""
  echo "Total: $n"
}

crear() {
  echo ""
  cyan "== Crear usuario =="
  read -rp "Nombre del usuario: " nombre
  [[ -z "$nombre" ]] && { rojo "Nombre vacío."; return; }
  if jq -e --arg n "$nombre" '.inbounds[0].settings.clients[] | select(.email == $n)' "$CONFIG" >/dev/null 2>&1; then
    rojo "Ya existe un usuario llamado $nombre"
    return
  fi
  local uuid
  uuid=$(uuidgen)
  local tmp
  tmp=$(mktemp)
  jq --arg id "$uuid" --arg n "$nombre" \
    '.inbounds[0].settings.clients += [{"id": $id, "email": $n, "level": 0}]' \
    "$CONFIG" > "$tmp" && mv "$tmp" "$CONFIG"
  systemctl restart xray 2>/dev/null || systemctl restart xray.service 2>/dev/null || true
  leer_datos
  echo ""
  verde "Usuario creado: $nombre"
  echo "UUID: $uuid"
  echo ""
  echo "Link VLESS:"
  # vless://UUID@RELAY:443?encryption=none&security=tls&sni=SNI&type=xhttp&path=PATH&mode=auto#NOMBRE
  local host="${RELAY:-$SNI}"
  local sni="${SNI:-$host}"
  local ruta_enc
  ruta_enc=$(printf '%s' "$RUTA" | sed 's|/|%2F|g')
  echo "vless://$uuid@$host:443?encryption=none&security=tls&sni=$sni&type=xhttp&path=$ruta_enc&mode=auto#$nombre"
  echo ""
  amarillo "Si el relay o el path no son correctos, usa la opción 5 para corregirlos y vuelve a crear el link."
}

eliminar() {
  listar
  echo ""
  read -rp "Nombre del usuario a eliminar: " nombre
  [[ -z "$nombre" ]] && { rojo "Nombre vacío."; return; }
  if ! jq -e --arg n "$nombre" '.inbounds[0].settings.clients[] | select(.email == $n)' "$CONFIG" >/dev/null 2>&1; then
    rojo "No existe un usuario llamado $nombre"
    return
  fi
  read -rp "¿Seguro que quieres eliminar a $nombre? [s/N]: " conf
  [[ "$conf" != "s" && "$conf" != "S" ]] && { echo "Cancelado."; return; }
  local tmp
  tmp=$(mktemp)
  jq --arg n "$nombre" \
    '.inbounds[0].settings.clients |= map(select(.email != $n))' \
    "$CONFIG" > "$tmp" && mv "$tmp" "$CONFIG"
  systemctl restart xray 2>/dev/null || true
  verde "Usuario $nombre eliminado."
}

generar_uuid() {
  echo ""
  cyan "== Generar UUID =="
  uuidgen
  echo ""
  echo "Ese UUID lo puedes usar al crear un usuario manualmente, o el menú ya genera uno solo al crear."
}

ver_estado() {
  echo ""
  systemctl status xray --no-pager -l 2>/dev/null | head -n 20 || echo "No se pudo leer el estado de xray."
  echo ""
  systemctl status haproxy --no-pager -l 2>/dev/null | head -n 10 || true
  systemctl status stunnel4 --no-pager -l 2>/dev/null | head -n 10 || true
  echo ""
  ss -tlnp 2>/dev/null | grep -E '443|8443|8444|xray|haproxy|stunnel' || true
}

# --- Stunnel4 + Certbot, sin conflicto con Xray/V2Ray ---
# Idea: por fuera TODO sigue en 443, pero 443 lo toma HAProxy.
# HAProxy lee el SNI (el dominio) y reparte:
#   dominio XHTTP/VLESS -> Xray en 127.0.0.1:8443
#   dominio SSH          -> Stunnel4 en 127.0.0.1:8444 -> SSH 22
# Así Stunnel4 escucha su tráfico por el 443, pero no choca con Xray,
# porque ninguno de los dos escucha directo en 443.
instalar_stunnel() {
  echo ""
  cyan "== Instalar Stunnel4 + Certbot (por el 443, sin chocar con Xray) =="
  echo ""
  echo "Por fuera todo entra por 443."
  echo "HAProxy toma el 443 y reparte por dominio (SNI):"
  echo "  - tu dominio XHTTP -> Xray en 8443"
  echo "  - tu dominio SSH   -> Stunnel4 en 8444 -> SSH 22"
  echo ""
  leer_datos
  local dominio_xray="${SNI:-}"
  echo "Dominio XHTTP/VLESS actual: ${dominio_xray:-no detectado}"
  read -rp "Dominio para SSH con Stunnel (ej: ssh-mustafavpn.duckdns.org): " dominio_ssh
  [[ -z "$dominio_ssh" ]] && { rojo "Dominio SSH vacío."; return; }
  if [[ "$dominio_ssh" == "$dominio_xray" ]]; then
    rojo "El dominio SSH no puede ser el mismo que el de XHTTP, si no HAProxy no sabe a dónde mandar el tráfico."
    echo "Usa otro subdominio, ej: ssh-tu-dominio.duckdns.org"
    return
  fi
  read -rp "Email para Certbot (para el cert de $dominio_ssh): " email
  [[ -z "$email" ]] && { rojo "Email vacío."; return; }

  echo ""
  amarillo "Instalando haproxy, stunnel4 y certbot..."
  apt-get update -qq
  apt-get install -y -qq haproxy stunnel4 certbot jq uuid-runtime >/dev/null 2>&1 || apt-get install -y haproxy stunnel4 certbot jq uuid-runtime

  # Respaldos
  cp "$CONFIG" "$CONFIG.bak.$(date +%Y%m%d-%H%M%S)" 2>/dev/null || true
  [[ -f /etc/haproxy/haproxy.cfg ]] && cp /etc/haproxy/haproxy.cfg "/etc/haproxy/haproxy.cfg.bak.$(date +%Y%m%d-%H%M%S)"
  [[ -f /etc/stunnel/stunnel.conf ]] && cp /etc/stunnel/stunnel.conf "/etc/stunnel/stunnel.conf.bak.$(date +%Y%m%d-%H%M%S)"

  # 1) Mover Xray de 443 a 8443 (interno, localhost)
  echo "Moviendo Xray de 443 a 127.0.0.1:8443..."
  systemctl stop xray 2>/dev/null || true
  local tmp
  tmp=$(mktemp)
  jq '.inbounds[0].port = 8443 | .inbounds[0].listen = "127.0.0.1"' "$CONFIG" > "$tmp" && mv "$tmp" "$CONFIG"

  # 2) Certbot para el dominio SSH. Necesita el 80 libre un momento.
  echo "Sacando certificado con Certbot para $dominio_ssh (puerto 80)..."
  systemctl stop haproxy 2>/dev/null || true
  if ! certbot certonly --standalone --non-interactive --agree-tos -m "$email" -d "$dominio_ssh"; then
    rojo "Certbot falló. Revisa que $dominio_ssh apunte con un registro A a la IP de este VPS y que el 80 esté libre."
    echo "No se cambió nada más, Xray quedó en 8443. Vuelve a intentarlo."
    return
  fi

  # 3) Stunnel4 en 127.0.0.1:8444 -> SSH 22, con ese cert
  echo "Configurando Stunnel4 en 127.0.0.1:8444 -> SSH 22..."
  mkdir -p /etc/stunnel
  cat > /etc/stunnel/stunnel.conf <<EOF
pid = /var/run/stunnel4/stunnel.pid
output = /var/log/stunnel4/stunnel.log
setuid = stunnel4
setgid = stunnel4
socket = l:TCP_NODELAY=1
socket = r:TCP_NODELAY=1
[ssh]
accept = 127.0.0.1:8444
connect = 127.0.0.1:22
cert = /etc/letsencrypt/live/$dominio_ssh/fullchain.pem
key = /etc/letsencrypt/live/$dominio_ssh/privkey.pem
EOF
  # Certbot renueva cada 60-90 días, Stunnel necesita releerlo
  mkdir -p /etc/letsencrypt/renewal-hooks/deploy
  cat > /etc/letsencrypt/renewal-hooks/deploy/stunnel4 <<'EOS'
#!/bin/sh
systemctl restart stunnel4 2>/dev/null || true
systemctl restart haproxy 2>/dev/null || true
EOS
  chmod +x /etc/letsencrypt/renewal-hooks/deploy/stunnel4
  sed -i 's/^ENABLED=.*/ENABLED=1/' /etc/default/stunnel4 2>/dev/null || echo "ENABLED=1" >> /etc/default/stunnel4
  mkdir -p /var/run/stunnel4 /var/log/stunnel4
  chown stunnel4:stunnel4 /var/run/stunnel4 /var/log/stunnel4 2>/dev/null || true
  # Que stunnel pueda leer la llave (grupo ssl-cert)
  usermod -a -G ssl-cert stunnel4 2>/dev/null || true
  chmod 750 /etc/letsencrypt/live /etc/letsencrypt/archive 2>/dev/null || true

  # 4) HAProxy en 443, reparto por SNI
  echo "Configurando HAProxy en 443..."
  cat > /etc/haproxy/haproxy.cfg <<EOF
global
    log /dev/log local0
    maxconn 4096
    daemon

defaults
    log global
    mode tcp
    option tcplog
    timeout connect 5s
    timeout client 120s
    timeout server 120s

frontend ft_443
    bind *:443
    mode tcp
    tcp-request inspect-delay 5s
    tcp-request content accept if { req_ssl_hello_type 1 }
    # Dominio SSH -> Stunnel4
    use_backend be_stunnel if { req_ssl_sni -i $dominio_ssh }
    # Todo lo demás (dominio XHTTP) -> Xray
    default_backend be_xray

backend be_xray
    mode tcp
    server xray 127.0.0.1:8443 check

backend be_stunnel
    mode tcp
    server stunnel 127.0.0.1:8444 check
EOF

  systemctl enable haproxy stunnel4 xray 2>/dev/null || true
  systemctl restart stunnel4
  systemctl restart xray
  systemctl restart haproxy

  echo ""
  verde "Listo, sin conflicto:"
  echo "  - Por fuera: HAProxy escucha en el 443"
  echo "  - Xray / VLESS: 127.0.0.1:8443  (dominio: ${dominio_xray:-?})"
  echo "  - Stunnel4 / SSH: 127.0.0.1:8444 -> SSH 22  (dominio: $dominio_ssh)"
  echo ""
  echo "Para conectar por SSH con Stunnel, en tu cliente usa:"
  echo "  Host: $dominio_ssh  Puerto: 443  TLS: sí"
  echo ""
  echo "Tu link VLESS sigue igual, por 443, con el mismo dominio de antes."
  echo "Si algo falla, revisa: systemctl status haproxy / stunnel4 / xray"
}

while true; do
  echo ""
  echo "=================================="
  cyan "   MENÚ XHTTP - VLESS"
  echo "=================================="
  echo "1) Crear usuario (genera UUID)"
  echo "2) Eliminar usuario"
  echo "3) Listar usuarios"
  echo "4) Generar solo un UUID"
  echo "5) Configurar relay / path / SNI"
  echo "6) Ver estado de Xray"
  echo "7) Instalar Stunnel4 + Certbot (443, sin chocar con Xray)"
  echo "8) Ver estado de Xray / HAProxy / Stunnel4"
  echo "0) Salir"
  echo "=================================="
  read -rp "Elige una opción: " op
  case "$op" in
    1) crear ;;
    2) eliminar ;;
    3) listar ;;
    4) generar_uuid ;;
    5) configurar_datos ;;
    6) ver_estado ;;
    7) instalar_stunnel ;;
    8) ver_estado ;;
    0) echo "Adiós."; exit 0 ;;
    *) rojo "Opción no válida." ;;
  esac
done
