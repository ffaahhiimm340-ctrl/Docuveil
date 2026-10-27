"""Synthetic benchmark generator. Standard library only; fully synthetic people.

    py -3.12 dataset/generate.py --people 50 --seed 1 --out dataset/generated

Writes three JSONL files (format: docs/contracts/fields.md):
    tamper.jsonl    baseline vs edited copy, label = changed fields with old/new values
    harmless.jsonl  baseline vs re-save / re-scan / reformat, label = no field changed
    audit.jsonl     one person's documents with injected naming/DOB/gender mismatches
"""

import argparse
import copy
import json
import random
from pathlib import Path

GIVEN_M = ["Rahul", "Amit", "Suresh", "Vikram", "Arjun", "Mohammed", "Rohan", "Karthik", "Aman", "Sandeep"]
GIVEN_F = ["Priya", "Anita", "Sunita", "Kavya", "Neha", "Lakshmi", "Pooja", "Divya", "Meera", "Riya"]
MIDDLE = ["Kumar", "Prasad", "Lal", "Devi", "Raj", "Nath", "Chandra"]
SURNAMES = ["Sharma", "Verma", "Patel", "Singh", "Iyer", "Reddy", "Nair", "Gupta", "Joshi", "Khan"]
SPELLING = {"Mohammed": "Mohammad", "Lakshmi": "Laxmi", "Kavya": "Kavia", "Sharma": "Sarma", "Singh": "Sing", "Krishna": "Krushna"}
UNIVERSITIES = ["Synthetic University of Pune", "Fictional Institute of Technology"]
INSURERS = ["Imaginary Life Insurance", "Sample General Insurance"]
MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]


def digits(r, n):
    return "".join(r.choice("0123456789") for _ in range(n))


def letters(r, n):
    return "".join(r.choice("ABCDEFGHJKLMNPRSTUVWXYZ") for _ in range(n))


def make_person(r, i):
    female = r.random() < 0.5
    given = r.choice(GIVEN_F if female else GIVEN_M)
    middle = r.choice(MIDDLE)
    surname = r.choice(SURNAMES)
    father = f"{r.choice(GIVEN_M)} {surname}"
    d, m, y = r.randint(1, 28), r.randint(1, 12), r.randint(1990, 2004)
    return {
        "idx": i, "name": f"{given} {middle} {surname}", "given": given, "middle": middle,
        "surname": surname, "father": father, "female": female, "dob": (d, m, y),
    }


def dob_str(p, fmt="slash"):
    d, m, y = p["dob"]
    return {"slash": f"{d:02d}/{m:02d}/{y}", "dash": f"{d}-{m}-{y}", "words": f"{d} {MONTHS[m - 1]} {y}"}[fmt]


def make_docs(r, p):
    pid = f"p{p['idx']:03d}"
    gender = "Female" if p["female"] else "Male"
    g = {
        "aadhaar": {"name": p["name"], "dob": dob_str(p), "gender": gender, "father_name": p["father"],
                    "id_number": f"{digits(r, 4)} {digits(r, 4)} {digits(r, 4)}"},
        "pan": {"name": p["name"].upper(), "dob": dob_str(p, "dash"), "father_name": p["father"].upper(),
                "id_number": f"{letters(r, 5)}{digits(r, 4)}{letters(r, 1)}"},
        "marksheet": {"name": p["name"], "dob": dob_str(p), "university": r.choice(UNIVERSITIES),
                      "semester": str(r.randint(1, 8)), "cgpa": f"{r.uniform(6, 9.9):.2f}",
                      "seat_number": f"S{digits(r, 6)}"},
        "passport": {"name": p["name"], "dob": dob_str(p, "words"), "gender": gender,
                     "father_name": p["father"], "id_number": f"{letters(r, 1)}{digits(r, 7)}",
                     "expiry_date": f"{r.randint(1, 28):02d}/{r.randint(1, 12):02d}/{r.randint(2027, 2034)}"},
        "insurance": {"name": p["name"], "policy_number": f"POL{digits(r, 8)}", "insurer": r.choice(INSURERS),
                      "sum_assured": str(r.choice([500000, 1000000, 2000000])), "nominee": p["father"],
                      "expiry_date": f"{r.randint(1, 28):02d}/{r.randint(1, 12):02d}/{r.randint(2027, 2035)}"},
    }
    docs = []
    for t, fields in g.items():
        text = "SYNTHETIC SAMPLE " + t.upper() + " " + " ".join(f"{k.replace('_', ' ')} {v}" for k, v in fields.items())
        docs.append({"id": f"{pid}-{t}", "doc_type": t, "fields": fields, "text": text})
    return docs


