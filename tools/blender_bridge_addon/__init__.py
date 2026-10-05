bl_info = {"name": "OnTheFly Codex Bridge", "author": "OnTheFly", "version": (1, 1, 0), "blender": (3, 6, 0), "location": "View3D > Sidebar > Codex", "category": "Development"}

import base64
import hmac
import queue
import secrets
import threading
import tempfile
import textwrap
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
import time
from pathlib import Path
import bpy
from bpy.props import StringProperty, BoolProperty, IntProperty

_project = None
_server = None
_network_token = ""
_network_jobs = queue.Queue()
_network_results = {}
_network_lock = threading.Lock()
_temporary_project = None
_chat_request = {}
_chat_status = {}


class NetworkHandler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def reply(self, status, value):
        data = json.dumps(value).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def authorized(self):
        return hmac.compare_digest(self.headers.get("Authorization", ""), "Bearer " + _network_token)

    def do_POST(self):
        self.connection.settimeout(2)
        if not self.authorized():
            self.reply(401, {"error": "Invalid pairing token"})
            return
        if self.path == "/chat/status":
            try:
                size = int(self.headers.get("Content-Length", "0"))
                if not 0 < size <= 524288: raise ValueError("Invalid status size")
                value = json.loads(self.rfile.read(size))
                with _network_lock:
                    _chat_status.clear()
                    _chat_status.update(value)
                self.reply(200, {"ok": True})
            except Exception as error:
                self.reply(400, {"error": str(error)})
            return
        if self.path != "/request":
            self.reply(404, {"error": "Unknown endpoint"})
            return
        try:
            size = int(self.headers.get("Content-Length", "0"))
            if not 0 < size <= 262144:
                raise ValueError("Invalid request size")
            request = json.loads(self.rfile.read(size))
            if request.get("action") not in ("inspect", "export_selected"):
                raise ValueError("Unsupported action")
            with _network_lock:
                if len(_network_results) >= 32:
                    raise ValueError("Too many pending requests")
                identifier = secrets.token_hex(16)
                _network_results[identifier] = {"created": time.time(), "response": None}
            _network_jobs.put((identifier, request))
            self.reply(202, {"id": identifier})
        except Exception as error:
            self.reply(400, {"error": str(error)})

    def do_GET(self):
        if not self.authorized():
            self.reply(401, {"error": "Invalid pairing token"})
            return
        if self.path == "/chat":
            with _network_lock: value = dict(_chat_request)
            self.reply(200, value)
            return
        identifier = self.path.removeprefix("/response/")
        with _network_lock:
            job = _network_results.get(identifier)
            if job is None:
                self.reply(404, {"error": "Unknown request"})
            elif job["response"] is None:
                self.reply(202, {"pending": True})
            else:
                response = job["response"]
                del _network_results[identifier]
                self.reply(200, response)


def network_tick():
    # The HTTP threads never access bpy; only this Blender timer executes jobs.
    for _ in range(4):
        try:
            identifier, request = _network_jobs.get_nowait()
        except queue.Empty:
            break
        try:
            result = dispatch(_project, request)
            if request["action"] == "export_selected":
                path = _project / result["path"]
                if path.stat().st_size > 64 * 1024 * 1024:
                    raise ValueError("Export exceeds the 64 MiB transfer limit")
                result["glb_base64"] = base64.b64encode(path.read_bytes()).decode("ascii")
            response = {"ok": True, "action": request["action"], "result": result}
        except Exception as error:
            response = {"ok": False, "error": str(error)}
        with _network_lock:
            if identifier in _network_results:
                _network_results[identifier]["response"] = response
    with _network_lock:
        for identifier in list(_network_results):
            if time.time() - _network_results[identifier]["created"] > 120:
                del _network_results[identifier]



def write_json(path, data):
    temporary = path.with_suffix(".tmp")
    temporary.write_text(json.dumps(data, indent=2), encoding="utf-8")
    for attempt in range(4):
        try:
            os.replace(temporary, path)
            return
        except PermissionError:
            if attempt == 3:
                raise
            time.sleep(0.01)


def export_path(project, relative):
    root = Path(project).resolve()
    candidate = (root / relative).resolve()
    assets = (root / "assets").resolve()
    if not candidate.is_relative_to(assets) or candidate.suffix.lower() != ".glb":
        raise ValueError("Export must be a .glb inside this project's assets folder")
    if candidate.exists():
        raise ValueError("File already exists; choose a new export filename")
    return candidate


