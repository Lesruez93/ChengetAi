"""Evidence minimisation for reported message excerpts.

A reporting tool accumulates other people's messages, and those messages carry
identifiers belonging to people who never consented to anything: the victim's
own account number, a third party's phone number, an OTP that is still live.
Storing them raw would mean every future breach of this database is also a
breach of them.

So excerpts are redacted at the boundary — in `submit_report`, before the
record ever reaches a store — rather than at render time. Redaction at render
time protects the screen; redaction at intake protects the database.

What survives redaction is exactly what the product needs: the scam's wording,
which is what the classifier learns from and what a moderator reads to judge a
report. What does not survive is anything that identifies a person or unlocks
an account.

The reported number itself is *not* redacted here — it is the subject of the
report and is stored in its own validated field.
"""

from __future__ import annotations

import re

MAX_EXCERPT_CHARS = 500

# Order matters: the more specific patterns run first, so an account number is
# not partially consumed by the generic long-digit rule.
_PATTERNS: tuple[tuple[re.Pattern[str], str], ...] = (
    # Email addresses.
    (re.compile(r"\b[\w.+-]+@[\w-]+\.[\w.-]+\b"), "[email]"),
    # URLs — kept as a marker because "the message contained a link" is signal,
    # while the link itself is a live phishing target we should not re-serve.
    (re.compile(r"\bhttps?://\S+|\bwww\.\S+", re.IGNORECASE), "[link]"),
    # A labelled secret: OTP/PIN/BVN/NIN/ID followed by its value.
    (re.compile(r"\b(otp|pin|bvn|nin|code|password)\b[\s:is]{0,6}\d{3,}",
                re.IGNORECASE), r"\1 [redacted]"),
    # Phone numbers in E.164 or local form, including spaced groupings.
    (re.compile(r"\+\d[\d\s-]{7,15}\d"), "[number]"),
    (re.compile(r"\b0\d[\d\s-]{6,12}\d\b"), "[number]"),
    # Any other run of 7+ digits: account numbers, ID numbers, card fragments.
    (re.compile(r"\b\d{7,}\b"), "[redacted]"),
)


def redact_excerpt(text: str, max_chars: int = MAX_EXCERPT_CHARS) -> str:
    """Strip personal identifiers and secrets from a reported message excerpt.

    Idempotent: redacting already-redacted text leaves it unchanged, so a
    re-import or a replayed report cannot double-mangle an excerpt.
    """
    if not text:
        return ""
    redacted = text
    for pattern, replacement in _PATTERNS:
        redacted = pattern.sub(replacement, redacted)
    redacted = re.sub(r"\s+", " ", redacted).strip()
    if len(redacted) > max_chars:
        redacted = redacted[:max_chars].rstrip() + "…"
    return redacted
