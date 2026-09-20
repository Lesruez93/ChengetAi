"""Generate a synthetic, labeled corpus of African mobile-money SMS/WhatsApp messages.

Produces sample_data/scam_corpus.jsonl: a balanced mix of scam and legitimate
messages modeled on publicly reported scam patterns across the seven markets in
`backend/app/services/countries.py` — wrong-deposit reversal fraud, fake job
offers, fake investment deals, fake loans and grants, SIM swap, OTP/identity
phishing, institutional impersonation and faith-based "seed" requests —
alongside legitimate wallet and bank notices and everyday family/business texts.

All messages are in **English**. The product classifies English only, so a corpus
containing Shona or Swahili would train the model on text no other part of the
system is equipped to handle. docs/accessibility.md records the coverage gap this
leaves.

WHY THE CORPUS IS MULTI-COUNTRY
-------------------------------
A corpus drawn from one market teaches the model that the local wallet's *name*
is the scam signal. That is precisely the overfit that makes generic spam
filters useless here, and it would reappear one country over: a model trained
only on "EcoCash" messages reads a Kenyan M-PESA scam as unremarkable. Mixing
markets forces the learned weight onto the mechanism — the reversal request,
the upfront fee, the shared code — which is the part that actually transfers.
Per-market variation now comes from wallets, banks, employers, names, towns and
currency rather than from language.

Each generator therefore draws its wallet, currency, names and institutions
from a country profile rather than hardcoding them, and every scam pattern is
emitted for every market.

This dataset is entirely synthetic (template + randomized slot filling) and
disclosed as such in docs/dataset_statement.md. It is not sourced from real
user messages, and every phone number in it is generated, not observed.

Usage:
    python generate_scam_corpus.py [--out scam_corpus.jsonl] [--seed 42]
"""

from __future__ import annotations

import argparse
import json
import random
from dataclasses import dataclass, field
from pathlib import Path


@dataclass(frozen=True)
class Market:
    """Locale slots the templates draw from. Mirrors the country registry in
    backend/app/services/countries.py, kept standalone so the generator runs
    without importing the backend package."""

    code: str
    wallets: tuple[str, ...]
    banks: tuple[str, ...]
    employers: tuple[str, ...]
    names: tuple[str, ...]
    towns: tuple[str, ...]
    currency: str
    amounts: tuple[int, ...]
    trunk_prefixes: tuple[str, ...]
    nsn_length: int
    # Locale-specific extra used by only some templates: what the market calls
    # the identity number a phishing message asks for.
    id_term: str = "ID number"
    # Market-flavoured English phrasings used in reversal templates, so the
    # register varies between markets even though the language does not.
    local_lines: tuple[str, ...] = field(default=())