def inspect_scene():
    objects = []
    for obj in bpy.context.scene.objects:
        objects.append({"name": obj.name, "type": obj.type, "selected": obj.select_get(),
                        "location": list(obj.location), "rotation": list(obj.rotation_euler),
                        "scale": list(obj.scale), "materials": [slot.material.name if slot.material else None for slot in obj.material_slots],
                        "vertices": len(obj.data.vertices) if obj.type == "MESH" else 0,
                        "polygons": len(obj.data.polygons) if obj.type == "MESH" else 0})
    return {"blend_file": bpy.data.filepath, "scene": bpy.context.scene.name,
            "active_object": bpy.context.view_layer.objects.active.name if bpy.context.view_layer.objects.active else None,
            "objects": objects}


def dispatch(project, request):
    action = request.get("action")
    if action == "inspect":
        return inspect_scene()
    if action == "export_selected":
        path = export_path(project, request.get("path", ""))
        if not bpy.context.selected_objects:
            raise ValueError("Select objects in Blender first")
        if bpy.context.mode != "OBJECT":
            raise ValueError("Switch Blender to Object Mode before exporting")
        path.parent.mkdir(parents=True, exist_ok=True)
        result = bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", use_selection=True)
        if "FINISHED" not in result or not path.is_file():
            raise RuntimeError("Blender did not complete the GLB export")
        return {"path": path.relative_to(Path(project).resolve()).as_posix(), "selected": [o.name for o in bpy.context.selected_objects]}
    raise ValueError("Unsupported action; use inspect or export_selected")


def tick():
    if _project is None:
        return None
    network_tick()
    if not _server:
        status_path = _project / ".godot/codex_chat/blender/chat_status.json"
        if status_path.exists():
            try:
                _chat_status.clear()
                _chat_status.update(json.loads(status_path.read_text(encoding="utf-8")))
            except (OSError, ValueError): pass
    for screen in bpy.data.screens:
        for area in screen.areas:
            if area.type == "VIEW_3D": area.tag_redraw()
    folder = _project / ".godot/codex_chat/blender"
    try:
        write_json(folder / "status.json", {"updated_at": time.time(), "project": str(_project), "blend_file": bpy.data.filepath, "version": list(bpy.app.version)})
        # All Blender API calls occur in this main-thread timer, not a worker.
        for path in sorted((folder / "requests").glob("*.json"))[:4]:
            if path.stat().st_size > 262144:
                response = {"ok": False, "error": "Request is too large"}
            else:
                try:
                    request = json.loads(path.read_text(encoding="utf-8"))
                    response = {"ok": True, "action": request.get("action"), "result": dispatch(_project, request)}
                except Exception as error:
                    response = {"ok": False, "error": str(error)}
            write_json(folder / "responses" / path.name, response)
            path.unlink()
    except Exception as error:
        print("Codex Blender bridge:", error)
    return 0.5


class CODEX_OT_start(bpy.types.Operator):
    bl_idname = "codex_bridge.start"
    bl_label = "Start bridge"

    def execute(self, context):
        global _project, _server, _network_token, _temporary_project
        stop()
        root = Path(bpy.path.abspath(context.scene.codex_bridge_project)).resolve()
        if context.scene.codex_bridge_network and not (root / "project.godot").is_file():
            _temporary_project = tempfile.TemporaryDirectory(prefix="codex_blender_")
            root = Path(_temporary_project.name)
        elif not (root / "project.godot").is_file():
            self.report({"ERROR"}, "Choose the Godot project folder containing project.godot")
            return {"CANCELLED"}
        _project = root
        for name in ["requests", "responses"]:
            (root / ".godot/codex_chat/blender" / name).mkdir(parents=True, exist_ok=True)
        if context.scene.codex_bridge_network:
            try:
                _network_token = secrets.token_urlsafe(32)
                _server = ThreadingHTTPServer(("0.0.0.0", context.scene.codex_bridge_port), NetworkHandler)
                _server.daemon_threads = True
                threading.Thread(target=_server.serve_forever, daemon=True).start()
                context.scene.codex_bridge_actual_port = _server.server_port
                context.scene.codex_bridge_token = _network_token
            except OSError as error:
                stop()
                self.report({"ERROR"}, str(error))
                return {"CANCELLED"}
        if not bpy.app.timers.is_registered(tick):
            bpy.app.timers.register(tick, first_interval=0.1, persistent=True)
        return {"FINISHED"}


class CODEX_OT_stop(bpy.types.Operator):
    bl_idname = "codex_bridge.stop"
    bl_label = "Stop bridge"

    def execute(self, context):
        stop()
        return {"FINISHED"}


class CODEX_OT_chat_send(bpy.types.Operator):
    bl_idname = "codex_bridge.chat_send"
    bl_label = "Send prompt"

    def execute(self, context):
        text = context.scene.codex_bridge_prompt.strip()
        if not _project or not text:
            self.report({"ERROR"}, "Start the bridge and enter a prompt first")
            return {"CANCELLED"}
        if _chat_request and _chat_status.get("id") != _chat_request.get("id"):
            self.report({"WARNING"}, "Waiting for Godot to accept the previous prompt")
            return {"CANCELLED"}
        if _chat_status.get("busy"):
            self.report({"WARNING"}, "Wait for the current response")
            return {"CANCELLED"}
        request = {"id": secrets.token_hex(16), "created": time.time(), "text": text, "scene": inspect_scene()}
        with _network_lock:
            _chat_request.clear()
            _chat_request.update(request)
        if not _server:
            write_json(_project / ".godot/codex_chat/blender/chat_request.json", request)
        context.scene.codex_bridge_prompt = ""
        return {"FINISHED"}


