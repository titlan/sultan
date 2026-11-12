#!/bin/bash
# ADMRufu - userV2ray.sh ACTUALIZADO 2026-11-12
# Cambios vs original 2022-04-11:
# - Fecha de expiracion: era date '+%y-%m-%d' (ano 2 digitos, ej 26-11-12).
#   Ahora '+%Y-%m-%d' (2026-11-12). El formato viejo rompia el calculo
#   de dias restantes en list_user().
# - newuser(): $users no estaba definido al crear el usuario (siempre
#   intentaba escribir en el indice vacio). Ahora se calcula el total
#   de clientes antes de agregar.
# - newuser()/deluser(): jq con --argjson y mv del temporal, sin el
#   bug de append del original. UUID con uuidgen o /proc/sys/kernel/random/uuid.
# - vmess(): link generado con los campos reales del config nuevo
#   (inbounds[0], streamSettings.wsSettings, security tls/none).
#   alterId se guarda en 0.
# - config por defecto: /usr/local/etc/xray/config.json (Xray-core).
#   Si el menu exporta otra ruta, se respeta.
# Se mantienen los nombres de funcion que el menu espera.

: "${config:=/usr/local/etc/xray/config.json}"
: "${temp:=/usr/local/etc/xray/temp.json}"

restart(){
    title "REINICIANDO XRAY"
    if systemctl restart xray 2>/dev/null && systemctl is-active --quiet xray; then
        print_center -verd "xray restart success !"
        msg -bar
        sleep 2
    else
        print_center -verm2 "xray restart fail !"
        msg -bar
        sleep 2
        return
    fi
}

list(){
    name=$(printf '%-25s' "$2")
    fecha=$(printf '%-10s' "$3")
    if [[ "$4" = "EXP" ]]; then
        dias=$(msg -verm2 "[$4]")
    else
        dias=$(msg -verd "[$4]")
    fi
    echo -e "$(msg -verd " [$1]") $(msg -verm2 ">") $(msg -azu "$name") $(msg -verm2 "$fecha") $dias"
}

userDat(){
    n=$(printf '%-5s' 'N°')
    u=$(printf '%-25s' 'Usuarios')
    f=$(printf '%-10s' 'fech exp')
    msg -azu "  $n $u $f dias"
    msg -bar
}

list_user(){
    unset seg
    seg=$(date +%s)
    userDat
    users=$(jq '.inbounds[0].settings.clients | length' "$config" 2>/dev/null || echo 0)
    for (( i = 0; i < users; i++ )); do
        user=$(jq -r --argjson a "$i" '.inbounds[0].settings.clients[$a].email' < "$config")
        fecha=$(jq -r --argjson a "$i" '.inbounds[0].settings.clients[$a].date' < "$config")
        [[ "$user" = "null" ]] && continue
        seg_exp=$(date +%s --date="$fecha" 2>/dev/null || echo "$seg")
        exp="$(( (seg_exp - seg) / 86400 ))"
        [[ "$exp" -lt "0" ]] && exp="EXP"
        list "$i" "$user" "$fecha" "$exp"
    done
}

col2(){
    msg -ne "$1" && msg -ama " $2"
}

