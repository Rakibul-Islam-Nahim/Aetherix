"""Normalize article categories to the Aetherix allowlist.

The product spec is intentionally strict: the UI surfaces four hard tags
and nothing else. Any tag emitted by the LLM worker (or stored from old
ingest cycles) is collapsed to one of these four, or to ``Technology``
as the catch-all bucket.

Allowlist:
    - ``Cyber Security``
    - ``Technology``
    - ``AI``
    - ``Hacking``

Anything else maps to ``Technology``.
"""
from __future__ import annotations

ALLOWED_TAGS: tuple[str, ...] = (
    "Cyber Security",
    "Technology",
    "AI",
    "Hacking",
)

_FALLBACK = "Technology"

# Case-insensitive substring rules. Order matters — first match wins.
_RULES: tuple[tuple[str, str], ...] = (
    ("hacking", "Hacking"),
    ("hack", "Hacking"),
    ("exploit", "Cyber Security"),
    ("vulnerab", "Cyber Security"),
    ("cve", "Cyber Security"),
    ("ransomware", "Cyber Security"),
    ("malware", "Cyber Security"),
    ("phishing", "Cyber Security"),
    ("breach", "Cyber Security"),
    ("cyber", "Cyber Security"),
    ("security", "Cyber Security"),
    (" ai ", "AI"),
    ("artificial intelligence", "AI"),
    ("machine learning", "AI"),
    ("llm", "AI"),
    ("gpt", "AI"),
    ("generative", "AI"),
    ("tech", "Technology"),
)


def normalize(categories: list[str] | None) -> list[str]:
    """Return a deduplicated list of normalized tags (max length 4)."""
    if not categories:
        return [_FALLBACK]

    seen: set[str] = set()
    out: list[str] = []

    def push(name: str) -> None:
        if name not in seen:
            seen.add(name)
            out.append(name)

    for raw in categories:
        if not raw:
            continue
        mapped = map_one(raw)
        if mapped is not None:
            push(mapped)

    if not out:
        return [_FALLBACK]
    return out[:4]


def map_one(name: str) -> str | None:
    """Map a single free-form category string to one of the allowlisted
    tags. Returns ``None`` if the input is empty/blank."""
    if not name:
        return None
    norm = " " + name.strip().lower() + " "

    for needle, tag in _RULES:
        if needle in norm:
            return tag

    # If the input already matches an allowed tag (case-insensitive), keep it.
    for tag in ALLOWED_TAGS:
        if tag.lower() == name.strip().lower():
            return tag

    return _FALLBACK


def primary(categories: list[str] | None) -> str:
    """Return the primary tag for an article.

    The four allowlisted tags have a priority order so the card UI gets a
    meaningful single value: ``Cyber Security`` > ``Hacking`` > ``AI`` >
    ``Technology``. ``Technology`` is the catch-all fallback.
    """
    priority = (
        "Cyber Security",
        "Hacking",
        "AI",
        "Technology",
    )
    tags = set(normalize(categories))
    for p in priority:
        if p in tags:
            return p
    return _FALLBACK