MARKETS: tuple[Market, ...] = (
    Market(
        code="ZW",
        wallets=("EcoCash", "OneMoney", "InnBucks"),
        banks=("Steward Bank", "CABS", "CBZ Bank"),
        employers=("Delta Corporation", "Econet Wireless", "OK Zimbabwe", "Simbisa Brands"),
        names=("Tendai", "Rutendo", "Farai", "Chipo", "Tapiwa", "Nyasha", "Tafadzwa", "Kudzai"),
        towns=("Harare", "Bulawayo", "Mutare", "Gweru", "Masvingo", "Chitungwiza"),
        currency="$",
        amounts=(20, 50, 80, 100, 200, 500),
        trunk_prefixes=("71", "73", "77", "78"),
        nsn_length=9,
        local_lines=(
            "Please send my money back, I entered the wrong number.",
            "Send it to this number so we can sort it out today.",
            "If it was not meant for you, reply so we can be refunded.",
        ),
    ),
    Market(
        code="KE",
        wallets=("M-PESA", "Airtel Money", "T-Kash"),
        banks=("Equity Bank", "KCB", "Co-operative Bank"),
        employers=("Safaricom", "Kenya Airways", "Naivas", "Jumia Kenya"),
        names=("Wanjiku", "Otieno", "Kamau", "Achieng", "Mutiso", "Njeri", "Kiprop", "Auma"),
        towns=("Nairobi", "Mombasa", "Kisumu", "Nakuru", "Eldoret", "Thika"),
        currency="KSh",
        amounts=(500, 1500, 3000, 5000, 10000, 25000),
        trunk_prefixes=("70", "71", "72", "74", "79"),
        nsn_length=9,
        local_lines=(
            "I have sent you money by mistake, please send it back.",
            "Send the money to this number quickly, before two o'clock.",
            "This is the last offer, do not miss this chance.",
        ),
    ),
    Market(
        code="NG",
        wallets=("OPay", "PalmPay", "Moniepoint", "MTN MoMo"),
        banks=("First Bank", "GTBank", "Access Bank", "Zenith Bank"),
        employers=("Dangote Group", "MTN Nigeria", "Shoprite Nigeria", "Jumia"),
        names=("Chinedu", "Aisha", "Emeka", "Ngozi", "Tunde", "Fatima", "Bola", "Ifeanyi"),
        towns=("Lagos", "Abuja", "Port Harcourt", "Kano", "Ibadan", "Enugu"),
        currency="₦",
        amounts=(5000, 15000, 50000, 120000, 250000, 500000),
        trunk_prefixes=("70", "80", "81", "90", "91"),
        nsn_length=10,
        id_term="BVN",
        local_lines=(
            "Please send it back, I sent the money by mistake.",
            "Do not waste time, the offer closes today.",
            "Your account will be restricted if you do not update now.",
        ),
    ),
    Market(
        code="UG",
        wallets=("MTN MoMo", "Airtel Money"),
        banks=("Stanbic Bank", "Centenary Bank", "DFCU Bank"),
        employers=("MTN Uganda", "Nile Breweries", "Uganda Airlines", "Cafe Javas"),
        names=("Nakato", "Okello", "Namukasa", "Wasswa", "Achan", "Mugisha", "Nabirye", "Opio"),
        towns=("Kampala", "Gulu", "Mbarara", "Jinja", "Mbale", "Entebbe"),
        currency="UGX",
        amounts=(20000, 50000, 150000, 400000, 900000),
        trunk_prefixes=("70", "75", "77", "78"),
        nsn_length=9,
        local_lines=(
            "Sorry, I sent you money by mistake, please return it.",
            "Send the money to this number now.",
        ),
    ),
    Market(
        code="ZA",
        wallets=("Capitec Pay", "FNB eWallet", "Standard Bank Instant Money", "ShopriteMoney"),
        banks=("Capitec", "FNB", "Absa", "Nedbank"),
        employers=("Shoprite", "MTN South Africa", "Discovery", "Takealot"),
        names=("Thabo", "Lerato", "Sipho", "Nomsa", "Bongani", "Zanele", "Katlego", "Andile"),
        towns=("Johannesburg", "Cape Town", "Durban", "Pretoria", "Gqeberha", "Bloemfontein"),
        currency="R",
        amounts=(200, 500, 1500, 3000, 8000, 20000),
        trunk_prefixes=("60", "71", "82", "83"),
        nsn_length=9,
        local_lines=(
            "Please reverse the money, I sent it to the wrong number.",
            "Your grant application has been approved, pay the release fee.",
        ),
    ),
    Market(
        code="GH",
        wallets=("MTN MoMo", "Telecel Cash", "AirtelTigo Money"),
        banks=("GCB Bank", "Ecobank Ghana", "Fidelity Bank"),
        employers=("MTN Ghana", "Melcom", "Ghana Airports Company", "Jumia Ghana"),
        names=("Kwame", "Akosua", "Kofi", "Ama", "Yaw", "Abena", "Kojo", "Efua"),
        towns=("Accra", "Kumasi", "Takoradi", "Tamale", "Cape Coast", "Tema"),
        currency="GH₵",
        amounts=(50, 150, 400, 900, 2500, 6000),
        trunk_prefixes=("24", "20", "54", "55"),
        nsn_length=9,
        local_lines=(
            "Please I sent the MoMo to your number by mistake, kindly reverse.",
            "This offer is closing today, send the fee now.",
        ),
    ),
    Market(
        code="TZ",
        wallets=("M-Pesa", "Mixx by Yas", "Airtel Money", "HaloPesa"),
        banks=("CRDB Bank", "NMB Bank", "NBC"),
        employers=("Vodacom Tanzania", "Azam", "Air Tanzania", "Tanga Cement"),
        names=("Neema", "Juma", "Zainabu", "Baraka", "Rehema", "Hamisi", "Upendo", "Salum"),
        towns=("Dar es Salaam", "Arusha", "Mwanza", "Dodoma", "Mbeya", "Zanzibar"),
        currency="TSh",
        amounts=(10000, 30000, 80000, 200000, 500000),
        trunk_prefixes=("65", "71", "74", "76"),
        nsn_length=9,
        local_lines=(
            "Sorry, I sent the money in error, please send it back to me.",
            "Send the registration fee to secure this job.",
        ),
    ),
)


