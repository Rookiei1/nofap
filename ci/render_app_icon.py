"""Draw the NoFap app icon: obsidian field, metal spine, one lava mark. No alpha."""
import struct
import zlib
from pathlib import Path


def chunk(tag, data):
    return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)


def png(width, height, pixel):
    raw = bytearray()
    for y in range(height):
        raw.append(0)
        for x in range(width):
            raw.extend(pixel(x, y))
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)) + chunk(
        b"IDAT", zlib.compress(bytes(raw), 9)
    ) + chunk(b"IEND", b"")


def pixel(x, y):
    background = (8, 8, 10)
    if 470 <= x <= 560 and 160 <= y <= 880:
        shade = 28 + int((x - 470) * 0.35)
        if x <= 478:
            shade = 150
        color = (shade, shade, shade + 2)
        mark = 160 + int((12 / 30) * (880 - 160))
        if abs(y - (880 - mark + 160)) <= 3 or abs(y - 592) <= 3:
            return (255, 42, 28)
        return color
    if 590 <= x <= 640 and 160 <= y <= 880 and (y - 160) % 180 < 2:
        return (150, 152, 156)
    return background


def main():
    destination = Path(__file__).resolve().parents[1] / "NoFap" / "Assets.xcassets" / "AppIcon.appiconset" / "AppIcon.png"
    destination.write_bytes(png(1024, 1024, pixel))
    print(f"Wrote {destination.name} ({destination.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
