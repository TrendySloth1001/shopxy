#!/usr/bin/env python3
"""Build the GST rate CSV from the CBIC "GST Ready Reckoner" PDF.

    npm run hsn:rates -- --pdf CBIC-GST-Ready-Reckoner-....pdf

Output (into --out-dir, default `readmes/hsn-rates/`):

    gst_rates_<ason>.csv   code → GST rate + compensation cess. Feed this to
                           `npm run hsn:import`.
    ambiguous_codes.csv    codes the reckoner declares at two different rates,
                           withheld with every rate + condition, for a human.
    ambiguous_cess.csv     cess entries withheld: two cess rates for one code,
                           or a cess that is not an ad-valorem percentage.
    reckoner_rows.json     the raw parse, kept so a surprise in the CSV can be
                           traced back to a page without re-reading the PDF.
    cess_rows.json         the same, for the compensation cess schedule.
    exclusions.json        codes lifted out of "other than …" clauses.

── Dependency ───────────────────────────────────────────────────────────────
ONE, and it is not in package.json because it is not a Node package:

    pip3 install pdfplumber

Why Python at all, in a TypeScript repo: the whole parse hangs on reading the
*x-position of every word* to segment four table columns whose cells wrap
independently of each other (see `column_anchors` / `extract`). pdfplumber's
`extract_words()` is what makes that possible. Nothing equivalent exists in
this backend's dependency tree — `pdfkit`, already a dependency, only *writes*
PDFs — and adding a JS PDF parser to a production backend for a tool that runs
once per rate notification is a bad trade. This script is also the exact
engine the current master was proven against; a reimplementation on a
different word-splitter would not reproduce the same CSV.

── The reckoner ─────────────────────────────────────────────────────────────
A four-column table repeated across ~90 pages:

    S. No. | Chapter/Heading/Sub-heading/Tariff item | Description of goods | Rate

CRITICAL: the rate printed is **CGST — half** the GST the customer pays.
Every rate is doubled on the way out:

    Schedule I    2.5%   → 5%
    Schedule II     9%   → 18%
    Schedule III   20%   → 40%
    Schedule IV   1.5%   → 3%
    Schedule V  0.125%   → 0.25%
    Schedule VI  0.75%   → 1.5%
    Schedule VII   14%   → 28%
    (exempt table prints "Nil" → 0%)

28% and 1.5% are NOT stale leftovers: Schedule VII (28%) is pan masala and
tobacco, Schedule VI (1.5%) is rough diamonds etc. 12% is the slab that no
longer exists. Do not "correct" any of these — the doubling is the only
transformation applied to a printed rate, and nothing in this file ever
authors one.

Schedule headers carry their own rate ("Schedule I – 2.5%"), which gives a
free per-row cross-check: a row whose printed rate disagrees with its schedule
header is a parse error, not a special case, and is a hard failure below.
"""

from __future__ import annotations

import argparse
import csv
import json
import re
import sys
import warnings
from collections import Counter, defaultdict
from pathlib import Path

try:
    import pdfplumber
except ImportError:  # pragma: no cover - environment guard
    sys.exit(
        "hsn-rates-extract needs pdfplumber (the one dependency):\n"
        "    pip3 install pdfplumber"
    )

warnings.filterwarnings("ignore")  # pdfminer is chatty about CropBox defaults


# ── Constants ────────────────────────────────────────────────────────────────

# The printed column is CGST; the customer pays CGST + SGST.
CGST_TO_GST = 2

# Every slab that legally exists after 22.09.2025. A rate outside this set means
# the parse drifted — refuse to write rather than emit quietly-wrong tax data.
# 12% is absent on purpose. 28% (Sch VII) and 1.5% (Sch VI) are present on
# purpose.
LEGAL_GST_RATES = {0.0, 0.25, 1.5, 3.0, 5.0, 18.0, 28.0, 40.0}

# The rate schedules number their serials 1..N with no gaps. Continuity across
# these six is the completeness test: a gap means a row was dropped, a
# duplicate means one was double-counted. Schedule VII is excluded because its
# handful of rows re-uses a serial in the source layout, and the exempt table
# restarts its numbering per list — neither is a parse defect.
CONTINUITY_SCHEDULES = ("I", "II", "III", "IV", "V", "VI")

SCHEDULE_RE = re.compile(r"Schedule\s+([IVX]+)\s*[–—-]\s*([\d.]+)\s*%")
SERIAL_RE = re.compile(r"^(\d+)\.$")
RATE_RE = re.compile(r"^([\d.]+)%$|^Nil$", re.I)

# Section headings: "1. CGST rates on goods…", "2. Exempted Goods…", etc. Only
# sections 1 and 2 are rate tables; the rest are prose/annexures.
SECTION_RE = re.compile(
    r"^(\d)\.\s+(CGST rates on goods|Exempted Goods|CGST Rates on Goods)", re.I
)

# A code is 2 (chapter), 4 (heading), 6 (sub-heading) or 8 (tariff item)
# digits. This length check — not the whitespace handling — is the real guard.
VALID_LEN = {2, 4, 6, 8}

EXCLUSION_RE = re.compile(r"(?:other\s+than|except)\s*([^\]\)]*)", re.I)
RANGE_RE = re.compile(r"^(\d+)\s*to\s*(\d+)$", re.I)