def rand_number(m: Market) -> str:
    prefix = random.choice(m.trunk_prefixes)
    rest = "".join(str(random.randint(0, 9)) for _ in range(m.nsn_length - len(prefix)))
    return f"0{prefix}{rest}"


def rand_amount(m: Market) -> str:
    return f"{m.currency}{random.choice(m.amounts):,}"


def rand_ref() -> str:
    return "".join(random.choice("ABCDEFGHJKLMNPQRSTUVWXYZ0123456789") for _ in range(10))


def _slots(m: Market) -> dict:
    return {
        "wallet": random.choice(m.wallets),
        "bank": random.choice(m.banks),
        "employer": random.choice(m.employers),
        "name": random.choice(m.names),
        "other": random.choice(m.names),
        "town": random.choice(m.towns),
        "amt": rand_amount(m),
        "bal": rand_amount(m),
        "num": rand_number(m),
        "ref": rand_ref(),
        "otp": random.randint(100000, 999999),
        "id_term": m.id_term,
        "local": random.choice(m.local_lines) if m.local_lines else "",
    }


# ---------------------------------------------------------------------------
# Scam generators. Each returns one message for the given market.
# ---------------------------------------------------------------------------

def mobile_money_reversal(m: Market) -> str:
    return random.choice([
        "{wallet}: Confirmed. You have received {amt} from {other}. Ref:{ref}. {local}",
        "{wallet} Alert: {amt} was sent to your wallet in error by {other}. Please reverse to "
        "{num} immediately or your account will be suspended. Ref {ref}.",
        "Hi, I sent {amt} to your {wallet} by mistake instead of my supplier. Please send it "
        "back to {num}, I really need it today, God bless you.",
        "URGENT {wallet}: Wrong deposit of {amt} detected on your line. Reverse to {num} now "
        "or the line will be blocked within 1 hour.",
    ]).format(**_slots(m))


def fake_job(m: Market) -> str:
    return random.choice([
        "Congratulations {name}! You have been shortlisted for a remote data entry job with "
        "{employer}. Pay {amt} registration fee to secure your slot: {wallet} {num}.",
        "Vacancy alert: {employer} is hiring general hands in {town}, no experience needed. "
        "Send your CV and {amt} processing fee to {num} to start Monday.",
        "{name}, your interview with {employer} is confirmed. A refundable {amt} medical "
        "clearance fee is payable to {num} before Friday.",
    ]).format(**_slots(m))


def fake_investment(m: Market) -> str:
    return random.choice([
        "Double your capital in 24hrs with our forex desk, minimum {amt}. Trusted by 200+ "
        "clients in {town}. WhatsApp {num} to start now, limited slots.",
        "{name}, our crypto trading platform pays guaranteed returns weekly. Deposit {amt} "
        "via {wallet} to {num} and withdraw anytime. Last chance today.",
        "Investment opportunity: we are buying USD at a premium rate today only. Send via "
        "{wallet} {num} first for verification, cash collected in {town}.",
    ]).format(**_slots(m))