vmess(){
    ps=$(jq -r ".inbounds[0].settings.clients[$1].email" "$config") && [[ $ps = null ]] && ps="default"
    id=$(jq -r ".inbounds[0].settings.clients[$1].id" "$config")
    aid=$(jq ".inbounds[0].settings.clients[$1].alterId" "$config")
    add=$(jq -r '.inbounds[0].domain // empty' "$config") && [[ -z "$add" ]] && add=$(curl -fsSL --max-time 5 https://api.ipify.org 2>/dev/null || hostname -I | awk '{print $1}')
    host=$(jq -r '.inbounds[0].streamSettings.wsSettings.headers.Host // empty' "$config")
    net=$(jq -r '.inbounds[0].streamSettings.network' "$config")
    path=$(jq -r '.inbounds[0].streamSettings.wsSettings.path // empty' "$config")
    port=$(jq '.inbounds[0].port' "$config")
    tls=$(jq -r '.inbounds[0].streamSettings.security' "$config")

    title "DATOS DE USUARIO: $ps"
    col2 "Remarks:" "$ps"
    col2 "Address:" "$add"
    col2 "Port:" "$port"
    col2 "id:" "$id"
    col2 "alterId:" "$aid"
    col2 "security:" "none"
    col2 "network:" "$net"
    col2 "Head Type:" "none"
    [[ -n $host ]] && col2 "Host/SNI:" "$host"
    [[ -n $path ]] && col2 "Path:" "$path"
    col2 "TLS:" "$tls"
    msg -bar
    var="{\"v\":\"2\",\"ps\":\"$ps\",\"add\":\"$add\",\"port\":$port,\"aid\":$aid,\"type\":\"none\",\"net\":\"$net\",\"path\":\"$path\",\"host\":\"$host\",\"id\":\"$id\",\"tls\":\"$tls\"}"
    msg -ama "vmess://$(echo "$var" | base64 -w0)"
    msg -bar
    read -r foo
}

newuser(){
    title "CREAR NUEVO USUARIO V2RAY"
    list_user
    back
    in_opcion "Nuevo Usuario"
    opcion=$(echo "$opcion" | tr -d '[[:space:]]')
    if [[ "$opcion" = "0" ]]; then
        return
    elif [[ -z "$opcion" ]]; then
        tput cuu1 && tput dl1
        msg -verm2 " no se puede ingresar campos vacios..."
        sleep 2
        return
    elif [[ ! "$opcion" =~ $tx_num ]]; then
        tput cuu1 && tput dl1
        msg -verm2 " ingrese solo letras y numeros..."
        sleep 2
        return
    elif [[ "${#opcion}" -lt "4" ]]; then
        tput cuu1 && tput dl1
        msg -verm2 " nombre demaciado corto!"
        sleep 2
        return
    elif [[ "$(jq -r '.inbounds[0].settings.clients[].email' < "$config" | grep -x "$opcion")" ]]; then
        tput cuu1 && tput dl1
        msg -verm2 " este nombe de ususario ya existe..."
        sleep 2
        return
    fi

    email="$opcion"
    in_opcion "Dias de duracion"
    opcion=$(echo "$opcion" | tr -d '[[:space:]]')
    if [[ "$opcion" = "0" ]]; then
        return
    elif [[ ! "$opcion" =~ $numero ]]; then
        tput cuu1 && tput dl1
        msg -verm2 " ingresa solo numeros"
        sleep 2
        return
    fi

    dias=$(date '+%Y-%m-%d' -d " +$opcion days")
    alterid=$(jq -r '.inbounds[0].settings.clients[0].alterId // 0' < "$config")
    if command -v uuidgen >/dev/null 2>&1; then
        uuid=$(uuidgen)
    else
        uuid=$(cat /proc/sys/kernel/random/uuid)
    fi
    users=$(jq '.inbounds[0].settings.clients | length' "$config")
    var="{\"alterId\":$alterid,\"id\":\"$uuid\",\"email\":\"$email\",\"date\":\"$dias\"}"

    jq --argjson a "$users" --argjson b "$var" '.inbounds[0].settings.clients[$a] = $b' "$config" > "$temp" && mv -f "$temp" "$config"
    chmod 644 "$config"
    restart
    vmess "$users"
}

deluser(){
    title "ELIMINAR USUARIOS"
    list_user
    back
    in_opcion "Opcion"
    opcion=$(echo "$opcion" | tr -d '[[:space:]]')
    if [[ "$opcion" = "0" ]]; then
        return
    elif [[ ! "$opcion" =~ $numero ]]; then
        tput cuu1 && tput dl1
        msg -verm2 " ingresa solo numeros"
        sleep 2
        return
    fi
    jq --argjson a "$opcion" 'del(.inbounds[0].settings.clients[$a])' "$config" > "$temp" && mv -f "$temp" "$config"
    chmod 644 "$config"
    restart
}

datos(){
    title "DATOS DE USUARIOS"
    list_user
    back
    in_opcion "Opcion"
    vmess "$opcion"
}

respaldo(){
    title "COPIAS DE SEGURIDAD DE USUARIOS"
    menu_func "CREAR COPIA DE USUARIOS" "RESTAURAR COPIA DE USUARIO"
    back
    opcion=$(selection_fun 2)

    case $opcion in
        1)rm -rf /root/User-V2ray.txt
        jq '.inbounds[0].settings.clients' < "$config" > /root/User-V2ray.txt
        title "COPIA REALIZADO CON EXITO"
        msg -ne " Copia: " && msg -ama "/root/User-V2ray.txt"
        msg -bar
        read -r foo;;
        2)[[ ! -e "/root/User-V2ray.txt" ]] && msg -verm2 " no hay copia de ususarios!" && sleep 3 && return
        var=$(cat /root/User-V2ray.txt)
        [[ -z "$var" ]] && msg -verm2 " copia de ususarios vacio!" && sleep 3 && return
        jq --argjson a "$var" '.inbounds[0].settings.clients = $a' "$config" > "$temp" && mv -f "$temp" "$config"
        chmod 644 "$config"
        title "COPIA RESTAURADA CON EXITO"
        sleep 2
        restart;;
        0)return;;
    esac
}

while :
do
    title "GESTION DE USUARIOS V2RAY"
    menu_func "$(msg -verd "CREAR USUARIOS")" \
    "$(msg -verm2 "ELIMINAR USUARIOS")" \
    "BLOQUEAR USUARIOS $(msg -verm2 "(no diponible!)")" \
    "$(msg -ama "VMESS DE USUARIOS")" \
    "RESPALDO DE SEGURIDAD"
    back
    opcion=$(selection_fun 5)
    case $opcion in
        1)newuser;;
        2)deluser;;
        3);;
        4)datos;;
        5)respaldo;;
        0)break;;
    esac
done
