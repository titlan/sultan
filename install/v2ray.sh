#!/bin/bash
# ADMRufu - v2ray.sh ACTUALIZADO 2026-11-12
# Cambios vs original 2022-04-11:
# - ins_v2r() ya NO usa rudi9999/ADMRufu (404) ni multi.netlify.app/go.sh
#   ni pip v2ray_util. Instala Xray-core (sucesor de V2Ray, mismo VMess)
#   con el instalador oficial XTLS/Xray-install.
# - Config nueva: /usr/local/etc/xray/config.json, servicio `xray`,
#   binario /usr/local/bin/xray. El menu debe apuntar $config a esa ruta
#   (ver instalar-actualizacion.sh, que parchea /etc/ADMRufu/menu).
# - restart() usa systemctl, no el comando `v2ray restart`.
# - port()/address()/host()/path()/alterid() corregidos: antes hacian
#   `jq ... < $temp >> $config` (append, duplicaba el JSON). Ahora
#   escriben a un temporal y lo mueven encima.
# - alterId esta obsoleto en Xray/VMess moderno: se fija en 0 y se avisa.
# - removeV2Ray() usa el desinstalador oficial, sin pip ni netlify.
# Se mantienen los nombres de funcion que el menu espera:
# ins_v2r, v2ray_tls, removeV2Ray, v2ray_stream, port, alterid,
# n_v2ray, address, host, path, reset.

# Ruta nueva. Si el menu aun exporta la vieja, se respeta solo si existe.
: "${config:=/usr/local/etc/xray/config.json}"
: "${temp:=/usr/local/etc/xray/temp.json}"
XRAY_BIN="/usr/local/bin/xray"

restart(){
    title "REINICIANDO XRAY / V2RAY"
    if systemctl restart xray 2>/dev/null && systemctl is-active --quiet xray; then
        print_center -verd "xray restart success !"
    else
        print_center -verm2 "xray restart fail !"
        systemctl status xray --no-pager -n 20 2>/dev/null || true
    fi
    msg -bar
    sleep 2
}

_default_config(){
    local uuid port path
    uuid="$(cat /proc/sys/kernel/random/uuid)"
    port="${1:-8443}"
    path="${2:-/v2ray}"
    cat > "$config" <<EOF
{
  "log": { "loglevel": "warning" },
  "inbounds": [
    {
      "port": $port,
      "protocol": "vmess",
      "settings": {
        "clients": [
          { "id": "$uuid", "alterId": 0, "email": "default", "date": "$(date +%Y-%m-%d -d '+30 days')" }
        ]
      },
      "streamSettings": {
        "network": "ws",
        "security": "none",
        "wsSettings": { "path": "$path", "headers": { "Host": "" } }
      }
    }
  ],
  "outbounds": [ { "protocol": "freedom" } ]
}
EOF
    chmod 644 "$config"
}

ins_v2r(){
    title "ESTA POR INSTALAR XRAY (V2RAY)!"
    print_center -ama "Se instalara Xray-core oficial, sucesor de V2Ray.\nEl instalador viejo de ADMRufu ya no existe (404)."
    enter
    apt-get update -y
    apt-get install -y curl jq uuid-runtime 2>/dev/null || apt-get install -y curl jq
    if [[ -x "$XRAY_BIN" ]] && systemctl is-active --quiet xray; then
        print_center -ama "Xray ya esta instalado, se reinstalara la configuracion si falta."
    else
        bash <(curl -fsSL https://github.com/XTLS/Xray-install/raw/main/install-release.sh) install || {
            print_center -verm2 "Fallo la instalacion oficial de Xray"
            return 1
        }
    fi
    mkdir -p "$(dirname "$config")"
    if [[ ! -s "$config" ]]; then
        _default_config 8443 "/v2ray"
        print_center -verd "Config creada: VMess + WebSocket, puerto 8443, path /v2ray"
        print_center -ama "UUID default creado. Crea usuarios con el menu de usuarios V2Ray."
    fi
    systemctl enable --now xray
    restart
}

