# Codex Chat for Godot

A Godot 4 editor dock for Codex chat, installed and enabled in OnTheFly.

## Use

1. Reopen the project, or toggle Codex Chat in Project > Project Settings > Plugins.
2. Open the **Codex** dock and click **Connect**. The plugin automatically finds
   the Codex executable on PATH or in the Codex desktop app's Windows bin folder.
   Use **Settings > Browse** if your installation is elsewhere.
3. It uses the CLI's existing login. If needed, run `codex login` in a terminal,
   then reconnect. No API key is stored in the Godot project.
4. Save your scenes/scripts, enter a request, then click **↵** beside the prompt.
   Settings → **Enter sends message** is enabled by default; Shift+Enter adds a
   new line. Turn it off to use Enter for new lines and the button to send.
   During a response the same square space shows an animated Stop button.
   Mic is on the left of the prompt. Disconnected controls show Connect and the
   settings gear; text zoom controls are inside Settings.
   Scene and Selection include the current scene path, node paths/types and scripts.
5. Replies stream into the dock. **Stop** interrupts a turn; **New chat** starts
   a separate conversation. **Refresh files** rescans changes made on disk.

Display, context, connection, and bumper profiling controls are under **Settings**
to leave more room for responses. Empty attachment previews stay hidden.
**Render Markdown** in Settings is enabled by default. The transcript supports headings,
bold/italic/strikethrough text, inline and fenced code, lists, quotes, pipe tables,
and clickable HTTP/HTTPS links. Uncheck to view raw Markdown. Original source
is saved so formatting survives reconnects. Streamed rendering updates at most
ten times per second; literal BBCode is escaped and inline images are not loaded.

## Windows connection

On Windows, use **Connect Windows** to select the local Codex connection and
reuse your CLI login. This overrides Termux mode; no pairing code is required.
Settings includes **Find local Codex** and **Browse** if detection fails.

## Bumper profiling

Double-tap LB in the game to open the bottom-center Codex dictation menu.
It plays a chime and records microphone speech with the existing local Whisper
model. LB cancels; RB stops recording, transcribes, and queues the message for
the connected dock's current conversation. Gameplay continues. A timing control
in the menu saves a custom 150–800 ms double-tap window; single-tap captures wait
for that window so opening the menu does not also take a photo. Sequence queue
editing and synchronized live voice/frame capture are tracked in
`CODEX_MENU_TODO.md` for later work.

Enable **LB profiling** in the dock. Tap LB for the recent profiling window;
hold it to capture until release (maximum 1–30 seconds, selected in the dock).
Enter context such as "standing still; patrons enabled" beside these controls.
The game shows **Captured**: press RB to send, or LB to cancel. **Auto-send
captured profiles** skips confirmation. These settings are off by default.
Use **D-pad Right** for physics ticks or **D-pad Left** for rendered frames.
You can also switch on the captured report before sending; both datasets cover
the same capture window. The prompt appears in a padded panel at the bottom center.

Physics reports contain one row per tick, with tick IDs, rendered-process frame
IDs, simulation step, wall interval, measured section times and section update
counts. Multiple ticks sharing a process frame identify catch-up work. Section
times measure instrumented callbacks, not Godot's physics solver. Wall intervals
and simulation steps are not CPU durations. GPU time remains unmeasured.

Reports queue locally until the enabled, connected dock is idle and go to its
current conversation. Sending preserves unsent drafts and image attachments.
Profiles contain frame/CPU timings, measured sections, patron counts, debug
settings and scene/camera/truck context. They do not capture images or videos.
The video replay buffer pauses while bumper profiling is enabled. With profiling
disabled, LB retains its screenshot/video behavior. This editor integration uses
the project's ignored `.godot/codex_chat/profiling` directory.

## Existing project conversations

After connecting, click **Project chats…**. The picker lists saved conversations
for this project and its parent workspace from the connected Codex server's
history store. **More** loads another page; you can also paste a thread ID.

**Import context** copies recent user/assistant messages into your next prompt
as reference data without switching your current conversation. Imports retain
up to 24,000 characters and disclose truncation or unavailable history. Pending
context is saved across editor restarts and consumed by the next sent message.

**Resume chat** continues the selected conversation using Codex's thread API.
Active chats are refused; wait for them to finish or import their context.
Unsupported desktop history formats or inaccessible threads show an error and
leave your current dock conversation intact. The connection must use the same
Codex history store/account to discover desktop chats. No history files are
copied or modified directly, and no message is sent until you click Send.

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
## Blender bridge

