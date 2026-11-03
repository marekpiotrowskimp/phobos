"""Dekoder zrzutów `PHOBOS --demo` z portu szeregowego.

Odtwarza obraz PAL 320×256 na podstawie rzeczywistej listy Coppera, bitplanów i danych
sprite'ów zapisanych przez Amigę (uproszczona emulacja OCS: lowres, DDFSTRT $30, BPLCON1,
moduły, 8 sprite'ów z trybem attached). Zapisuje <nazwa>.png do katalogu wyjściowego.
"""

from __future__ import annotations

import struct
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
GENERATED = ROOT / "assets" / "generated"


def lzss_decode(data: bytes) -> bytes:
    out = bytearray()
    position = 0
    while position < len(data):
        flags = data[position]
        position += 1
        for bit in range(8):
            if position >= len(data):
                break
            if flags & (0x80 >> bit):
                out.append(data[position])
                position += 1
            else:
                value = (data[position] << 8) | data[position + 1]
                position += 2
                start = len(out) - (value >> 4)
                for k in range((value & 15) + 3):
                    out.append(out[start + k])
    return bytes(out)


def chip_image() -> bytes:
    """Zawartość Chip RAM z zasobami, tak jak rozpakowuje ją program."""
    return lzss_decode((GENERATED / "gfx.lz").read_bytes()) + (GENERATED / "sfx.raw").read_bytes()
DISPLAY_TOP = 0x2C
FETCH_WORDS = 21


class Memory:
    def __init__(self) -> None:
        self.blocks: list[tuple[int, bytes]] = []

    def add(self, address: int, data: bytes) -> None:
        self.blocks.append((address, data))

    def word(self, address: int) -> int:
        for start, data in self.blocks:
            if start <= address < start + len(data) - 1:
                offset = address - start
                return (data[offset] << 8) | data[offset + 1]
        return 0


def parse_dumps(raw: bytes):
    dumps = []
    position = 0
    while True:
        start = raw.find(b"\n@@DUMP ", position)
        if start < 0:
            break
        line_end = raw.index(b"\n", start + 1)
        name = raw[start + 8:line_end].decode("ascii", "replace").strip()
        cursor = raw.index(b"\n", line_end + 1) + 1
        memory = Memory()
        asset_address = None
        ok = True
        while cursor < len(raw) and raw[cursor:cursor + 1] == b"B":
            address, length = struct.unpack(">II", raw[cursor + 1:cursor + 9])
            data = raw[cursor + 9:cursor + 9 + length]
            (checksum,) = struct.unpack(">I", raw[cursor + 9 + length:cursor + 13 + length])
            value = 0
            for byte in data:
                value = (value * 31 + byte) & 0xFFFFFFFF
            if value != checksum or len(data) != length:
                ok = False
            if length == 0 and asset_address is None:
                asset_address = address
            else:
                memory.add(address, data)
            cursor += 13 + length
        if asset_address is not None:
            memory.add(asset_address, chip_image())
        copper_address = memory.blocks[0][0] if memory.blocks else 0
        dumps.append((name, memory, copper_address, ok))
        position = cursor
    return dumps


