"""Render synthetic documents as scanned images and OCR them with RapidOCR.

    dataset/.venv/Scripts/python dataset/scan_ocr.py --people 40 --out dataset/generated
    add --engine windows to use the OCR built into Windows, as the app does

For each document three images are made and OCR'd:
  original  - a scan of the document
  rescan    - another scan of the same, unchanged document (new tilt, blur,
              resolution and JPEG quality), the harmless case
  edited    - a scan of the document with one digit of one field changed
Writes ocr.jsonl (OCR text + gold fields per image). Images go to
<out>/scans/. Everything is synthetic (people from generate.py).
"""

import argparse
import io
import json
import os
import random
import re
import subprocess
import time
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

from generate import make_person
from render_text import all_docs, render

FONTS = ["arial.ttf", "times.ttf", "verdana.ttf", "cour.ttf"]


def draw(text, font_name, size):
    font = ImageFont.truetype(font_name, size)
    lines = text.split("\n")
    w = max(int(font.getlength(l)) for l in lines) + 120
    h = int(len(lines) * size * 1.7) + 120
    img = Image.new("L", (w, h), 250)
    d = ImageDraw.Draw(img)
    y = 60
    for line in lines:
        d.text((60, y), line, fill=25, font=font)
        y += int(size * 1.7)
    return img


def scan(r, img):
    """What a phone scan does: tilt, softness, lower resolution, JPEG."""
    img = img.rotate(r.uniform(-1.5, 1.5), expand=True, fillcolor=250)
    img = img.filter(ImageFilter.GaussianBlur(r.uniform(0.0, 1.0)))
    scale = r.uniform(0.6, 0.9)
    small = img.resize((int(img.width * scale), int(img.height * scale)))
    img = small.resize(img.size)
    buf = io.BytesIO()
    img.convert("RGB").save(buf, "JPEG", quality=r.randint(35, 70))
    return Image.open(io.BytesIO(buf.getvalue())).convert("RGB")


def ocr_text(engine, img):
    """OCR boxes regrouped into lines, top to bottom, left to right."""
    res, _ = engine(img)
    if not res:
        return ""
    boxes = []
    for box, txt, _score in res:
        ys = [p[1] for p in box]
        boxes.append(((min(ys) + max(ys)) / 2, max(ys) - min(ys), min(p[0] for p in box), txt))
    boxes.sort()
    lines, cur = [], [boxes[0]]
    for b in boxes[1:]:
        if abs(b[0] - cur[-1][0]) < 0.5 * max(b[1], cur[-1][1]):
            cur.append(b)
        else:
            lines.append(cur)
            cur = [b]
    lines.append(cur)
    return "\n".join(" ".join(t for *_, t in sorted(l, key=lambda b: b[2])) for l in lines)


def windows_ocr(img, tmp):
    """The OCR built into Windows, through windows_ocr.ps1."""
    img.save(tmp, quality=90)
    res = subprocess.run(
        ["powershell", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass",
         "-File", str(Path(__file__).with_name("windows_ocr.ps1"))],
        env={**os.environ, "DOCUVEIL_OCR_IMAGE": str(Path(tmp).resolve())},
        capture_output=True, encoding="utf-8", errors="replace", check=True,
    )
    return res.stdout.strip()


def edit_one_digit(r, text, gold):
    """Change one digit of one printed field value. Returns (text, gold, edit)
    or None when no field value with a digit is printed verbatim."""
    keys = [k for k, v in gold.items() if v in text and re.search(r"\d", v)]
    if not keys:
        return None
    k = r.choice(keys)
    old = gold[k]
    idx = [i for i, c in enumerate(old) if c.isdigit()]
    i = r.choice(idx)
    new = old[:i] + str((int(old[i]) + r.randint(1, 8)) % 10) + old[i + 1:]
    g = dict(gold)
    g[k] = new
    return text.replace(old, new, 1), g, {"field": k, "old": old, "new": new}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--people", type=int, default=40)
    ap.add_argument("--seed", type=int, default=11)
    ap.add_argument("--out", default="dataset/generated")
    ap.add_argument("--engine", choices=["rapidocr", "windows"], default="rapidocr")
    a = ap.parse_args()
    r = random.Random(a.seed)
    out = Path(a.out)
    (out / "scans").mkdir(parents=True, exist_ok=True)
    if a.engine == "rapidocr":
        from rapidocr_onnxruntime import RapidOCR  # only needed for this engine

        rapid = RapidOCR()
        read = lambda img: ocr_text(rapid, img)
    else:
        read = lambda img: windows_ocr(img, out / "scans" / "_current.jpg")
    rows, t0 = [], time.time()
    for i in range(a.people):
        p = make_person(r, i)
        for doc in all_docs(r, p):
            text, gold = render(r, doc)
            font, size = r.choice(FONTS), r.randint(26, 34)
            variants = [("original", text, gold, None), ("rescan", text, gold, None)]
            e = edit_one_digit(r, text, gold)
            if e:
                variants.append(("edited", *e))
            for name, t, g, edit in variants:
                img = scan(r, draw(t, font, size))
                img.save(out / "scans" / f"{doc['id']}-{name}.jpg", quality=80)
                rows.append({"id": doc["id"], "doc_type": doc["doc_type"], "variant": name,
                             "font": font, "ocr": a.engine, "text": read(img), "fields": g, "edit": edit})
        print(f"person {i + 1}/{a.people}  images={len(rows)}  {time.time() - t0:.0f}s", flush=True)
    with open(out / "ocr.jsonl", "w", encoding="utf-8") as fh:
        for row in rows:
            fh.write(json.dumps(row, ensure_ascii=False) + "\n")
    print(f"wrote {len(rows)} rows -> {out / 'ocr.jsonl'}")


if __name__ == "__main__":
    main()