# ── Chapter-level rows ───────────────────────────────────────────────────────
#
# The notification routinely writes a NARROW description against a bare 2-digit
# chapter number:
#
#     441.  87   Electrically operated vehicles …            2.5%
#     473.  90   Coronary stents …                           2.5%
#     204.  27   Bio-gas                                     2.5%
#
# Those rate a handful of goods; they do not rate the chapter. But the resolver
# walks the code ladder and stops at the FIRST ratable ancestor, so a chapter
# emitted as ratable silently becomes the rate of every code beneath it that the
# schedules do not rate individually. Left unchecked it billed 3926 "other
# articles of plastics" at chapter 39's 5% instead of the 18% that Schedule II
# serial 127 prints for that exact heading.
#
# THE TEST: a 2-digit code is emitted only when the row rates the chapter's
# goods AS A WHOLE — the description is the chapter's own subject rather than a
# list of particular goods — and any condition it carries is one the line can
# evaluate (sale value per piece/pair), not a narrowing of WHICH goods are
# covered.
#
# Applying that test is a reading of the notification, not a regex, so its
# outcome for THIS document is recorded below and everything else is dropped
# **and reported, per row, on every run**. A different notification therefore
# starts from "no chapter is ratable" and forces someone to re-read the chapter
# rows. That is the safe direction: a chapter with no rate asks the merchant, a
# chapter with the wrong rate bills them.
#
#     (code, schedule, serial) → a phrase that must still appear in the row
#
# The phrase is a tripwire, not a parse: if a re-numbered notification puts a
# different row at that serial, the run fails instead of quietly allow-listing
# whatever moved into the slot.
CHAPTER_WIDE_ROWS = {
    # Chapter 60 is "Knitted or crocheted fabrics" and the row says exactly
    # that, plus "[All goods]" — the notification's own way of writing
    # chapter-wide.
    ("60", "I", 387): "Knitted or crocheted fabrics [All goods]",
    # 61/62/63/64: apparel, made-ups and footwear are rated for the whole
    # chapter, split only by SALE VALUE — a condition about the line, not about
    # which goods are covered. 61/62/63 print both sides of the ₹2,500 band at
    # chapter level, so they land in ambiguous_codes.csv and are resolved by the
    # APPAREL rule in hsn.rules.ts; 64 prints only the lower band here and pairs
    # with the heading-level 18% of Schedule II via the FOOTWEAR rule.
    ("61", "I", 388): "of sale value not exceeding Rs 2500 per piece",
    ("61", "II", 197): "of sale value exceeding Rs. 2500 per piece",
    ("62", "I", 389): "of sale value not exceeding Rs. 2500 per piece",
    ("62", "II", 198): "of sale value exceeding Rs. 2500 per piece",
    ("63", "I", 390): "Other made up textile articles, sets",
    ("63", "II", 199): "Other made-up textile articles, sets",
    ("64", "I", 392): "Footwear of sale value not exceeding Rs.2500 per pair",
}


# ── The compensation cess schedule ───────────────────────────────────────────
#
# Section 5 of the same document (Notification 1/2017-Compensation Cess (Rate),
# pages 87–93 of the 22.09.2025 reckoner) is a second, differently-shaped table:
#
#     S. No. | Chapter/Heading/Sub-heading/Tariff item | Description | Cess
#
# It is NOT part of the CGST schedules and its rate is NOT doubled: compensation
# cess is a single levy, not a CGST/SGST pair. Pan masala is 28% GST **plus 60%
# cess**; dropping the cess under-bills it by 60 points, and jarda scented
# tobacco by 160.
#
# Its serials carry letter suffixes (1, 1A, 36B …) and its columns sit at
# different x-positions from the rate table, hence a separate parser.
CESS_HEADER_RE = re.compile(r"Effective\s+Compensation\s+Cess\s+as\s+on", re.I)
CESS_COLUMNS_RE = re.compile(r"^\(1\)\s*\(2\)\s*\(3\)\s*\(4\)$")
CESS_SERIAL_RE = re.compile(r"^(\d+)([A-Z]?)\.?$")
CESS_PCT_RE = re.compile(r"^(\d+(?:\.\d+)?)%$")
# S.No 47 and 48 print one NIL per lettered sub-clause of a single row.
CESS_NIL_RE = re.compile(r"^NIL(?:\s+NIL)*$", re.I)


# ── Phase 1: PDF → rows ──────────────────────────────────────────────────────


def column_anchors(words):
    """Modal x0 of the code and description columns on this page.

    The table is segmented by where words physically sit, not by splitting
    text. Splitting on whitespace cannot work: descriptions contain numbers,
    codes contain spaces, and both wrap. The x-windows below are the printed
    column positions of this document.
    """
    xs = Counter(round(w["x0"], 0) for w in words)
    code_x = next((x for x, _ in xs.most_common() if 105 <= x <= 175), None)
    desc_x = next((x for x, _ in xs.most_common() if 176 <= x <= 320), None)
    return code_x, desc_x


def lines_of(page):
    """Words grouped into visual lines, each sorted left to right."""
    buckets = {}
    for w in page.extract_words():
        buckets.setdefault(round(w["top"]), []).append(w)
    return [sorted(ws, key=lambda w: w["x0"]) for _, ws in sorted(buckets.items())]


