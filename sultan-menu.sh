#!/usr/bin/env bash
# sultan-menu.sh - Menú en español para titlan/sultan
# (V2Ray VLESS Server Manager de Humran13 + Stunnel4/SSH)
#
# Instalación del menú:
#   sudo cp sultan-menu.sh /usr/local/sbin/sultan-menu
#   sudo chmod +x /usr/local/sbin/sultan-menu
#   sudo sultan-menu
#
# Lo que hace:
#   - Usuarios V2Ray: usa el manager `vless` (Humran13) que ya trae
#     el instalador. Crear / eliminar / listar / mostrar link.
#   - Usuarios SSH: crea usuarios Linux con contraseña, para usar
#     con Stunnel4 + SSL/TLS (como HTTP Custom, puerto 443).
#   - Stunnel4 en el puerto 443, con 2 dominios:
#       * dominio V2Ray (ej. vpn-mustafavpn.duckdns.org)
#       * dominio SSH   (ej. ssh-mustafavpn.duckdns.org)
#     Como el 443 solo lo puede escuchar un programa, se pone HAProxy
#     en el 443 y se reparte por SNI:
#       SNI = dominio V2Ray -> Xray/V2Ray en 127.0.0.1:8443
#       SNI = dominio SSH   -> Stunnel4 en 127.0.0.1:8444 -> SSH 22
#     Por eso el menú cambia el puerto de los perfiles V2Ray a 8443
#     en /etc/v2ray-vless-server/state.json y luego corre `vless repair`
#     para que el manager regenere su config. Los links vless://
#     nuevos salen con el puerto 8443 por fuera? NO: por fuera sigue
#     siendo el 443 (HAProxy), el 8443 es solo interno. El link que
#     muestra `vless user show` dirá 8443; en ANUBIS hay que poner
#     el puerto 443 a mano, o volver a generar el link con 443.
#     OJO: después de instalar Stunnel+HAProxy, cuando crees un
#     usuario V2Ray nuevo, su link vendrá con puerto 8443: en el
#     cliente (ANUBIS) pon puerto 443, dominio V2Ray y SNI igual.
#
# Requisitos: Ubuntu 22.04+, root, V2Ray ya instalado con install.sh,
# y los 2 dominios apuntando (registro A) a la IP de este VPS.
set -uo pipefail

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    echo "Ejecuta como root: sudo sultan-menu"
    exit 1
fi

STATE_FILE="/etc/v2ray-vless-server/state.json"
SSH_USERS_FILE="/etc/sultan-ssh-users.txt"
VLESS_BIN="vless"

pause() { read -r -p "Pulsa Enter para continuar... " _ < /dev/tty; }

# ---------- V2Ray (vless) ----------
vless_perfiles() {
    if command -v "$VLESS_BIN" >/dev/null 2>&1; then
        "$VLESS_BIN" profile list 2>/dev/null || echo "(no se pudieron listar los perfiles, ¿V2Ray instalado?)"
    else
        echo "El comando 'vless' no existe. Instala primero con install.sh"
    fi
}

crear_usuario_v2ray() {
    echo "--- Perfiles V2Ray ---"
    vless_perfiles
    echo ""
    read -r -p "ID del perfil (ej. default): " perfil < /dev/tty
    [[ -z "$perfil" ]] && perfil="default"
    read -r -p "Nombre del usuario V2Ray: " nombre < /dev/tty
    [[ -z "$nombre" ]] && { echo "Nombre vacío, cancelado."; return; }
    "$VLESS_BIN" user add "$perfil" "$nombre"
    echo ""
    echo "--- Link del usuario ---"
    "$VLESS_BIN" user show "$nombre" || true
    echo ""
    echo "NOTA: si ya instalaste Stunnel+HAProxy, el link dirá puerto 8443."
    echo "En ANUBIS pon puerto 443 a mano, con el dominio V2Ray y su SNI."
}

eliminar_usuario_v2ray() {
    "$VLESS_BIN" user list 2>/dev/null || true
    read -r -p "Nombre del usuario V2Ray a eliminar: " nombre < /dev/tty
    [[ -z "$nombre" ]] && { echo "Nombre vacío, cancelado."; return; }
    "$VLESS_BIN" user delete "$nombre"
}

listar_usuarios_v2ray() {
    "$VLESS_BIN" user list
}

