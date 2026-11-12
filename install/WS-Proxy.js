#!/usr/bin/env node
/*
 * Proxy Bridge - ACTUALIZADO 2026-11-12 (ADMRufu)
 * Original: Copyright PANCHO7532 - P7COMUnications LLC (c) 2021
 * Dedicado a Emanuel Miranda.
 *
 * Cambios vs 2021:
 * - 'use strict', variables declaradas, puertos con parseInt (antes
 *   packetsToSkip era string y la comparacion fallaba en algunos casos).
 * - Manejo de errores en ambos lados (socket y conexion destino):
 *   antes un error en conn antes de conectar dejaba el socket colgado.
 * - Timeout de 5 min sin actividad, para no dejar conexiones muertas.
 * - Log con fecha a stdout (systemd lo guarda en journalctl).
 * - --expose-gc ya no es obligatorio: el GC corre solo si esta activo,
 *   sin el warning cada segundo si no lo esta.
 * - Misma conducta de cara al cliente: responde HTTP/1.1 101 y
 *   reenvia los paquetes despues de saltar `packetsToSkip`.
 * Uso: node WS-Proxy.js -dhost 127.0.0.1 -dport 109 -mport 80 [-skip 1]
 */
'use strict';
const net = require('net');

let dhost = '127.0.0.1';
let dport = 8080;
let mainPort = 8888;
let packetsToSkip = 0;

for (let c = 0; c < process.argv.length; c++) {
  switch (process.argv[c]) {
    case '-skip': packetsToSkip = parseInt(process.argv[c + 1], 10) || 0; break;
    case '-dhost': dhost = process.argv[c + 1]; break;
    case '-dport': dport = parseInt(process.argv[c + 1], 10) || 8080; break;
    case '-mport': mainPort = parseInt(process.argv[c + 1], 10) || 8888; break;
  }
}

function log(msg) {
  console.log(`[${new Date().toISOString()}] ${msg}`);
}

if (global.gc) setInterval(() => { try { global.gc(); } catch (e) {} }, 5000);

const server = net.createServer();
server.on('connection', (socket) => {
  let packetCount = 0;
  socket.setTimeout(5 * 60 * 1000, () => socket.destroy());
  socket.write('HTTP/1.1 101 Switching Protocols\r\nContent-Length: 1048576000000\r\n\r\n');
  log(`Connection received from ${socket.remoteAddress}:${socket.remotePort}`);

  const conn = net.createConnection({ host: dhost, port: dport });
  conn.setTimeout(5 * 60 * 1000, () => conn.destroy());

  conn.on('connect', () => log(`Redirecting to ${dhost}:${dport}`));
  conn.on('error', (err) => { log(`[REMOTE] ${err.message}`); socket.destroy(); });
  conn.on('data', (data) => { if (!socket.destroyed) socket.write(data); });
  conn.on('close', () => { if (!socket.destroyed) socket.destroy(); });

  socket.on('data', (data) => {
    if (packetCount < packetsToSkip) { packetCount++; return; }
    if (conn.writable) conn.write(data);
  });
  socket.on('error', (err) => { log(`[SOCKET] ${err.message}`); conn.destroy(); });
  socket.on('close', () => { log(`Connection terminated for ${socket.remoteAddress}:${socket.remotePort}`); conn.destroy(); });
});

server.on('error', (err) => { log(`[SERVER] ${err.message}`); process.exit(1); });
server.listen(mainPort, () => {
  log(`Server started on port: ${mainPort}`);
  log(`Redirecting requests to: ${dhost} at port ${dport}`);
});