def tamper(r, doc):
    d = copy.deepcopy(doc)
    key = r.choice([k for k in d["fields"] if k not in ("university", "insurer")])
    old = d["fields"][key]
    if key == "cgpa":
        new = f"{min(9.99, float(old) + r.uniform(0.3, 1.5)):.2f}"
    elif key in ("dob", "expiry_date"):
        parts = old.replace("-", "/").split("/")
        if len(parts) == 3 and parts[2].isdigit():
            parts[2] = str(int(parts[2]) + r.choice([-3, -1, 1, 2, 4]))
            new = "/".join(parts)
        else:
            new = old + " (edited)"
    elif key == "name":
        last = old.split()[-1]
        other = r.choice([s for s in SURNAMES if s.lower() != last.lower()])
        new = old[: len(old) - len(last)] + (other.upper() if last.isupper() else other)
    elif key == "sum_assured":
        new = str(int(old) * 5)
    elif key == "gender":
        new = "Male" if old.lower().startswith("f") else "Female"
    elif key in ("father_name", "nominee"):
        parts = old.split()
        new = " ".join([r.choice([g for g in GIVEN_M if g.upper() != parts[0].upper()])] + parts[1:])
        if old.isupper():
            new = new.upper()
    elif key == "id_number" and not old[-1].isdigit():
        new = old[:-1] + ("Z" if old[-1] != "Z" else "K")
    elif key == "semester":
        new = str((int(old) % 8) + 1)
    else:
        new = old[:-1] + str((int(old[-1]) + 1) % 10) if old[-1].isdigit() else old + "X"
    if new == old:
        new = old + "9"
    d["fields"][key] = new
    d["text"] = d["text"].replace(old, new)
    return d, {key: [old, new]}


def harmless(r, doc):
    d = copy.deepcopy(doc)
    kind = r.choice(["resave", "rescan_noise", "case_change", "date_format"])
    if kind == "rescan_noise":
        d["text"] = d["text"].replace(" ", "  ", 2).lower()
        if "cgpa" in d["fields"]:
            d["fields"]["cgpa"] += "0"
    elif kind == "case_change" and "name" in d["fields"]:
        d["fields"]["name"] = d["fields"]["name"].upper()
    elif kind == "date_format" and "dob" in d["fields"]:
        d["fields"]["dob"] = d["fields"]["dob"].replace("/", "-")
    else:
        kind = "resave"
    return d, kind


def indian_grouping(n):
    s = str(int(n))
    if len(s) <= 3:
        return s
    head, tail = s[:-3], s[-3:]
    parts = []
    while len(head) > 2:
        parts.insert(0, head[-2:])
        head = head[:-2]
    if head:
        parts.insert(0, head)
    return ",".join(parts + [tail])


def _set(d, key, new):
    old = d["fields"][key]
    d["fields"][key] = new
    d["text"] = d["text"].replace(old, new)
    return old


