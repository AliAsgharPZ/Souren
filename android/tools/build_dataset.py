#!/usr/bin/env python3
"""Build Souren's bundled 552-entry dataset from the canonical website dictionary and owner word-list uploads.

The uploads are parallel lists, but NOT line-aligned as whole files:
the Persian file holds equivalents for only 336 of the 552 Arabic words,
grouped in blocks of 42 whose order differs from the Arabic file.
Each block below was verified semantically (first pair = anchor, checked
by hand, plus spot pairs). The builder FAILS if any anchor mismatches,
so a re-uploaded/reordered file can never silently produce wrong pairs.
The canonical website dictionary adds six words to the original 546-word list;
216 supplement entries complete the Persian equivalents for all 552 words.
Explanatory concepts are carried across from the canonical website dictionary.
"""
import json, sys

AR = "data/arabic_all.txt"
FA = "data/persian_all.txt"

a = [x.strip() for x in open(AR, encoding="utf-8").read().splitlines() if x.strip()]
p = [x.strip() for x in open(FA, encoding="utf-8").read().splitlines() if x.strip()]
assert len(a) == 552, len(a)
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

# The website's 552-entry dictionary is the canonical source for word order
# and explanatory concepts. The 546-word owner uploads remain the base list;
# six later additions are appended to arabic_all.txt and supplemented below.
with open('../dictionary.json', encoding='utf-8') as source_file:
    canonical = json.load(source_file)['dictionary']
canonical_words = [entry['arabic'] for entry in canonical]
assert canonical_words == a, 'Arabic_All must match the canonical 552-entry website dictionary order'
concepts = {entry['arabic']: entry.get('concept', '') for entry in canonical}

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

# Supplement: equivalents for the 216 words missing from Persian_All,
# authored for Souren (data/supplement_fa.py) — order-verified there.
import os, sys
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "data"))
from supplement_fa import PAIRS as SUPPLEMENT  # noqa: E402
missing = [w for w in a if w not in pairs]
assert len(missing) == 216, len(missing)
assert [w for w, _ in SUPPLEMENT] == missing, "supplement order mismatch"
for w, eq in SUPPLEMENT:
    pairs[w] = [e.strip() for e in eq.split(",") if e.strip()]

assert len(pairs) == 552, len(pairs)
for item in canonical:
    assert pairs[item['arabic']] == item['meanings'], (item['arabic'], pairs[item['arabic']], item['meanings'])

entries = []
for w in a:
    entries.append({"ar": w, "fa": pairs.get(w, []), "concept": concepts.get(w, "")})
out = {
    "version": 3,
    "source": "Canonical 552-entry dictionary.json + Arabic_All v1.5 + Persian_All v1.6 + 216 supplement equivalents",
    "arabicCount": len(a),
    "pairCount": len(pairs),
    "entries": entries,
}
for output_path in ("data/dataset.json", "assets/db/dataset.json"):
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=1)
print(f"OK: {len(a)} Arabic words, {len(pairs)} with Persian equivalents, {len(a)-len(pairs)} without; wrote source and bundled datasets")
for w, eq in pairs.items():
    print(w, "->", ", ".join(eq))
