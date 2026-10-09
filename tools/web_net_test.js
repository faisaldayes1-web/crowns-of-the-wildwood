// Browser-to-browser online test: two Chromium pages run the web export and
// play through the room relay (server/relay.js), the way two iPads would.
//
//   1. UI: the host taps ONLINE > CREATE ROOM, the joiner taps ONLINE, taps
//      the code in on the letter pad and taps JOIN, the host taps CHOOSE MAP >
//      START MATCH > START MATCH, and the joiner must get its seat.
//   2. Gameplay: the same --net-test the headless smoke test runs (walking,
//      a swing, effects, chat), through the relay, both pages in the browser.
//
// Needs a web export first (Godot 4.3, the "Web" preset), then:
//   godot --headless --export-release "Web" /tmp/web/index.html
//   NODE_PATH=$(npm root -g) node tools/web_net_test.js /tmp/web
//
// Writes screenshots and console logs to $OUT (default: a temp folder).
const { chromium } = require("playwright");
const http = require("http");
const fs = require("fs");
const path = require("path");
const os = require("os");
const { spawn } = require("child_process");

const WEB = path.resolve(process.argv[2] || "web");
const OUT = process.env.OUT || fs.mkdtempSync(path.join(os.tmpdir(), "webnet-"));
const HTTP_PORT = +(process.env.HTTP_PORT || 8099);
const RELAY_PORT = +(process.env.RELAY_PORT || 8798);
const RELAY = `ws://127.0.0.1:${RELAY_PORT}`;
const W = 1280, H = 720;   // the game's own viewport size: page pixels are the menus' pixels

const TYPES = { ".html": "text/html", ".js": "text/javascript", ".wasm": "application/wasm", ".pck": "application/octet-stream", ".png": "image/png" };

function serve() {
  // The export as is, except the page takes its command line from ?a=...
  // (tests only; the published page is untouched).
  return http.createServer((req, res) => {
    let file = decodeURIComponent(req.url.split("?")[0]);
    if (file === "/") file = "/index.html";
    const p = path.join(WEB, path.normalize(file));
    if (!p.startsWith(WEB) || !fs.existsSync(p)) { res.writeHead(404); res.end(); return; }
    let body = fs.readFileSync(p);
    if (file === "/index.html") {
      body = body.toString().replace('"args":[]',
        '"args":(new URLSearchParams(location.search).get("a")||"").split(" ").filter(Boolean)');
    }
    res.writeHead(200, { "Content-Type": TYPES[path.extname(p)] || "application/octet-stream" });
    res.end(body);
  }).listen(HTTP_PORT);
}

const browsers = [];

async function open(name, args) {
  // One browser per player, like two iPads (and neither is a background tab).
  const browser = await chromium.launch({ args: ["--use-gl=angle", "--use-angle=swiftshader", "--enable-unsafe-swiftshader",
    "--autoplay-policy=no-user-gesture-required", "--disable-renderer-backgrounding", "--disable-background-timer-throttling",
    "--disable-backgrounding-occluded-windows"] });
  browsers.push(browser);
  const page = await browser.newPage({ viewport: { width: W, height: H } });
  const log = [];
  page.on("console", (m) => { log.push(m.text()); fs.appendFileSync(path.join(OUT, name + ".log"), m.text() + "\n"); });
  page.on("pageerror", (e) => log.push("PAGEERROR " + e.message));
  const a = ["--", "--relay=" + RELAY, ...args].join(" ");
  await page.goto(`http://127.0.0.1:${HTTP_PORT}/index.html?a=${encodeURIComponent(a)}`);
  return { page, log, name, browser };
}

async function until(p, re, ms) {
  const t0 = Date.now();
  while (Date.now() - t0 < ms) {
    const hit = p.log.find((l) => re.test(l));
    if (hit) return hit;
    await new Promise((r) => setTimeout(r, 250));
  }
  throw new Error(`${p.name}: no "${re}" within ${ms / 1000} s`);
}

async function tap(p, x, y, what) {
  // Held for a while: a software-rendered page runs a few frames a second,
  // and the menus look for the press on a frame.
  await p.page.mouse.move(x, y);
  await p.page.waitForTimeout(500);
  await p.page.mouse.down();
  await p.page.waitForTimeout(700);
  await p.page.mouse.up();
  console.log(`${p.name}: tap ${what}`);
  await p.page.waitForTimeout(2000);
  if (process.env.SHOTS) await shot(p, "tap-" + what.replace(/\W+/g, "_"));
}

// Screenshots are for looking at afterwards; a slow page must not fail the test.
const shot = (p, n) => p.page.screenshot({ path: path.join(OUT, `${p.name}-${n}.png`), timeout: 120000 }).catch((e) => console.log(`${p.name}: no screenshot ${n}`));