mostrar_usuario_v2ray() {
    read -r -p "Nombre del usuario V2Ray: " nombre < /dev/tty
    [[ -z "$nombre" ]] && { echo "Nombre vacío, cancelado."; return; }
    "$VLESS_BIN" user show "$nombre"
}

# ---------- SSH ----------
crear_usuario_ssh() {
    read -r -p "Nombre del usuario SSH: " usuario < /dev/tty
    [[ -z "$usuario" ]] && { echo "Nombre vacío, cancelado."; return; }
    if id "$usuario" >/dev/null 2>&1; then
        echo "El usuario '$usuario' ya existe."
        return
    fi
    read -r -s -p "Contraseña para $usuario: " clave < /dev/tty; echo ""
    read -r -s -p "Repite la contraseña: " clave2 < /dev/tty; echo ""
    [[ "$clave" != "$clave2" ]] && { echo "Las contraseñas no coinciden."; return; }
    [[ -z "$clave" ]] && { echo "Contraseña vacía, cancelado."; return; }
    adduser --disabled-password --gecos "" "$usuario"
    echo "$usuario:$clave" | chpasswd
    touch "$SSH_USERS_FILE"
    grep -qx "$usuario" "$SSH_USERS_FILE" 2>/dev/null || echo "$usuario" >> "$SSH_USERS_FILE"
    echo ""
    echo "Usuario SSH '$usuario' creado."
    echo "En ANUBIS (modo SSH + SSL/TLS): host = tu dominio SSH, puerto 443,"
    echo "usuario = $usuario, contraseña = la que pusiste, SNI = tu dominio SSH."
}

eliminar_usuario_ssh() {
    echo "--- Usuarios SSH creados con este menú ---"
    [[ -f "$SSH_USERS_FILE" ]] && cat "$SSH_USERS_FILE" || echo "(ninguno registrado)"
    read -r -p "Nombre del usuario SSH a eliminar: " usuario < /dev/tty
    [[ -z "$usuario" ]] && { echo "Nombre vacío, cancelado."; return; }
    read -r -p "¿Seguro? Se borra el usuario y su carpeta [s/N]: " conf < /dev/tty
    [[ "$conf" =~ ^[Ss]$ ]] || { echo "Cancelado."; return; }
    userdel -r "$usuario" 2>/dev/null || userdel "$usuario"
    sed -i "/^${usuario}$/d" "$SSH_USERS_FILE" 2>/dev/null || true
    echo "Usuario SSH '$usuario' eliminado."
}

listar_usuarios_ssh() {
    echo "--- Usuarios SSH creados con este menú ---"
    [[ -f "$SSH_USERS_FILE" ]] && cat "$SSH_USERS_FILE" || echo "(ninguno registrado)"
    echo ""
    echo "--- Usuarios del sistema (UID >= 1000, sin sistema) ---"
    awk -F: '$3 >= 1000 && $3 < 65534 {print $1}' /etc/passwd
}