def cess_page(lines, pageno, cess_rows, current):
    """One page of the compensation-cess schedule → rows, appended in place.

    Returns (current, finished). Its columns sit at different x-positions from
    the rate table and its serials carry letter suffixes, so it cannot share the
    rate parser. Two layout facts matter:

      * the four-column header repeats at the top of EVERY page, and a row that
        wraps across a page break would otherwise swallow it — so each page is
        picked up after the "(1) (2) (3) (4)" marker line;
      * the table ends at the left-margin "Explanation.–" block, which is prose;
        the word "Explanation" also appears INSIDE descriptions, hence the
        x-position test rather than a text test.
    """
    start = 0
    for i, line in enumerate(lines):
        if CESS_COLUMNS_RE.match(" ".join(w["text"] for w in line).strip()):
            start = i + 1

    for line in lines[start:]:
        text = " ".join(w["text"] for w in line).strip()
        head = line[0]
        if head["x0"] < 80 and text.startswith("Explanation"):
            return current, True
        if text == str(pageno):  # the page number, printed under the table
            continue

        m = CESS_SERIAL_RE.match(head["text"])
        starts_row = bool(m) and head["x0"] < 120
        cell_code = " ".join(w["text"] for w in line if 120 <= w["x0"] < 190).strip()
        cell_desc = " ".join(w["text"] for w in line if 190 <= w["x0"] < 445).strip()
        cell_rate = " ".join(w["text"] for w in line if w["x0"] >= 445).strip()

        if starts_row:
            if current:
                cess_rows.append(current)
            current = {
                "serial": m.group(1) + m.group(2),
                "page": pageno,
                "code_cell": cell_code,
                "description": cell_desc,
                "rate_cell": cell_rate,
            }
        elif current:
            if cell_code:
                current["code_cell"] += " " + cell_code
            if cell_desc:
                current["description"] += " " + cell_desc
            if cell_rate:
                current["rate_cell"] += " " + cell_rate

    return current, False


def extract(pdf_path):
    """Parse the reckoner into one dict per table row.

    A logical row spans several visual lines and the code cell wraps
    independently of the description, so lines are grouped by the serial number
    in column 1 (the only thing that reliably marks a row boundary) and each
    column is re-joined separately from its own x-window.

    Returns (rate rows, compensation-cess rows, pages scanned). The cess
    schedule is the tail of the same document and is parsed in the same pass.
    """
    rows = []
    cess_rows = []
    cess_current = None
    in_cess = False
    cess_done = False
    schedule = None
    schedule_rate = None
    section = None
    pages_scanned = 0

    with pdfplumber.open(pdf_path) as pdf:
        for pageno, page in enumerate(pdf.pages, start=1):
            pages_scanned += 1
            words = page.extract_words()
            if not words:
                continue
            lines = lines_of(page)

            # Everything from the "Effective Compensation Cess" heading on is the
            # cess schedule, which the rate parser must not touch.
            if not in_cess and any(
                CESS_HEADER_RE.search(" ".join(w["text"] for w in line))
                for line in lines
            ):
                in_cess = True
            if in_cess:
                if not cess_done:
                    cess_current, cess_done = cess_page(
                        lines, pageno, cess_rows, cess_current
                    )
                continue

            code_x, desc_x = column_anchors(words)
            current = None

            for line in lines:
                text = " ".join(w["text"] for w in line).strip()

                m = SECTION_RE.match(text)
                if m:
                    section = m.group(2).lower()
                    schedule, schedule_rate = None, None

                m = SCHEDULE_RE.search(text)
                if m:
                    if current:
                        rows.append(current)
                        current = None
                    schedule = m.group(1)
                    schedule_rate = float(m.group(2))
                    continue

                if desc_x is None or code_x is None:
                    continue
                # Exempt table rows print "Nil" and belong to section 2, which
                # has no schedule header of its own.
                if schedule_rate is None and section != "exempted goods":
                    continue

                head = line[0]
                sm = SERIAL_RE.match(head["text"])
                # A serial only starts a row when it sits left of the code
                # column — otherwise it is a numbered clause inside a
                # description.
                starts_row = bool(sm) and head["x0"] < code_x - 5

                cell_code = " ".join(
                    w["text"] for w in line if code_x - 6 <= w["x0"] < desc_x - 6
                ).strip()
                cell_desc = " ".join(
                    w["text"] for w in line if desc_x - 6 <= w["x0"] < 500
                ).strip()
                rate_tok = next(
                    (
                        w["text"]
                        for w in line
                        if w["x0"] >= 500 and RATE_RE.match(w["text"])
                    ),
                    None,
                )

                if starts_row:
                    if current:
                        rows.append(current)
                    current = {
                        "serial": int(sm.group(1)),
                        "page": pageno,
                        "schedule": schedule,
                        "schedule_rate": schedule_rate,
                        "section": section,
                        "code_cell": cell_code,
                        "description": cell_desc,
                        "printed_rate": rate_tok,
                    }
                elif current:
                    # Continuation: each column continues independently.
                    if cell_code:
                        current["code_cell"] += " " + cell_code
                    if cell_desc:
                        current["description"] += " " + cell_desc
                    if rate_tok and not current["printed_rate"]:
                        current["printed_rate"] = rate_tok

            if current:
                rows.append(current)

        if cess_current:
            cess_rows.append(cess_current)

    return rows, cess_rows, pages_scanned


# ── Phase 2: rows → codes ────────────────────────────────────────────────────


def digits(text):
    return re.sub(r"\D", "", text)


def split_terms(cell):
    """Break a code cell into its top-level alternatives.

    Bracketed exclusions are lifted out first so their inner codes are never
    mistaken for included ones — "0402 [other than 0402 91 10]" must not rate
    04029110.
    """
    exclusions = []
    for m in EXCLUSION_RE.finditer(cell):
        for part in re.split(r"[,;]| or ", m.group(1)):
            d = digits(part)
            if len(d) in VALID_LEN:
                exclusions.append(d)
    # Drop the bracketed/parenthesised segments entirely.
    body = re.sub(r"\[[^\]]*\]|\([^\)]*\)", " ", cell)
    body = EXCLUSION_RE.sub(" ", body)
    terms = [t.strip() for t in re.split(r",|;|\bor\b|\band\b", body, flags=re.I)]
    return [t for t in terms if t.strip()], exclusions