def fake_loan_aid(m: Market) -> str:
    return random.choice([
        "{name}, you qualify for a loan of up to {amt} at 0% interest. Send a {amt} activation "
        "fee to {num} to release the funds today.",
        "Relief Programme: You have been selected to receive {amt} in food relief aid. Confirm "
        "by sending a {amt} registration fee to {num} before slots close tonight.",
        "Your grant application has been approved for {amt}. A clearance fee is payable to "
        "{wallet} {num} before disbursement. Reference {ref}.",
    ]).format(**_slots(m))


def sim_swap(m: Market) -> str:
    return random.choice([
        "NOTICE: Your SIM will be deactivated in 24 hours for failing re-registration. Reply "
        "with your {id_term} and full names to {num} to keep your line active.",
        "{name}, a SIM swap request was received for your line. If this was not you, call "
        "{num} immediately to cancel and confirm your {id_term}.",
        "Your line has been flagged for suspension under the new registration rules. Send your "
        "{id_term} and date of birth to {num} to re-register now.",
    ]).format(**_slots(m))


def otp_phishing(m: Market) -> str:
    return random.choice([
        "{bank} ALERT: Your {id_term} is due for revalidation. Failure to update within 24hrs "
        "will restrict your account. Reply with your {id_term} and PIN to verify your account.",
        "{wallet} security check: we detected a suspicious login. Read back the one-time code "
        "we just sent to confirm your account, or it will be locked.",
        "{bank}: To reverse the unauthorised debit of {amt} on your account, confirm your card "
        "number and the OTP sent to your phone. Ref {ref}.",
    ]).format(**_slots(m))


def impersonation(m: Market) -> str:
    return random.choice([
        "This is {wallet} support. We are investigating fraud on your wallet. Call {num} now "
        "and do not discuss this with anyone, including your bank.",
        "{bank} Fraud Desk: unusual activity detected on your account. Our agent will call you "
        "from {num} shortly — please answer and confirm your details.",
        "Hello {name}, this is your {wallet} agent. My till is down, please send the {amt} to "
        "my personal number {num} instead and I will process it.",
    ]).format(**_slots(m))


def faith_seed(m: Market) -> str:
    return random.choice([
        "{name}, the Man of God saw your breakthrough this week, but you must sow a seed of "
        "{amt} today to {num} to activate it.",
        "URGENT prophecy for {name}: danger is near your family. Send {amt} anointing oil fee "
        "to {num} today for the protection prayer.",
        "A word came for you {name}. Sow your seed of {amt} via {wallet} to {num} before the "
        "midnight service and expect your miracle.",
    ]).format(**_slots(m))


# ---------------------------------------------------------------------------
# Legitimate generators — the false-positive guardrail.
# ---------------------------------------------------------------------------

def legit_wallet_notice(m: Market) -> str:
    return random.choice([
        "{wallet}: You have successfully sent {amt} to {other} {num}. New balance {bal}. "
        "Ref {ref}. Thank you for using {wallet}.",
        "{wallet}: Your one time password is {otp}. Do not share this code with anyone, "
        "including {wallet} staff. It expires in 5 minutes.",
        "{wallet}: You have received {amt} from {other}. New balance {bal}. Ref {ref}.",
        "{wallet}: Airtime purchase of {amt} was successful. New balance {bal}. Ref {ref}.",
    ]).format(**_slots(m))


def legit_bank_notice(m: Market) -> str:
    return random.choice([
        "{bank}: Your account ending 4821 was credited with {amt} on 12/07. Available balance "
        "{bal}. For queries call the number on your card.",
        "{bank} alert: A withdrawal of {amt} was made at the {town} branch on 12/07. If this "
        "was not you, call our fraud line immediately.",
        "{bank}: Your statement for July is ready in the mobile app. No action is required.",
        "{bank}: Your loan repayment of {amt} has been received. Outstanding balance {bal}. "
        "Thank you.",
    ]).format(**_slots(m))


