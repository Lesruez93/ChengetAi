"""Scam category taxonomy, shared by the classifier, the reporting flow and the feed.

The categories are deliberately phrased around the *mechanism* of the scam
rather than the brand it impersonates, so one taxonomy holds across every
market ChengetAI covers. "Reverse this wrong deposit" is the same attack
whether the wallet named in the message is EcoCash, M-PESA, MTN MoMo or OPay —
splitting it per provider would fragment the trend data that makes the feed
useful, and would need a new category every time a new wallet launches.

`SCAM_CATEGORIES` is the curated set the apps offer in pickers. The backend's
`category` field stays free text so an unanticipated pattern can still be
recorded, but anything outside this set aggregates under "other" in the UI.
"""

from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class ScamCategory:
    key: str
    label: str
    description: str
    # What a person should do first if they have already engaged. Surfaced by
    # the support-pathway endpoint so a verdict always comes with a next step.
    first_action: str


SCAM_CATEGORIES: tuple[ScamCategory, ...] = (
    ScamCategory(
        key="mobile_money_reversal",
        label="Wrong deposit / reversal",
        description=(
            "A fake or reversible deposit notice pressures you into sending real money "
            "'back' to a stranger. Works identically across EcoCash, M-PESA, MTN MoMo, "
            "Airtel Money and OPay."
        ),
        first_action=(
            "Do not send anything back. Check your real balance in the wallet app or "
            "official USSD menu, not from the SMS. Ask your provider to confirm whether "
            "any deposit actually landed."
        ),
    ),
    ScamCategory(
        key="fake_job",
        label="Fake job or recruitment",
        description=(
            "An unsolicited job offer that requires an upfront registration, processing "
            "or medical fee before work that does not exist."
        ),
        first_action=(
            "Legitimate employers do not charge to hire you. Verify the company through "
            "its own published contact details, never the number in the message."
        ),
    ),
    ScamCategory(
        key="fake_investment",
        label="Fake investment, forex or crypto",
        description=(
            "Guaranteed or doubled returns on forex, crypto or a 'trading platform', "
            "usually with a deadline and a small number of remaining slots."
        ),
        first_action=(
            "Guaranteed returns do not exist. Check whether the operator is licensed "
            "with your national financial regulator before sending anything."
        ),
    ),
    ScamCategory(
        key="fake_loan_aid",
        label="Fake loan, grant or relief aid",
        description=(
            "A loan, government grant or NGO relief payment that requires an activation, "
            "clearance or insurance fee to release funds."
        ),
        first_action=(
            "No genuine grant or relief programme asks you to pay to receive money. "
            "Confirm through the agency's official channel."
        ),
    ),
    ScamCategory(
        key="sim_swap",
        label="SIM swap or line suspension",
        description=(
            "A message claiming your line will be blocked, or that your SIM is being "
            "upgraded or re-registered — a pretext to take over the number that receives "
            "your wallet's one-time codes."
        ),
        first_action=(
            "If your line suddenly loses service, treat it as an emergency: contact your "
            "operator from another phone and freeze your wallet immediately."
        ),
    ),
    ScamCategory(
        key="otp_phishing",
        label="OTP, PIN or ID phishing",
        description=(
            "A request for a one-time code, wallet PIN, or national identity number "
            "(BVN, NIN, ID number), often framed as a security check."
        ),
        first_action=(
            "Never read a one-time code back to anyone. No provider, bank or agent ever "
            "needs your PIN or OTP. If you shared one, change your PIN and call your "
            "provider's fraud line now."
        ),
    ),
    ScamCategory(
        key="impersonation",
        label="Bank, telco or agent impersonation",
        description=(
            "Someone posing as your bank, mobile operator, wallet support desk or a "
            "known agent, usually to move you to a 'secure' number or link."
        ),
        first_action=(
            "Hang up and call the number printed on your card or the operator's official "
            "website. Never use a callback number supplied in the message."
        ),
    ),
    ScamCategory(
        key="faith_seed",
        label="Faith-based 'seed' or prophecy request",
        description=(
            "A prophecy, blessing or protection prayer conditioned on sending money to a "
            "personal wallet number."
        ),
        first_action=(
            "Verify through your congregation's known leadership and official accounts "
            "before sending anything to a personal number."
        ),
    ),
    ScamCategory(
        key="other",
        label="Other",
        description="A scam pattern that does not fit the categories above.",
        first_action=(
            "Stop engaging, keep the message as evidence, and report it through the "
            "official channels for your country."
        ),
    ),
)

CATEGORIES_BY_KEY: dict[str, ScamCategory] = {c.key: c for c in SCAM_CATEGORIES}
SCAM_CATEGORY_KEYS: tuple[str, ...] = tuple(c.key for c in SCAM_CATEGORIES)


def get_category(key: str) -> ScamCategory:
    """Look up a category, falling back to 'other' for free-text values."""
    return CATEGORIES_BY_KEY.get(key, CATEGORIES_BY_KEY["other"])