def expand(term):
    """One term → the codes it denotes, or ([], reason) when it isn't a code.

    Codes carry spaces for two unrelated reasons and both are handled the same
    way — by deleting the whitespace:

      * by convention, because that is how the tariff prints a tariff item:
        "0101 21 00" is 01012100;
      * by accident, because the column is narrow enough that a line wrap
        splits "1702" into "170" + "2".

    Stripping whitespace resolves both identically, which is exactly why the
    2/4/6/8 digit-length check afterwards is the real guard: anything else is
    reported, never guessed.
    """
    t = " ".join(term.split())
    if not t:
        return [], None
    if re.search(r"any\s*chapter", t, re.I):
        return [], "any-chapter"
    compact = re.sub(r"\s+", "", t)
    m = RANGE_RE.match(compact)
    if m:
        lo, hi = m.group(1), m.group(2)
        if len(lo) == len(hi) and len(lo) in VALID_LEN and int(lo) <= int(hi):
            width = len(lo)
            return [str(n).zfill(width) for n in range(int(lo), int(hi) + 1)], None
        return [], "bad-range:%s" % t
    d = digits(compact)
    if not d:
        return [], "no-digits:%s" % t[:40]
    if len(d) not in VALID_LEN:
        # Two tariff items that lost their separator to a line wrap
        # ("2711 12 00" + "2711 13 00" → one 16-digit run). Only split when it
        # divides evenly into 8s AND every piece looks like a tariff item in the
        # same heading, so an arbitrary digit run is still reported, not guessed.
        if len(d) % 8 == 0 and len(d) > 8:
            parts = [d[i : i + 8] for i in range(0, len(d), 8)]
            if len({p[:4] for p in parts}) == 1:
                return parts, None
        return [], "bad-length:%s->%s" % (t[:40], d)
    return [d], None


def chapter_verdict(code, schedule, serial, description):
    """Does this row rate the WHOLE chapter? → (keep, note).

    Default deny. See CHAPTER_WIDE_ROWS: the reading lives there, this only
    enforces it and flags a row that has moved out from under its entry.
    """
    phrase = CHAPTER_WIDE_ROWS.get((code, schedule, serial))
    if phrase is None:
        return False, "not a whole-chapter row"
    if phrase.lower() not in " ".join(description.split()).lower():
        return False, "STALE: expected %r in the description" % phrase
    return True, None


def build(rows, rules):
    """Rows → (unambiguous, ambiguous, exclusions, skipped terms)."""
    candidates = defaultdict(list)
    excluded = defaultdict(set)
    skipped_detail = []
    rule_warnings = []
    chapter_rows = []

    for r in rows:
        printed = r.get("printed_rate")
        if not printed:
            continue
        # THE doubling. CGST as printed → the GST the customer pays.
        gst = (
            0.0
            if printed.lower() == "nil"
            else round(float(printed.rstrip("%")) * CGST_TO_GST, 3)
        )

        terms, exclusions = split_terms(r["code_cell"])
        for e in exclusions:
            excluded[e].add(gst)

        for term in terms:
            codes, reason = expand(term)
            if reason:
                skipped_detail.append(
                    {
                        "page": r["page"],
                        "schedule": r["schedule"] or r["section"],
                        "serial": r["serial"],
                        "reason": reason,
                    }
                )
            for code in codes:
                sched = r["schedule"] or r["section"]
                if len(code) == 2:
                    # A bare chapter number is guilty until proven chapter-wide:
                    # it becomes the rate of everything beneath it.
                    keep, note = chapter_verdict(
                        code, sched, r["serial"], r["description"]
                    )
                    chapter_rows.append(
                        {
                            "code": code,
                            "schedule": sched,
                            "serial": r["serial"],
                            "page": r["page"],
                            "rate": gst,
                            "description": " ".join(r["description"].split())[:120],
                            "kept": keep,
                            "note": note,
                        }
                    )
                    if not keep:
                        continue
                candidates[code].append(
                    {
                        "rate": gst,
                        "description": " ".join(r["description"].split())[:300],
                        "schedule": sched,
                        "serial": r["serial"],
                        "page": r["page"],
                    }
                )

    # A code carrying two different rates is not a parse failure — GST is
    # declared per (code + condition), so heading 1006 is nil loose and 5%
    # pre-packaged-and-labelled. Nothing in the code decides which, so these
    # are withheld rather than guessed: an auto-filled wrong rate is worse than
    # asking, because it is silent and it prints on the invoice.
    unambiguous, ambiguous = {}, {}
    for code, entries in candidates.items():
        if len({e["rate"] for e in entries}) == 1:
            unambiguous[code] = entries[0]
        else:
            ambiguous[code] = entries

    # Price-threshold codes are ambiguous in the same way, but with a condition
    # the system CAN evaluate — see hsn-rules-dump.ts. Emitted at the rule's
    # base rate so the overlay can refine them; without this, T-shirts cannot
    # price a line at all. Both rates come from the schedules; nothing here
    # invents one, and a base the schedules don't print is reported.
    for rule in rules:
        if rule.get("base") is None:
            continue
        code = rule["code"]
        entries = candidates.get(code) or []
        rates_seen = {e["rate"] for e in entries}
        if rates_seen and float(rule["base"]) not in rates_seen:
            rule_warnings.append(
                "rule base %s%% for %s is not among the rates the schedules print for it (%s)"
                % (rule["base"], code, sorted(rates_seen))
            )
        ambiguous.pop(code, None)
        unambiguous[code] = {
            "rate": float(rule["base"]),
            "description": entries[0]["description"] if entries else "HSN %s" % code,
            "schedule": "rule",
            "serial": 0,
            "page": 0,
        }

    return (
        unambiguous,
        ambiguous,
        excluded,
        skipped_detail,
        rule_warnings,
        candidates,
        chapter_rows,
    )