# ---------- Stunnel4 + HAProxy en 443, 2 dominios ----------
instalar_stunnel_haproxy() {
    echo "=== Instalar Stunnel4 en el puerto 443 (con HAProxy, 2 dominios) ==="
    echo ""
    echo "V2Ray y Stunnel no pueden escuchar los dos en el 443."
    echo "HAProxy escucha en el 443 y reparte por SNI:"
    echo "  dominio V2Ray -> V2Ray en 127.0.0.1:8443"
    echo "  dominio SSH   -> Stunnel4 en 127.0.0.1:8444 -> SSH 22"
    echo ""
    command -v "$VLESS_BIN" >/dev/null 2>&1 || { echo "Falta 'vless'. Instala primero V2Ray con install.sh"; return; }
    [[ -f "$STATE_FILE" ]] || { echo "No existe $STATE_FILE. Instala primero V2Ray con install.sh"; return; }

    # Dominio V2Ray: intentar sacarlo del estado, si no, preguntar
    local dominio_v2ray=""
    dominio_v2ray="$(jq -r '.profiles[0].extra.domain // empty' "$STATE_FILE" 2>/dev/null || true)"
    if [[ -z "$dominio_v2ray" ]]; then
        dominio_v2ray="$(jq -r '.profiles[0].domain // empty' "$STATE_FILE" 2>/dev/null || true)"
    fi
    read -r -p "Dominio V2Ray [${dominio_v2ray}]: " d1 < /dev/tty
    dominio_v2ray="${d1:-$dominio_v2ray}"
    [[ -z "$dominio_v2ray" ]] && { echo "Falta el dominio V2Ray."; return; }
    read -r -p "Dominio SSH (ej. ssh-midominio.duckdns.org): " dominio_ssh < /dev/tty
    [[ -z "$dominio_ssh" ]] && { echo "Falta el dominio SSH."; return; }
    read -r -p "Email para el certificado Let's Encrypt (Enter para ninguno): " email < /dev/tty

    echo ""
    echo "1) Respaldo de la configuración V2Ray..."
    cp -f "$STATE_FILE" "${STATE_FILE}.bak.$(date +%Y%m%d%H%M%S)"
    [[ -f /etc/v2ray-vless-server/xray/config.json ]] && cp -f /etc/v2ray-vless-server/xray/config.json "/tmp/xray-config.json.bak"
    [[ -f /etc/haproxy/haproxy.cfg ]] && cp -f /etc/haproxy/haproxy.cfg "/tmp/haproxy.cfg.bak"
    [[ -f /etc/stunnel/stunnel.conf ]] && cp -f /etc/stunnel/stunnel.conf "/tmp/stunnel.conf.bak"

    echo "2) Moviendo V2Ray a interno 8443 (en state.json)..."
    jq '.profiles[].port = 8443' "$STATE_FILE" > /tmp/state.json.tmp && mv /tmp/state.json.tmp "$STATE_FILE"
    chmod 0640 "$STATE_FILE"

    echo "3) Instalando haproxy, stunnel4 y certbot..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    apt-get install -y -qq haproxy stunnel4 certbot >/dev/null || { echo "Falló la instalación de paquetes."; return; }

    echo "4) Certificado para el dominio SSH ($dominio_ssh)..."
    local cert_dir="" key_file="" cert_file=""
    if [[ -f "/etc/v2ray-vless-server/tls/${dominio_ssh}/fullchain.pem" ]]; then
        cert_dir="/etc/v2ray-vless-server/tls/${dominio_ssh}"
    elif [[ -f "/etc/letsencrypt/live/${dominio_ssh}/fullchain.pem" ]]; then
        cert_dir="/etc/letsencrypt/live/${dominio_ssh}"
    else
        echo "   Parando haproxy para liberar el puerto 80 (certbot standalone)..."
        systemctl stop haproxy 2>/dev/null || true
        if [[ -n "$email" ]]; then
            certbot certonly --standalone -d "$dominio_ssh" --non-interactive --agree-tos -m "$email" || { echo "Certbot falló. Revisa que el dominio apunte a este VPS y el puerto 80 esté libre."; return; }
        else
            certbot certonly --standalone -d "$dominio_ssh" --non-interactive --agree-tos --register-unsafely-without-email || { echo "Certbot falló. Revisa que el dominio apunte a este VPS y el puerto 80 esté libre."; return; }
        fi
        cert_dir="/etc/letsencrypt/live/${dominio_ssh}"
    fi
    cert_file="${cert_dir}/fullchain.pem"
    key_file="${cert_dir}/privkey.pem"
    echo "   Certificado: $cert_file"

    echo "5) Escribiendo /etc/stunnel/stunnel.conf (acepta 127.0.0.1:8444 -> SSH 22)..."
    cat > /etc/stunnel/stunnel.conf <<EOF
; Stunnel4 para SSH, instalado por sultan-menu.sh (titlan/sultan)
; HAProxy en el 443 reparte por SNI a este Stunnel en 8444.
cert = ${cert_file}
key = ${key_file}
[ssh]
accept = 127.0.0.1:8444
connect = 127.0.0.1:22
EOF
    sed -i 's/^ENABLED=0/ENABLED=1/' /etc/default/stunnel4 2>/dev/null || echo "ENABLED=1" >> /etc/default/stunnel4
    # Que stunnel pueda leer el certificado
    getent group ssl-cert >/dev/null && usermod -a -G ssl-cert stunnel 2>/dev/null || true
    chgrp ssl-cert "$cert_file" "$key_file" 2>/dev/null || true
    chmod 0640 "$cert_file" "$key_file" 2>/dev/null || true
    # Hook para renovar el certificado y reiniciar stunnel+haproxy
    mkdir -p /etc/letsencrypt/renewal-hooks/deploy
    cat > /etc/letsencrypt/renewal-hooks/deploy/restart-stunnel-haproxy.sh <<'HOOK'
#!/bin/sh
systemctl restart stunnel4 haproxy 2>/dev/null || true
HOOK
    chmod +x /etc/letsencrypt/renewal-hooks/deploy/restart-stunnel-haproxy.sh

    echo "6) Regenerando la config de V2Ray (vless repair)..."
    "$VLESS_BIN" repair || { echo "vless repair falló. Revisa con: sudo vless diagnostics"; return; }

    echo "7) Escribiendo /etc/haproxy/haproxy.cfg (443 por SNI)..."
    cat > /etc/haproxy/haproxy.cfg <<EOF
# HAProxy en 443, instalado por sultan-menu.sh (titlan/sultan)
# SNI $dominio_ssh -> Stunnel4 (SSH) | resto -> V2Ray
global
    log /dev/log local0
    maxconn 2048
defaults
    log global
    mode tcp
    timeout connect 5s
    timeout client 300s
    timeout server 300s
frontend ft_443
    bind *:443
    tcp-request inspect-delay 5s
    tcp-request content accept if { req_ssl_hello_type 1 }
    use_backend be_stunnel if { req_ssl_sni -i ${dominio_ssh} }
    default_backend be_v2ray
backend be_v2ray
    server v2ray 127.0.0.1:8443
backend be_stunnel
    server stunnel 127.0.0.1:8444
EOF

    echo "8) Arrancando servicios..."
    systemctl enable --now stunnel4 haproxy 2>/dev/null || true
    systemctl restart stunnel4 haproxy
    systemctl restart v2ray-vless-server 2>/dev/null || true
    sleep 2
    echo ""
    echo "--- Estado ---"
    systemctl is-active stunnel4 haproxy v2ray-vless-server 2>/dev/null || true
    ss -tlnp 2>/dev/null | grep -E ':(443|8443|8444)\b' || ss -tlnp | head -n 20
    echo ""
    echo "Listo. Ahora:"
    echo "  V2Ray:  $dominio_v2ray:443  (por HAProxy, interno 8443)"
    echo "  SSH TLS: $dominio_ssh:443  (por HAProxy -> Stunnel4 8444 -> SSH 22)"
    echo "  Crea el usuario SSH con la opción 5 de este menú."
    echo "  NOTA: los links vless:// dirán puerto 8443; en ANUBIS pon 443."
}

