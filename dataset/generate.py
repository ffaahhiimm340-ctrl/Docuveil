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
        new = old.replace(old.split()[-1], r.choice(SURNAMES))
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
    a = ap.parse_args()
    r = random.Random(a.seed)
    out = Path(a.out)
    out.mkdir(parents=True, exist_ok=True)
    tam, har, aud = [], [], []
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
    for name, rows in (("tamper", tam), ("harmless", har), ("audit", aud)):
        with open(out / f"{name}.jsonl", "w", encoding="utf-8") as f:
            for row in rows:
                f.write(json.dumps(row, ensure_ascii=False) + "\n")
    print(f"people={a.people} tamper={len(tam)} harmless={len(har)} audit={len(aud)} -> {out}")


if __name__ == "__main__":
    main()