def hard_tamper(r, doc):
    """Subtle edits. Returns (edited doc, changed_fields, subtype)."""
    d = copy.deepcopy(doc)
    f = d["fields"]
    kinds = []
    if "cgpa" in f:
        kinds.append("digit_flip_cgpa")
    if "sum_assured" in f:
        kinds += ["amount_insert", "digit_flip_amount"]
    for k in ("id_number", "policy_number", "seat_number"):
        if k in f:
            kinds.append("digit_flip_" + k)
    for k in ("dob", "expiry_date"):
        if k in f and f[k].count("/") == 2 and int(f[k].split("/")[0]) != int(f[k].split("/")[1]) \
                and int(f[k].split("/")[0]) <= 12:
            kinds.append("day_month_swap_" + k)
    if "name" in f and len(f["name"]) > 4:
        kinds += ["name_letter", "name_letter_ocrlike"]
    kind = r.choice(kinds)

    def flip_digit(s):
        idx = [i for i, c in enumerate(s) if c.isdigit()]
        i = r.choice(idx)
        return s[:i] + str((int(s[i]) + r.randint(1, 8)) % 10) + s[i + 1:]

    if kind == "amount_insert":
        key = "sum_assured"
        old = _set(d, key, indian_grouping(int(f[key]) * 10))
        old = doc["fields"][key]
    elif kind.startswith("digit_flip"):
        key = "cgpa" if kind.endswith("cgpa") else "sum_assured" if kind.endswith("amount") else kind[len("digit_flip_"):]
        old = doc["fields"][key]
        new = flip_digit(old)
        if new == old:
            new = old[:-1] + str((int(old[-1]) + 1) % 10)
        _set(d, key, new)
    elif kind.startswith("day_month_swap"):
        key = kind[len("day_month_swap_"):]
        dd, mm, yy = f[key].split("/")
        old = doc["fields"][key]
        _set(d, key, f"{mm}/{dd}/{yy}")
    else:
        key = "name"
        old = doc["fields"][key]
        if kind == "name_letter":  # a letter that is not an OCR confusable of the original
            i = next(i for i, c in enumerate(old) if c.isalpha() and c.lower() not in "oilsbzgecuv")
            swap = {"a": "e", "h": "n", "m": "n", "r": "t", "t": "r", "k": "x", "p": "q", "d": "k", "n": "m"}
            c = old[i].lower()
            new = old[:i] + (swap.get(c, "x").upper() if old[i].isupper() else swap.get(c, "x")) + old[i + 1:]
        else:  # one-letter edit that looks like an OCR confusion
            cand = [i for i, c in enumerate(old) if c.lower() in "oilsbzgecuv"]
            i = cand[0] if cand else 0
            pair = {"o": "0", "i": "l", "l": "i", "s": "5", "b": "8", "z": "2", "g": "6", "e": "c", "c": "e", "u": "v", "v": "u"}
            new = old[:i] + pair.get(old[i].lower(), "0") + old[i + 1:]
        if new == old:
            new = old + "x"
        _set(d, key, new)
    return d, {key: [old, d["fields"][key]]}, kind


def hard_harmless(r, doc):
    """Changes that must not be reported as tampering. Returns (doc, subtype)."""
    d = copy.deepcopy(doc)
    f = d["fields"]
    options = ["whitespace_reflow", "metadata_only"]
    if "sum_assured" in f:
        options += ["amount_indian_commas", "amount_rs_prefix"]
    if "dob" in f:
        options += ["date_words"]
    if "id_number" in f and "0" in f["id_number"]:
        options += ["ocr_letter_o"]
    if "name" in f and any(c in f["name"].lower() for c in "il"):
        options += ["ocr_name_noise"]
    kind = r.choice(options)
    if kind == "whitespace_reflow":
        d["text"] = " \n ".join(d["text"].split(" "))
        if "name" in f:
            _set(d, "name", "  " + f["name"].replace(" ", "  ") + " ")
    elif kind == "amount_indian_commas":
        _set(d, "sum_assured", indian_grouping(f["sum_assured"]))
    elif kind == "amount_rs_prefix":
        _set(d, "sum_assured", "Rs. " + indian_grouping(f["sum_assured"]))
    elif kind == "date_words":
        dd, mm, yy = (int(x) for x in f["dob"].replace("-", "/").split("/")[:3]) if "/" in f["dob"] or "-" in f["dob"] \
            else (None, None, None)
        if dd:
            _set(d, "dob", f"{dd} {MONTHS[mm - 1]} {yy}")
        else:
            kind = "metadata_only"
    elif kind == "ocr_letter_o":
        _set(d, "id_number", f["id_number"].replace("0", "O", 1))
    elif kind == "ocr_name_noise":
        old = f["name"]
        low = old.lower()
        i = low.find("l") if "l" in low else low.find("i")
        new = old[:i] + ("1" if "l" in low else "l") + old[i + 1:]
        _set(d, "name", new)
    return d, kind


