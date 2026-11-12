#!/bin/bash
# ADMRufu - ws-cdn.sh ACTUALIZADO 2026-11-12
# SSH OVER WEBSOCKET CDN (Cloudflare) - Proxy WS con Node.js
# Cambios vs original 2022:
# - Deteccion de Node: antes `which nodejs` y un test con ${node_v}
#   (variable sin definir) que casi siempre fallaba. Ahora busca
#   `node`, luego `nodejs`, y si no hay ninguno instala nodejs con apt.
#   Node 18/20/22 en Ubuntu 22.04/24.04 funciona con WS-Proxy.js.
# - stop_ws(): antes hacia `systemctl disable nodews.${1}` (el primer
#   argumento, vacio) en lugar de nodews.${i}. Ahora desactiva el
#   servicio correcto y hace daemon-reload.
# - Al crear el servicio: systemctl daemon-reload + verificar que
#   quedo active, antes solo hacia enable/start sin comprobar.
# - drop_port(): ahora lista Dropbear, SSH y Xray (8443), no solo
#   Dropbear. Asi el WS puede redirigir a SSH 22, Dropbear, o a
#   Xray/V2Ray en 8443.
# - El servicio corre con --expose-gc para que el GC del proxy
#   no deje fugas de memoria.
# Se mantienen los nombres que el menu espera: conf, stop_ws,
# stop_port, encab, y el menu final con opciones 1/2/3.

check_drop(){
    ins=$(dpkg --get-selections 2>/dev/null | grep -w "dropbear" | grep -v "dropbear-" | awk '{printf $2}')
    [[ -z "$ins" ]] && ins="deinstall"
    if [[ "$ins" = "deinstall" ]]; then
        encab
        print_center -ama "Dropbear no se encuentra instalado"
        msg -bar
        echo -ne "\033[1;37m desea instalarlo [s/n]: " && read -r opcion
        [[ $opcion = @(s|S|y|Y) ]] && clear && msg -bar && ${ADM_inst}/dropbear.sh
    fi
}

node_bin(){
    # Devuelve la ruta de node, instalandolo si hace falta.
    if command -v node >/dev/null 2>&1; then
        command -v node
    elif command -v nodejs >/dev/null 2>&1; then
        command -v nodejs
    else
        print_center -ama "Node.js no encontrado, instalando..."
        apt-get update -y && apt-get install -y nodejs
        command -v node || command -v nodejs || echo ""
    fi
}

drop_port(){
    local portasVAR=$(lsof -V -i tcp -P -n | grep -v "ESTABLISHED" | grep -v "COMMAND" | grep "LISTEN")
    local NOREPEAT
    local reQ
    local Port
    while read -r port; do
        reQ=$(echo ${port} | awk '{print $1}')
        Port=$(echo ${port} | awk '{print $9}' | awk -F ":" '{print $2}')
        [[ $(echo -e $NOREPEAT | grep -w "$Port") ]] && continue
        NOREPEAT+="$Port\n"
        case ${reQ} in
            dropbear|sshd|ssh|xray|v2ray)
                DPB+=" $reQ:$Port";;
        esac
    done <<< "${portasVAR}"
}