# ── Phase 2b: the compensation cess schedule ─────────────────────────────────


def cess_value(cell):
    """A printed cess cell → (percent, None) or (None, why it can't be one).

    Only a bare ad-valorem percentage is representable as a number on a code.
    "0.32R per unit" is a share of the declared retail sale price, "5% +
    Rs.2076 per thousand" and "21% or Rs. 4170 per thousand, whichever is
    higher" are compound rates that need the pack size and the RSP. None of
    those can be flattened into a percentage, and guessing one under-bills or
    over-bills tobacco by tens of points — so they are reported, never
    converted.
    """
    t = " ".join(cell.split())
    if not t:
        return None, "(no cess printed)"
    if CESS_NIL_RE.match(t):
        return 0.0, None
    m = CESS_PCT_RE.match(t)
    if m:
        return float(m.group(1)), None
    return None, t


def build_cess(cess_rows):
    """Cess rows → (per-code cess, ambiguous, unrepresentable, chapter rows).

    The cess printed here is the WHOLE cess — unlike the CGST schedules there is
    no doubling, because compensation cess is a single levy.
    """
    candidates = defaultdict(list)
    unrepresentable = []
    chapter_rows = []
    skipped_terms = []

    for r in cess_rows:
        value, why = cess_value(r["rate_cell"])
        terms, _ = split_terms(r["code_cell"])
        codes = []
        for term in terms:
            got, reason = expand(term)
            if reason:
                skipped_terms.append(
                    {"serial": r["serial"], "page": r["page"], "reason": reason}
                )
            codes.extend(got)

        for code in codes:
            entry = {
                "serial": r["serial"],
                "page": r["page"],
                "description": " ".join(r["description"].split())[:200],
                "printed": " ".join(r["rate_cell"].split()),
            }
            if len(code) == 2:
                # Same trap as the rate table, and no chapter row in this
                # schedule rates a whole chapter (41A is coal rejects, 42A/42B
                # are used and fuel-cell vehicles). All three print NIL, which
                # is already the residual of S.No 56, so nothing is lost.
                chapter_rows.append({"code": code, **entry})
                continue
            if value is None:
                unrepresentable.append({"code": code, **entry, "why": why})
                continue
            candidates[code].append({"cess": value, **entry})

    unambiguous, ambiguous = {}, {}
    for code, entries in candidates.items():
        if len({e["cess"] for e in entries}) == 1:
            unambiguous[code] = entries[0]
        else:
            ambiguous[code] = entries

    return unambiguous, ambiguous, unrepresentable, chapter_rows, skipped_terms


def attach_cess(unambiguous, cess):
    """Hang the cess column on the rate rows. Returns (derived, orphaned).

    A cess is only ever read off the row that PRICES the line — the resolver
    stops at the first ratable ancestor and takes its cess with it — so a cess
    declared against a tariff item the schedules rate only at heading level
    would never be seen. Those rows are carried down to the item at the rate its
    nearest rated ancestor already carries in this same CSV: the identical
    inference the resolver makes at runtime, not a new rate. Every one is
    reported. A cess whose ancestors are all unrated (or ambiguous) is dropped
    and reported — nothing here invents a GST rate to hang a cess on.
    """
    derived, orphaned = [], []
    for code in sorted(cess):
        entry = cess[code]
        if code in unambiguous:
            unambiguous[code]["cess"] = entry["cess"]
            continue
        if not entry["cess"]:
            # NIL is the schedule's own residual (S.No 56, "any chapter, all
            # goods other than those mentioned above — NIL"). Nothing to carry.
            continue
        ancestor = next(
            (code[:w] for w in (6, 4, 2) if w < len(code) and code[:w] in unambiguous),
            None,
        )
        if ancestor is None:
            orphaned.append({"code": code, **entry})
            continue
        unambiguous[code] = {
            "rate": unambiguous[ancestor]["rate"],
            "cess": entry["cess"],
            "description": entry["description"],
            "schedule": "cess:%s via %s" % (entry["serial"], ancestor),
            "serial": entry["serial"],
            "page": entry["page"],
        }
        derived.append({"code": code, "ancestor": ancestor, **entry})
    return derived, orphaned


# ── Phase 3: verification ────────────────────────────────────────────────────


