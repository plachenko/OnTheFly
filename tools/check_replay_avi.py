"""Validate an exported replay's RIFF sizes, MJPEG decoding, and seek index."""
import io
import struct
import sys
from pathlib import Path
from PIL import Image

data = Path(sys.argv[1]).read_bytes()
u32 = lambda offset: struct.unpack_from("<I", data, offset)[0]
assert data[:4] == b"RIFF" and data[8:12] == b"AVI "
assert u32(4) == len(data) - 8
count = u32(48)
offset = 12
movie = None
entries = []
while offset < len(data):
    tag, size = data[offset:offset + 4], u32(offset + 4)
    end = offset + 8 + size
    assert end <= len(data)
    if tag == b"LIST" and data[offset + 8:offset + 12] == b"movi":
        movie = offset + 8
        frame = offset + 12
        while frame < end:
            length = u32(frame + 4)
            assert data[frame:frame + 4] == b"00dc"
            with Image.open(io.BytesIO(data[frame + 8:frame + 8 + length])) as image:
                image.load()
                assert image.size == (640, 360) and image.format == "JPEG"
            entries.append((b"00dc", 0x10, frame - movie, length))
            frame += 8 + length + (length & 1)
        assert frame == end
    if tag == b"idx1":
        actual = [struct.unpack_from("<4sIII", data, i) for i in range(offset + 8, end, 16)]
        assert actual == entries
    offset = end + (size & 1)
assert offset == len(data) and len(entries) == count and movie is not None
print(f"AVI validated: {count} independently decoded JPEG frames, {count / 15:.2f}s, valid seek index")
