"""Country registry: the single source of truth for everything locale-specific.

ChengetAI operates across several African mobile-money markets, and almost
every "local" detail the product touches differs between them: the dial code
and national number format, which wallets people actually use, what the
first-level administrative unit is called, and which languages scam messages
are written in.

Rather than scattering those differences through the classifier, the
reputation service, the feed and the UI, they live here as one immutable
registry. Adding a country is a data change in this file plus a support-channel
entry in `app/services/support.py` — no service logic changes.

Region lists are deliberately *coarse* (4-16 buckets per country) rather than
exhaustive administrative lists. The hotspot map exists to tell a user
"is this scam wave near me?", and a 47-county or 36-state map answers that
worse than a regional one does, because each bucket ends up with too few
reports to be meaningful. Where a country's official first-level unit is
already coarse (Zimbabwe's 10 provinces, South Africa's 9) we use it directly;
where it isn't, we use the standard grouping people actually speak in
(Nigeria's 6 geopolitical zones, Kenya's 8 historical regions, Tanzania's
zones).
"""

from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class Country:
    """Everything the product needs to behave correctly in one market."""

    code: str                       # ISO 3166-1 alpha-2, e.g. "KE"
    name: str
    dial_code: str                  # country calling code without "+", e.g. "254"
    trunk_prefix: str               # digit(s) dropped when converting local -> E.164
    nsn_length: int                 # digits in the national significant number
    mobile_prefixes: tuple[str, ...]  # leading digits of an NSN that denote a mobile line
    region_label: str               # what the first-level unit is called locally
    regions: tuple[str, ...]
    providers: tuple[str, ...]      # mobile-money wallets in everyday use
    languages: tuple[str, ...]      # languages scam messages plausibly arrive in
    currency_code: str
    currency_symbol: str

    @property
    def example_msisdn(self) -> str:
        """A syntactically valid local-format number, for placeholder text."""
        prefix = self.mobile_prefixes[0]
        return f"{self.trunk_prefix}{prefix}{'1234567890'[: self.nsn_length - len(prefix)]}"


