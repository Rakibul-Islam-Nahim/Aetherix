"""Unit tests for the tag allowlist normalizer."""
from app.services.tag_normalize import ALLOWED_TAGS, map_one, normalize, primary


def test_allowed_set():
    assert set(ALLOWED_TAGS) == {"Cyber Security", "Technology", "AI", "Hacking"}


def test_primary_uses_first_allowlisted():
    # "Cyber Security" contains "cyber" -> Cyber Security wins.
    assert primary(["Women in Tech", "Cyber Security", "AI"]) == "Cyber Security"


def test_primary_picks_most_specific():
    # "CVE-2026-001" -> Cyber Security, not AI
    assert primary(["CVE-2026-001"]) == "Cyber Security"
    # "GPT-5 launch" -> AI
    assert primary(["GPT-5 launch"]) == "AI"


def test_normalize_dedupes_and_caps():
    out = normalize(["Cyber Security", "ransomware", "exploit", "AI"])
    assert out == ["Cyber Security", "AI"]


def test_normalize_unknown_falls_back_to_technology():
    out = normalize(["Women in Tech", "Diversity", "Press release"])
    assert out == ["Technology"]


def test_normalize_empty_returns_fallback():
    assert normalize(None) == ["Technology"]
    assert normalize([]) == ["Technology"]


def test_map_one_returns_none_for_blank():
    assert map_one("") is None
    assert map_one(None) is None  # type: ignore[arg-type]


def test_map_one_recognises_exact_allowlist():
    assert map_one("Hacking") == "Hacking"
    assert map_one("AI") == "AI"
    assert map_one("technology") == "Technology"