def legit_family_business(m: Market) -> str:
    return random.choice([
        "Hi {name}, did you manage to get the school fees money? We need to pay on Friday. "
        "Please call me when you see this.",
        "{name}, tomorrow's meeting has moved to 10am at the {town} office. Please confirm "
        "you will be there.",
        "Thanks for the delivery today, invoice #{ref} has been settled in full. Receipt "
        "attached, regards {other}.",
        "Good morning {name}! I tried calling you, we need to talk about this week's order. "
        "I will call again this evening.",
        "Reminder: your water bill for the {town} account is due on the 25th. Pay via {wallet} "
        "to avoid disconnection.",
        "{name}, I have arrived safely in {town}. Will send you the photos later tonight.",
    ]).format(**_slots(m))


SCAM_GENERATORS = (
    ("mobile_money_reversal", mobile_money_reversal),
    ("fake_job", fake_job),
    ("fake_investment", fake_investment),
    ("fake_loan_aid", fake_loan_aid),
    ("sim_swap", sim_swap),
    ("otp_phishing", otp_phishing),
    ("impersonation", impersonation),
    ("faith_seed", faith_seed),
)

LEGIT_GENERATORS = (
    ("wallet_notice", legit_wallet_notice),
    ("bank_notice", legit_bank_notice),
    ("family_business", legit_family_business),
)


def build_corpus(n_per_scam: int, n_per_legit: int) -> list[dict]:
    """Emit every pattern for every market, so no single country dominates."""
    rows = []
    for market in MARKETS:
        for category, gen in SCAM_GENERATORS:
            for _ in range(n_per_scam):
                rows.append({"text": gen(market), "label": "scam",
                             "category": category, "country": market.code})
        for category, gen in LEGIT_GENERATORS:
            for _ in range(n_per_legit):
                rows.append({"text": gen(market), "label": "legit",
                             "category": category, "country": market.code})
    random.shuffle(rows)
    return rows


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", default=str(Path(__file__).parent / "scam_corpus.jsonl"))
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--per-scam-category", type=int, default=6,
                        help="Per scam category, per market (8 categories x 7 markets).")
    parser.add_argument("--per-legit-category", type=int, default=16,
                        help="Per legit category, per market (3 categories x 7 markets).")
    args = parser.parse_args()

    random.seed(args.seed)
    rows = build_corpus(args.per_scam_category, args.per_legit_category)

    # de-duplicate while preserving order
    seen: set[str] = set()
    unique_rows = []
    for row in rows:
        if row["text"] not in seen:
            seen.add(row["text"])
            unique_rows.append(row)

    contents = "".join(json.dumps(row, ensure_ascii=False) + "\n" for row in unique_rows)
    with open(args.out, "w", encoding="utf-8") as f:
        f.write(contents)

    # Also vendored inside backend/app/data/ so the classifier's copy ships in
    # the Docker image (the production build context is backend/, which does
    # not include this sample_data/ directory) — see backend/app/services/classifier.py.
    vendored_path = Path(__file__).parent.parent / "backend" / "app" / "data" / "scam_corpus.jsonl"
    if vendored_path.parent.is_dir():
        vendored_path.write_text(contents, encoding="utf-8")

    n_scam = sum(1 for r in unique_rows if r["label"] == "scam")
    n_legit = sum(1 for r in unique_rows if r["label"] == "legit")
    by_country = {}
    for r in unique_rows:
        by_country[r["country"]] = by_country.get(r["country"], 0) + 1
    print(f"Wrote {len(unique_rows)} messages to {args.out} ({n_scam} scam, {n_legit} legit)")
    if vendored_path.parent.is_dir():
        print(f"Also updated vendored copy at {vendored_path}")
    print("By market: " + ", ".join(f"{k}={v}" for k, v in sorted(by_country.items())))


if __name__ == "__main__":
    main()