def verify(
    rows,
    unambiguous,
    ambiguous,
    excluded,
    skipped,
    rule_warnings,
    candidates,
    pages,
    chapter_rows,
    cess_report,
):
    """Print the summary and return the list of hard failures.

    Everything is checked BEFORE anything is written. A failure here means no
    output file is produced at all — a missing CSV is a problem someone fixes,
    a wrong one is a problem someone bills.
    """
    failures = []
    out = print

    out("")
    out("── extraction ──────────────────────────────────────────────────────")
    out("pages scanned : %d" % pages)
    out("rows recovered: %d" % len(rows))
    out("")
    out("  section              sched  printed  rows   serials      gaps  dupes")

    grouped = defaultdict(list)
    for r in rows:
        grouped[(r["section"], r["schedule"])].append(r)

    def sort_key(kv):
        section, sched = kv[0]
        order = {s: i for i, s in enumerate(CONTINUITY_SCHEDULES + ("VII",))}
        return (section or "", order.get(sched, 99))

    for (section, sched), group in sorted(grouped.items(), key=sort_key):
        serials = [r["serial"] for r in group]
        counts = Counter(serials)
        dupes = sorted(s for s, n in counts.items() if n > 1)
        span = set(range(min(serials), max(serials) + 1))
        gaps = sorted(span - set(serials))
        printed = sorted({r["printed_rate"] for r in group if r["printed_rate"]})
        out(
            "  %-20s %-6s %-8s %-5d  %-11s  %-4d  %d"
            % (
                (section or "-")[:20],
                sched or "-",
                ",".join(printed) or "-",
                len(group),
                "%d-%d" % (min(serials), max(serials)),
                len(gaps),
                len(dupes),
            )
        )

        # Completeness test: the rate schedules run 1..N with no gaps and no
        # repeats. Anything else means a row was dropped or double-counted.
        if sched in CONTINUITY_SCHEDULES:
            if min(serials) != 1:
                failures.append(
                    "Schedule %s starts at serial %d, not 1" % (sched, min(serials))
                )
            if gaps:
                failures.append(
                    "Schedule %s has %d missing serial(s): %s"
                    % (sched, len(gaps), gaps[:20])
                )
            if dupes:
                failures.append(
                    "Schedule %s has %d duplicated serial(s): %s"
                    % (sched, len(dupes), dupes[:20])
                )

        # Per-row cross-check against the schedule header's own rate.
        for r in group:
            if r["printed_rate"] is None or r.get("schedule_rate") is None:
                continue
            if r["printed_rate"].lower() == "nil":
                continue
            if abs(float(r["printed_rate"].rstrip("%")) - r["schedule_rate"]) > 1e-9:
                failures.append(
                    "p%d Schedule %s serial %d prints %s but its schedule header says %s%%"
                    % (
                        r["page"],
                        sched,
                        r["serial"],
                        r["printed_rate"],
                        r["schedule_rate"],
                    )
                )

    out("")
    out("── codes ───────────────────────────────────────────────────────────")
    out("rated (unambiguous): %d" % len(unambiguous))
    out("withheld (ambiguous): %d" % len(ambiguous))
    out("exclusions captured : %d" % len(excluded))
    out("")
    out("rate distribution (GST %, already doubled from printed CGST):")
    dist = Counter(e["rate"] for e in unambiguous.values())
    for rate, n in sorted(dist.items()):
        out("  %6s%%  %5d" % (rate, n))

    # The slab check runs over EVERY rate the parse derived, not just the ones
    # that reach the CSV. A rate that lands on a code with a second, different
    # rate is withheld as ambiguous and would otherwise slip past this gate
    # unseen — but an impossible slab anywhere means the parse drifted, and the
    # next run (or the human reading ambiguous_codes.csv) inherits it.
    derived = defaultdict(list)
    for code, entries in candidates.items():
        for e in entries:
            derived[e["rate"]].append((code, e))
    for rule_code, entry in unambiguous.items():
        if entry["schedule"] == "rule":
            derived[entry["rate"]].append((rule_code, entry))

    for rate in sorted(derived):
        if rate in LEGAL_GST_RATES:
            continue
        where = derived[rate]
        out("")
        out("  ← %s%% IS NOT A LEGAL SLAB — %d occurrence(s):" % (rate, len(where)))
        for code, e in where[:10]:
            out(
                "      %-9s p%-4d %-16s serial %s"
                % (code, e["page"], e["schedule"] or "-", e["serial"])
            )
        failures.append(
            "rate %s%% is not a legal GST slab (allowed: %s) — %d occurrence(s), "
            "first at code %s p%d %s serial %s"
            % (
                rate,
                sorted(LEGAL_GST_RATES),
                len(where),
                where[0][0],
                where[0][1]["page"],
                where[0][1]["schedule"],
                where[0][1]["serial"],
            )
        )
    out("")
    out("code width:")
    for width, n in sorted(Counter(len(c) for c in unambiguous).items()):
        out("  %d digits  %5d" % (width, n))

    out("")
    out("── skipped terms (%d) ───────────────────────────────────────────────" % len(skipped))
    kinds = Counter(s["reason"].split(":")[0] for s in skipped)
    for kind, n in sorted(kinds.items(), key=lambda kv: -kv[1]):
        out("  %-12s %d" % (kind, n))
    out("")
    for s in sorted(skipped, key=lambda s: (s["page"], s["serial"])):
        out(
            "  p%-4d %-16s serial %-5d %s"
            % (s["page"], s["schedule"] or "-", s["serial"], s["reason"])
        )

    # ── Chapter-level rows ───────────────────────────────────────────────────
    kept = [c for c in chapter_rows if c["kept"]]
    dropped = [c for c in chapter_rows if not c["kept"]]
    out("")
    out("── chapter-level rows (2-digit codes) ──────────────────────────────")
    out(
        "  A chapter emitted as ratable becomes the rate of EVERY code beneath\n"
        "  it that the schedules do not rate individually. Only a row that rates\n"
        "  the whole chapter may do that; the rest are dropped here."
    )
    out("")
    out("  kept as whole-chapter (%d):" % len(kept))
    for c in sorted(kept, key=lambda c: c["code"]):
        out(
            "    %-3s %-16s serial %-5s p%-4d %6s%%  %s"
            % (
                c["code"],
                c["schedule"] or "-",
                c["serial"],
                c["page"],
                c["rate"],
                c["description"][:70],
            )
        )
    out("")
    out("  dropped — the row describes a subset, not the chapter (%d):" % len(dropped))
    for c in sorted(dropped, key=lambda c: (c["code"], str(c["serial"]))):
        out(
            "    %-3s %-16s serial %-5s p%-4d %6s%%  %s"
            % (
                c["code"],
                c["schedule"] or "-",
                c["serial"],
                c["page"],
                c["rate"],
                c["description"][:70],
            )
        )
        if c["note"] and c["note"].startswith("STALE"):
            failures.append(
                "chapter %s %s serial %s is allow-listed as whole-chapter but %s"
                % (c["code"], c["schedule"], c["serial"], c["note"])
            )

    # An allow-listed row that the parse never saw means the document changed
    # under the table — fail rather than silently lose a chapter rate.
    seen = {(c["code"], c["schedule"], c["serial"]) for c in chapter_rows}
    for key in CHAPTER_WIDE_ROWS:
        if key not in seen:
            failures.append(
                "allow-listed whole-chapter row %s (schedule %s serial %s) is not in "
                "this document — re-read the chapter rows before trusting the CSV"
                % key
            )

    # ── Compensation cess ────────────────────────────────────────────────────
    out("")
    out("── compensation cess ───────────────────────────────────────────────")
    out("  rows parsed              : %d" % cess_report["rows"])
    out("  codes with a usable cess : %d" % len(cess_report["cess"]))
    out("  withheld (two cess rates): %d" % len(cess_report["ambiguous"]))
    out("  not a percentage         : %d" % len(cess_report["unrepresentable"]))
    out("")
    for code in sorted(cess_report["cess"]):
        e = cess_report["cess"][code]
        out(
            "    %-10s %6s%%  S.No %-5s p%-4d %s"
            % (code, e["cess"], e["serial"], e["page"], e["description"][:55])
        )
    if cess_report["derived"]:
        out("")
        out(
            "  carried to the tariff item at its rated ancestor's GST rate (%d)\n"
            "  — the cess is only read off the row that prices the line:"
            % len(cess_report["derived"])
        )
        for d in cess_report["derived"]:
            out(
                "    %-10s cess %6s%%  GST from %-6s S.No %s"
                % (d["code"], d["cess"], d["ancestor"], d["serial"])
            )
    if cess_report["orphaned"]:
        out("")
        out("  DROPPED — a cess with no rated ancestor to hang it on (%d):" % len(cess_report["orphaned"]))
        for d in cess_report["orphaned"]:
            out("    %-10s cess %6s%%  S.No %-5s %s" % (d["code"], d["cess"], d["serial"], d["description"][:50]))
    if cess_report["ambiguous"]:
        out("")
        out("  WITHHELD — the schedule prints more than one cess for the code:")
        for code in sorted(cess_report["ambiguous"]):
            rates = ", ".join(
                "%s%% (S.No %s)" % (e["cess"], e["serial"])
                for e in cess_report["ambiguous"][code]
            )
            out("    %-10s %s" % (code, rates))
    if cess_report["unrepresentable"]:
        out("")
        out(
            "  SKIPPED — per-unit or compound, not expressible as a percentage\n"
            "  (R = declared retail sale price; these need the pack size / RSP):"
        )
        for e in cess_report["unrepresentable"]:
            out(
                "    %-10s S.No %-5s %-34s %s"
                % (e["code"], e["serial"], e["why"][:34], e["description"][:40])
            )
    if cess_report["chapter_rows"]:
        out("")
        out("  chapter-level cess rows, dropped for the same reason as above:")
        for e in cess_report["chapter_rows"]:
            out(
                "    %-3s S.No %-5s %-8s %s"
                % (e["code"], e["serial"], e["printed"][:8], e["description"][:60])
            )

    if rule_warnings:
        out("")
        out("── rule cross-check ────────────────────────────────────────────────")
        for w in rule_warnings:
            out("  ! %s" % w)

    return failures


