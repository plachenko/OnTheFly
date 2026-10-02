# Codex Chat for Godot

A Godot 4 editor dock for Codex chat, installed and enabled in OnTheFly.

## Use

1. Reopen the project, or toggle Codex Chat in Project > Project Settings > Plugins.
2. Open the **Codex** dock and click **Connect**. The plugin automatically finds
   the Codex executable on PATH or in the Codex desktop app's Windows bin folder.
   Use **Settings > Browse** if your installation is elsewhere.
3. It uses the CLI's existing login. If needed, run `codex login` in a terminal,
   then reconnect. No API key is stored in the Godot project.
4. Save your scenes/scripts, enter a request, then click **Send** or Ctrl+Enter.
   Scene and Selection include the current scene path, node paths/types and scripts.
5. Replies stream into the dock. **Stop** interrupts a turn; **New chat** starts
   a separate conversation. **Refresh files** rescans changes made on disk.

## Screenshot paint-overs

Click **Paint-over**. Choose **Capture 3D** to capture the first editor 3D viewport,
or **Open screenshot** to load a PNG, JPEG or WebP (including screenshots from the
running game). Draw with the left mouse button. Use the brush-size slider, palette or custom color picker. **Sample color**
lets you click the displayed image (including annotations) to pick a color, and
use **Undo** or **Clear** as needed. Two text fields above the image provide
**Original image context** and **Paint-over context**. Explain the current behavior
and intended changes there. Click **Attach paint-over to message**, add your request
in the dock, and send. Codex receives both the original and annotated image, each
paired with its own context text.
The original screenshot is preserved. Clear images removes pending attachments.

## Extra reference images

**Attach images** opens a multi-select file picker for PNG, JPEG and WebP references.
Each attachment appears with a thumbnail and editable context field. The remove
button removes just that image; **Clear images** removes all pending attachments.
Reference images can accompany the original screenshot and paint-over in one
message. Images are copied under `.godot/codex_chat/references/`; your source files
are preserved. Each image is sent together with its context text.

## Access and storage

The dock starts its own Codex app-server on a random loopback port with a random
connection token. It never connects to or stops the desktop app's own server.
It uses workspace-write access and on-request approvals; **Read only** starts a
new chat restricted to reading. Command/file approvals appear as Allow once/Deny.
Question prompts support buttons and typed answers. Additional permission grants
and unsupported MCP forms are declined; the chat explains that limitation.

Executable settings, conversation ID, transcript, connection token and paint-overs
live under `.godot/codex_chat/`, which Godot excludes from game exports. The token
is removed when the plugin disconnects. Codex maintains conversation history in
its own user storage. Scene context describes the editor selection; file edits
happen on disk, not through Godot's Undo/Redo stack. Stop active work before closing
the editor. This dock maintains its own conversation, separate from this chat.

## Import into another project

Extract the ZIP into a Godot 4 project so it contains
`addons/codex_chat/plugin.cfg`. Enable **Codex Chat** in Project Settings > Plugins.
Install/sign in to the Codex CLI, or point Settings to the executable bundled with
the Codex desktop app. This requires a CLI supporting authenticated WebSocket
app-server transport; it was verified with this machine's installed Codex version
and Godot 4.7.2. No Node.js or Python dependency is required by the plugin.

Protocol reference: https://developers.openai.com/codex/app-server/


## Godot Android + Codex CLI in Termux

This connects the Godot dock to your existing Codex CLI on the same phone.
It does **not** install or connect a plugin in the ChatGPT Android app.

1. Put the Godot project in shared storage that both Godot and Termux can access.
   Grant storage access with `termux-setup-storage` if you have not done so.
2. Your CLI must support `codex app-server --listen` and `--ws-auth`.
   Check `codex app-server --help`. Sign in using `codex login` if necessary.
3. The pairing helper uses Node.js built-in modules. If Node is missing, install
   it in Termux with `pkg install nodejs`.
4. In Termux, change into the folder containing `project.godot` and run:

   ```sh
   node addons/codex_chat/termux_pair.mjs
   ```

5. In Godot, enable Codex Chat, open the Codex dock, choose **Pair Termux**,
   and enter the eight-digit code shown in Termux. The dock then connects.
6. Keep Termux running while chatting. Restarting the helper creates a new token
   and code, so pair again. Closing Godot does not stop the Termux server.

Codes are valid for five minutes and one use, with five attempts. Both services
listen only on this phone's loopback interface. The short code exchanges a
random connection token; it is not your OpenAI API key or ChatGPT password.
The plugin stores the token in the project's ignored `.godot` directory.
The helper was tested on the available Windows host; Android device testing
must be completed on your phone with your installed CLI build.

## ChatGPT Android voice control — not connected yet

ChatGPT Live cannot directly call the localhost server in Termux or adopt this
pairing code. Controlling Godot from that app needs a cloud-connected ChatGPT
plugin and an authenticated relay/tunnel to the phone. This package supplies
Godot chat and local Termux pairing only; no cloud service is deployed or plugin
registered in your ChatGPT account.

The optional local inbox is for an authorized Codex session that already has
access to these project files. Enabling it does not itself connect ChatGPT:
`.godot/codex_chat/remote/status.json` reports readiness, context and transcript;
write `request.json` with a unique `id`, `action: "prompt"` and `text` to relay
an instruction. Images must be absolute paths inside the project. Actions
`interrupt` and `refresh` are also supported. Duplicate IDs are ignored, and
prompts wait until the dock is connected and idle. Enable this only when you
intend another authorized session to relay your instructions.

## Desktop voice requests through MCP

The desktop app can call a local MCP adapter that forwards your instructions to
this dock's existing inbox. Remote host pairing codes are not a registration
mechanism for this Godot plugin. The Termux code above remains separate.

1. Open Godot, click Connect in the Codex dock, and enable **Allow desktop requests**.
2. In desktop Settings > MCP servers > Add server, choose STDIO, name it
   `godot-codex`, and use your Node.js executable as the command.
3. Add the absolute path to `addons/codex_chat/desktop_mcp.mjs` as the first
   argument. Optionally add the project directory as the second argument;
   otherwise the adapter uses the project containing the script.
4. Save and restart the MCP connection as prompted. Ask the desktop chat to
   read `godot_status`, then send your authorized request using `godot_prompt`.
   Voice can provide the request when the desktop voice session supports tool use.

For this project the script path is:
`C:/Users/Shadow/Documents/OnTheFly/Food_Truck_Drive/addons/codex_chat/desktop_mcp.mjs`.
Node.js 18 or later is required for this adapter; the Godot dock still runs without Node.

Tools: `godot_status`, `godot_prompt`, `godot_interrupt`, `godot_refresh`.
The adapter rejects stale editor status, disabled inboxes, busy prompt submission,
and overwriting pending requests. A returned request ID means queued, not completed.
Check status for `last_request` acknowledgement, busy state and transcript results.
Godot approvals still appear in the Godot dock. This does not merge the two chats
or stream microphone audio into Godot. It requires both clients to access the same
local project files. No cloud endpoint, account credential or desktop modification
is introduced. Local programs with project filesystem access can also write this
inbox; the checkbox is consent to local relay, not an authentication boundary.

Official interface: https://learn.chatgpt.com/docs/extend/mcp?surface=cli