class CODEX_OT_chat_response(bpy.types.Operator):
    bl_idname = "codex_bridge.chat_response"
    bl_label = "Open full response"

    def execute(self, context):
        document = bpy.data.texts.get("Codex Response") or bpy.data.texts.new("Codex Response")
        document.clear()
        document.write(str(_chat_status.get("response", "No response yet")))
        context.area.type = "TEXT_EDITOR"
        context.area.spaces.active.text = document
        return {"FINISHED"}


class CODEX_PT_bridge(bpy.types.Panel):
    bl_label = "Godot Codex Bridge"
    bl_idname = "CODEX_PT_bridge"
    bl_space_type = "VIEW_3D"
    bl_region_type = "UI"
    bl_category = "Codex"

    def draw(self, context):
        self.layout.prop(context.scene, "codex_bridge_project", text="Godot project")
        self.layout.prop(context.scene, "codex_bridge_network", text="Allow network connections")
        if context.scene.codex_bridge_network:
            self.layout.prop(context.scene, "codex_bridge_port", text="Port (0 = automatic)")
            self.layout.label(text="Connect to this computer's IP and port %d" % context.scene.codex_bridge_actual_port)
            self.layout.prop(context.scene, "codex_bridge_token", text="Pairing token")
            self.layout.label(text="Use a trusted LAN or VPN; HTTP is unencrypted.")
        self.layout.operator("codex_bridge.start")
        self.layout.operator("codex_bridge.stop")
        self.layout.label(text="Running" if _project else "Stopped")
        box = self.layout.box()
        box.label(text="Chat with project Codex")
        box.prop(context.scene, "codex_bridge_prompt", text="Prompt")
        row = box.row()
        row.enabled = bool(_project) and not _chat_status.get("busy", False)
        row.operator("codex_bridge.chat_send", icon="PLAY")
        waiting = _chat_request and _chat_status.get("id") != _chat_request.get("id")
        box.label(text="Waiting for Godot…" if waiting else str(_chat_status.get("status", "Connect Codex in Godot first")))
        for line in str(_chat_status.get("response", "")).splitlines()[-20:]:
            for wrapped in textwrap.wrap(line, width=48): box.label(text=wrapped)
        if _chat_status.get("response"): box.operator("codex_bridge.chat_response", icon="TEXT")


def stop():
    global _project, _server, _temporary_project, _network_token
    if _server:
        _server.shutdown()
        _server.server_close()
        _server = None
    _network_token = ""
    _chat_request.clear()
    _chat_status.clear()
    with _network_lock:
        _network_results.clear()
    while not _network_jobs.empty():
        try: _network_jobs.get_nowait()
        except queue.Empty: break
    if _project:
        try:
            (_project / ".godot/codex_chat/blender/status.json").unlink(missing_ok=True)
        except PermissionError:
            pass  # The heartbeat expires even if a Windows reader has it open.
    _project = None
    if _temporary_project:
        _temporary_project.cleanup()
        _temporary_project = None
    if bpy.app.timers.is_registered(tick):
        bpy.app.timers.unregister(tick)


_classes = (CODEX_OT_start, CODEX_OT_stop, CODEX_OT_chat_send, CODEX_OT_chat_response, CODEX_PT_bridge)


def register():
    for cls in _classes:
        bpy.utils.register_class(cls)
    bpy.types.Scene.codex_bridge_prompt = StringProperty(name="Prompt", options={"SKIP_SAVE"}, maxlen=10000)
    bpy.types.Scene.codex_bridge_project = StringProperty(name="Godot project", subtype="DIR_PATH")
    bpy.types.Scene.codex_bridge_network = BoolProperty(default=False)
    bpy.types.Scene.codex_bridge_port = IntProperty(default=0, min=0, max=65535)
    bpy.types.Scene.codex_bridge_actual_port = IntProperty(default=0, options={"SKIP_SAVE"})
    bpy.types.Scene.codex_bridge_token = StringProperty(options={"SKIP_SAVE"})


def unregister():
    stop()
    for name in ["codex_bridge_prompt", "codex_bridge_project", "codex_bridge_network", "codex_bridge_port", "codex_bridge_actual_port", "codex_bridge_token"]:
        delattr(bpy.types.Scene, name)
    for cls in reversed(_classes):
        bpy.utils.unregister_class(cls)
