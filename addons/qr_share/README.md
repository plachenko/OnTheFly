QR generation source: https://github.com/Greaby/godot-qrcode-generator (MIT).
The game adds a four-module quiet zone and nearest-neighbor scaling.

Android scanning uses https://github.com/godot-mobile-plugins/godot-qr v1.2
and https://github.com/godot-mobile-plugins/godot-native-camera v3.0 (MIT).
Their notices are in the corresponding addon folders. The shared FrameInfo
wrapper has one local fix: call is_grayscale() when selecting the image format.
