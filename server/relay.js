// Crowns of the Wildwood room relay.
//
// Browsers (the iPad web build) cannot open the UDP links desktop ENet uses,
// so online play goes through this small WebSocket relay instead. It knows
// nothing about the game: one player CREATEs a room and gets a short code,
// others JOIN with the code, and the relay passes each binary packet to the
// peer it is addressed to. The host's game stays the authority (see
// docs/online-plan.md); this program only forwards bytes.
//
// Protocol (one WebSocket per player):
//   text frames, JSON, both ways:
//     -> {"op":"create"}               <- {"op":"created","code":"KQ7M","id":1}
//     -> {"op":"join","code":"KQ7M"}   <- {"op":"joined","code":"KQ7M","id":<n>}
//     <- {"op":"peer","id":<n>}        to the host: a joiner arrived; to a joiner: the host (1)
//     <- {"op":"left","id":<n>}        to the host: that joiner left
//     <- {"op":"closed"}               the host left: the room is gone
//     <- {"op":"error","msg":"..."}
//   binary frames: 4-byte little-endian int32, then the payload.
//     host -> relay:   the int is the target (n = that joiner, 0 = every
//                      joiner, -n = every joiner but n)
//     joiner -> relay: always delivered to the host, whatever the int says
//     relay -> player: the int is the sender's id
//
// Run: npm install && node relay.js   (PORT, default 8787)
// Health check: GET / answers "ok" with the room count.

const http = require("http");
const { WebSocketServer } = require("ws");

const PORT = parseInt(process.env.PORT || "8787", 10);
const MAX_PEERS = parseInt(process.env.MAX_PEERS || "8", 10);       // joiners per room
const MAX_ROOMS = parseInt(process.env.MAX_ROOMS || "500", 10);
const MAX_PACKET = +(process.env.MAX_PACKET || 1024 * 1024);   // one game packet (a big first snapshot fits)
const CODE_CHARS = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"; // no 0/O, 1/I

const rooms = new Map(); // code -> { host: ws, peers: Map<id, ws>, next: int }

function send(ws, obj) {
  if (ws.readyState === ws.OPEN) ws.send(JSON.stringify(obj));
}

function newCode() {
  for (let tries = 0; tries < 1000; tries++) {
    let c = "";
    for (let i = 0; i < 4; i++) c += CODE_CHARS[Math.floor(Math.random() * CODE_CHARS.length)];
    if (!rooms.has(c)) return c;
  }
  return null;
}

function members(room) {
  return room.peers; // includes the host as id 1
}

function leave(ws) {
  const room = ws.room && rooms.get(ws.room);
  if (!room) return;
  room.peers.delete(ws.id);
  if (ws.id === 1) {
    for (const p of room.peers.values()) {
      send(p, { op: "closed" });
      p.room = null;
      p.close(1000, "host left");
    }
    rooms.delete(ws.room);
    log(`room ${ws.room} closed`);
  } else {
    send(room.peers.get(1), { op: "left", id: ws.id });
    log(`room ${ws.room}: peer ${ws.id} left (${room.peers.size} in room)`);
  }
  ws.room = null;
}

function log(msg) {
  console.log(new Date().toISOString() + " " + msg);
}

const server = http.createServer((req, res) => {
  res.writeHead(200, { "Content-Type": "text/plain", "Access-Control-Allow-Origin": "*" });
  res.end(`ok ${rooms.size} rooms\n`);
});

const wss = new WebSocketServer({ server, maxPayload: MAX_PACKET });

wss.on("connection", (ws) => {
  ws.room = null;
  ws.id = 0;
  ws.alive = true;
  ws.on("pong", () => (ws.alive = true));

  ws.on("message", (data, isBinary) => {
    ws.alive = true;   // anything it sends proves the link is alive
    if (!isBinary) {
      let msg;
      try {
        msg = JSON.parse(data.toString());
      } catch {
        return send(ws, { op: "error", msg: "bad message" });
      }
      if (ws.room) return send(ws, { op: "error", msg: "already in a room" });
      if (msg.op === "create") {
        if (rooms.size >= MAX_ROOMS) return send(ws, { op: "error", msg: "the server is full" });
        const code = newCode();
        if (!code) return send(ws, { op: "error", msg: "no free room codes" });
        rooms.set(code, { peers: new Map([[1, ws]]), next: 2 });
        ws.room = code;
        ws.id = 1;
        send(ws, { op: "created", code, id: 1 });
        log(`room ${code} created`);
      } else if (msg.op === "join") {
        const code = String(msg.code || "").toUpperCase().trim();
        const room = rooms.get(code);
        if (!room) return send(ws, { op: "error", msg: `no room ${code}` });
        if (room.peers.size > MAX_PEERS) return send(ws, { op: "error", msg: "that room is full" });
        const id = room.next++;
        ws.room = code;
        ws.id = id;
        send(ws, { op: "joined", code, id });
        // Star layout: joiners only ever see the host, the host sees everyone.
        send(room.peers.get(1), { op: "peer", id });
        send(ws, { op: "peer", id: 1 });
        room.peers.set(id, ws);
        log(`room ${code}: peer ${id} joined (${room.peers.size} in room)`);
      } else {
        send(ws, { op: "error", msg: "unknown op" });
      }
      return;
    }
    // Binary: forward to the addressed peer(s) in the same room.
    const room = ws.room && rooms.get(ws.room);
    if (!room || data.length < 4) return;
    // Joiners talk to the host only; the host can address anyone.
    const target = ws.id === 1 ? data.readInt32LE(0) : 1;
    data.writeInt32LE(ws.id, 0); // receivers see the sender
    for (const [pid, p] of members(room)) {
      if (pid === ws.id) continue;
      if (target > 0 && pid !== target) continue;
      if (target < 0 && pid === -target) continue;
      if (p.readyState === p.OPEN) p.send(data, { binary: true });
    }
  });

  ws.on("close", (code, reason) => {
    if (ws.room) log(`room ${ws.room}: peer ${ws.id} closed (${code}${reason && reason.length ? " " + reason : ""})`);
    leave(ws);
  });
  ws.on("error", () => leave(ws));
});

// Drop dead connections (a tablet that went to sleep): a ping every 20 s,
// and a link that misses MISSED_PINGS in a row is closed. Lenient on purpose:
// a browser busy building a match reads nothing (so answers no ping) for a while.
const MISSED_PINGS = +(process.env.MISSED_PINGS || 4);
setInterval(() => {
  for (const ws of wss.clients) {
    ws.missed = ws.alive ? 0 : (ws.missed || 0) + 1;
    if (ws.missed >= MISSED_PINGS) {
      ws.terminate();
      continue;
    }
    ws.alive = false;
    ws.ping();
  }
}, 20000);

server.listen(PORT, () => log(`relay listening on ${PORT}`));