# ── Wiring ───────────────────────────────────────────────────────────────────


def write_outputs(
    out_dir, csv_name, unambiguous, ambiguous, excluded, rows, cess_rows, cess_report
):
    out_dir.mkdir(parents=True, exist_ok=True)

    csv_path = out_dir / csv_name
    with open(csv_path, "w", newline="") as fh:
        w = csv.writer(fh)
        # `cess` is picked up by hsn-import's CESS_FIELDS. Blank means the cess
        # schedule declares nothing for this code, which is the residual NIL of
        # its S.No 56 — NOT "unknown".
        w.writerow(["code", "rate", "cess", "description", "schedule", "source_page"])
        for code in sorted(unambiguous):
            e = unambiguous[code]
            w.writerow(
                [
                    code,
                    e["rate"],
                    e.get("cess", ""),
                    e["description"],
                    e["schedule"],
                    e["page"],
                ]
            )

    # The cess rows a human has to decide, for the same reason ambiguous_codes
    # exists: two printed cess rates, or a rate that is not a percentage at all.
    cess_amb_path = out_dir / "ambiguous_cess.csv"
    with open(cess_amb_path, "w", newline="") as fh:
        w = csv.writer(fh)
        w.writerow(["code", "printed_cess", "why_withheld", "condition", "serial", "source_page"])
        for code in sorted(cess_report["ambiguous"]):
            for e in cess_report["ambiguous"][code]:
                w.writerow(
                    [code, e["printed"], "two or more cess rates for this code",
                     e["description"], e["serial"], e["page"]]
                )
        for e in cess_report["unrepresentable"]:
            w.writerow(
                [e["code"], e["printed"], "not an ad-valorem percentage",
                 e["description"], e["serial"], e["page"]]
            )
        for e in cess_report["orphaned"]:
            w.writerow(
                [e["code"], e["printed"], "no rated ancestor to carry it to",
                 e["description"], e["serial"], e["page"]]
            )

    # First-class output, not a side effect: these are the codes a human has to
    # decide, and they are the whole reason the importer is allowed to trust
    # everything else in the CSV.
    amb_path = out_dir / "ambiguous_codes.csv"
    with open(amb_path, "w", newline="") as fh:
        w = csv.writer(fh)
        w.writerow(["code", "rate", "condition", "schedule", "source_page"])
        for code in sorted(ambiguous):
            for e in ambiguous[code]:
                w.writerow([code, e["rate"], e["description"], e["schedule"], e["page"]])

    excl_path = out_dir / "exclusions.json"
    with open(excl_path, "w") as fh:
        json.dump({k: sorted(v) for k, v in excluded.items()}, fh, indent=1)

    rows_path = out_dir / "reckoner_rows.json"
    with open(rows_path, "w") as fh:
        json.dump(rows, fh, indent=1)

    cess_rows_path = out_dir / "cess_rows.json"
    with open(cess_rows_path, "w") as fh:
        json.dump(cess_rows, fh, indent=1)

    return csv_path, amb_path, excl_path, rows_path, cess_rows_path, cess_amb_path