COUNTRIES: dict[str, Country] = {
    "ZW": Country(
        code="ZW",
        name="Zimbabwe",
        dial_code="263",
        trunk_prefix="0",
        nsn_length=9,
        mobile_prefixes=("71", "73", "77", "78"),
        region_label="Province",
        regions=(
            "Harare", "Bulawayo", "Manicaland", "Mashonaland Central",
            "Mashonaland East", "Mashonaland West", "Masvingo",
            "Matabeleland North", "Matabeleland South", "Midlands",
        ),
        providers=("EcoCash", "OneMoney", "InnBucks"),
        languages=("English", "Shona", "Ndebele"),
        currency_code="USD",
        currency_symbol="$",
    ),
    "KE": Country(
        code="KE",
        name="Kenya",
        dial_code="254",
        trunk_prefix="0",
        nsn_length=9,
        mobile_prefixes=("7", "1"),
        region_label="Region",
        regions=(
            "Nairobi", "Central", "Coast", "Eastern",
            "North Eastern", "Nyanza", "Rift Valley", "Western",
        ),
        providers=("M-PESA", "Airtel Money", "T-Kash"),
        languages=("English", "Swahili", "Sheng"),
        currency_code="KES",
        currency_symbol="KSh",
    ),
    "NG": Country(
        code="NG",
        name="Nigeria",
        dial_code="234",
        trunk_prefix="0",
        nsn_length=10,
        mobile_prefixes=("70", "71", "80", "81", "90", "91"),
        region_label="Zone",
        regions=(
            "Lagos", "FCT Abuja", "South West", "South East",
            "South South", "North Central", "North East", "North West",
        ),
        providers=("OPay", "PalmPay", "Moniepoint", "Paga", "MTN MoMo", "Kuda"),
        languages=("English", "Nigerian Pidgin", "Hausa", "Yoruba", "Igbo"),
        currency_code="NGN",
        currency_symbol="₦",
    ),
    "UG": Country(
        code="UG",
        name="Uganda",
        dial_code="256",
        trunk_prefix="0",
        nsn_length=9,
        mobile_prefixes=("70", "71", "72", "74", "75", "76", "77", "78", "79"),
        region_label="Region",
        regions=("Central", "Eastern", "Northern", "Western"),
        providers=("MTN MoMo", "Airtel Money"),
        languages=("English", "Luganda", "Swahili"),
        currency_code="UGX",
        currency_symbol="UGX",
    ),
    "ZA": Country(
        code="ZA",
        name="South Africa",
        dial_code="27",
        trunk_prefix="0",
        nsn_length=9,
        mobile_prefixes=("6", "7", "8"),
        region_label="Province",
        regions=(
            "Gauteng", "Western Cape", "KwaZulu-Natal", "Eastern Cape",
            "Free State", "Limpopo", "Mpumalanga", "North West", "Northern Cape",
        ),
        providers=("Capitec Pay", "FNB eWallet", "Standard Bank Instant Money",
                   "ShopriteMoney", "MTN MoMo"),
        languages=("English", "isiZulu", "isiXhosa", "Afrikaans", "Sesotho"),
        currency_code="ZAR",
        currency_symbol="R",
    ),
    "GH": Country(
        code="GH",
        name="Ghana",
        dial_code="233",
        trunk_prefix="0",
        nsn_length=9,
        mobile_prefixes=("2", "5"),
        region_label="Region",
        regions=(
            "Greater Accra", "Ashanti", "Central", "Eastern", "Western",
            "Volta", "Northern", "Bono", "Upper East", "Upper West",
        ),
        providers=("MTN MoMo", "Telecel Cash", "AirtelTigo Money"),
        languages=("English", "Twi", "Ga", "Ewe", "Hausa"),
        currency_code="GHS",
        currency_symbol="GH₵",
    ),
    "TZ": Country(
        code="TZ",
        name="Tanzania",
        dial_code="255",
        trunk_prefix="0",
        nsn_length=9,
        mobile_prefixes=("6", "7"),
        region_label="Zone",
        regions=(
            "Dar es Salaam", "Coastal", "Northern", "Lake",
            "Central", "Southern Highlands", "Western", "Zanzibar",
        ),
        providers=("M-Pesa", "Mixx by Yas", "Airtel Money", "HaloPesa"),
        languages=("Swahili", "English"),
        currency_code="TZS",
        currency_symbol="TSh",
    ),
}

SUPPORTED_COUNTRY_CODES: tuple[str, ...] = tuple(COUNTRIES)

# Longest dial codes first, so "263" is tried before "27" when matching a
# raw E.164 string — otherwise a Zimbabwean number would parse as South African.
_DIAL_CODES_BY_LENGTH: list[tuple[str, str]] = sorted(
    ((c.dial_code, c.code) for c in COUNTRIES.values()),
    key=lambda pair: len(pair[0]),
    reverse=True,
)


class UnknownCountryError(ValueError):
    """Raised when a country code is not in the registry."""


def get_country(code: str) -> Country:
    country = COUNTRIES.get((code or "").strip().upper())
    if country is None:
        raise UnknownCountryError(
            f"'{code}' is not a supported country. Supported: {', '.join(SUPPORTED_COUNTRY_CODES)}."
        )
    return country


def country_for_dial_code(digits: str) -> Country | None:
    """Match a digits-only E.164 string (no '+') to its country, longest code first."""
    for dial_code, iso in _DIAL_CODES_BY_LENGTH:
        if digits.startswith(dial_code):
            return COUNTRIES[iso]
    return None


def all_countries() -> list[Country]:
    return [COUNTRIES[code] for code in SUPPORTED_COUNTRY_CODES]


def regions_for(code: str) -> tuple[str, ...]:
    return get_country(code).regions


def is_valid_region(code: str, region: str) -> bool:
    return region in get_country(code).regions