// Where the buttons are at 1280x720 (scripts/menu.gd).
const ONLINE_PLANK = [226, 643];
const LEFT_BIG = [370, 463];        // CREATE ROOM, then CHOOSE MAP
const CODE_CHARS = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
const key = (ch) => { const i = CODE_CHARS.indexOf(ch); return [714 + (i % 8) * 56, 263 + Math.floor(i / 8) * 48]; };
const JOIN = [983, 467];
const DELETE = [754, 467];
const MAP_START = [640, 655];
const LOBBY_START = [1028, 680];

async function uiTest() {
  const host = await open("ui-host", []);
  const joiner = await open("ui-joiner", []);
  await until(host, /NET ready/, 180000);
  await until(joiner, /NET ready/, 180000);
  // A software-rendered page can still be busy after the title is up and
  // drop a tap, so each step is retried until its result shows in the log.
  let code = null;
  for (let i = 0; i < 4 && !code; i++) {
    await host.page.waitForTimeout(6000);
    await tap(host, ...ONLINE_PLANK, "ONLINE");
    await tap(host, ...LEFT_BIG, "CREATE ROOM");
    code = await until(host, /NET room \w+ created/, 30000).then((l) => l.match(/room (\w+)/)[1], () => null);
  }
  if (!code) throw new Error("ui-host: CREATE ROOM never made a room");
  console.log("room code", code);
  await shot(host, "1-room");
  let joined = false;
  for (let i = 0; i < 4 && !joined; i++) {
    await tap(joiner, ...ONLINE_PLANK, "ONLINE");
    for (let k = 0; k < 4; k++) await tap(joiner, ...DELETE, "DELETE");
    for (const ch of code) await tap(joiner, ...key(ch), ch);
    await shot(joiner, "1-code");
    await tap(joiner, ...JOIN, "JOIN");
    joined = await until(joiner, /NET welcomed/, 30000).then(() => true, () => false);
  }
  if (!joined) throw new Error("ui-joiner: JOIN never reached the host");
  await until(host, /NET peer \d+ ready/, 180000);
  await joiner.page.waitForTimeout(2000);
  await shot(joiner, "2-waiting");
  await shot(host, "2-joined");
  await tap(host, ...LEFT_BIG, "CHOOSE MAP");
  await tap(host, ...MAP_START, "START MATCH (map)");
  await tap(host, ...LOBBY_START, "START MATCH (lobby)");
  await until(joiner, /NET slot/, 900000);
  // Walk the joiner's hero for a few seconds, then look at both screens.
  await joiner.page.waitForTimeout(8000);
  await joiner.page.mouse.click(640, 360);
  for (const k of ["KeyW", "KeyD", "KeyS"]) {
    await joiner.page.keyboard.down(k);
    await joiner.page.waitForTimeout(1500);
    await joiner.page.keyboard.up(k);
  }
  await shot(joiner, "3-match");
  await shot(host, "3-match");
  const errs = [...host.log, ...joiner.log].filter((l) => /SCRIPT ERROR|PAGEERROR|NET host closed|NET peer \d+ left/.test(l));
  await host.browser.close();
  await joiner.browser.close();
  if (errs.length) throw new Error("ui: errors:\n" + errs.slice(0, 10).join("\n"));
  console.log("UI TEST PASS");
}

async function gameplayTest() {
  const host = await open("net-host", ["--room-create", "--net-test"]);
  const code = (await until(host, /NET room \w+ created/, 180000)).match(/room (\w+)/)[1];
  const joiner = await open("net-joiner", ["--room-join=" + code, "--net-test"]);
  const done = await Promise.all([until(host, /NETTEST host (PASS|FAIL)/, 600000), until(joiner, /NETTEST client (PASS|FAIL)/, 600000)]);
  for (const l of [...host.log, ...joiner.log].filter((l) => /^NET/.test(l))) console.log("  " + l);
  await host.browser.close();
  await joiner.browser.close();
  if (!done.every((l) => /PASS/.test(l))) throw new Error("gameplay: " + done.join(" / "));
  console.log("GAMEPLAY TEST PASS");
}

(async () => {
  console.log("web net test: logs and screenshots in", OUT);
  const relay = spawn("node", [path.join(__dirname, "..", "server", "relay.js")], { env: { ...process.env, PORT: String(RELAY_PORT) }, stdio: ["ignore", fs.openSync(path.join(OUT, "relay.log"), "a"), "inherit"] });
  const server = serve();
  let ok = true;
  for (const t of (process.env.ONLY ? [process.env.ONLY] : ["ui", "gameplay"])) {
    try {
      await (t === "ui" ? uiTest : gameplayTest)();
    } catch (e) {
      ok = false;
      console.log(`${t.toUpperCase()} TEST FAIL: ${e.message}`);
    }
  }
  for (const b of browsers) await b.close().catch(() => {});
  server.close();
  relay.kill();
  console.log(ok ? "WEB NET TEST PASS" : "WEB NET TEST FAIL");
  process.exit(ok ? 0 : 1);
})();