ver_estado() {
    echo "--- V2Ray ---"
    "$VLESS_BIN" status 2>/dev/null || echo "vless no disponible"
    echo ""
    echo "--- Stunnel4 / HAProxy ---"
    systemctl status stunnel4 --no-pager -l 2>/dev/null | head -n 15 || echo "stunnel4 no instalado"
    systemctl status haproxy --no-pager -l 2>/dev/null | head -n 15 || echo "haproxy no instalado"
    echo ""
    echo "--- Puertos ---"
    ss -tlnp 2>/dev/null | grep -E ':(22|80|443|8443|8444)\b' || ss -tlnp
}

while true; do
    echo ""
    echo "========== SULTAN - Menú V2Ray + SSH/Stunnel4 =========="
    echo "  V2Ray (vless):"
    echo "    1. Crear usuario V2Ray"
    echo "    2. Eliminar usuario V2Ray"
    echo "    3. Listar usuarios V2Ray"
    echo "    4. Mostrar link VLESS de un usuario"
    echo "  SSH (para Stunnel4):"
    echo "    5. Crear usuario SSH"
    echo "    6. Eliminar usuario SSH"
    echo "    7. Listar usuarios SSH"
    echo "  Stunnel4:"
    echo "    8. Instalar Stunnel4 en el 443 con HAProxy (2 dominios)"
    echo "    9. Ver estado (V2Ray / Stunnel4 / HAProxy / puertos)"
    echo "    0. Salir"
    echo "=========================================================="
    read -r -p "Elige una opción: " op < /dev/tty
    case "$op" in
        1) crear_usuario_v2ray; pause ;;
        2) eliminar_usuario_v2ray; pause ;;
        3) listar_usuarios_v2ray; pause ;;
        4) mostrar_usuario_v2ray; pause ;;
        5) crear_usuario_ssh; pause ;;
        6) eliminar_usuario_ssh; pause ;;
        7) listar_usuarios_ssh; pause ;;
        8) instalar_stunnel_haproxy; pause ;;
        9) ver_estado; pause ;;
        0) exit 0 ;;
        *) echo "Opción no válida." ;;
    esac
done
