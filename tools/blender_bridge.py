"""Local CLI for the Godot/Blender project bridge. No network or third-party dependencies."""
import base64
import urllib.request
import argparse
import json
import os
import time
import uuid
from pathlib import Path


def remote_request(root, connection, action, output, timeout):
    url = connection["url"].rstrip("/")
    if not url.startswith(("http://", "https://")):
        raise ValueError("Remote Blender URL must use HTTP or HTTPS")
    headers = {"Authorization": "Bearer " + connection["token"], "Content-Type": "application/json"}
    def fetch(endpoint, payload=None):
        data = json.dumps(payload).encode() if payload is not None else None
        with urllib.request.urlopen(urllib.request.Request(url + endpoint, data=data, headers=headers), timeout=10) as response:
            return response.status, json.load(response)
    target = None
    if action == "export_selected":
        if not output: raise ValueError("Set --output to a new assets/... .glb path")
        target = (root / output).resolve()
        if not target.is_relative_to(root / "assets") or target.suffix.lower() != ".glb" or target.exists():
            raise ValueError("Export target must be a new .glb inside project assets")
    _, accepted = fetch("/request", {"action": action, "path": output or ""})
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        status, response = fetch("/response/" + accepted["id"])
        if status == 202:
            time.sleep(0.25)
            continue
        if not response.get("ok"): raise RuntimeError(response.get("error", "Remote request failed"))
        result = response["result"]
        if target:
            blob = base64.b64decode(result.pop("glb_base64"), validate=True)
            if len(blob) > 64 * 1024 * 1024 or blob[:4] != b"glTF": raise ValueError("Invalid remote GLB")
            target.parent.mkdir(parents=True, exist_ok=True)
            with target.open("xb") as file: file.write(blob)
            result["path"] = target.relative_to(root).as_posix()
        return result
    raise TimeoutError("Remote request timed out; the host may still finish an export")


def request(project, action, output=None, timeout=30):
    root = Path(project).resolve()
    folder = root / ".godot/codex_chat/blender"
    remote = folder / "remote_connection.json"
    if remote.exists():
        return remote_request(root, json.loads(remote.read_text(encoding="utf-8")), action, output, timeout)
    status = folder / "status.json"
    if not status.exists() or time.time() - json.loads(status.read_text(encoding="utf-8")).get("updated_at", 0) > 5:
        raise RuntimeError("Blender bridge is offline. Start it in Blender's Codex sidebar.")
    identifier = uuid.uuid4().hex
    request_file = folder / "requests" / (identifier + ".json")
    temporary = request_file.with_suffix(".tmp")
    response_file = folder / "responses" / request_file.name
    data = {"action": action}
    if output:
        data["path"] = output
    temporary.write_text(json.dumps(data), encoding="utf-8")
    os.replace(temporary, request_file)
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if response_file.exists():
            response = json.loads(response_file.read_text(encoding="utf-8"))
            response_file.unlink()
            if not response.get("ok"):
                raise RuntimeError(response.get("error", "Blender request failed"))
            return response["result"]
        time.sleep(0.1)
    request_file.unlink(missing_ok=True)
    raise TimeoutError("Blender request timed out. A started export may still finish; inspect before retrying.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", default=".")
    parser.add_argument("action", choices=["inspect", "export_selected"])
    parser.add_argument("--output", help="New assets/... .glb path for selected-object export")
    args = parser.parse_args()
    try:
        print(json.dumps(request(args.project, args.action, args.output), indent=2))
    except Exception as error:
        parser.exit(1, str(error) + "\n")
