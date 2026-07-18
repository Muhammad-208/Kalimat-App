#!/usr/bin/env python3
"""
normalize.py — Arabic text normalization and root matching.

The hard, reusable core of "add every source": every dictionary writes headwords
differently (tashkeel, أ/ا, ى/ي, hamza seats, the ال article, sun-letter shadda,
geminate roots like ربب/يمم). We reduce both sides to comparable keys so each
entry files under the right root. No external dependencies.
"""
import re
import unicodedata

_TASHKEEL = re.compile(r"[\u064B-\u065F\u0670]")   # harakat, tanwin, shadda, sukun, dagger-alef
_TATWEEL = re.compile(r"\u0640")
_NON_ARABIC = re.compile(r"[^\u0621-\u064A\s]")


def strip_diacritics(text: str) -> str:
    text = unicodedata.normalize("NFC", text)
    text = _TASHKEEL.sub("", text)
    text = _TATWEEL.sub("", text)
    return text


def normalize(text: str) -> str:
    """No diacritics; unified hamza/alef/yaa/taa. Keeps letters only."""
    t = strip_diacritics(text)
    for a, b in (("أ", "ا"), ("إ", "ا"), ("آ", "ا"), ("ٱ", "ا"),
                 ("ؤ", "و"), ("ئ", "ي"), ("ء", ""), ("ى", "ي"), ("ة", "ه")):
        t = t.replace(a, b)
    t = _NON_ARABIC.sub("", t)
    return re.sub(r"\s+", " ", t).strip()


def _strip_article(n: str) -> str:
    """Drop a leading ال article, but never below 3 letters (avoid eating roots)."""
    return n[2:] if n.startswith("ال") and len(n) >= 4 else n


def collapse_doubles(n: str) -> str:
    """Merge adjacent identical letters: ربب→رب, يمم→يم, بحر→بحر."""
    out = []
    for ch in n.replace(" ", ""):
        if not out or out[-1] != ch:
            out.append(ch)
    return "".join(out)


class RootIndex:
    """Maps a dictionary headword to a root_id. Returns (root_id, 'exact'|'fuzzy'|None)."""

    def __init__(self, roots: list[tuple[int, str]]):
        self.exact: dict[str, int] = {}
        self.fuzzy: dict[str, int] = {}
        for rid, root in roots:
            self.exact[normalize(root)] = rid
            self.fuzzy.setdefault(collapse_doubles(normalize(root)), rid)

    def match(self, headword: str):
        n = normalize(headword)
        for cand in (n, _strip_article(n)):          # exact wins
            if cand in self.exact:
                return self.exact[cand], "exact"
        for cand in (n, _strip_article(n)):          # geminate/weak fallback
            if collapse_doubles(cand) in self.fuzzy:
                return self.fuzzy[collapse_doubles(cand)], "fuzzy"
        return None, None


if __name__ == "__main__":
    idx = RootIndex([(1, "بحر"), (2, "يمم"), (8, "قول"), (10, "ربب")])
    for w in ["الْبَحْر", "بحر", "بَحَرَ", "اليَمّ", "يَمّ", "قَوْل", "الرَّبّ", "خطأ"]:
        print(f"{w:>10}  ->  {idx.match(w)}")