Install `tools/blender_bridge_addon.zip` using Blender's Preferences → Add-ons →
Install from Disk, then enable **OnTheFly Codex Bridge**. In the 3D View sidebar
(N), open **Codex**, select this Godot project directory (the folder containing
`project.godot`), and click **Start bridge**. In the Godot panel, open
**Settings → Blender bridge… → Connect / inspect**. The scene summary includes
objects, selection, transforms, materials and mesh counts. **Export selected GLB**
exports selected Blender objects into `assets/blender_exports/`, refreshes Godot,
and records the changed file when conversation archiving is enabled. Use Object
Mode for export. Export paths must be new `.glb` files inside the project assets
folder; existing files cannot be overwritten. Stop the bridge in Blender when
finished. Installation and GLB export were tested with Steam Blender 5.2.2 LTS.

To connect across devices, install the add-on in the target Blender instance,
enable **Allow network connections**, and click **Start bridge**. Copy its port
and pairing token. In Godot's **Settings → Blender bridge…**, enable **Connect to
a remote Blender instance**, enter `http://HOST_IP:PORT` and the token, then click
**Connect / inspect**. The Blender project directory is optional in network mode.
Each Blender instance can use its own port; port 0 chooses an available port.
Restarting the bridge creates a new token. Instances are selected by address,
without automatic discovery. Windows Firewall may need to allow Blender on the
private network.

Use a trusted LAN or VPN: the HTTP connection is unencrypted. The target must be
reachable and running the companion add-on. Android Godot can use the same remote
connection. No shared project folder is required; exported GLBs transfer into the
Godot project's assets folder (maximum 64 MiB per export).

Codex can use `python tools/blender_bridge.py --project . inspect` or
`python tools/blender_bridge.py --project . export_selected --output
assets/blender_exports/new_asset.glb`. The CLI uses the remote connection saved by
the panel, or the local project inbox when remote mode is disabled. Pairing details
stay in ignored local settings, outside conversation archives. Requests are limited
to scene inspection and selected-object export, without arbitrary Python execution.
Blender processes scene operations on its main thread. Remote pairing, inspection,
and GLB transfer were tested between separate Godot and Steam Blender processes.

Blender's **Codex** sidebar includes a **Prompt** box and **Send prompt**. Keep
Godot open with Codex connected, and pair its Blender bridge with this instance.
Prompts use the current Godot Codex conversation and include Blender scene context;
they do not require an API key in Blender. The existing Godot draft is preserved.
Responses appear in Blender with a waiting/working status; **Open full response**
opens a Blender text document for scrolling and copying. Any approval requests
remain in Godot. This works through the local project inbox or remote pairing.

## Conversation archives

Settings includes an optional **Archive project conversations** toggle. It is off
by default. Local-only archives use the ignored `.godot/codex_chat/archive` folder.
Enable **Store archive in Git-ready project folder** to write JSON snapshots into
`codex_history/`; commit that folder normally to carry history between clones.
Switching storage copies the current conversation on the next save and leaves
existing snapshots in place. The browser reads both folders, even while archiving
is off and before connecting to Codex. Disabling archiving stops new writes; it
does not delete history.

Use **Settings → Local archive…** to read conversations, inspect reported
file-change diffs, and open changed files at the affected line. **Continue from
archive** imports reference context into a fresh Codex chat on the current device,
preserving the unsent draft. It does not require the original machine's Codex
thread database. The source archive stays intact and the continuation records its
parent archive. Imported context is limited to the latest 32,000 conversation
characters, 8,000 command characters, and 8,000 diff characters; complete saved
content remains browsable. Snapshots include commands/output and reported diffs,
not file version backups, image attachments, or dock connection credentials.
Review their contents before committing. `codex_history/` is excluded from game
exports.

The footer **Mic** button records local dictation. Click **Transcribe** to stop
and insert recognized speech into the existing prompt, or **Cancel mic** to discard
it. Recording stops automatically after 30 seconds. Speech is processed on a
worker thread with Godot Whisper v2.0.1 and the bundled `ggml-tiny.en.bin` English
model. No recording is uploaded, saved to disk, or automatically sent to Codex.
Restart Godot once after installation so the native extension and microphone
input setting take effect. Android needs microphone permission in the Godot
editor; allow the permission request, then press Mic again. The addon includes
Android native libraries, but microphone capture and speed require device testing.
Windows sample-audio transcription is covered by `tools/codex_dictation_test.gd`.
The model comes from https://huggingface.co/ggerganov/whisper.cpp and the addon
from https://github.com/appsinacup/godot-whisper (MIT; license in its addon folder).

Settings includes **Auto drive: follow changed files**, off by default. When enabled,
completed file-change events open scripts and select the first changed line from
the reported diff. Changes without a diff open at line 1. Changed scenes open in
the scene editor. A short debounce follows the latest file in a batch. Switching
scripts, moving the caret, or scrolling manually pauses following; enable the
toggle again to resume. This follows reported edits, not arbitrary shell reads.

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