def main():
    ap = argparse.ArgumentParser(
        description="Extract GST rates from the CBIC GST Ready Reckoner PDF.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="Requires pdfplumber:  pip3 install pdfplumber",
    )
    ap.add_argument("--pdf", help="the CBIC Ready Reckoner PDF")
    ap.add_argument(
        "--from-rows",
        help="skip the PDF and re-build from a previous reckoner_rows.json",
    )
    ap.add_argument(
        "--rules",
        help="price-threshold rules JSON from `npm run hsn:rules-dump` "
        "(default <out-dir>/rules.json)",
    )
    ap.add_argument(
        "--out-dir",
        default=str(Path(__file__).resolve().parents[3] / "readmes" / "hsn-rates"),
        help="where to write the outputs (default readmes/hsn-rates/)",
    )
    ap.add_argument(
        "--as-on",
        default="22092025",
        help="date tag for the CSV filename, DDMMYYYY (default 22092025)",
    )
    args = ap.parse_args()

    if not args.pdf and not args.from_rows:
        ap.error("one of --pdf or --from-rows is required")

    out_dir = Path(args.out_dir)
    rules_path = Path(args.rules) if args.rules else out_dir / "rules.json"
    if not rules_path.exists():
        sys.exit(
            "REFUSING TO RUN: price-threshold rules not found at %s\n"
            "  Run `npm run hsn:rules-dump` first (npm run hsn:rates does both).\n"
            "  Without them the ~30 apparel/footwear/hotel codes are withheld as\n"
            "  ambiguous and a T-shirt cannot price a line at all." % rules_path
        )
    rules = json.loads(rules_path.read_text())

    if args.from_rows:
        rows_file = Path(args.from_rows)
        rows = json.loads(rows_file.read_text())
        pages = max((r["page"] for r in rows), default=0)
        cess_file = rows_file.parent / "cess_rows.json"
        cess_rows = json.loads(cess_file.read_text()) if cess_file.exists() else []
        print(
            "re-building from %s (%d rows, %d cess rows)"
            % (args.from_rows, len(rows), len(cess_rows))
        )
        if not cess_rows:
            print(
                "  ! no cess_rows.json beside it — the cess column will be empty.\n"
                "    Re-run with --pdf to pick the compensation cess schedule back up."
            )
    else:
        print("reading %s …" % args.pdf)
        rows, cess_rows, pages = extract(args.pdf)

    (
        unambiguous,
        ambiguous,
        excluded,
        skipped,
        rule_warnings,
        candidates,
        chapter_rows,
    ) = build(rows, rules)

    cess, cess_ambiguous, cess_unrepresentable, cess_chapters, cess_skipped = build_cess(
        cess_rows
    )
    cess_derived, cess_orphaned = attach_cess(unambiguous, cess)
    cess_report = {
        "rows": len(cess_rows),
        "cess": cess,
        "ambiguous": cess_ambiguous,
        "unrepresentable": cess_unrepresentable,
        "chapter_rows": cess_chapters,
        "derived": cess_derived,
        "orphaned": cess_orphaned,
        "skipped": cess_skipped,
    }

    failures = verify(
        rows,
        unambiguous,
        ambiguous,
        excluded,
        skipped,
        rule_warnings,
        candidates,
        pages,
        chapter_rows,
        cess_report,
    )

    print("")
    print("── sanity gates ────────────────────────────────────────────────────")
    if failures:
        print("  FAIL — %d problem(s), nothing was written:" % len(failures))
        for f in failures:
            print("    · %s" % f)
        print("")
        print(
            "  Tax data that is quietly wrong is worse than tax data that is\n"
            "  missing: it prints on invoices and the department reconciles\n"
            "  against it. Fix the parse (or the source) and re-run."
        )
        sys.exit(1)

    print("  PASS — every rate is a legal slab; Schedules %s are contiguous." % ", ".join(CONTINUITY_SCHEDULES))

    csv_path, amb_path, excl_path, rows_path, cess_rows_path, cess_amb_path = (
        write_outputs(
            out_dir,
            "gst_rates_%s.csv" % args.as_on,
            unambiguous,
            ambiguous,
            excluded,
            rows,
            cess_rows,
            cess_report,
        )
    )

    with_cess = sum(1 for e in unambiguous.values() if e.get("cess"))
    print("")
    print("── written ─────────────────────────────────────────────────────────")
    print("  %s  (%d codes, %d carrying cess)" % (csv_path, len(unambiguous), with_cess))
    print("  %s  (%d codes withheld for review)" % (amb_path, len(ambiguous)))
    print(
        "  %s  (%d cess entries withheld for review)"
        % (
            cess_amb_path,
            len(cess_report["ambiguous"])
            + len(cess_report["unrepresentable"])
            + len(cess_report["orphaned"]),
        )
    )
    print("  %s" % excl_path)
    print("  %s" % rows_path)
    print("  %s" % cess_rows_path)
    print("")
    print("Next:")
    print(
        "  npm run hsn:import -- --directory <hsn_directory.csv> --rates %s" % csv_path
    )


if __name__ == "__main__":
    main()
