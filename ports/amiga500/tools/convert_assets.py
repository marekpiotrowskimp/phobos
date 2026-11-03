"""Konwersja zasobów PHOBOS (macOS/Godot) do formatów Amigi 500 OCS.

Wynik trafia do ports/amiga500/assets/generated/:
- assets.h      — stałe, offsety, palety, tabele fontów i dźwięków,
- chip.bin      — dane ładowane do Chip RAM (boby, maski, sprite'y, tło, próbki SFX),
- music.bin     — warstwy muzyki (Fast/Slow RAM, strumieniowane do Paula),
- assets.s      — dołącza powyższe pliki przez .incbin,
- manifest.json — źródła, sumy kontrolne i parametry konwersji,
- preview/*.png — podgląd przekonwertowanej grafiki.
"""

from __future__ import annotations

import hashlib
import io
import json
import math
import random
import struct
from pathlib import Path

import cairosvg
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[1]
REPOSITORY = ROOT.parents[1]
OUTPUT = ROOT / "assets" / "generated"
PREVIEW = OUTPUT / "preview"

PX_PER_UNIT = 8
ENEMY_DIRS = 16
PLAYER_DIRS = 16
ARENA_W = 336
ARENA_H = 216
ARENA_ROWS = 200
ARENA_MARGIN = 8

# Paleta areny (OCS 12-bit, składowe 0..15).
ARENA_PALETTE = [
    (0, 0, 1),    # 0 pustka / najciemniejsza podłoga
    (0, 1, 2),    # 1 podłoga
    (1, 2, 3),    # 2 płyty, cienie
    (2, 3, 5),    # 3 siatka, pierścień, kable
    (4, 5, 7),    # 4 nity, jasny metal
    (1, 3, 7),    # 5 ściany
    (3, 0, 1),    # 6 ciemna czerwień: krew, cień skorpiona
    (9, 1, 2),    # 7 czerwień korpusu
    (15, 5, 3),   # 8 jasna czerwień / pomarańcz / telegraph
    (9, 5, 0),    # 9 bursztyn, pasy ostrzegawcze
    (15, 12, 3),  # 10 jasny bursztyn / rdzeń eksplozji
    (5, 1, 8),    # 11 fiolet
    (12, 5, 15),  # 12 jasny fiolet
    (3, 13, 6),   # 13 zieleń leczenia
    (3, 11, 15),  # 14 cyjan: Overdrive, tracer
    (13, 15, 15), # 15 biel: rdzeń tracera, napisy
]
# Paleta HUD (górny i dolny pasek).
HUD_PALETTE = [
    (0, 0, 1),    # 0 tło
    (15, 15, 15), # 1 biel — fala, wynik
    (13, 14, 15), # 2 jasny tekst
    (7, 11, 13),  # 3 tekst pomocniczy
    (2, 14, 5),   # 4 HP
    (3, 11, 15),  # 5 Overdrive
    (1, 1, 2),    # 6 tło paska
    (5, 6, 7),    # 7 obramowanie paska
    (15, 3, 3),   # 8 czerwień ostrzeżenia
    (0, 1, 2),    # 9 cień tekstu
    (0, 0, 0), (0, 0, 0), (0, 0, 0), (0, 0, 0), (0, 0, 0), (0, 0, 0),
]
# Paleta ekranów menu / wyników (3 bitplany).
MENU_PALETTE = [
    (0, 0, 1),    # 0 tło
    (7, 14, 15),  # 1 tytuł
    (13, 14, 15), # 2 treść
    (6, 11, 13),  # 3 podpowiedź
    (15, 15, 15), # 4 zaznaczenie
    (3, 5, 6),    # 5 przygaszony
    (15, 3, 3),   # 6 czerwień
    (1, 2, 4),    # 7 ramka
]
CROSSHAIR_COLORS = {9: (6, 14, 15), 10: (15, 13, 8), 11: (15, 15, 15)}

SFX_RATE = 11025
SFX_PERIOD = round(3546895 / SFX_RATE)
MUSIC_RATE = 8000
MUSIC_PERIOD = round(3546895 / MUSIC_RATE)
MUSIC_BUFFER = 320  # bajtów na blok strumienia (2 bloki w Chip RAM)

manifest: list[dict] = []
chip = bytearray()
symbols: dict[str, int] = {}


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def note_source(name: str, relative: str, **params) -> None:
    source = REPOSITORY / relative
    manifest.append({"name": name, "source": relative, "sha256": sha(source), **params})


def chip_add(name: str, data: bytes, align: int = 8) -> int:
    while len(chip) % align:
        chip.append(0)
    symbols[name] = len(chip)
    chip.extend(data)
    return symbols[name]


def to24(color: tuple[int, int, int]) -> tuple[int, int, int]:
    return tuple(v * 17 for v in color)


def color_distance(a, b) -> float:
    # Odległość ważona percepcyjnie (redmean).
    rmean = (a[0] + b[0]) / 2
    dr, dg, db = a[0] - b[0], a[1] - b[1], a[2] - b[2]
    return (2 + rmean / 256) * dr * dr + 4 * dg * dg + (2 + (255 - rmean) / 256) * db * db


def nearest(rgb, palette, allowed) -> int:
    best = allowed[0]
    best_d = 1e18
    for index in allowed:
        d = color_distance(rgb, palette[index])
        if d < best_d:
            best_d = d
            best = index
    return best


def render_svg(relative: str, width: int, height: int | None = None) -> Image.Image:
    data = cairosvg.svg2png(
        url=str(REPOSITORY / relative), output_width=width, output_height=height or width
    )
    return Image.open(io.BytesIO(data)).convert("RGBA")


def load_rgba(relative: str) -> Image.Image:
    return Image.open(REPOSITORY / relative).convert("RGBA")


def brighten(image: Image.Image, factor: float, lift: int = 0) -> Image.Image:
    r, g, b, a = image.split()
    lut = [min(255, int(v * factor + lift)) for v in range(256)]
    return Image.merge("RGBA", (r.point(lut), g.point(lut), b.point(lut), a))