v2ray_tls(){
    # Si hay certificado en /etc/ADMRufu/source/cert, usarlo.
    # Si no, avisar: el TLS se configura con certbot aparte, no con `v2ray tls`
    # (ese comando ya no existe).
    local db cert key domi
    db="$(ls "${ADM_crt:-/etc/ADMRufu/source/cert}" 2>/dev/null)"
    if [[ -n "$(echo "$db" | grep '\.crt')" ]]; then
        cert=$(echo "$db" | grep '\.crt' | head -n1)
        key=$(echo "$db" | grep '\.key' | head -n1)
        DOMI="$(cat "${ADM_src:-/etc/ADMRufu/source}/dominio.txt" 2>/dev/null)"
        title "CERTIFICADO SSL ENCONTRADO"
        echo -e "$(msg -azu "DOMI:") $(msg -ama "$DOMI")"
        echo -e "$(msg -azu "CERT:") $(msg -ama "$cert")"
        echo -e "$(msg -azu "KEY:")  $(msg -ama "$key")"
        msg -bar
        msg -ne " Continuar, usando este certificado [S/N]: " && read -r opcion_tls
        if [[ $opcion_tls = @(S|s) ]]; then
            jq --arg a "${ADM_crt:-/etc/ADMRufu/source/cert}/$cert" --arg b "${ADM_crt:-/etc/ADMRufu/source/cert}/$key" \
               --arg d "$DOMI" \
               '.inbounds[0].streamSettings.security = "tls"
                | .inbounds[0].streamSettings.tlsSettings = {"serverName": $d, "certificates": [{"certificateFile": $a, "keyFile": $b}]}' \
               "$config" > "$temp" && mv -f "$temp" "$config"
            restart
            return
        fi
    fi
    title "CERTIFICADO TLS XRAY"
    print_center -ama "El comando 'v2ray tls' ya no existe.\nUsa certbot para tu dominio y luego vuelve aqui\ncon el .crt/.key en /etc/ADMRufu/source/cert,\no edita $config a mano."
    enter
}