def render(memory: Memory, copper: int) -> Image.Image:
    colors = [0] * 32
    bplpt = [0] * 6
    sprpt = [0] * 8
    regs = {"bplcon0": 0, "bplcon1": 0, "mod1": 0, "mod2": 0}
    instructions = []
    address = copper
    for _ in range(2048):
        a = memory.word(address)
        b = memory.word(address + 2)
        address += 4
        instructions.append((a, b))
        if a == 0xFFFF and b == 0xFFFE:
            break

    def move(register: int, value: int) -> None:
        if 0x180 <= register < 0x1C0:
            colors[(register - 0x180) // 2] = value & 0xFFF
        elif 0xE0 <= register < 0xF8:
            index = (register - 0xE0) // 4
            if register & 2:
                bplpt[index] = (bplpt[index] & 0xFFFF0000) | value
            else:
                bplpt[index] = (bplpt[index] & 0xFFFF) | (value << 16)
        elif 0x120 <= register < 0x140:
            index = (register - 0x120) // 4
            if register & 2:
                sprpt[index] = (sprpt[index] & 0xFFFF0000) | value
            else:
                sprpt[index] = (sprpt[index] & 0xFFFF) | (value << 16)
        elif register == 0x100:
            regs["bplcon0"] = value
        elif register == 0x102:
            regs["bplcon1"] = value
        elif register == 0x108:
            regs["mod1"] = value - 0x10000 if value & 0x8000 else value
        elif register == 0x10A:
            regs["mod2"] = value - 0x10000 if value & 0x8000 else value

    pc = 0
    high = False

    def run_until(line: int) -> None:
        nonlocal pc, high
        while pc < len(instructions):
            a, b = instructions[pc]
            if a == 0xFFFF and b == 0xFFFE:
                return
            if a & 1:
                vertical = a >> 8
                if a == 0xFFDF:
                    if line < 256:
                        return
                    high = True
                    pc += 1
                    continue
                target = vertical + (256 if high else 0)
                if target > line:
                    return
                pc += 1
                continue
            move(a & 0x1FE, b)
            pc += 1

    run_until(0)
    sprites = []
    for index in range(8):
        base = sprpt[index]
        pos = memory.word(base)
        ctl = memory.word(base + 2)
        vstart = (pos >> 8) | (((ctl >> 2) & 1) << 8)
        vstop = (ctl >> 8) | (((ctl >> 1) & 1) << 8)
        hstart = ((pos & 0xFF) << 1) | (ctl & 1)
        sprites.append((base, vstart, vstop, hstart, bool(ctl & 0x80)))

    image = Image.new("RGB", (320, 256))
    pixels = image.load()
    for line in range(DISPLAY_TOP, DISPLAY_TOP + 256):
        run_until(line)
        planes = (regs["bplcon0"] >> 12) & 7
        row = [0] * 320
        if planes:
            fetched = []
            for plane in range(planes):
                words = [memory.word(bplpt[plane] + i * 2) for i in range(FETCH_WORDS)]
                bits = 0
                for value in words:
                    bits = (bits << 16) | value
                fetched.append(bits)
                bplpt[plane] += FETCH_WORDS * 2 + (regs["mod1"] if plane % 2 == 0 else regs["mod2"])
            total = FETCH_WORDS * 16
            for x in range(320):
                value = 0
                for plane in range(planes):
                    delay = regs["bplcon1"] & 15 if plane % 2 == 0 else (regs["bplcon1"] >> 4) & 15
                    index = x + 16 - delay
                    if 0 <= index < total and (fetched[plane] >> (total - 1 - index)) & 1:
                        value |= 1 << plane
                row[x] = value
        y = line - DISPLAY_TOP
        sprite_colors = [None] * 320
        for index in range(7, -1, -1):
            base, vstart, vstop, hstart, attached = sprites[index]
            if not (vstart <= line < vstop):
                continue
            offset = 4 + (line - vstart) * 4
            data_a = memory.word(base + offset)
            data_b = memory.word(base + offset + 2)
            if index % 2 == 1 and attached:
                continue
            pair_attached = index % 2 == 0 and sprites[index + 1][4]
            if pair_attached:
                obase, ovstart, _, _, _ = sprites[index + 1]
                ooffset = 4 + (line - ovstart) * 4
                odata_a = memory.word(obase + ooffset)
                odata_b = memory.word(obase + ooffset + 2)
            for bit in range(16):
                x = hstart - 128 + bit
                if not 0 <= x < 320:
                    continue
                shift = 15 - bit
                value = ((data_a >> shift) & 1) | (((data_b >> shift) & 1) << 1)
                if pair_attached:
                    value |= (((odata_a >> shift) & 1) << 2) | (((odata_b >> shift) & 1) << 3)
                    if value:
                        sprite_colors[x] = 16 + value
                elif value:
                    sprite_colors[x] = 16 + (index // 2) * 4 + value
        for x in range(320):
            color = colors[sprite_colors[x]] if sprite_colors[x] is not None else colors[row[x]]
            pixels[x, y] = (((color >> 8) & 15) * 17, ((color >> 4) & 15) * 17, (color & 15) * 17)
    return image


def main() -> None:
    raw = Path(sys.argv[1]).read_bytes()
    out = Path(sys.argv[2])
    out.mkdir(parents=True, exist_ok=True)
    for line in raw.split(b"\n"):
        if line.startswith(b"T") or line.startswith(b"RESULT") or line.startswith(b"PHOBOS"):
            print(line.decode("ascii", "replace"))
    for name, memory, copper, ok in parse_dumps(raw):
        image = render(memory, copper)
        image.resize((960, 768), Image.Resampling.NEAREST).save(out / f"{name}.png")
        print(f"{name}.png{'' if ok else ' (BŁĄD SUMY KONTROLNEJ)'}")


if __name__ == "__main__":
    main()
