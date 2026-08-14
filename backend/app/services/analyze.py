"""The universal analyzer behind `POST /analyze`.

One text box, anything pasted into it. This module splits the paste into
entities (`services/entities.py`), routes each to the checker that can actually
judge it — the classifier for prose, the reputation store for numbers, the URL
heuristics for links — and then reduces the findings to a single answer.

The combination step is worst-of, not an average. A message reading "your parcel
is waiting" is unremarkable prose; the same message carrying a link to
`ecocash-verify.tk/login` is a phishing attempt, and averaging the two into
"probably fine" would be exactly the wrong answer. Every component finding is
returned alongside the verdict, so the user sees which part was the problem.
"""

from __future__ import annotations

from app.schemas.analyze import AnalyzeResponse, LinkFinding, NumberFinding
from app.schemas.classify import ClassifyResponse
from app.services.classifier import get_classifier
from app.services.entities import extract_phone_numbers, extract_urls
from app.services.link_check import assess_url
from app.services.reputation import lookup_number, top_category_for
from app.services.store import Store

METHOD_NOTE = (
    "Message wording is judged by the scam classifier; phone numbers by community "
    "reports; links by the shape of the web address only — links are never opened or "
    "fetched. The overall verdict is the worst of the three."
)

_SEVERITY: dict[str, int] = {
    "scam": 3, "high": 3,
    "suspicious": 2, "medium": 2,
    "low": 1,
    "safe": 0, "unknown": 0,
}

_VERDICT_BY_SEVERITY = {3: "scam", 2: "suspicious", 1: "safe", 0: "safe"}

# Below this many words a paste is treated as a bare link/number rather than a
# message, and the classifier — which is trained on sentences — is skipped
# instead of being asked to judge "0771234567".
_MIN_WORDS_FOR_CLASSIFIER = 4


def analyze(store: Store, text: str, strategy: str | None = None) -> AnalyzeResponse:
    links = [_to_link_finding(url) for url in extract_urls(text)]
    local_numbers, unrecognized = extract_phone_numbers(text)
    numbers = [_to_number_finding(store, msisdn) for msisdn in local_numbers]
    message = _classify_prose(text, strategy)

    severity = max(
        [_SEVERITY.get(message.verdict, 0) if message else 0]
        + [_SEVERITY.get(link.risk_level, 0) for link in links]
        + [_SEVERITY.get(number.risk_level, 0) for number in numbers]
    )

    return AnalyzeResponse(
        verdict=_VERDICT_BY_SEVERITY[severity],
        confidence=_confidence(severity, message, links, numbers),
        summary=_summarize(severity, message, links, numbers, unrecognized),
        message=message,
        links=links,
        numbers=numbers,
        unrecognized_numbers=unrecognized,
        method_note=METHOD_NOTE,
    )


def _classify_prose(text: str, strategy: str | None) -> ClassifyResponse | None:
    if len(text.split()) < _MIN_WORDS_FOR_CLASSIFIER:
        return None
    # ClassifyRequest caps text at 4000 chars; /analyze accepts more, so trim
    # rather than reject a long paste whose links and numbers we can still check.
    return get_classifier(strategy).classify(text[:4000])


def _to_link_finding(url: str) -> LinkFinding:
    assessment = assess_url(url)
    return LinkFinding(
        url=assessment.url,
        host=assessment.host,
        risk_level=assessment.risk_level,
        reasons=assessment.reasons,
    )


def _to_number_finding(store: Store, msisdn: str) -> NumberFinding:
    reputation = lookup_number(store, msisdn)
    number = store.upsert_number_reputation(msisdn)
    return NumberFinding(
        msisdn=reputation.msisdn,
        risk_level=reputation.risk_level,
        report_count=reputation.report_count,
        is_publicly_flagged=reputation.is_publicly_flagged,
        top_category=top_category_for(number) if reputation.report_count else None,
    )


def _confidence(
    severity: int,
    message: ClassifyResponse | None,
    links: list[LinkFinding],
    numbers: list[NumberFinding],
) -> float:
    """How sure we are of the *overall* verdict, taken from whichever signal
    produced it. Reporting the classifier's confidence for a verdict that a
    blocklisted number actually drove would be describing the wrong evidence."""
    candidates: list[float] = []

    if message and _SEVERITY.get(message.verdict, 0) == severity:
        candidates.append(message.confidence)

    for link in links:
        if _SEVERITY.get(link.risk_level, 0) == severity:
            candidates.append(0.85 if link.risk_level == "high" else 0.6)

    for number in numbers:
        if _SEVERITY.get(number.risk_level, 0) == severity:
            # More corroborating reports, more confidence, capped — this is
            # crowd-sourced evidence and never becomes certainty.
            candidates.append(min(0.95, 0.6 + 0.05 * number.report_count))

    if not candidates:
        return 0.5
    return round(max(candidates), 2)


def _summarize(
    severity: int,
    message: ClassifyResponse | None,
    links: list[LinkFinding],
    numbers: list[NumberFinding],
    unrecognized: list[str],
) -> str:
    parts: list[str] = []

    # Any number with reports against it gets said out loud, not just the ones
    # that clear "medium". A single report doesn't justify a scam verdict, but
    # summarising it as "nothing was flagged" would contradict the finding shown
    # directly underneath it.
    reported_numbers = [n for n in numbers if n.report_count > 0]
    risky_links = [link for link in links if link.risk_level in {"medium", "high"}]
    minor_links = [link for link in links if link.risk_level == "low"]

    if reported_numbers:
        first = reported_numbers[0]
        plural = "time" if first.report_count == 1 else "times"
        extra = f" (and {len(reported_numbers) - 1} more)" if len(reported_numbers) > 1 else ""
        hedge = "" if first.is_publicly_flagged else ", which is not yet enough to flag it publicly"
        parts.append(
            f"{first.msisdn} has been reported {first.report_count} {plural} by the community{extra}{hedge}."
        )

    if risky_links:
        first = risky_links[0]
        extra = f" (and {len(risky_links) - 1} more)" if len(risky_links) > 1 else ""
        parts.append(f"The link to {first.host} looks unsafe{extra}.")
    elif minor_links:
        parts.append(f"The link to {minor_links[0].host} has a minor warning sign.")

    if message and message.verdict != "safe":
        parts.append(f"The wording reads as {message.verdict}.")

    if not parts:
        checked: list[str] = []
        if message:
            checked.append("the wording")
        if links:
            checked.append(f"{len(links)} link{'s' if len(links) > 1 else ''}")
        if numbers:
            checked.append(f"{len(numbers)} number{'s' if len(numbers) > 1 else ''}")
        subject = ", ".join(checked) if checked else "this text"
        parts.append(
            f"Nothing was flagged in {subject}. That is not a guarantee — a new scam "
            "nobody has reported yet will still look clean here."
        )

    if unrecognized:
        parts.append(
            f"Could not check {len(unrecognized)} number"
            f"{'s' if len(unrecognized) > 1 else ''} — not a Zimbabwean mobile number."
        )

    if severity >= 3:
        parts.append("Do not send money, share an OTP, or tap any link in this.")
    elif severity == 2:
        parts.append("Verify through an official channel before acting on it.")

    return " ".join(parts)
