#!/usr/bin/env python3
"""Build Souren's bundled dataset from the owner's two uploaded word lists.

The uploads are parallel lists, but NOT line-aligned as whole files:
the Persian file holds equivalents for only 336 of the 546 Arabic words,
grouped in blocks of 42 whose order differs from the Arabic file.
Each block below was verified semantically (first pair = anchor, checked
by hand, plus spot pairs). The builder FAILS if any anchor mismatches,
so a re-uploaded/reordered file can never silently produce wrong pairs.
Arabic words without a Persian block stay in the lexicon, flagged
hasEquivalent=False, so the app can show them honestly as «برابر ندارد».
"""
import json, sys

AR = "data/arabic_all.txt"
FA = "data/persian_all.txt"

a = [x.strip() for x in open(AR, encoding="utf-8").read().splitlines() if x.strip()]
p = [x.strip() for x in open(FA, encoding="utf-8").read().splitlines() if x.strip()]
assert len(a) == 546, len(a)
assert len(p) == 336, len(p)

# (arabic_start_1based, persian_start_1based, anchor_arabic, anchor_persian)
BLOCKS = [
    (1,   1,   "ابتدا",   "آغاز"),
    (190, 43,  "ابد",     "جاودان, همیشگی"),
    (253, 85,  "ابتلا",   "گرفتاری"),
    (295, 127, "ابتکار",  "نوآوری"),
    (337, 169, "اتقان",   "استواری کار"),
    (400, 211, "ابدا",    "هرگز"),
    (463, 253, "اجتماعی", "جامعه‌ای"),
    (505, 295, "افسر",    "سرگرد, درجه‌دار"),
]
BLOCK_LEN = 42

pairs = {}
for a0, p0, anchor_a, anchor_p in BLOCKS:
    ai, pi = a0 - 1, p0 - 1
    assert a[ai] == anchor_a, (a[ai], anchor_a)
    assert p[pi] == anchor_p, (p[pi], anchor_p)
    for k in range(BLOCK_LEN):
        word = a[ai + k]
        eq = [e.strip() for e in p[pi + k].split(",") if e.strip()]
        assert word not in pairs, word
        pairs[word] = eq

# Supplement: equivalents for the 210 words missing from Persian_All,
# authored for Souren (data/supplement_fa.py) — order-verified there.
import os, sys
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "data"))
from supplement_fa import PAIRS as SUPPLEMENT  # noqa: E402
missing = [w for w in a if w not in pairs]
assert [w for w, _ in SUPPLEMENT] == missing, "supplement order mismatch"
for w, eq in SUPPLEMENT:
    pairs[w] = [e.strip() for e in eq.split(",") if e.strip()]

entries = []
for w in a:
    entries.append({"ar": w, "fa": pairs.get(w, [])})
out = {
    "version": 2,
    "source": "Arabic_All v1.5 + Persian_All v1.6 (owner upload) + supplement_fa (210 equivalents authored for Souren v0.2)",
    "arabicCount": len(a),
    "pairCount": len(pairs),
    "entries": entries,
}
with open("data/dataset.json", "w", encoding="utf-8") as f:
    json.dump(out, f, ensure_ascii=False, indent=1)
print(f"OK: {len(a)} arabic words, {len(pairs)} with persian equivalents, {len(a)-len(pairs)} without")
for w, eq in pairs.items():
    print(w, "->", ", ".join(eq))