def quantize(image: Image.Image, palette24, allowed, alpha_cut=110) -> list[list[int]]:
    """Zwraca macierz indeksów; -1 oznacza przezroczystość."""
    w, h = image.size
    px = image.load()
    out = []
    cache = {}
    for y in range(h):
        row = []
        for x in range(w):
            r, g, b, a = px[x, y]
            if a < alpha_cut:
                row.append(-1)
                continue
            key = (r >> 2, g >> 2, b >> 2)
            if key not in cache:
                cache[key] = nearest((r, g, b), palette24, allowed)
            row.append(cache[key])
        out.append(row)
    return out


def interleaved_bob(indices: list[list[int]], words: int, planes: int = 4) -> tuple[bytes, bytes]:
    """Grafika i maska w formacie przeplatanym: wiersz → plany → słowa."""
    gfx = bytearray()
    mask = bytearray()
    for row in indices:
        plane_words = [[0] * words for _ in range(planes)]
        mask_words = [0] * words
        for x, value in enumerate(row):
            if value < 0:
                continue
            word, bit = divmod(x, 16)
            bit = 15 - bit
            mask_words[word] |= 1 << bit
            for plane in range(planes):
                if value & (1 << plane):
                    plane_words[plane][word] |= 1 << bit
        for plane in range(planes):
            for value in plane_words[plane]:
                gfx += struct.pack(">H", value)
            for value in mask_words:
                mask += struct.pack(">H", value)
    return bytes(gfx), bytes(mask)


def indices_to_image(indices, palette24, scale=1, background=(10, 10, 20)) -> Image.Image:
    h = len(indices)
    w = len(indices[0])
    image = Image.new("RGB", (w, h), background)
    px = image.load()
    for y in range(h):
        for x in range(w):
            if indices[y][x] >= 0:
                px[x, y] = palette24[indices[y][x]]
    if scale != 1:
        image = image.resize((w * scale, h * scale), Image.Resampling.NEAREST)
    return image


def fit_cell(image: Image.Image, cell: int, target: float, angle: float) -> Image.Image:
    """Skaluje cały kanwas źródłowy do `target` px, obraca o `angle` stopni zgodnie z ruchem
    wskazówek zegara i wycina centralną komórkę `cell`×`cell`."""
    big = 256
    scaled = image.resize((big, big), Image.Resampling.LANCZOS)
    rotated = scaled.rotate(-angle, resample=Image.Resampling.BICUBIC, expand=True)
    factor = target / big
    size = max(1, round(rotated.width * factor))
    small = rotated.resize((size, size), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (cell, cell))
    offset = (cell - size) // 2
    canvas.alpha_composite(small, (offset, offset)) if offset >= 0 else canvas.alpha_composite(
        small.crop((-offset, -offset, -offset + cell, -offset + cell))
    )
    return canvas


# ---------------------------------------------------------------- tło areny

