import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtemp, mkdir, writeFile, readFile, rm} from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import {createBridge, handle} from '../addons/codex_chat/desktop_mcp.mjs';
test('desktop MCP handshake and tool errors', async () => {
  const init = await handle({id:1,method:'initialize',params:{protocolVersion:'2024-11-05'}},()=>{});
  assert.equal(init.result.serverInfo.name,'godot-codex');
  assert.equal((await handle({id:2,method:'tools/list'},()=>{})).result.tools.length,4);
  assert.equal(await handle({method:'notifications/initialized'},()=>{}),null);
  const result = await handle({id:3,method:'tools/call',params:{name:'godot_status'}},()=>{throw new Error('offline');});
  assert.equal(result.result.isError,true);
});
test('inbox consent, freshness, queue protection and acknowledgement', async () => {
  const project = await mkdtemp(path.join(os.tmpdir(),'godot-mcp-'));
  const directory = path.join(project,'.godot/codex_chat/remote');
  await mkdir(directory,{recursive:true});
  const call = createBridge(project);
  const state = {enabled:false,connected:true,busy:false,last_request:'',updated_at:new Date().toISOString().replace(/\.\d{3}Z$/,'')};
  const save = () => writeFile(path.join(directory,'status.json'),JSON.stringify(state));
  try {
    await save();
    await assert.rejects(call('godot_prompt',{text:'Test'}),/Enable/);
    state.enabled=true; state.busy=true; await save();
    await assert.rejects(call('godot_prompt',{text:'Test'}),/idle/);
    state.busy=false; await save();
    const queued = await call('godot_prompt',{text:'Change the scene'});
    assert.equal(queued.queued,true);
    const request = JSON.parse(await readFile(path.join(directory,'request.json'),'utf8'));
    assert.equal(request.text,'Change the scene');
    await assert.rejects(call('godot_prompt',{text:'Second'}),/pending/);
    state.last_request=request.id; await save();
    assert.equal((await call('godot_interrupt')).queued,true);
    state.updated_at='2000-01-01T00:00:00'; await save();
    await assert.rejects(call('godot_status'),/stale/);
  } finally { await rm(project,{recursive:true,force:true}); }
});
