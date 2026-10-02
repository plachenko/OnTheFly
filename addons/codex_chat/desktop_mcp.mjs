import {readFile, writeFile, rename, mkdir} from 'node:fs/promises';
import path from 'node:path';
import readline from 'node:readline';
import {randomUUID} from 'node:crypto';
import {fileURLToPath} from 'node:url';

export function createBridge(project) {
  const directory = path.join(path.resolve(project), '.godot', 'codex_chat', 'remote');
  async function status() {
    const state = JSON.parse(await readFile(path.join(directory, 'status.json'), 'utf8'));
    const age = Date.now() - Date.parse(state.updated_at + (/[Z+-]\d*:?\d*$/.test(state.updated_at) ? '' : 'Z'));
    if (!Number.isFinite(age) || age > 10000 || age < -10000) throw new Error('Godot status is stale. Open the editor and enable the inbox.');
    return state;
  }
  return async function call(name, args = {}) {
    const state = await status();
    if (name === 'godot_status') return state;
    if (!state.enabled) throw new Error('Enable Allow desktop requests in the Godot Codex dock.');
    const actions = {godot_prompt:'prompt', godot_interrupt:'interrupt', godot_refresh:'refresh'};
    const action = actions[name];
    if (!action) throw new Error('Unknown tool.');
    if (action === 'prompt' && (!state.connected || state.busy)) throw new Error('Godot Codex must be connected and idle before sending a prompt.');
    if (action === 'refresh' && state.busy) throw new Error('Wait for the current Godot turn before refreshing.');
    if (action === 'prompt' && (typeof args.text !== 'string' || !args.text.trim() || args.text.length > 100000)) throw new Error('Provide a nonempty prompt of at most 100000 characters.');
    const target = path.join(directory, 'request.json');
    try {
      const previous = JSON.parse(await readFile(target, 'utf8'));
      if (previous.id && previous.id !== state.last_request) throw new Error('A request is already pending. Wait for Godot to accept it.');
    } catch (error) { if (error.code !== 'ENOENT') throw error; }
    const request = {id:randomUUID(), action, ...(action === 'prompt' ? {text:args.text} : {})};
    await mkdir(directory, {recursive:true});
    const temporary = target + '.' + request.id + '.tmp';
    await writeFile(temporary, JSON.stringify(request), {flag:'wx'});
    await rename(temporary, target);
    return {queued:true, request_id:request.id, message:'Queued locally. Call godot_status to confirm last_request and observe busy/transcript. This is not completion.'};
  };
}
const tools = [
  {name:'godot_status', description:'Read live Godot editor context, connection, busy state, request acknowledgement and Codex transcript. Read this before sending work.', inputSchema:{type:'object',properties:{},additionalProperties:false}, annotations:{readOnlyHint:true}},
  {name:'godot_prompt', description:'Send the user\'s authorized instruction to Codex in the Godot editor. Starts a separate Codex turn that may edit project files. Requires inbox enabled, connected and idle. Check godot_status afterwards; queued is not completed.', inputSchema:{type:'object',properties:{text:{type:'string',minLength:1,maxLength:100000}},required:['text'],additionalProperties:false}, annotations:{readOnlyHint:false,destructiveHint:true}},
  {name:'godot_interrupt', description:'Ask the Godot Codex dock to stop its active turn.', inputSchema:{type:'object',properties:{},additionalProperties:false}, annotations:{readOnlyHint:false}},
  {name:'godot_refresh', description:'Rescan project files in Godot after changes on disk.', inputSchema:{type:'object',properties:{},additionalProperties:false}, annotations:{readOnlyHint:false}}
];
export async function handle(message, call) {
  const {id, method, params = {}} = message;
  if (id === undefined) return null;
  try {
    let result;
    if (method === 'initialize') result = {protocolVersion:params.protocolVersion || '2024-11-05',capabilities:{tools:{}},serverInfo:{name:'godot-codex',version:'1.0.0'},instructions:'Relay only user-authorized Godot work. Read status first. A queued request is not completion. Godot runs a separate Codex conversation; poll status for acknowledgement and results.'};
    else if (method === 'ping') result = {};
    else if (method === 'tools/list') result = {tools};
    else if (method === 'tools/call') {
      if (!tools.some(tool => tool.name === params.name)) return {jsonrpc:'2.0',id,error:{code:-32602,message:'Unknown tool'}};
      try { result = {content:[{type:'text',text:JSON.stringify(await call(params.name, params.arguments))}]}; }
      catch (error) { result = {isError:true,content:[{type:'text',text:error.message}]}; }
    } else return {jsonrpc:'2.0',id,error:{code:-32601,message:'Method not found'}};
    return {jsonrpc:'2.0',id,result};
  } catch (error) { return {jsonrpc:'2.0',id,error:{code:-32603,message:error.message}}; }
}
if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const call = createBridge(process.argv[2] || path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..'));
  const lines = readline.createInterface({input:process.stdin});
  for await (const line of lines) {
    try { const response = await handle(JSON.parse(line), call); if (response) process.stdout.write(JSON.stringify(response) + '\n'); }
    catch { process.stdout.write(JSON.stringify({jsonrpc:'2.0',id:null,error:{code:-32700,message:'Parse error'}}) + '\n'); }
  }
}
