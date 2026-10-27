"""Render synthetic documents as realistic printed text, for field extraction.

    py -3.12 dataset/render_text.py --people 100 --seed 3 --out dataset/generated

Writes extraction.jsonl: one line per (document, layout, noise level) with the
rendered text and the gold fields. People and field values come from
generate.py, so everything stays fictional. Layouts imitate how each document
is printed (label wording, label above or beside the value, names split into
surname and given names); `noise` applies OCR-style character confusions.
"""

import argparse
import json
import random
from pathlib import Path

from generate import MONTHS, make_docs, make_person

ROMAN = ["I", "II", "III", "IV", "V", "VI", "VII", "VIII"]


def _dob_variant(r, dob):
    """The same date printed another common way."""
    d, m, y = (int(x) for x in dob.replace("-", "/").split("/")) if "/" in dob or "-" in dob else (None,) * 3
    if d is None:
        return dob
    return r.choice([f"{d:02d}/{m:02d}/{y}", f"{d:02d}-{m:02d}-{y}", f"{d} {MONTHS[m - 1]} {y}"])


def render(r, doc):
    """Return (text, gold fields) for one document. Gold values are exactly
    what is printed, so a perfect extractor can match them."""
    t, f = doc["doc_type"], dict(doc["fields"])
    sep = r.choice([": ", " : ", " - ", "  "])
    lines = []
    if t == "aadhaar":
        f["dob"] = _dob_variant(r, f["dob"])
        rel = r.choice(["D/O" if f["gender"] == "Female" else "S/O", "C/O"])
        lines = [
            r.choice(["GOVERNMENT OF INDIA", "Government of India"]),
            f["name"],
            f"{r.choice(['DOB', 'Date of Birth', 'Year of Birth / DOB'])}{sep}{f['dob']}",
            f"{f['gender'].upper() if r.random() < 0.5 else f['gender']}",
            f["id_number"],
            f"{rel}{r.choice([': ', ' '])}{f['father_name']}, {r.randint(1, 99)} Sample Nagar, Pune",
            r.choice(["Mera Aadhaar, Meri Pehchaan", "SYNTHETIC SAMPLE - NOT A REAL DOCUMENT"]),
        ]
    elif t == "pan":
        above = r.random() < 0.6  # label on the line above the value
        pairs = [("Name", f["name"]), (r.choice(["Father's Name", "Fathers Name"]), f["father_name"]),
                 ("Date of Birth", f["dob"])]
        lines = ["INCOME TAX DEPARTMENT", "GOVT. OF INDIA", "Permanent Account Number Card", f["id_number"]]
        for label, value in pairs:
            lines += [label, value] if above else [f"{label}{sep}{value}"]
        lines.append("Signature")
    elif t == "marksheet":
        sem_roman = r.random() < 0.5
        lines = [
            f["university"].upper(),
            r.choice(["Statement of Marks", "Grade Card", "MARKSHEET"]),
            f"{r.choice(['Name of the Student', 'Student Name', 'Name'])}{sep}{f['name']}",
            f"{r.choice(['Seat No.', 'Seat Number', 'Roll No'])}{sep}{f['seat_number']}",
            f"Semester{sep}{ROMAN[int(f['semester']) - 1] if sem_roman else f['semester']}",
            f"Date of Birth{sep}{f['dob']}",
            f"{r.choice(['CGPA', 'SGPA / CGPA', 'Cumulative GPA'])}{sep}{f['cgpa']}",
            f"Result{sep}PASS",
        ]
    elif t == "passport":
        parts = f["name"].split()
        surname, given = parts[-1], " ".join(parts[:-1])
        f["name"] = f"{given} {surname}"
        lines = [
            "REPUBLIC OF INDIA", "Type P   Country Code IND",
            "Surname", surname.upper(), "Given Name(s)", given.upper(),
            f"Sex{sep}{f['gender'][0]}",
            f"Date of Birth{sep}{f['dob']}",
            f"Passport No.{sep}{f['id_number']}",
            f"Date of Expiry{sep}{f['expiry_date']}",
            "Name of Father / Legal Guardian", f["father_name"].upper(),
        ]
    elif t == "insurance":
        amount = f["sum_assured"]
        printed = r.choice([amount, f"Rs. {int(amount):,}".replace(",", ","), "Rs. " + _indian(int(amount))])
        f["sum_assured"] = printed
        lines = [
            f["insurer"], r.choice(["Policy Schedule", "POLICY CERTIFICATE"]),
            f"{r.choice(['Policy No.', 'Policy Number'])}{sep}{f['policy_number']}",
            f"{r.choice(['Policyholder Name', 'Name of the Insured', 'Proposer Name'])}{sep}{f['name']}",
            f"{r.choice(['Sum Insured', 'Sum Assured'])}{sep}{printed}",
            f"{r.choice(['Policy Expiry Date', 'Valid Till', 'Expiry Date'])}{sep}{f['expiry_date']}",
            f"Nominee{sep}{f['nominee']}",
        ]
    return "\n".join(lines), f


def _indian(n):
    s = str(n)
    head, tail = s[:-3], s[-3:]
    parts = []
    while len(head) > 2:
        parts.insert(0, head[-2:])
        head = head[:-2]
    return ",".join(([head] if head else []) + parts + [tail])


OCR_SWAPS = {"O": "0", "0": "O", "l": "1", "1": "l", "I": "l", "S": "5", "B": "8", "e": "c", "m": "rn"}


def ocr_noise(r, text, rate):
    """Character confusions a scan typically produces, at roughly [rate] per
    eligible character. Digits only ever turn into look-alike letters."""
    out = []
    for ch in text:
        if ch in OCR_SWAPS and r.random() < rate:
            out.append(OCR_SWAPS[ch])
        else:
            out.append(ch)
    return "".join(out)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--people", type=int, default=100)
    ap.add_argument("--seed", type=int, default=3)
    ap.add_argument("--out", default="dataset/generated")
    a = ap.parse_args()
    r = random.Random(a.seed)
    rows = []
    for i in range(a.people):
        p = make_person(r, i)
        for doc in make_docs(r, p):
            text, gold = render(r, doc)
            for noise in (0.0, 0.02, 0.05):
                rows.append({"id": doc["id"], "doc_type": doc["doc_type"], "noise": noise,
                             "text": ocr_noise(r, text, noise) if noise else text, "fields": gold})
    out = Path(a.out)
    out.mkdir(parents=True, exist_ok=True)
    with open(out / "extraction.jsonl", "w", encoding="utf-8") as fh:
        for row in rows:
            fh.write(json.dumps(row, ensure_ascii=False) + "\n")
    print(f"documents={len(rows) // 3} rows={len(rows)} -> {out / 'extraction.jsonl'}")


if __name__ == "__main__":
    main()
