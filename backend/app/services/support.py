"""Support pathways: what a person should actually do after a scam verdict.

A detection tool that only says "this is a scam" leaves the user exactly where
it found them. The Safety, Reporting & Protection problem is a *pathway*
problem: someone who has just lost money, or is about to, needs to know which
door to knock on, in what order, and how fast — and that door is different in
Lagos than in Nairobi.

This module holds the per-country escalation ladder, ordered by urgency:

1. `wallet`    - the mobile-money provider, who can freeze or trace a transfer
                 while it is still recoverable. Almost always the first call.
2. `regulator` - the telecoms or financial-services regulator, who acts on the
                 *number* and on patterns across many complaints.
3. `police`    - law enforcement, for the criminal case and for anything
                 involving threats, coercion or physical risk.
4. `support`   - non-enforcement help: consumer protection, legal aid, GBV and
                 counselling lines for cases where the fraud is entangled with
                 abuse or coercion.

DATA INTEGRITY NOTE
-------------------
Every entry carries a `verified` flag. `True` means the contact is a
long-standing, widely published national short code. `False` means the
*organisation* is correct but the specific contact string has not been
confirmed against the operator's own published channel, so the UI shows it as
"confirm this number with your provider" rather than presenting it as fact.
Shipping an unverified emergency number as though it were verified is its own
safety failure, so the distinction is carried all the way to the client rather
than being flattened here. Confirming every `False` entry with the relevant
operator is a required pre-pilot task, tracked in docs/deployment_plan.md.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Literal

from app.services.countries import get_country
from app.services.taxonomy import get_category

ChannelKind = Literal["wallet", "regulator", "police", "support"]


@dataclass(frozen=True)
class SupportChannel:
    kind: ChannelKind
    organisation: str
    what_it_does: str
    contact: str | None
    url: str | None
    verified: bool


# Steps that hold regardless of country or category. Ordered by how quickly
# they stop losing money, not by how obvious they are.
UNIVERSAL_FIRST_STEPS: tuple[str, ...] = (
    "Stop replying. Every further message gives the sender more to work with.",
    "Do not send money, airtime, or a one-time code, however urgent the message sounds.",
    "Screenshot the message and note the number before you block it — that is your evidence.",
    "If you already sent money, contact your wallet provider immediately. Speed is the "
    "single biggest factor in whether a transfer can be reversed.",
)

SUPPORT_CHANNELS: dict[str, tuple[SupportChannel, ...]] = {
    "ZW": (
        SupportChannel("wallet", "EcoCash / OneMoney fraud desk",
                       "Freeze your wallet and request a trace on a transfer you have just sent.",
                       None, None, False),
        SupportChannel("regulator", "POTRAZ (Postal and Telecommunications Regulatory Authority of Zimbabwe)",
                       "Acts on complaints about numbers used for fraud and on operator conduct.",
                       None, "https://www.potraz.gov.zw", False),
        SupportChannel("regulator", "Reserve Bank of Zimbabwe",
                       "Handles complaints against licensed financial and mobile-money institutions.",
                       None, "https://www.rbz.co.zw", False),
        SupportChannel("police", "Zimbabwe Republic Police",
                       "Opens a criminal case. Go with your screenshots and transaction references.",
                       "995", None, True),
    ),
    "KE": (
        SupportChannel("wallet", "M-PESA / Airtel Money customer care",
                       "Can reverse a transfer that has not yet been withdrawn, and block the recipient.",
                       None, None, False),
        SupportChannel("regulator", "Communications Authority of Kenya",
                       "Regulates operators and acts on SIM and number misuse.",
                       None, "https://www.ca.go.ke", False),
        SupportChannel("regulator", "Central Bank of Kenya",
                       "Handles complaints against licensed payment and banking institutions.",
                       None, "https://www.centralbank.go.ke", False),
        SupportChannel("police", "Directorate of Criminal Investigations (DCI)",
                       "Runs the cybercrime investigation unit for fraud cases.",
                       None, "https://www.dci.go.ke", False),
        SupportChannel("police", "Police emergency",
                       "For any threat to your safety, not only financial loss.",
                       "999", None, True),
    ),
    "NG": (
        SupportChannel("wallet", "OPay / PalmPay / Moniepoint / MTN MoMo support",
                       "Can place a lien on a receiving account if you report fast enough.",
                       None, None, False),
        SupportChannel("regulator", "Nigerian Communications Commission (NCC)",
                       "Consumer complaints about telecoms services and numbers used for fraud.",
                       "622", "https://www.ncc.gov.ng", True),
        SupportChannel("regulator", "Central Bank of Nigeria",
                       "Handles complaints against licensed banks and payment service providers.",
                       None, "https://www.cbn.gov.ng", False),
        SupportChannel("police", "Economic and Financial Crimes Commission (EFCC)",
                       "Investigates financial fraud, including mobile-money and online scams.",
                       None, "https://www.efcc.gov.ng", False),
        SupportChannel("police", "Police emergency",
                       "For any threat to your safety, not only financial loss.",
                       "112", None, True),
    ),
    "UG": (
        SupportChannel("wallet", "MTN MoMo / Airtel Money fraud desk",
                       "Freeze your wallet and request a trace on a recent transfer.",
                       None, None, False),
        SupportChannel("regulator", "Uganda Communications Commission (UCC)",
                       "Acts on numbers used for fraud and on operator conduct.",
                       None, "https://www.ucc.co.ug", False),
        SupportChannel("regulator", "Bank of Uganda",
                       "Handles complaints against licensed payment service providers.",
                       None, "https://www.bou.or.ug", False),
        SupportChannel("police", "Uganda Police Force",
                       "Opens a criminal case through the cybercrime unit.",
                       "999", None, True),
    ),
    "ZA": (
        SupportChannel("wallet", "Your bank or wallet fraud line",
                       "Can stop an eWallet or Instant Money voucher before it is cashed out.",
                       None, None, False),
        SupportChannel("regulator", "SABRIC (South African Banking Risk Information Centre)",
                       "Coordinates bank-sector fraud intelligence and public scam warnings.",
                       None, "https://www.sabric.co.za", False),
        SupportChannel("regulator", "ICASA",
                       "Regulates operators and handles complaints about numbers used for fraud.",
                       None, "https://www.icasa.org.za", False),
        SupportChannel("police", "SAPS emergency",
                       "For a criminal case, and for any threat to your safety.",
                       "10111", None, True),
        SupportChannel("support", "National Consumer Commission",
                       "Consumer redress where a supplier or service is involved.",
                       None, "https://www.thencc.org.za", False),
    ),
    "GH": (
        SupportChannel("wallet", "MTN MoMo / Telecel Cash / AirtelTigo Money support",
                       "Can hold a receiving wallet while a transfer is still recoverable.",
                       None, None, False),
        SupportChannel("regulator", "Cyber Security Authority incident reporting point",
                       "Ghana's national 24/7 point of contact for reporting cybercrime and online fraud.",
                       "292", "https://www.csa.gov.gh", True),
        SupportChannel("regulator", "National Communications Authority (NCA)",
                       "Acts on SIM registration abuse and numbers used for fraud.",
                       None, "https://nca.org.gh", False),
        SupportChannel("police", "Ghana Police Service",
                       "Opens a criminal case through the cybercrime unit.",
                       "191", None, True),
    ),
    "TZ": (
        SupportChannel("wallet", "M-Pesa / Mixx by Yas / Airtel Money support",
                       "Freeze your wallet and request a trace on a recent transfer.",
                       None, None, False),
        SupportChannel("regulator", "Tanzania Communications Regulatory Authority (TCRA)",
                       "Acts on numbers used for fraud and on operator conduct.",
                       None, "https://www.tcra.go.tz", False),
        SupportChannel("regulator", "Bank of Tanzania",
                       "Handles complaints against licensed payment service providers.",
                       None, "https://www.bot.go.tz", False),
        SupportChannel("police", "Tanzania Police Force",
                       "Opens a criminal case through the cybercrime unit.",
                       "112", None, True),
    ),
}

DATA_NOTE = (
    "Organisation names and websites are compiled from public sources. Entries marked "
    "unverified have not been confirmed against the operator's own published channel — "
    "confirm the contact before relying on it, and prefer the number printed on your "
    "card, SIM pack or the organisation's official website."
)


def build_support_pathway(country_code: str, category: str | None = None) -> dict:
    """The ordered 'what do I do now' ladder for one country, optionally
    tailored with the category-specific first action."""
    country = get_country(country_code)
    channels = SUPPORT_CHANNELS.get(country.code, ())

    steps = list(UNIVERSAL_FIRST_STEPS)
    category_action = None
    if category:
        category_action = get_category(category).first_action
        steps.insert(0, category_action)

    return {
        "country": country.code,
        "country_name": country.name,
        "category": category,
        "immediate_steps": steps,
        "category_first_action": category_action,
        "channels": [
            {
                "kind": ch.kind,
                "organisation": ch.organisation,
                "what_it_does": ch.what_it_does,
                "contact": ch.contact,
                "url": ch.url,
                "verified": ch.verified,
            }
            for ch in channels
        ],
        "data_note": DATA_NOTE,
    }
