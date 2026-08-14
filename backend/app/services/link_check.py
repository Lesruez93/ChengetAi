"""Assessing a URL from its address alone.

Nothing here fetches the link. That is a deliberate constraint, not a gap: this
service would be resolving URLs supplied by strangers on behalf of users, which
turns the backend into a request-forwarding proxy for attacker-controlled
addresses (SSRF against internal hosts, and a way to make our server register
clicks on someone else's phishing page). Everything below is therefore a
judgement about the *shape* of the address.

The trade is that a hostile page on a clean-looking domain reads as "nothing
obviously wrong", so `unknown` is a distinct verdict from `low` and the UI is
careful never to present it as "safe".

Rules, not a model, for the same reason as `services/reputation.py`: each signal
has to be explainable to a user in one sentence, and typosquat detection is
exact-match logic over a brand list, not a learned boundary.
"""

from __future__ import annotations

import ipaddress
import re
from dataclasses import dataclass
from urllib.parse import urlsplit

# Institutions whose names get impersonated locally. Matching is on the brand
# token appearing anywhere in the hostname while the registrable domain is not
# the real one — "ecocash-verify.xyz" and "secure-ecocash.co.zw.login.tk" both
# trip it, "ecocash.co.zw" does not.
_BRAND_DOMAINS: dict[str, str] = {
    "ecocash": "ecocash.co.zw",
    "onemoney": "onemoney.co.zw",
    "innbucks": "innbucks.co.zw",
    "econet": "econet.co.zw",
    "netone": "netone.co.zw",
    "telecel": "telecel.co.zw",
    "zesa": "zesa.co.zw",
    "stewardbank": "stewardbank.co.zw",
    "cbz": "cbz.co.zw",
    "nmbz": "nmbz.co.zw",
    "posb": "posb.co.zw",
    "zimra": "zimra.co.zw",
    "potraz": "potraz.gov.zw",
    "whatsapp": "whatsapp.com",
}

_SHORTENERS = frozenset(
    {
        "bit.ly", "tinyurl.com", "t.co", "goo.gl", "ow.ly", "buff.ly", "is.gd",
        "cutt.ly", "rb.gy", "shorturl.at", "rebrand.ly", "tiny.cc", "s.id", "lnkd.in",
    }
)

# TLDs with free or near-free registration, heavily over-represented in phishing.
_HIGH_ABUSE_TLDS = frozenset(
    {"tk", "ml", "ga", "cf", "gq", "xyz", "top", "click", "link", "work", "zip", "mov", "icu", "buzz", "cyou"}
)

_CREDENTIAL_PATH_RE = re.compile(
    r"(login|signin|verify|verification|confirm|secure|update|account|wallet|otp|pin|password|unlock|reactivate)",
    re.IGNORECASE,
)

# Weights: 3 = on its own, strong enough to call the link dangerous.
_WEIGHT_HIGH = 3
_WEIGHT_MEDIUM = 2
_WEIGHT_LOW = 1


@dataclass
class LinkAssessment:
    url: str
    host: str
    risk_level: str  # unknown | low | medium | high
    reasons: list[str]


def _normalize(url: str) -> str:
    """Give a bare host a scheme so `urlsplit` puts it in `netloc`, and record
    the absence separately."""
    if "://" in url:
        return url
    return f"http://{url}"


def _registrable_domain(host: str) -> str:
    """Last two labels, or three for the `co.zw`-style second-level suffixes that
    matter here. Not a full public-suffix list — enough for the brand check."""
    labels = host.split(".")
    if len(labels) >= 3 and labels[-2] in {"co", "org", "ac", "gov", "net"}:
        return ".".join(labels[-3:])
    return ".".join(labels[-2:])


def assess_url(url: str) -> LinkAssessment:
    parts = urlsplit(_normalize(url))
    host = (parts.hostname or "").lower().rstrip(".")

    if not host:
        return LinkAssessment(url=url, host="", risk_level="unknown", reasons=["This does not look like a working web address."])

    reasons: list[str] = []
    score = 0

    def flag(weight: int, reason: str) -> None:
        nonlocal score
        score += weight
        reasons.append(reason)

    # -- host identity --

    is_ip_host = False
    try:
        ipaddress.ip_address(host)
        is_ip_host = True
    except ValueError:
        pass

    if is_ip_host:
        flag(_WEIGHT_HIGH, "The address is a raw IP number instead of a name — real companies do not send links like this.")

    if "xn--" in host:
        flag(_WEIGHT_HIGH, "The address uses look-alike foreign characters disguised as ordinary letters.")

    if "@" in parts.netloc:
        flag(_WEIGHT_HIGH, "Everything before the '@' is decoration — the real destination is hidden after it.")

    registrable = _registrable_domain(host)

    for brand, official in _BRAND_DOMAINS.items():
        if brand in host.replace("-", "").replace(".", "") and registrable != official:
            flag(
                _WEIGHT_HIGH,
                f"Uses the {brand} name but is not the real {official} website.",
            )
            break

    if registrable in _SHORTENERS:
        flag(_WEIGHT_MEDIUM, "A shortened link — you cannot see where it actually goes until you tap it.")

    tld = host.rsplit(".", 1)[-1]
    if tld in _HIGH_ABUSE_TLDS:
        flag(_WEIGHT_MEDIUM, f"Ends in .{tld}, a cheap domain ending used heavily for scam sites.")

    # Count only the labels *above* the registrable domain, ignoring a leading
    # "www". Counting dots outright would flag every ordinary
    # "www.brand.co.zw" — a false positive on precisely the real bank and telco
    # sites this is meant to distinguish from their impersonators.
    subdomains = [
        label
        for label in host[: -len(registrable)].strip(".").split(".")
        if label and label != "www"
    ]
    if not is_ip_host and len(subdomains) >= 2:
        flag(_WEIGHT_LOW, "An unusually long chain of names, often used to bury the real address.")

    first_label = host.split(".")[0]
    if first_label.count("-") >= 3:
        flag(_WEIGHT_LOW, "The name is padded with hyphens, a common way to imitate a real brand.")

    if len(host) > 40:
        flag(_WEIGHT_LOW, "The address is unusually long.")

    # -- what it asks for --

    if _CREDENTIAL_PATH_RE.search(parts.path or ""):
        flag(_WEIGHT_MEDIUM, "The page asks you to log in, verify, or unlock something — the usual way details are stolen.")

    if parts.scheme == "http" and "://" in url:
        flag(_WEIGHT_LOW, "Not a secure (https) connection.")

    risk_level = "unknown"
    if score >= _WEIGHT_HIGH:
        risk_level = "high"
    elif score == _WEIGHT_MEDIUM:
        risk_level = "medium"
    elif score == _WEIGHT_LOW:
        risk_level = "low"

    if not reasons:
        reasons.append(
            "Nothing suspicious in the address itself. That does not make it safe — "
            "only open it if you know who sent it."
        )

    return LinkAssessment(url=url, host=host, risk_level=risk_level, reasons=reasons)
