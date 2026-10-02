import test from 'node:test';
import assert from 'node:assert/strict';
import {makePairingServer} from '../addons/codex_chat/termux_pair.mjs';
async function service(options, run) {
  const server = makePairingServer({code:'12345678',token:'test-token',serverUrl:'ws://127.0.0.1:45000',expiresAt:Date.now()+60000,...options});
  await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
  const url = `http://127.0.0.1:${server.address().port}/pair`;
  const pair = (code, headers={})=>fetch(url,{method:'POST',headers:{'Content-Type':'application/json',...headers},body:JSON.stringify({code})});
  try { await run(pair); } finally { await new Promise(resolve=>server.close(resolve)); }
}
test('pairing is one-use, rejects browser origins and incorrect codes',async()=>service({},async pair=>{
  assert.equal((await pair('12345678',{Origin:'https://untrusted.example'})).status,403);
  assert.equal((await pair('00000000')).status,401);
  const accepted=await pair('12345678');
  assert.equal(accepted.status,200);
  assert.deepEqual(await accepted.json(),{server_url:'ws://127.0.0.1:45000',token:'test-token'});
  assert.equal((await pair('12345678')).status,410);
}));
test('codes expire and lock after five incorrect attempts',async()=>{
  await service({expiresAt:Date.now()-1},async pair=>assert.equal((await pair('12345678')).status,410));
  await service({},async pair=>{
    for(let i=0;i<5;i++) assert.equal((await pair('00000000')).status,401);
    assert.equal((await pair('12345678')).status,410);
  });
});
