"""Pulling the checkable things out of a blob of pasted text.

The universal analyzer (`POST /analyze`) accepts whatever the user has in their
clipboard — a forwarded WhatsApp message, a bare link, a phone number on its
own, or all three at once — so before anything can be judged, the text has to be
split into entities that different checkers can handle.

Deliberately plain regex, not AI: "does this substring look like a URL" is a
lexical question with a right answer, and a model would only add latency and
unpredictability to it. The classifier still sees the *whole* original text; this
module only decides what gets looked up alongside it.
"""

from __future__ import annotations

import re

# Scheme'd or www-prefixed URLs are unambiguous. Trailing punctuation is stripped
# afterwards, since a link at the end of a sentence usually collects a full stop.
_EXPLICIT_URL_RE = re.compile(r"(?:https?://|www\.)[^\s<>\"'\]\)]+", re.IGNORECASE)

# A bare host like "ecocash-verify.co.zw/login" — only trusted when the TLD is
# one we recognise, otherwise ordinary prose ("reverse.the", "e.g.") parses as a
# domain and every message ends up "containing a link".
_BARE_HOST_RE = re.compile(
    r"\b(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z]{2,24}(?:/[^\s<>\"'\]\)]*)?",
    re.IGNORECASE,
)

_KNOWN_TLDS = frozenset(
    {
        # Zimbabwe
        "zw",
        # generic
        "com", "net", "org", "info", "biz", "app", "io", "me", "co", "dev", "ai",
        # cheap/abused TLDs that show up constantly in phishing
        "xyz", "top", "click", "link", "live", "online", "site", "shop", "store",
        "tk", "ml", "ga", "cf", "gq", "work", "zip", "mov", "icu", "buzz", "cyou",
        # other ccTLDs seen in scams targeting the region
        "za", "uk", "us", "ru", "cn", "in", "ng", "ke", "tz", "zm", "mw", "bw",
        # ccTLDs repurposed as vanity endings — these are what URL shorteners
        # use (bit.ly, goo.gl, is.gd, tiny.cc, s.id, shorturl.at), so leaving
        # them out would make shortened links invisible to the analyzer.
        "ly", "gl", "gd", "cc", "at", "sh", "ws", "to", "tv", "fm", "am", "id", "so",
    }
)

# Any run of digits long enough to be a phone number, tolerating the spacing,
# dashes and brackets people actually type.
_PHONE_CANDIDATE_RE = re.compile(r"\+?\d[\d\s\-().]{7,}\d")

_MIN_PHONE_DIGITS = 9


def extract_urls(text: str) -> list[str]:
    """URLs in first-seen order, de-duplicated case-insensitively."""
    found: list[str] = []
    seen: set[str] = set()

    def add(candidate: str) -> None:
        cleaned = candidate.rstrip(".,;:!?)]}'\"")
        if not cleaned:
            return
        key = cleaned.lower()
        if key not in seen:
            seen.add(key)
            found.append(cleaned)

    for match in _EXPLICIT_URL_RE.finditer(text):
        add(match.group(0))

    # Only consider bare hosts in the text left over after explicit URLs are
    # removed, so "https://a.co/x" doesn't also yield "a.co" as a second link.
    remainder = _EXPLICIT_URL_RE.sub(" ", text)
    for match in _BARE_HOST_RE.finditer(remainder):
        candidate = match.group(0).rstrip(".,;:!?)]}'\"")
        host = candidate.split("/", 1)[0]
        if host.rsplit(".", 1)[-1].lower() in _KNOWN_TLDS:
            add(candidate)

    return found


def strip_urls(text: str) -> str:
    """Text with URLs blanked out, so digits inside a link path aren't mistaken
    for a phone number."""
    return _BARE_HOST_RE.sub(" ", _EXPLICIT_URL_RE.sub(" ", text))


def extract_phone_numbers(text: str) -> tuple[list[str], list[str]]:
    """Phone-like runs found in [text], as `(zimbabwean, unrecognized)`.

    The first list holds numbers normalized to the local `0XXXXXXXXX` form, ready
    to look up. The second holds things that are clearly a phone number but not
    one this system knows anything about — foreign numbers, mistyped ones — which
    the analyzer reports rather than silently drops, since "we can't check this"
    is a different answer from "this is fine".
    """
    # Imported here rather than at module scope: reputation imports nothing from
    # this module, and keeping the dependency one-directional avoids a cycle.
    from app.services.reputation import ValidationError, normalize_msisdn

    local: list[str] = []
    unrecognized: list[str] = []
    seen: set[str] = set()

    for match in _PHONE_CANDIDATE_RE.finditer(strip_urls(text)):
        raw = match.group(0).strip()
        digits = re.sub(r"\D", "", raw)
        if len(digits) < _MIN_PHONE_DIGITS:
            continue

        try:
            msisdn = normalize_msisdn(raw)
        except ValidationError:
            key = f"?{digits}"
            if key not in seen:
                seen.add(key)
                unrecognized.append(raw)
            continue

        if msisdn not in seen:
            seen.add(msisdn)
            local.append(msisdn)

    return local, unrecognized
