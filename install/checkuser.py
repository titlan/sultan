#!/usr/bin/env python3
# checkUser para ADMRufu - igual que el de Enigma
# POST http://<IP-VPS>:6888/checkUser  con body {"user": "mexico"}
# Responde texto plano:
#   "not exist"              -> el usuario no existe en /etc/passwd
#   "01/01/2027"             -> fecha de vencimiento (dd/MM/yyyy) del usuario
#   "never"                  -> existe pero nunca vence
# Solo usa la libreria estandar de Python 3, sin Flask ni nada extra.
import json
import pwd
import spwd
import datetime
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

PORT = 6888

def expiry_of(username):
    """Devuelve (existe, fecha_ddmmyyyy_o_never)."""
    try:
        pwd.getpwnam(username)
    except KeyError:
        return False, None
    try:
        # /etc/shadow campo 8 = dias desde 1970-01-01 en que vence la cuenta
        days = spwd.getspnam(username).sp_expire
    except Exception:
        days = -1
    if days is None or days < 0:
        return True, "never"
    date = datetime.date(1970, 1, 1) + datetime.timedelta(days=days)
    return True, date.strftime("%d/%m/%Y")

class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        if self.path != "/checkUser":
            self._send(404, "not found")
            return
        try:
            length = int(self.headers.get("Content-Length") or 0)
            body = self.rfile.read(length).decode("utf-8", "replace")
            data = json.loads(body) if body.strip() else {}
            username = str(data.get("user", "")).strip()
        except Exception:
            self._send(400, "bad request")
            return
        if not username:
            self._send(400, "bad request")
            return
        exists, expiry = expiry_of(username)
        self._send(200, "not exist" if not exists else expiry)

    def _send(self, code, text):
        payload = text.encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def log_message(self, *args):
        # Silencioso: no llenar el log con cada consulta
        pass

if __name__ == "__main__":
    ThreadingHTTPServer(("0.0.0.0", PORT), Handler).serve_forever()
