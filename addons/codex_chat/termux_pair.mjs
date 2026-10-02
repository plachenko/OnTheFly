import http from 'node:http';
import net from 'node:net';
import crypto from 'node:crypto';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {spawn} from 'node:child_process';
import {pathToFileURL} from 'node:url';

export function makePairingServer({code, token, serverUrl, expiresAt, maxAttempts = 5}) {
  let attempts = 0;
  let paired = false;
  return http.createServer((req, res) => {
    const reply = (status, value) => {
      res.writeHead(status, {'Content-Type': 'application/json', 'Cache-Control': 'no-store'});
      res.end(JSON.stringify(value));
    };
    if (req.method !== 'POST' || req.url !== '/pair' || req.headers.origin) return reply(403, {error: 'Pair from the Godot plugin.'});
    if (paired || Date.now() > expiresAt || attempts >= maxAttempts) return reply(410, {error: 'Code used, expired or locked. Restart the helper for a new code.'});
    let body = '';
    req.on('data', chunk => {
      body += chunk;
      if (body.length > 2048) req.destroy();
    });
    req.on('end', () => {
      let input;
      try { input = JSON.parse(body); } catch { attempts++; return reply(400, {error: 'Invalid pairing request.'}); }
      // Check again: another request may have redeemed the code while this body arrived.
      if (paired || Date.now() > expiresAt || attempts >= maxAttempts) return reply(410, {error: 'Restart the helper for a new code.'});
      attempts++;
      const actual = Buffer.from(String(input.code ?? ''));
      const expected = Buffer.from(code);
      if (actual.length !== expected.length || !crypto.timingSafeEqual(actual, expected)) return reply(401, {error: 'Incorrect pairing code.'});
      paired = true;
      reply(200, {server_url: serverUrl, token});
      console.error('Godot paired. Keep this Termux session running.');
    });
  });
}

async function main() {
  const project = process.cwd();
  if (!fs.existsSync(path.join(project, 'project.godot'))) throw new Error('Run this helper from the Godot project folder containing project.godot.');
  const executable = process.argv[2] || 'codex';
  const privateDir = fs.mkdtempSync(path.join(os.tmpdir(), 'godot-codex-'));
  fs.chmodSync(privateDir, 0o700);
  const tokenFile = path.join(privateDir, 'token');
  const token = crypto.randomBytes(32).toString('hex');
  fs.writeFileSync(tokenFile, token, {mode: 0o600});
  const serverUrl = 'ws://127.0.0.1:45000';
  const child = spawn(executable, ['app-server', '--listen', serverUrl, '--ws-auth', 'capability-token', '--ws-token-file', tokenFile], {cwd: project, stdio: ['ignore', 'pipe', 'pipe']});
  child.stdout.pipe(process.stderr);
  child.stderr.pipe(process.stderr);
  let pairing;
  let stopping = false;
  const cleanup = () => {
    if (stopping) return;
    stopping = true;
    pairing?.close();
    child.kill();
    fs.rmSync(privateDir, {recursive: true, force: true});
  };
  process.once('SIGINT', () => { cleanup(); process.exit(0); });
  process.once('SIGTERM', () => { cleanup(); process.exit(0); });
  child.once('error', error => { console.error(`Could not start Codex: ${error.message}`); cleanup(); process.exitCode = 1; });
  child.once('exit', code => { cleanup(); process.exitCode = code || 0; });
  // Wait for the app-server listener before offering a code.
  for (let attempt = 0; attempt < 60; attempt++) {
    if (stopping) return;
    const ready = await new Promise(resolve => {
      const socket = net.connect({host: '127.0.0.1', port: 45000});
      socket.setTimeout(200);
      socket.once('connect', () => { socket.destroy(); resolve(true); });
      socket.once('error', () => { socket.destroy(); resolve(false); });
      socket.once('timeout', () => { socket.destroy(); resolve(false); });
    });
    if (ready) break;
    if (attempt === 59) { cleanup(); throw new Error('Codex did not start. Check that your CLI supports authenticated app-server WebSockets.'); }
    await new Promise(resolve => setTimeout(resolve, 200));
  }
  const code = crypto.randomInt(10000000, 100000000).toString();
  pairing = makePairingServer({code, token, serverUrl, expiresAt: Date.now() + 5*60*1000});
  pairing.once('error', error => { console.error(error.message); cleanup(); process.exitCode = 1; });
  pairing.listen(45001, '127.0.0.1', () => {
    console.log(`\nGodot pairing code: ${code.slice(0,4)} ${code.slice(4)}\nValid for five minutes, one use. In Godot: Codex dock > Pair Termux.\nThis connects Godot to Codex; it does not register a ChatGPT Android plugin.\nKeep Termux running. Press Ctrl+C to stop.\n`);
  });
}
if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) {
  main().catch(error => { console.error(error.message); process.exitCode = 1; });
}