def name_variants(p):
    """(label level, variant) pairs for the Aadhaar name vs another document."""
    g, mid, s = p["given"], p["middle"], p["surname"]
    out = [
        ("equivalent", f"{g[0]}. {mid} {s}"),
        ("equivalent", f"{g} {mid[0]}. {s}"),
        ("equivalent", f"{s} {g} {mid}"),
        ("equivalent", f"{p['name'].upper()}"),
        ("likelyProblem", f"{g} {s}"),
        ("likelyProblem", f"{SPELLING.get(g, g + 'a')} {mid} {s}"),
        ("blocking", f"{r_other(p)} {mid} {r_other_s(p)}"),
    ]
    if p["female"]:
        out.append(("likelyProblem", f"{g} {mid} {'Mehta' if s != 'Mehta' else 'Shah'}"))
    return out


def r_other(p):
    return "Anil" if p["given"] != "Anil" else "Vijay"


def r_other_s(p):
    return "Bose" if p["surname"] != "Bose" else "Rao"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--people", type=int, default=50)
    ap.add_argument("--seed", type=int, default=1)
    ap.add_argument("--out", default="dataset/generated")
    ap.add_argument("--hard", action="store_true",
                    help="also write tamper_hard.jsonl / harmless_hard.jsonl (subtle edits, OCR noise, Indian formats)")
    a = ap.parse_args()
    r = random.Random(a.seed)
    out = Path(a.out)
    out.mkdir(parents=True, exist_ok=True)
    tam, har, aud, tam_h, har_h = [], [], [], [], []
    for i in range(a.people):
        p = make_person(r, i)
        docs = make_docs(r, p)
        for doc in docs:
            edited, changed = tamper(r, doc)
            tam.append({"kind": "tamper", "baseline": doc, "current": edited,
                        "label": {"verdict": "tampered", "changed_fields": changed}})
            same, transform = harmless(r, doc)
            har.append({"kind": "harmless", "baseline": doc, "current": same,
                        "label": {"verdict": "harmless" if transform != "resave" else "unchanged_fields",
                                  "transform": transform, "changed_fields": {}}})
        if a.hard:
            for doc in docs:
                edited, changed, sub = hard_tamper(r, doc)
                tam_h.append({"kind": "tamper", "baseline": doc, "current": edited,
                              "label": {"verdict": "tampered", "subtype": sub, "changed_fields": changed}})
                same, sub = hard_harmless(r, doc)
                har_h.append({"kind": "harmless", "baseline": doc, "current": same,
                              "label": {"verdict": "harmless", "subtype": sub, "changed_fields": {}}})
        # Audit cases: a clean set, then one injected mismatch per case.
        by = {d["doc_type"]: d for d in docs}
        aud.append({"kind": "audit", "documents": docs, "label": {"mismatches": []}})
        for level, variant in name_variants(p):
            ds = copy.deepcopy(docs)
            ds[1]["fields"]["name"] = variant  # PAN
            aud.append({"kind": "audit", "documents": ds, "label": {"mismatches": [
                {"field": "name", "docs": [by["aadhaar"]["id"], by["pan"]["id"]], "level": level}]}})
        ds = copy.deepcopy(docs)
        d, m, y = p["dob"]
        ds[2]["fields"]["dob"] = f"{(d % 28) + 1:02d}/{m:02d}/{y}"  # marksheet
        aud.append({"kind": "audit", "documents": ds, "label": {"mismatches": [
            {"field": "dob", "docs": [by["aadhaar"]["id"], by["marksheet"]["id"]], "level": "blocking"}]}})
        ds = copy.deepcopy(docs)
        ds[3]["fields"]["gender"] = "Male" if p["female"] else "Female"  # passport
        aud.append({"kind": "audit", "documents": ds, "label": {"mismatches": [
            {"field": "gender", "docs": [by["aadhaar"]["id"], by["passport"]["id"]], "level": "blocking"}]}})
    sets = [("tamper", tam), ("harmless", har), ("audit", aud)]
    if a.hard:
        sets += [("tamper_hard", tam_h), ("harmless_hard", har_h)]
    for name, rows in sets:
        with open(out / f"{name}.jsonl", "w", encoding="utf-8") as f:
            for row in rows:
                f.write(json.dumps(row, ensure_ascii=False) + "\n")
    print(f"people={a.people} tamper={len(tam)} harmless={len(har)} audit={len(aud)} -> {out}")


if __name__ == "__main__":
    main()