conf(){
    check_drop
    [[ $opcion = @(n|N) ]] && return 1
    drop_port
    encab
    print_center -azu "Seleccione puerto de redireccion de trafico"
    msg -bar
    n=1
    for i in $DPB; do
        echo -e " \033[1;32m[$n] \033[1;31m> \033[1;37m$i\033[0m"
        drop[$n]=$i
        num_opc=$n
        let n++
    done
    back
    opc=$(selection_fun $num_opc)
    [[ $opc = 0 ]] && return 1
    encab
    echo -e "\033[1;33m Puerto de redireccion de trafico: \033[1;32m${drop[$opc]}\033[0m"
    msg -bar
    while [[ -z $opc2 ]]; do
        echo -ne "\033[1;37m Ingrese un puerto para WEBSOCKET: " && read -r opc2
        tput cuu1 && tput dl1
        [[ $(mportas | grep -w "${opc2}") = "" ]] && {
            echo -e "\033[1;33m Puerto de websocket:\033[1;32m ${opc2} OK"
            msg -bar
        } || {
            echo -e "\033[1;33m Puerto de websocket:\033[1;31m ${opc2} FAIL" && sleep 2
            tput cuu1 && tput dl1
            unset opc2
        }
    done
    while :; do
        echo -ne "\033[1;37m Desea continuar [s/n]: " && read -r start
        tput cuu1 && tput dl1
        if [[ -z $start ]]; then
            echo -e "\033[1;37m debes ingresar una opcion \033[1;32m[S] \033[1;37mpara Si \033[1;31m[n] \033[1;37mpara No." && sleep 2
            tput cuu1 && tput dl1
        else
            [[ $start = @(n|N) ]] && break
            if [[ $start = @(s|S) ]]; then
                node_v=$(node_bin)
                [[ -z "$node_v" ]] && { print_center -verm2 "No se pudo instalar Node.js"; return 1; }
                echo -e "Node.js: $node_v ($($node_v --version))"
                dest_port=$(echo "${drop[$opc]}" | awk -F ":" '{print $2}')
                cat > /etc/systemd/system/nodews.$opc2.service <<EOF
[Unit]
Description=ADMRufu WebSocket Proxy (Node) puerto $opc2 -> 127.0.0.1:$dest_port
Documentation=https://github.com/titlan/sultan
After=network.target nss-lookup.target

[Service]
User=nobody
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=${node_v} --expose-gc /etc/ADMRufu/install/WS-Proxy.js -dhost 127.0.0.1 -dport ${dest_port} -mport $opc2
Restart=on-failure
RestartSec=3s

[Install]
WantedBy=multi-user.target
EOF
                systemctl daemon-reload
                systemctl enable nodews.$opc2 &>/dev/null
                systemctl start nodews.$opc2 &>/dev/null
                if systemctl is-active --quiet nodews.$opc2; then
                    print_center -verd "WebSocket activo en puerto $opc2 -> 127.0.0.1:$dest_port"
                else
                    print_center -verm2 "El servicio nodews.$opc2 no arranco. Revisa: journalctl -u nodews.$opc2 -n 30"
                    systemctl status nodews.$opc2 --no-pager -n 20 2>/dev/null || true
                fi
                enter
                break
            fi
        fi
    done
    return 1
}

stop_ws(){
    ck_ws=$(lsof -V -i tcp -P -n | grep -v "ESTABLISHED" | grep -v "COMMAND" | grep "node")
    if [[ -z $(echo "$ck_ws" | awk '{print $1}' | head -n 1) ]]; then
        print_center -verm2 "WEBSOCKET no encontrado"
    else
        ck_port=$(echo "$ck_ws" | awk '{print $9}' | awk -F ":" '{print $2}')
        for i in $ck_port; do
            systemctl stop nodews.${i} &>/dev/null
            systemctl disable nodews.${i} &>/dev/null
            rm -f /etc/systemd/system/nodews.${i}.service &>/dev/null
        done
        systemctl daemon-reload
        print_center -verm2 "WEBSOCKET detenido"
    fi
    enter
    return 1
}

stop_port(){
    clear
    STWS=$(lsof -V -i tcp -P -n | grep -v "ESTABLISHED" | grep -v "COMMAND" | grep "node" | awk '{print $9}' | awk -F ":" '{print $2}')
    title "DETENER UN PUERTO"
    n=1
    for i in $STWS; do
        echo -e " \033[1;32m[$n] \033[1;31m> \033[1;37m$i\033[0m"
        wspr[$n]=$i
        let n++
    done
    back
    echo -ne "\033[1;37m opcion: " && read -r prws
    tput cuu1 && tput dl1
    [[ $prws = "0" ]] && return
    systemctl stop nodews.${wspr[$prws]} &>/dev/null
    systemctl disable nodews.${wspr[$prws]} &>/dev/null
    rm -f /etc/systemd/system/nodews.${wspr[$prws]}.service &>/dev/null
    systemctl daemon-reload
    print_center -verm2 "PUERTO WEBSOCKET ${wspr[$prws]} detenido"
    enter
    return 1
}

encab(){
    title "SSH OVER WEBSOCKET CDN CLOUDFLARE"
}

encab
menu_func "INICIAR/AGREGAR PROXY WS CDN" "DETENER PROXY WS CDN"

sf=2
[[ $(lsof -V -i tcp -P -n | grep -v "ESTABLISHED" | grep -v "COMMAND" | grep "node" | wc -l) -ge "2" ]] && echo -e "$(msg -verd " [3]") $(msg -verm2 ">") $(msg -azu "DETENER UN PUERTO")" && sf=3
back
selection=$(selection_fun ${sf})
case ${selection} in
    1) conf;;
    2) stop_ws && read -r foo;;
    3) stop_port;;
    0) return 1;;
esac
