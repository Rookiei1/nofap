"""Draw the NoFap icon: a faceted metal N on obsidian, with one red edge. No ruler ticks."""
import struct
import zlib
from pathlib import Path


def chunk(tag, data):
    return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)


def png(width, height, rows):
    raw = bytearray()
    for row in rows:
        raw.append(0)
        raw.extend(row)
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)) + chunk(
        b"IDAT", zlib.compress(bytes(raw), 9)
    ) + chunk(b"IEND", b"")


def inside_parallelogram(x, y, top_left, top_right, bottom_right, bottom_left):
    def cross(ax, ay, bx, by, px, py):
        return (bx - ax) * (py - ay) - (by - ay) * (px - ax)

    points = (top_left, top_right, bottom_right, bottom_left)
    signs = []
    for index, point in enumerate(points):
        nxt = points[(index + 1) % 4]
        signs.append(cross(point[0], point[1], nxt[0], nxt[1], x, y))
    return all(value >= 0 for value in signs) or all(value <= 0 for value in signs)


def render(size):
    pixels = [[(8, 8, 10) for _ in range(size)] for _ in range(size)]
    scale = size / 1024

    def bar(points, shade):
        min_x = max(0, int(min(point[0] for point in points)) - 1)
        max_x = min(size - 1, int(max(point[0] for point in points)) + 1)
        min_y = max(0, int(min(point[1] for point in points)) - 1)
        max_y = min(size - 1, int(max(point[1] for point in points)) + 1)
        for y in range(min_y, max_y + 1):
            for x in range(min_x, max_x + 1):
                if inside_parallelogram(x + 0.5, y + 0.5, *points):
                    pixels[y][x] = shade

    def S(value):
        return value * scale

    # Left stem, highlighted on its leading edge.
    bar(
        ((S(270), S(150)), (S(450), S(150)), (S(450), S(874)), (S(270), S(874))),
        (176, 180, 186),
    )
    bar(
        ((S(330), S(150)), (S(450), S(150)), (S(450), S(874)), (S(330), S(874))),
        (70, 74, 82),
    )
    # Diagonal overlapping both stems so the mark reads as one N.
    bar(
        ((S(360), S(150)), (S(530), S(150)), (S(754), S(874)), (S(584), S(874))),
        (214, 218, 224),
    )
    bar(
        ((S(430), S(190)), (S(530), S(150)), (S(754), S(874)), (S(680), S(874))),
        (88, 92, 100),
    )
    # Right stem, side facet, and one lava edge. No tick marks.
    bar(
        ((S(620), S(150)), (S(800), S(150)), (S(800), S(874)), (S(620), S(874))),
        (186, 190, 196),
    )
    bar(
        ((S(710), S(150)), (S(800), S(150)), (S(800), S(874)), (S(710), S(874))),
        (46, 48, 54),
    )
    bar(
        ((S(708), S(280)), (S(728), S(280)), (S(728), S(760)), (S(708), S(760))),
        (255, 42, 28),
    )
    return [b"".join(bytes(pixel) for pixel in row) for row in pixels]


def main():
    destination = Path(__file__).resolve().parents[1] / "NoFap" / "Assets.xcassets" / "AppIcon.appiconset" / "AppIcon.png"
    destination.write_bytes(png(1024, 1024, render(1024)))
    print(f"Wrote {destination.name} ({destination.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
