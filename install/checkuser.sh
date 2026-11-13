#!/bin/bash
# ADMRufu - checkuser.sh (2026-11-13)
# checkUser como el de Enigma: POST http://<IP-VPS>:6888/checkUser
# con {"user": "mexico"} -> "not exist" o fecha dd/MM/yyyy.
# Se llama desde menu_inst.sh, opcion [23] CHECKUSER.
clear
echo "=============================="
echo "  CHECKUSER (puerto 6888)"
echo "=============================="
if systemctl is-active --quiet checkuser 2>/dev/null; then
  echo "Estado: ACTIVO [ON]"
else
  echo "Estado: APAGADO [OFF]"
fi
IP=$(curl -s -m 5 ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')
echo "URL: http://$IP:6888/checkUser"
echo
echo "[1] Instalar / Iniciar checkUser"
echo "[2] Probar con un usuario"
echo "[3] Detener checkUser"
echo "[0] Volver"
echo -n "opcion: "
read -r opc
case "$opc" in
  1)
    cp /etc/ADMRufu/install/checkuser.py /usr/local/bin/checkuser.py 2>/dev/null || cp "$(dirname "$0")/checkuser.py" /usr/local/bin/checkuser.py
    chmod +x /usr/local/bin/checkuser.py
    cp /etc/ADMRufu/install/checkuser.service /etc/systemd/system/checkuser.service 2>/dev/null || cp "$(dirname "$0")/checkuser.service" /etc/systemd/system/checkuser.service
    systemctl daemon-reload
    systemctl enable --now checkuser
    sleep 1
    systemctl status checkuser --no-pager | head -n 8
    echo
    echo "Recuerda abrir el puerto 6888 TCP en el firewall de Lightsail."
    ;;
  2)
    echo -n "Usuario a consultar: "
    read -r usr
    echo "Respuesta:"
    curl -s -X POST http://127.0.0.1:6888/checkUser -H 'Content-Type: application/json' -d "{\"user\": \"$usr\"}"
    echo
    ;;
  3)
    systemctl stop checkuser 2>/dev/null; systemctl disable checkuser 2>/dev/null
    echo "checkUser detenido."
    ;;
  *) ;;
esac
echo
echo "Enter para continuar..."
read -r foo
