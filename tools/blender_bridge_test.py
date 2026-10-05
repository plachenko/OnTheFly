import importlib.util
import json
import sys
import tempfile
import threading
import time
import types
import unittest
from pathlib import Path

HERE = Path(__file__).parent

def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module

class BridgeTest(unittest.TestCase):
    def test_exchange_and_export_boundaries(self):
        fake = types.ModuleType("bpy")
        fake.types = types.SimpleNamespace(Operator=object, Panel=object)
        fake.app = types.SimpleNamespace(version=(4, 5, 0))
        fake.data = types.SimpleNamespace(filepath="test.blend", screens=[])
        properties = types.ModuleType("bpy.props")
        properties.StringProperty = lambda **kwargs: None
        properties.BoolProperty = lambda **kwargs: None
        properties.IntProperty = lambda **kwargs: None
        original = sys.modules.get("bpy")
        sys.modules["bpy"] = fake
        sys.modules["bpy.props"] = properties
        try:
            addon = load("test_blender_addon", HERE / "blender_bridge_addon/__init__.py")
            cli = load("test_blender_cli", HERE / "blender_bridge.py")
            with tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                folder = root / ".godot/codex_chat/blender"
                for name in ["requests", "responses"]:
                    (folder / name).mkdir(parents=True)
                addon._project = root
                addon.inspect_scene = lambda: {"scene": "Test scene", "objects": []}
                addon.tick()
                scene = types.SimpleNamespace(codex_bridge_prompt="Describe this scene")
                operator = addon.CODEX_OT_chat_send()
                operator.report = lambda *args: None
                self.assertEqual(operator.execute(types.SimpleNamespace(scene=scene)), {"FINISHED"})
                chat = json.loads((folder / "chat_request.json").read_text())
                self.assertEqual(chat["text"], "Describe this scene")
                self.assertEqual(chat["scene"]["scene"], "Test scene")
                self.assertEqual(scene.codex_bridge_prompt, "")
                self.assertEqual(operator.execute(types.SimpleNamespace(scene=types.SimpleNamespace(codex_bridge_prompt="duplicate"))), {"CANCELLED"})
                addon.write_json(folder / "chat_status.json", {"id": chat["id"], "busy": False, "response": "Scene summary"})
                addon.tick()
                self.assertEqual(addon._chat_status["response"], "Scene summary")
                result = []
                worker = threading.Thread(target=lambda: result.append(cli.request(root, "inspect", timeout=3)))
                worker.start()
                for _ in range(50):
                    addon.tick()
                    if not worker.is_alive(): break
                    time.sleep(0.02)
                worker.join()
                self.assertEqual(result[0]["scene"], "Test scene")
                self.assertEqual(addon.export_path(root, "assets/test.glb"), root / "assets/test.glb")
                for path in ["../outside.glb", "tools/test.glb", "assets/test.blend"]:
                    with self.assertRaises(ValueError): addon.export_path(root, path)
                target = root / "assets/test.glb"
                target.parent.mkdir()
                target.write_bytes(b"existing")
                with self.assertRaises(ValueError): addon.export_path(root, "assets/test.glb")
                with self.assertRaises(ValueError): addon.dispatch(root, {"action": "execute_python"})
                (folder / "status.json").unlink()
                with self.assertRaises(RuntimeError): cli.request(root, "inspect")
        finally:
            if original is None: sys.modules.pop("bpy", None)
            else: sys.modules["bpy"] = original
            sys.modules.pop("bpy.props", None)

if __name__ == "__main__": unittest.main()