def build_arena() -> list[list[int]]:
    palette24 = [to24(c) for c in ARENA_PALETTE]
    floor_w = 40 * PX_PER_UNIT
    floor_h = 24 * PX_PER_UNIT
    floor = render_svg("project/assets/sprites/arena/arena_floor.svg", floor_w * 4, floor_h * 4)
    floor = floor.resize((floor_w, floor_h), Image.Resampling.LANCZOS)
    note_source("arena_floor", "project/assets/sprites/arena/arena_floor.svg",
                size=[floor_w, floor_h], palette="arena 0-9")
    cx = ARENA_W // 2
    cy = ARENA_H // 2
    # Oświetlenie w grze jest ciemne: przyciemnienie + winieta jak w shaderze Godot.
    floor_layer = Image.new("RGBA", (ARENA_W, ARENA_H), to24(ARENA_PALETTE[0]) + (255,))
    floor_layer.alpha_composite(floor, (cx - floor_w // 2, cy - floor_h // 2))
    fpx = floor_layer.load()
    for y in range(ARENA_H):
        for x in range(ARENA_W):
            r, g, b, a = fpx[x, y]
            dx = (x - cx) / (ARENA_W / 2)
            dy = (y - cy) / (ARENA_H / 2)
            d = math.hypot(dx * 0.75, dy * 0.85)
            v = 0.62 - 0.22 * max(0.0, min(1.0, (d - 0.35) / 0.55))
            fpx[x, y] = (int(r * v), int(g * v), int(b * v), 255)
    # Ściany: 1 jednostka grubości wyśrodkowana na krawędzi areny.
    hw = 20 * PX_PER_UNIT
    hh = 12 * PX_PER_UNIT
    t = PX_PER_UNIT // 2
    outer = (cx - hw - t, cy - hh - t, cx + hw + t - 1, cy + hh + t - 1)
    inner = (cx - hw + t, cy - hh + t, cx + hw - t - 1, cy + hh - t - 1)
    result = Image.new("RGBA", (ARENA_W, ARENA_H), to24(ARENA_PALETTE[0]) + (255,))
    draw = ImageDraw.Draw(result)
    draw.rectangle(outer, fill=to24(ARENA_PALETTE[5]))
    draw.rectangle(outer, outline=to24(ARENA_PALETTE[3]))
    result.paste(floor_layer.crop((inner[0], inner[1], inner[2] + 1, inner[3] + 1)), (inner[0], inner[1]))
    draw.rectangle(inner, outline=to24(ARENA_PALETTE[2]))
    indices = quantize(result, palette24, [0, 1, 2, 3, 4, 5, 6, 7, 9], alpha_cut=0)
    indices_to_image(indices, palette24, 2).save(PREVIEW / "arena.png")
    return indices


# ---------------------------------------------------------------- przeciwnicy

ENEMY_SETS = {
    "red": ("scorpion_crawl", [0, 6, 7, 8, 10]),
    "amber": ("scorpion_amber", [0, 6, 9, 10]),
    "violet": ("scorpion_violet", [0, 6, 11, 12, 8]),
}
ENEMY_TARGET = 2.30 * PX_PER_UNIT * 0.92


def enemy_frames():
    palette24 = [to24(c) for c in ARENA_PALETTE]
    bobs = []
    previews = []
    for variant, (prefix, allowed) in ENEMY_SETS.items():
        frames = []
        for frame in range(4):
            relative = f"project/assets/sprites/enemy/{prefix}_{frame + 1}.png"
            note_source(f"enemy_{variant}_{frame}", relative, cell=16, directions=ENEMY_DIRS)
            frames.append(brighten(load_rgba(relative), 1.55, 6))
        for direction in range(ENEMY_DIRS):
            for frame in range(4):
                cell = fit_cell(frames[frame], 16, ENEMY_TARGET, direction * 360 / ENEMY_DIRS)
                idx = quantize(cell, palette24, allowed)
                bobs.append(idx)
                if frame == 0:
                    previews.append(idx)
    sheet = Image.new("RGB", (16 * ENEMY_DIRS * 4, 16 * 3 * 4))
    for i, idx in enumerate(previews):
        sheet.paste(indices_to_image(idx, palette24, 4), ((i % ENEMY_DIRS) * 64, (i // ENEMY_DIRS) * 64))
    sheet.save(PREVIEW / "enemies.png")
    return bobs


def spawn_frames():
    """Skorpion w fazie pojawiania się: dwie skale × 8 kierunków × 3 warianty."""
    palette24 = [to24(c) for c in ARENA_PALETTE]
    bobs = []
    for variant, (prefix, allowed) in ENEMY_SETS.items():
        source = brighten(load_rgba(f"project/assets/sprites/enemy/{prefix}_1.png"), 1.55, 6)
        for scale in (0.30, 0.62):
            for direction in range(8):
                cell = fit_cell(source, 16, ENEMY_TARGET * scale, direction * 45)
                bobs.append(quantize(cell, palette24, allowed))
    return bobs


def telegraph_frames():
    palette24 = [to24(c) for c in ARENA_PALETTE]
    relative = "project/assets/sprites/effects/spawn_telegraph.svg"
    note_source("telegraph", relative, cell=16, frames=8)
    source = render_svg(relative, 256)
    bobs = []
    target = 2.05 * PX_PER_UNIT
    for bright in (0, 1):
        for frame in range(4):
            image = fit_cell(source, 16, target, frame * 22.5)
            if not bright:
                image = brighten(image, 0.55)
            allowed = [6, 7, 8] if bright else [6, 7]
            bobs.append(quantize(image, palette24, allowed, alpha_cut=70))
    sheet = Image.new("RGB", (16 * 8 * 4, 64))
    for i, idx in enumerate(bobs):
        sheet.paste(indices_to_image(idx, palette24, 4), (i * 64, 0))
    sheet.save(PREVIEW / "telegraph.png")
    return bobs


def pickup_frames():
    palette24 = [to24(c) for c in ARENA_PALETTE]
    bobs = []
    previews = []
    for kind, allowed in (("heal_nanocapsule", [0, 1, 2, 3, 4, 13, 15]),
                          ("overdrive_reactor", [0, 1, 2, 3, 5, 14, 15])):
        relative = f"project/assets/sprites/pickups/{kind}.svg"
        note_source(kind, relative, cell=16, frames=8)
        source = brighten(render_svg(relative, 256), 1.25)
        for frame in range(8):
            image = fit_cell(source, 16, 1.41 * PX_PER_UNIT * 1.15, frame * 45 / 2)
            idx = quantize(image, palette24, allowed)
            bobs.append(idx)
            previews.append(idx)
    sheet = Image.new("RGB", (16 * 8 * 4, 128))
    for i, idx in enumerate(previews):
        sheet.paste(indices_to_image(idx, palette24, 4), ((i % 8) * 64, (i // 8) * 64))
    sheet.save(PREVIEW / "pickups.png")
    return bobs


def explosion_frames():
    """Cząsteczki jak w GPUParticles3D: 24 kule, prędkość 1–7 j/s, grawitacja, 0,6 s."""
    palette24 = [to24(c) for c in ARENA_PALETTE]
    rng = random.Random(8505)
    frames = []
    count = 8
    variants = []
    for variant in range(2):
        particles = []
        for _ in range(24):
            # Emisja ze sfery r=0,4; kierunek losowy (spread 180°), rzut z góry.
            theta = rng.uniform(0, math.tau)
            phi = math.acos(rng.uniform(-1, 1))
            speed = rng.uniform(1.0, 7.0)
            vx = math.sin(phi) * math.cos(theta) * speed
            vz = math.sin(phi) * math.sin(theta) * speed
            r0 = rng.uniform(0, 0.4)
            ox = math.cos(theta) * r0
            oz = math.sin(theta) * r0
            size = rng.uniform(0.08, 0.3)
            particles.append((ox, oz, vx, vz, size))
        variants.append(particles)
    for particles in variants:
        for frame in range(count):
            t = (frame + 0.5) / count * 0.6
            image = Image.new("RGBA", (32 * 4, 32 * 4))
            draw = ImageDraw.Draw(image)
            age = t / 0.6
            for ox, oz, vx, vz, size in particles:
                x = (ox + vx * t) * PX_PER_UNIT * 4 + 64
                y = (oz + vz * t) * PX_PER_UNIT * 4 + 64
                radius = max(1.6, size * PX_PER_UNIT * 4 * (1.15 - age * 0.55))
                if age < 0.3:
                    color = (255, 230, 120, 255)
                elif age < 0.6:
                    color = (255, 120, 40, 255)
                else:
                    color = (190, 40, 20, 255)
                draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=color)
            if frame == 0:
                draw.ellipse((64 - 14, 64 - 14, 64 + 14, 64 + 14), fill=(255, 245, 200, 255))
            small = image.resize((32, 32), Image.Resampling.LANCZOS)
            frames.append(quantize(small, palette24, [6, 7, 8, 10, 15], alpha_cut=90))
    sheet = Image.new("RGB", (32 * count * 4, 32 * 2 * 4))
    for i, idx in enumerate(frames):
        sheet.paste(indices_to_image(idx, palette24, 4), ((i % count) * 128, (i // count) * 128))
    sheet.save(PREVIEW / "explosions.png")
    return frames


# ---------------------------------------------------------------- gracz (sprite'y)

def build_player_palette(images: list[Image.Image]) -> list[tuple[int, int, int]]:
    pixels = []
    for image in images:
        for r, g, b, a in image.getdata():
            if a >= 110:
                pixels.append((r, g, b))
    sample = Image.new("RGB", (len(pixels), 1))
    sample.putdata(pixels)
    reduced = sample.quantize(colors=12, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    colors = reduced.getpalette()[: 12 * 3]
    result = [(0, 0, 0)] * 16
    free = [1, 2, 3, 4, 5, 6, 7, 8, 12, 13, 14, 15]
    quantized = sorted({tuple(round(v / 17) for v in colors[i * 3:i * 3 + 3]) for i in range(12)},
                       key=lambda c: sum(c))
    while len(quantized) < len(free):
        quantized.append(quantized[-1])
    for slot, color in zip(free, quantized):
        result[slot] = color
    for slot, color in CROSSHAIR_COLORS.items():
        result[slot] = color
    return result


def player_frames():
    sources = []
    for frame in range(4):
        relative = f"project/assets/sprites/player/player_move_{frame + 1}.png"
        note_source(f"player_{frame}", relative, cell=32, directions=PLAYER_DIRS)
        sources.append(brighten(load_rgba(relative), 2.1, 10))
    target = 3.17 * PX_PER_UNIT
    cells = []
    for direction in range(PLAYER_DIRS):
        for frame in range(4):
            cells.append(fit_cell(sources[frame], 32, target, direction * 360 / PLAYER_DIRS))
    palette = build_player_palette(cells)
    palette24 = [to24(c) for c in palette]
    allowed = [i for i in range(1, 16) if i not in CROSSHAIR_COLORS] + [9]
    data = bytearray()
    previews = []
    for cell in cells:
        idx = quantize(cell, palette24, allowed)
        previews.append(idx)
        # Dwie pary sprite'ów połączonych (attached): lewa i prawa połowa 16 px.
        for half in range(2):
            for sprite in range(2):
                for y in range(32):
                    plane_a = 0
                    plane_b = 0
                    for lx in range(16):
                        value = idx[y][half * 16 + lx]
                        if value < 0:
                            continue
                        bits = value >> (2 * sprite)
                        bit = 15 - lx
                        if bits & 1:
                            plane_a |= 1 << bit
                        if bits & 2:
                            plane_b |= 1 << bit
                    data += struct.pack(">HH", plane_a, plane_b)
    sheet = Image.new("RGB", (32 * PLAYER_DIRS * 3, 32 * 4 * 3))
    for i, idx in enumerate(previews):
        direction, frame = divmod(i, 4)
        sheet.paste(indices_to_image(idx, palette24, 3), (direction * 96, frame * 96))
    sheet.save(PREVIEW / "player.png")
    return bytes(data), palette


def crosshair_sprite() -> bytes:
    rows = [
        "......3333......",
        "....33....33....",
        "...3........3...",
        "..3...........3.",
        ".3.....11.....3.",
        ".3.....11......3",
        "3......11......3",
        "3..1111..1111..3",
        "3..1111..1111..3",
        "3......11......3",
        ".3.....11.....3.",
        ".3.....11.....3.",
        "..3..........3..",
        "...3........3...",
        "....33....33....",
        "......3333......",
    ]
    rows = [
        "................",
        ".......33.......",
        ".......33.......",
        ".......11.......",
        "................",
        "................",
        ".......22.......",
        ".3311.2..2.1133.",
        ".3311.2..2.1133.",
        ".......22.......",
        "................",
        "................",
        ".......11.......",
        ".......33.......",
        ".......33.......",
        "................",
    ]
    data = bytearray()
    for row in rows:
        a = 0
        b = 0
        for x, ch in enumerate(row):
            if ch == ".":
                continue
            value = int(ch)
            if value & 1:
                a |= 1 << (15 - x)
            if value & 2:
                b |= 1 << (15 - x)
        data += struct.pack(">HH", a, b)
    return bytes(data)


def muzzle_sprite() -> bytes:
    rows = [
        "...2222.",
        "..233332",
        ".2333333",
        ".2333332",
        "..23332.",
        "...222..",
        "........",
        "........",
    ]
    data = bytearray()
    for row in rows:
        a = 0
        b = 0
        for x, ch in enumerate(row):
            if ch == ".":
                continue
            value = int(ch)
            if value & 1:
                a |= 1 << (15 - x - 4)
            if value & 2:
                b |= 1 << (15 - x - 4)
        data += struct.pack(">HH", a, b)
    return bytes(data)


# ---------------------------------------------------------------- fonty

FONT_CHARS = (
    " !\"#%'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[]_"
    "abcdefghijklmnopqrstuvwxyz|"
    "ĄĆĘŁŃÓŚŹŻąćęłńóśźż·•—"
)


def make_font(name: str, relative: str, size: int, weight: float, width: float | None,
              threshold: int, spacing: int, height: int) -> dict:
    path = REPOSITORY / relative
    note_source(f"font_{name}", relative, size=size, weight=weight)
    font = ImageFont.truetype(str(path), size * 4)
    axes = {"Weight": weight}
    if width is not None:
        axes["Width"] = width
    try:
        names = [axis[b"name"] if isinstance(axis.get(b"name"), bytes) else axis.get("name")
                 for axis in font.get_variation_axes()]
        values = []
        for axis in font.get_variation_axes():
            axis_name = axis.get("name")
            if isinstance(axis_name, bytes):
                axis_name = axis_name.decode()
            values.append(axes.get(axis_name, axis.get("default")))
        font.set_variation_by_axes(values)
        del names
    except OSError:
        pass
    ascent, descent = font.getmetrics()
    rendered = []
    top = 10 ** 6
    bottom = 0
    for char in FONT_CHARS:
        if char == " ":
            rendered.append((char, None))
            continue
        advance = font.getlength(char)
        canvas = Image.new("L", (int(advance) + size * 4, (ascent + descent) + 16), 0)
        ImageDraw.Draw(canvas).text((size * 2, 8), char, font=font, fill=255)
        small = canvas.resize((canvas.width // 4, canvas.height // 4), Image.Resampling.BOX)
        bits = small.point(lambda v: 255 if v >= threshold else 0)
        bbox = bits.getbbox()
        rendered.append((char, (bits, bbox)))
        if bbox:
            top = min(top, bbox[1])
            bottom = max(bottom, bbox[3])
    height = bottom - top
    glyphs = []
    for char, item in rendered:
        if item is None or item[1] is None:
            glyphs.append((ord(char), max(2, size // 3), [0] * height))
            continue
        bits, bbox = item
        x0, _, x1, _ = bbox
        w = min(x1 - x0, 32)
        rows = []
        for y in range(height):
            value = 0
            for x in range(w):
                if bits.getpixel((x0 + x, top + y)):
                    value |= 1 << (31 - x)
            rows.append(value)
        glyphs.append((ord(char), w + spacing, rows))
    return {"name": name, "height": height, "glyphs": glyphs}


def font_preview(font: dict, text: str, path: Path) -> None:
    width = sum(next(g[1] for g in font["glyphs"] if g[0] == ord(c)) for c in text) + 4
    image = Image.new("RGB", (width, font["height"] + 4), (4, 6, 14))
    px = image.load()
    x = 2
    for c in text:
        code, adv, rows = next(g for g in font["glyphs"] if g[0] == ord(c))
        for y, value in enumerate(rows):
            for bx in range(32):
                if value & (1 << (31 - bx)) and x + bx < width:
                    px[x + bx, y + 2] = (230, 240, 255)
        x += adv
    image.resize((image.width * 4, image.height * 4), Image.Resampling.NEAREST).save(path)


# ---------------------------------------------------------------- audio (port audio_lib.gd)

class Rng:
    def __init__(self, seed: int) -> None:
        self.r = random.Random(seed)

    def randf(self) -> float:
        return self.r.random()


def saw(f, t):
    return math.sin(math.tau * f * t) * 0.65 + math.sin(math.tau * 2 * f * t) * 0.3 + math.sin(math.tau * 3 * f * t) * 0.15


def sq(f, t):
    return math.sin(math.tau * f * t) * 0.7 + math.sin(math.tau * 3 * f * t) * 0.25 + math.sin(math.tau * 5 * f * t) * 0.12


def norm(samples, peak):
    mx = max(0.0001, max(abs(s) for s in samples))
    return [s * peak / mx for s in samples]


def synth(duration, fn, rate):
    n = int(duration * rate)
    return [fn(i / rate) for i in range(n)]


def build_sfx(rate: int) -> dict[str, list[float]]:
    rng = Rng(31337)
    noise = lambda: rng.randf() * 2 - 1
    sfx = {}
    sfx["shot"] = norm(synth(0.09, lambda t: noise() * math.exp(-55 * t) * 0.6 + math.sin(math.tau * (200 - 1100 * t) * t) * math.exp(-30 * t) * 0.8, rate), 0.95)
    sfx["hit"] = norm(synth(0.05, lambda t: noise() * math.exp(-70 * t) * 0.55 + math.sin(math.tau * (900 + 900 * t) * t) * math.exp(-60 * t) * 0.45, rate), 0.8)
    sfx["enemy_die"] = norm(synth(0.4, lambda t: saw(300 - 620 * t, t) * math.exp(-8 * t) * 0.45 + noise() * math.exp(-12 * t) * 0.6 + math.sin(math.tau * 70 * t) * math.exp(-20 * t) * 0.7, rate), 0.95)
    sfx["player_damage"] = norm(synth(0.3, lambda t: sq(90, t) * math.exp(-10 * t) * 0.45 + noise() * math.exp(-18 * t) * 0.55, rate), 0.9)

    def heal(t):
        f = 330 + 1100 * t
        return math.sin(math.tau * f * t) * math.exp(-5 * t) * 0.5 + math.sin(math.tau * f * 2 * t) * math.exp(-5 * t) * 0.25
    sfx["pickup_heal"] = norm(synth(0.3, heal, rate), 0.75)
    sfx["pickup_overdrive"] = norm(synth(0.5, lambda t: saw(140 + 2500 * t, t) * math.exp(-3 * t) * 0.5 + noise() * math.exp(-7 * t) * 0.3, rate), 0.85)
    sfx["overdrive_off"] = norm(synth(0.4, lambda t: saw(max(1400 - 2800 * t, 60), t) * math.exp(-3 * t) * 0.5, rate), 0.7)

    def wave_start(t):
        alarm = 440 if int(t / 0.18) % 2 == 0 else 554
        return math.sin(math.tau * 60 * t) * math.exp(-6 * t) * 0.8 + math.sin(math.tau * alarm * t) * (0.5 + 0.5 * math.sin(math.tau * 2.7 * t)) * 0.22 * math.exp(-t)
    sfx["wave_start"] = norm(synth(1.0, wave_start, rate), 0.95)

    def wave_clear(t):
        s = 0.0
        for nt, nf in enumerate((440.0, 659.25, 880.0)):
            t0 = nt * 0.2
            if t >= t0:
                s += math.sin(math.tau * nf * t) * math.exp(-9 * (t - t0)) * 0.3
        return s
    sfx["wave_clear"] = norm(synth(0.6, wave_clear, rate), 0.75)

    def game_over(t):
        s = 0.0
        for t0, f in ((0.0, 220.0), (0.25, 196.0), (0.5, 164.81), (0.75, 130.81)):
            if t >= t0:
                s += saw(f, t) * math.exp(-3.5 * (t - t0)) * 0.32
        return s + math.sin(math.tau * 55 * t) * math.exp(-2.2 * t) * 0.5
    sfx["game_over"] = norm(synth(1.6, game_over, rate), 0.9)
    return sfx


def build_music_layer(level: int, rate: int, rng: Rng) -> list[float]:
    total = 4.0
    n = int(total * rate)
    chords = [
        [55.0, 110.0, 130.81, 164.81],
        [43.65, 87.31, 110.0, 130.81],
        [65.41, 130.81, 164.81, 196.0],
        [49.0, 98.0, 123.47, 146.83],
    ]
    scale1 = [220.0, 261.63, 293.66, 329.63, 392.0, 440.0]
    scale2 = [440.0, 523.25, 587.33, 659.25, 783.99]
    out = []
    for i in range(n):
        t = i / rate
        bar = int(t) % 4
        bt = t - bar
        c = chords[bar]
        env = math.sin(math.pi * min(bt, 1.0)) ** 2
        s = 0.0
        for k in range(3):
            s += saw(c[1 + k], t) * 0.16 * env
        if level >= 1:
            st = int(bt / 0.25) * 0.25
            if bt - st < 0.16:
                s += saw(c[0], t) * 0.22 * math.exp(-38 * (bt - st))
        if level >= 2:
            hst = int(bt / 0.0625) * 0.0625
            if bt - hst < 0.05:
                s += (rng.randf() * 2 - 1) * 0.05 * math.exp(-160 * (bt - hst))
            aidx = int(bt / 0.125) % len(scale1)
            ast = int(bt / 0.125) * 0.125
            if bt - ast < 0.09:
                s += sq(scale1[aidx], t) * 0.11 * math.exp(-70 * (bt - ast))
        if level >= 3:
            kst = int(bt / 0.25) * 0.25
            if bt - kst < 0.16:
                s += math.sin(math.tau * (85 - 130 * (bt - kst)) * t) * 0.34 * math.exp(-26 * (bt - kst))
            bidx = int(bt / 0.0625) % len(scale2)
            bst = int(bt / 0.0625) * 0.0625
            if bt - bst < 0.05:
                s += sq(scale2[bidx] * 0.5, t) * 0.10 * math.exp(-90 * (bt - bst))
            if bt < 0.25:
                s += (rng.randf() * 2 - 1) * 0.06 * math.exp(-22 * bt)
        out.append(s)
    return out


def to_s8(samples: list[float], gain: float = 1.0) -> bytes:
    return bytes((max(-128, min(127, round(s * gain * 127))) & 0xFF) for s in samples)


def lowpass(samples: list[float], rate: int, cutoff: float) -> list[float]:
    alpha = 1 - math.exp(-math.tau * cutoff / rate)
    out = []
    y = 0.0
    for s in samples:
        y += alpha * (s - y)
        out.append(y)
    return out


# ---------------------------------------------------------------- zapis

IMA_STEPS = [
    7, 8, 9, 10, 11, 12, 13, 14, 16, 17, 19, 21, 23, 25, 28, 31, 34, 37, 41, 45, 50, 55, 60, 66,
    73, 80, 88, 97, 107, 118, 130, 143, 157, 173, 190, 209, 230, 253, 279, 307, 337, 371, 408,
    449, 494, 544, 598, 658, 724, 796, 876, 963, 1060, 1166, 1282, 1411, 1552, 1707, 1878, 2066,
    2272, 2499, 2749, 3024, 3327, 3660, 4026, 4428, 4871, 5358, 5894, 6484, 7132, 7845, 8630,
    9493, 10442, 11487, 12635, 13899, 15289, 16818, 18500, 20350, 22385, 24623, 27086, 29794, 32767,
]
IMA_INDEX = [-1, -1, -1, -1, 2, 4, 6, 8, -1, -1, -1, -1, 2, 4, 6, 8]


def ima_encode(data: bytes) -> bytes:
    """IMA ADPCM 4-bit: próbki s8 (×256), dwie próbki na bajt (starszy półbajt pierwszy)."""
    predicted = 0
    index = 0
    nibbles = []
    for byte in data:
        sample = (byte - 256 if byte > 127 else byte) * 256
        step = IMA_STEPS[index]
        diff = sample - predicted
        code = 0
        if diff < 0:
            code = 8
            diff = -diff
        delta = step >> 3
        if diff >= step:
            code |= 4
            diff -= step
            delta += step
        if diff >= step >> 1:
            code |= 2
            diff -= step >> 1
            delta += step >> 1
        if diff >= step >> 2:
            code |= 1
            delta += step >> 2
        predicted = predicted - delta if code & 8 else predicted + delta
        predicted = max(-32768, min(32767, predicted))
        index = max(0, min(88, index + IMA_INDEX[code]))
        nibbles.append(code)
    if len(nibbles) % 2:
        nibbles.append(0)
    return bytes((nibbles[i] << 4) | nibbles[i + 1] for i in range(0, len(nibbles), 2))


def lzss_encode(data: bytes) -> bytes:
    """LZSS: bajt flag (bit=1 literał, 0 odwołanie), odwołanie = 12 bitów przesunięcia + 4 bity długości-3."""
    out = bytearray()
    position = 0
    size = len(data)
    table: dict[bytes, list[int]] = {}
    while position < size:
        flag_index = len(out)
        out.append(0)
        flags = 0
        for bit in range(8):
            if position >= size:
                break
            best_length = 0
            best_offset = 0
            key = data[position:position + 3]
            if len(key) == 3:
                candidates = table.get(key, [])
                for start in reversed(candidates[-64:]):
                    offset = position - start
                    if offset > 4095:
                        break
                    length = 3
                    while length < 18 and position + length < size and data[start + length] == data[position + length]:
                        length += 1
                    if length > best_length:
                        best_length = length
                        best_offset = offset
                        if length == 18:
                            break
            if best_length >= 3:
                value = (best_offset << 4) | (best_length - 3)
                out += bytes((value >> 8, value & 0xFF))
                advance = best_length
            else:
                flags |= 1 << (7 - bit)
                out.append(data[position])
                advance = 1
            for k in range(advance):
                p = position + k
                if p + 3 <= size:
                    table.setdefault(data[p:p + 3], []).append(p)
            position += advance
        out[flag_index] = flags
    return bytes(out)


DATA_LINES: list[str] = []


def c_array(name: str, values, ctype: str = "unsigned short", per_line: int = 12, fmt="0x{:04x}") -> list[str]:
    """Definicja trafia do assets_data.c, nagłówek dostaje deklarację extern."""
    values = list(values)
    DATA_LINES.append(f"const {ctype} {name}[{len(values)}] = {{")
    for i in range(0, len(values), per_line):
        DATA_LINES.append("\t" + ", ".join(fmt.format(v) for v in values[i:i + per_line]) + ",")
    DATA_LINES.append("};")
    return [f"extern const {ctype} {name}[{len(values)}];"]


def ocs(color) -> int:
    return (color[0] << 8) | (color[1] << 4) | color[2]


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    PREVIEW.mkdir(parents=True, exist_ok=True)
    for stale in ("sprites.h", "font.h"):
        (OUTPUT / stale).unlink(missing_ok=True)
    header = [
        "#ifndef PHOBOS_ASSETS_H",
        "#define PHOBOS_ASSETS_H",
        "",
        "/* Wygenerowano przez tools/convert_assets.py — nie edytować ręcznie. */",
        "",
    ]

    arena = build_arena()
    gfx, _ = interleaved_bob(arena, ARENA_W // 16)
    chip_add("ASSET_ARENA", gfx)

    enemies = enemy_frames()
    data = bytearray()
    for idx in enemies:
        g, m = interleaved_bob(idx, 1)
        data += g + m
    chip_add("ASSET_ENEMIES", data)

    spawn = spawn_frames()
    data = bytearray()
    for idx in spawn:
        g, m = interleaved_bob(idx, 1)
        data += g + m
    chip_add("ASSET_SPAWN", data)

    telegraph = telegraph_frames()
    data = bytearray()
    for idx in telegraph:
        g, m = interleaved_bob(idx, 1)
        data += g + m
    chip_add("ASSET_TELEGRAPH", data)

    pickups = pickup_frames()
    data = bytearray()
    for idx in pickups:
        g, m = interleaved_bob(idx, 1)
        data += g + m
    chip_add("ASSET_PICKUPS", data)

    explosions = explosion_frames()
    data = bytearray()
    for idx in explosions:
        g, m = interleaved_bob(idx, 2)
        data += g + m
    chip_add("ASSET_EXPLOSIONS", data)

    player, player_palette = player_frames()
    chip_add("ASSET_PLAYER", player)
    chip_add("ASSET_CROSSHAIR", crosshair_sprite())
    chip_add("ASSET_MUZZLE", muzzle_sprite())

    sfx = build_sfx(SFX_RATE)
    sfx_order = ["shot", "hit", "enemy_die", "player_damage", "pickup_heal", "pickup_overdrive",
                 "overdrive_off", "wave_start", "wave_clear", "game_over"]
    sfx_offsets = []
    for name in sfx_order:
        samples = lowpass(sfx[name], SFX_RATE, 4200)
        raw = to_s8(samples)
        if len(raw) % 2:
            raw += b"\x00"
        offset = chip_add(f"SFX_{name.upper()}", raw, align=2)
        sfx_offsets.append((name, offset, len(raw)))
    chip_add("SFX_SILENCE", b"\x00\x00\x00\x00", align=2)

    music_rng = Rng(31337)
    music = bytearray()
    layer_length = 0
    for level in range(4):
        layer = lowpass(build_music_layer(level, MUSIC_RATE, music_rng), MUSIC_RATE, 3400)
        raw = to_s8(norm(layer, 0.92))
        layer_length = len(raw)
        music += raw
    (OUTPUT / "music.bin").write_bytes(bytes(music))
    (OUTPUT / "chip.bin").write_bytes(bytes(chip))
    sfx_start = symbols["SFX_SHOT"]
    gfx_lz = lzss_encode(bytes(chip[:sfx_start]))
    sfx_raw = bytes(chip[sfx_start:])
    music_ima = ima_encode(bytes(music))
    (OUTPUT / "gfx.lz").write_bytes(gfx_lz)
    (OUTPUT / "sfx.raw").write_bytes(sfx_raw)
    (OUTPUT / "sfx.ima").unlink(missing_ok=True)
    (OUTPUT / "music.ima").write_bytes(music_ima)
    print(f"gfx.lz {len(gfx_lz)} B, sfx.raw {len(sfx_raw)} B, music.ima {len(music_ima)} B")

    # Fonty: XL (tytuły, banery), L (fala w HUD), S (UI).
    fonts = [
        make_font("xl", "project/assets/fonts/Tektur-Variable.ttf", 22, 760, 88, 120, 1, 18),
        make_font("l", "project/assets/fonts/Tektur-Variable.ttf", 16, 760, 88, 120, 1, 14),
        make_font("s", "project/assets/fonts/Oxanium-Variable.ttf", 9, 600, None, 110, 1, 9),
    ]
    for font in fonts:
        font_preview(font, "FALA 12 · 33 s PHOBOS ŁATWY Zabicia: 07 wznów ĄĆĘŁŃÓŚŹŻ", PREVIEW / f"font_{font['name']}.png")

    header.append(f"#define ASSET_CHIP_SIZE {len(chip)}UL")
    header.append(f"#define ASSET_GFX_SIZE {symbols['SFX_SHOT']}UL")
    header.append(f"#define ASSET_SFX_SAMPLES {len(chip) - symbols['SFX_SHOT']}UL")
    header.append(f"#define ASSET_MUSIC_SIZE {len(music)}UL")
    for name, offset in symbols.items():
        header.append(f"#define {name} {offset}UL")
    header += [
        "",
        f"#define ASSET_ARENA_WIDTH {ARENA_W}",
        f"#define ASSET_ARENA_HEIGHT {ARENA_H}",
        f"#define ASSET_ENEMY_DIRS {ENEMY_DIRS}",
        f"#define ASSET_PLAYER_DIRS {PLAYER_DIRS}",
        "#define ASSET_BOB16_SIZE 256",
        "#define ASSET_BOB32_SIZE 1024",
        "#define ASSET_PLAYER_FRAME_SIZE 512",
        f"#define ASSET_SFX_PERIOD {SFX_PERIOD}",
        f"#define ASSET_MUSIC_PERIOD {MUSIC_PERIOD}",
        f"#define ASSET_MUSIC_LAYER_LENGTH {layer_length}UL",
        f"#define ASSET_MUSIC_BUFFER {MUSIC_BUFFER}",
        f"#define ASSET_SFX_COUNT {len(sfx_order)}",
        "",
    ]
    header += c_array("asset_sin", [round(math.sin(i * math.tau / 1024) * 16384) for i in range(1024)], "short", 12, "{:d}")
    header += c_array("asset_atan", [round(math.atan(i / 64) / math.tau * 1024) for i in range(65)], "unsigned char", 16, "{:d}")
    header += c_array("asset_arena_palette", [ocs(c) for c in ARENA_PALETTE])
    header += c_array("asset_hud_palette", [ocs(c) for c in HUD_PALETTE])
    header += c_array("asset_menu_palette", [ocs(c) for c in MENU_PALETTE])
    header += c_array("asset_sprite_palette", [ocs(c) for c in player_palette])
    header.append("")
    header.append("typedef struct { unsigned long offset; unsigned short length; } AssetSample;")
    header.append("extern const AssetSample asset_sfx[ASSET_SFX_COUNT];")
    DATA_LINES.append("const AssetSample asset_sfx[ASSET_SFX_COUNT] = {")
    for name, offset, length in sfx_offsets:
        DATA_LINES.append(f"\t{{{offset}UL, {length}}}, /* {name} */")
    DATA_LINES.append("};")
    header.append("enum {")
    for name, _, _ in sfx_offsets:
        header.append(f"\tSFX_ID_{name.upper()},")
    header.append("};")
    header.append("")
    header.append("typedef struct {")
    header.append("\tunsigned short code;")
    header.append("\tunsigned char advance;")
    header.append("\tunsigned char pad;")
    header.append("\tunsigned short rows;")
    header.append("} AssetGlyph;")
    header.append("typedef struct {")
    header.append("\tunsigned short height;")
    header.append("\tunsigned short count;")
    header.append("\tconst AssetGlyph *glyphs;")
    header.append("\tconst unsigned long *bits;")
    header.append("} AssetFont;")
    for font in fonts:
        n = font["name"]
        rows_all = []
        glyph_lines = [f"const AssetGlyph asset_font_{n}_glyphs[{len(font['glyphs'])}] = {{"]
        for code, adv, rows in sorted(font["glyphs"], key=lambda g: g[0]):
            glyph_lines.append(f"\t{{0x{code:04x}, {adv}, 0, {len(rows_all)}}},")
            rows_all += rows
        glyph_lines.append("};")
        DATA_LINES.extend(glyph_lines)
        c_array(f"asset_font_{n}_bits", rows_all, "unsigned long", 6, "0x{:08x}UL")
        DATA_LINES.append(
            f"const AssetFont asset_font_{n} = {{{font['height']}, {len(font['glyphs'])}, "
            f"asset_font_{n}_glyphs, asset_font_{n}_bits}};"
        )
        header.append(f"extern const AssetFont asset_font_{n};")
        header.append("")
    header += ["#endif", ""]
    (OUTPUT / "assets.h").write_text("\n".join(header), encoding="utf-8")
    (OUTPUT / "assets_data.c").write_text(
        "/* Wygenerowano przez tools/convert_assets.py — nie edytować ręcznie. */\n"
        "#include \"assets.h\"\n\n" + "\n".join(DATA_LINES) + "\n", encoding="utf-8")
    (OUTPUT / "assets.s").write_text(
        "\t.data\n"
        "\t.balign 4\n"
        "\t.globl _asset_gfx_lz\n"
        "_asset_gfx_lz:\n"
        "\t.incbin \"gfx.lz\"\n"
        "\t.balign 4\n"
        "\t.globl _asset_sfx_raw\n"
        "_asset_sfx_raw:\n"
        "\t.incbin \"sfx.raw\"\n"
        "\t.balign 4\n"
        "\t.globl _asset_music_ima\n"
        "_asset_music_ima:\n"
        "\t.incbin \"music.ima\"\n",
        encoding="ascii",
    )
    manifest.append({"name": "sfx", "rate": SFX_RATE, "format": "s8 PCM", "sounds": sfx_order})
    manifest.append({"name": "music", "rate": MUSIC_RATE, "format": "s8 PCM", "layers": 4,
                     "layer_bytes": layer_length})
    manifest.append({"name": "gfx.lz", "bytes": len(gfx_lz), "format": "LZSS 12/4"})
    manifest.append({"name": "sfx.raw", "bytes": len(sfx_raw), "format": "s8 PCM"})
    manifest.append({"name": "music.ima", "bytes": len(music_ima), "format": "IMA ADPCM 4-bit"})
    manifest.append({"name": "chip.bin", "bytes": len(chip),
                     "sha256": hashlib.sha256(bytes(chip)).hexdigest()})
    manifest.append({"name": "music.bin", "bytes": len(music),
                     "sha256": hashlib.sha256(bytes(music)).hexdigest()})
    (OUTPUT / "manifest.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=True) + "\n",
                                          encoding="ascii")
    print(f"chip.bin {len(chip)} B, music.bin {len(music)} B")


if __name__ == "__main__":
    main()