removeV2Ray(){
    title "DESINSTALANDO XRAY / V2RAY"
    bash <(curl -fsSL https://github.com/XTLS/Xray-install/raw/main/install-release.sh) --remove 2>/dev/null || true
    systemctl disable --now xray 2>/dev/null || true
    rm -rf /usr/local/etc/xray /usr/local/bin/xray /var/log/xray
    rm -rf /etc/v2ray /var/log/v2ray /etc/xray /var/log/xray
    clear
    msg -bar
    print_center "XRAY / V2RAY REMOVIDO!"
    enter
    return 1
}

v2ray_stream(){
    title "PROTOCOLOS XRAY"
    print_center -ama "VMess + WebSocket es el protocolo por defecto.\nPara VLESS / XHTTP / REALITY usa el instalador sultan\n(titlan/sultan) o edita $config directamente."
    msg -bar
    read -r foo
}

port(){
    local port
    port=$(jq -r '.inbounds[0].port' "$config")
    title "CONFIG PUERTO XRAY"
    print_center -azu "puerto actual: $(msg -ama "$port")"
    back
    in_opcion "Nuevo puerto"
    opcion=$(echo "$opcion" | tr -d '[[:space:]]')
    tput cuu1 && tput dl1
    if [[ -z "$opcion" ]]; then msg -ne " debes ingresar una opcion"; sleep 2; return
    elif [[ ! $opcion =~ $numero ]]; then msg -ne " solo debes ingresar numeros"; sleep 2; return
    elif [[ "$opcion" = "0" ]]; then return; fi
    jq --argjson a "$opcion" '.inbounds[0].port = $a' "$config" > "$temp" && mv -f "$temp" "$config"
    chmod 644 "$config"
    restart
}

alterid(){
    title "CONFIG alterId XRAY"
    print_center -ama "alterId esta obsoleto en VMess moderno.\nXray lo ignora salvo 0. Se fija en 0."
    jq '.inbounds[0].settings.clients[].alterId = 0' "$config" > "$temp" && mv -f "$temp" "$config"
    chmod 644 "$config"
    restart
}

n_v2ray(){
    title "CONFIGURACION NATIVA XRAY"
    echo -ne "\033[1;37m"
    ${EDITOR:-nano} "$config"
    "$XRAY_BIN" -test -config "$config" && restart || print_center -verm2 "Config invalida, revisa el archivo"
}

address(){
    local add
    add=$(jq -r '.inbounds[0].domain // empty' "$config")
    [[ -z "$add" ]] && add=$(curl -fsSL --max-time 5 https://api.ipify.org 2>/dev/null || hostname -I | awk '{print $1}')
    title "CONFIG address XRAY"
    print_center -azu "actual: $(msg -ama "$add")"
    back
    in_opcion "Nuevo address"
    opcion=$(echo "$opcion" | tr -d '[[:space:]]')
    tput cuu1 && tput dl1
    if [[ -z "$opcion" ]]; then msg -ne " debes ingresar una opcion"; sleep 2; return
    elif [[ "$opcion" = "0" ]]; then return; fi
    jq --arg a "$opcion" '.inbounds[0].domain = $a' "$config" > "$temp" && mv -f "$temp" "$config"
    chmod 644 "$config"
    restart
}

host(){
    local host
    host=$(jq -r '.inbounds[0].streamSettings.wsSettings.headers.Host // empty' "$config")
    [[ -z "$host" ]] && host='sin host'
    title "CONFIG host XRAY"
    print_center -azu "Actual: $(msg -ama "$host")"
    back
    in_opcion "Nuevo host"
    opcion=$(echo "$opcion" | tr -d '[[:space:]]')
    tput cuu1 && tput dl1
    if [[ -z "$opcion" ]]; then msg -ne " debes ingresar una opcion"; sleep 2; return
    elif [[ "$opcion" = "0" ]]; then return; fi
    jq --arg a "$opcion" '.inbounds[0].streamSettings.wsSettings.headers.Host = $a' "$config" > "$temp" && mv -f "$temp" "$config"
    chmod 644 "$config"
    restart
}

path(){
    local path
    path=$(jq -r '.inbounds[0].streamSettings.wsSettings.path // empty' "$config")
    [[ -z "$path" ]] && path=''
    title "CONFIG path XRAY"
    print_center -azu "Actual: $(msg -ama "$path")"
    back
    in_opcion "Nuevo path"
    opcion=$(echo "$opcion" | tr -d '[[:space:]]')
    tput cuu1 && tput dl1
    if [[ -z "$opcion" ]]; then msg -ne " debes ingresar una opcion"; sleep 2; return
    elif [[ "$opcion" = "0" ]]; then return; fi
    jq --arg a "$opcion" '.inbounds[0].streamSettings.wsSettings.path = $a' "$config" > "$temp" && mv -f "$temp" "$config"
    chmod 644 "$config"
    restart
}

reset(){
    title "RESTAURANDO AJUSTES XRAY"
    local user
    user=$(jq -c '.inbounds[0].settings.clients' < "$config" 2>/dev/null)
    _default_config 8443 "/v2ray"
    if [[ -n "$user" && "$user" != "null" ]]; then
        title "RESTAURANDO USUARIOS"
        jq --argjson a "$user" '.inbounds[0].settings.clients = $a' "$config" > "$temp" && mv -f "$temp" "$config"
        chmod 644 "$config"
    fi
    sleep 1
    restart
}

while :
do
    clear
    msg -bar
    print_center -verd "xray / v2ray manager by @Rufu99 - actualizado 2026"
    msg -bar
    msg -ama "INSTALACION"
    msg -bar3
    menu_func "$(msg -verd "INSTALL/RE-REINSTALL XRAY")" \
    "$(msg -verm2 "DESINSTALAR XRAY")\n$(msg -bar3)\n$(msg -ama "CONFIGURACION")\n$(msg -bar3)" \
    "Certif ssl/tls" \
    "Protocolos" \
    "puerto" \
    "alterId (obsoleto, se fija 0)" \
    "Conf xray (editor)\n$(msg -bar3)\n$(msg -ama "CLIENTES")\n$(msg -bar3)" \
    "address" \
    "Host" \
    "Path\n$(msg -bar3)\n$(msg -ama "EXTRAS")\n$(msg -bar3)" \
    "Restablecer ajustes"
    back
    opcion=$(selection_fun 12)
    case $opcion in
        1)ins_v2r;;
        2)removeV2Ray;;
        3)v2ray_tls;;
        4)v2ray_stream;;
        5)port;;
        6)alterid;;
        7)n_v2ray;;
        8)address;;
        9)host;;
        10)path;;
        11)reset;;
        0)break;;
    esac
    [[ "$?" = "1" ]] && break
done
return 1
