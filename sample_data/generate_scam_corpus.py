"""Generate a synthetic, labeled corpus of Zimbabwean SMS/WhatsApp messages.

Produces sample_data/scam_corpus.jsonl: a balanced mix of scam and legitimate
messages modeled on publicly reported Zimbabwean scam patterns (EcoCash
reversal fraud, fake job offers, fake forex deals, "wrong transfer" scams,
fake NGO/loan offers, church/prophet scams) alongside legitimate bank/mobile
money notices and everyday family/business messages. Text mixes English and
Shona the way real local messages do.

This dataset is entirely synthetic (template + randomized slot filling) and
disclosed as such in docs/dataset_statement.md. It is not sourced from real
user messages or real phone numbers.

Usage:
    python generate_scam_corpus.py [--out scam_corpus.jsonl] [--seed 42]
"""

from __future__ import annotations

import argparse
import json
import random
from pathlib import Path

NAMES = [
    "Tendai", "Rutendo", "Farai", "Chipo", "Tapiwa", "Nyasha", "Blessing",
    "Tafadzwa", "Rumbidzai", "Kudzai", "Simba", "Vimbai", "Tinashe", "Ropafadzo",
    "Munashe", "Panashe", "Fadzai", "Anesu",
]

CHURCHES = ["Prophet Freedom", "Apostle Divine", "Prophetess Grace", "Major 1 Ministries", "Prophet T"]
COMPANIES = ["Delta Corporation", "Econet Wireless", "Steward Bank", "OK Zimbabwe", "TelOne", "Simbisa Brands"]
FOREX_HANDLES = ["Mai Rue Forex", "Bulls Forex Bureau", "QuickCash FX", "TrustFX Harare"]
TOWNS = ["Harare", "Bulawayo", "Mutare", "Gweru", "Masvingo", "Chitungwiza", "Kwekwe", "Kadoma"]


def rand_number() -> str:
    return f"07{random.randint(1,8)}{random.randint(1000000,9999999)}"


def rand_amount() -> str:
    return f"${random.choice([20, 30, 50, 80, 100, 150, 200, 300, 500])}"


def rand_ref() -> str:
    return "".join(random.choice("ABCDEFGHJKLMNPQRSTUVWXYZ0123456789") for _ in range(10))


# Each generator returns (template_list, category)
def ecocash_reversal_scam(name: str) -> str:
    templates = [
        "Confirmed. You have received {amt} from {n2}. Ref:{ref}. Kana yakanga isiri yako pindura kuti tidzorerwe (mistake transfer) tinokutumira number yekudzorera mari.",
        "EcoCash Alert: {amt} was sent to your wallet in error by {n2}. Please reverse to 07{d} immediately or your account will be suspended. Ref {ref}.",
        "Zvakanaka {name}, ndakukanganisa kutumira {amt} panhamba yenyu. Ndapota dzoserai pa 07{d}, ndinokutumirai zvekutenga chikafu mangwana.",
        "URGENT EcoCash: Wrong deposit of {amt} detected on your line. Dial *151*2*{d}# now to reverse or line will be blocked in 1 hour.",
    ]
    t = random.choice(templates)
    return t.format(name=name, amt=rand_amount(), n2=random.choice(NAMES), ref=rand_ref(), d=rand_number()[2:])


def fake_job_scam(name: str) -> str:
    templates = [
        "Congratulations {name}! You have been shortlisted for a $800/month remote data entry job with {co}. Pay $15 registration fee to secure your slot: EcoCash 07{d}.",
        "Vacancy alert: {co} is hiring general hands, no experience needed, $450/week. Send your CV and $10 processing fee to 07{d} to start Monday.",
        "Hie {name}, tine mabasa ekunze kwenyika (UK/Dubai) anobhadhara well. Tumira $25 application fee pa 07{d} kuti tikutumire application form.",
    ]
    t = random.choice(templates)
    return t.format(name=name, co=random.choice(COMPANIES), d=rand_number()[2:])


def fake_forex_scam(name: str) -> str:
    templates = [
        "{fx}: Best USD to ZWL rate today, 1:38! Send your USD to 07{d} EcoCash and we swap instantly, no fees for first 5 clients today {name}.",
        "Forex deal {name}: Double your USD in 24hrs, minimum $50. Trusted by 200+ Harare clients. WhatsApp 07{d} to start now, limited slots.",
        "{fx} bureau: We are buying USD cash at premium rate today only. Meet our agent in {town} or send via EcoCash 07{d} first for verification.",
    ]
    t = random.choice(templates)
    return t.format(name=name, fx=random.choice(FOREX_HANDLES), d=rand_number()[2:], town=random.choice(TOWNS))


def wrong_transfer_scam(name: str) -> str:
    templates = [
        "Ndine urombo {name}, ndakutumira mari pa nhamba dzenyu neaccident, {amt}. Ndapota dzoserai pa 07{d}, ndiri kuchema mari yekurapa mwana.",
        "Hi, I sent {amt} to your EcoCash number by mistake instead of my supplier. Please send it back to 07{d}, I really need it today, God bless you.",
        "Good day {name}, saw a wrong transfer of {amt} landed on your wallet from my business account. Kindly reverse to 07{d} before I report to bank.",
    ]
    t = random.choice(templates)
    return t.format(name=name, amt=rand_amount(), d=rand_number()[2:])


def fake_loan_ngo_scam(name: str) -> str:
    templates = [
        "{name}, you qualify for a ZWL loan of up to $2000 with 0% interest from Hope Foundation Zimbabwe. Send $12 activation fee to 07{d} to release funds today.",
        "NGO Relief Programme: You have been selected to receive $300 food relief aid. Confirm by sending $8 registration to 07{d} before slots close tonight.",
        "Munhu wangu {name}, tine chikwereti chekubatsira zvikoro (school fees loan), hapana interest. Tumira $10 pa 07{d} kuti tikuvhurirei account.",
    ]
    t = random.choice(templates)
    return t.format(name=name, d=rand_number()[2:])


def church_prophet_scam(name: str) -> str:
    templates = [
        "{name}, {prophet} akuona mweya wako uri kurwiswa. Tumira seed $20 pa 07{d} kuti tikunamatirei mangwana pamusangano mukuru.",
        "Word from {prophet}: A breakthrough is coming to you this week {name}, but you must sow a seed of $15 today to 07{d} to activate it.",
        "URGENT prophecy for {name}: {prophet} says danger is near your family. Send $25 anointing oil fee to 07{d} today for protection prayer.",
    ]
    t = random.choice(templates)
    return t.format(name=name, prophet=random.choice(CHURCHES), d=rand_number()[2:])


def legit_bank_notice(name: str) -> str:
    templates = [
        "Steward Bank: Your account ending 4821 was credited with {amt} on {date}. Available balance {bal}. For queries call 0242 xxx xxx.",
        "EcoCash: You have successfully sent {amt} to {n2} 07{d}. New balance {bal}. Ref {ref}. Thank you for using EcoCash.",
        "OneMoney: Your OTP is {otp}. Do not share this code with anyone, including OneMoney staff. It expires in 5 minutes.",
        "CABS Bank alert: A withdrawal of {amt} was made at {town} branch on {date}. If this was not you, call our fraud line immediately.",
    ]
    t = random.choice(templates)
    return t.format(
        amt=rand_amount(), date="12/07", bal=rand_amount(), n2=random.choice(NAMES),
        d=rand_number()[2:], ref=rand_ref(), otp=random.randint(100000, 999999), town=random.choice(TOWNS),
    )


def legit_family_business(name: str) -> str:
    templates = [
        "Hie {name}, ndaunza mari yezvikoro here? Tinofanira kubhadhara Friday. Ndapota tibate kana waona message iyi.",
        "{name}, meeting yedu yamangwana yashanduka kuita 10am, ku office. Please confirm unenge uripo.",
        "Thanks for the delivery today, invoice #{ref} has been settled in full. Receipt attached, regards {n2}.",
        "Zuva rakanaka {name}! Ndakuedza kukufonera, tinofanira kutaura nezve order yevhiki rino. Ndinokufonerazve manheru.",
        "Reminder: your Delta water bill for {town} account is due on the 25th. Pay via EcoCash Paynow to avoid disconnection.",
    ]
    t = random.choice(templates)
    return t.format(name=name, n2=random.choice(NAMES), ref=rand_ref(), town=random.choice(TOWNS))


SCAM_GENERATORS = [
    ("ecocash_reversal", ecocash_reversal_scam),
    ("fake_job", fake_job_scam),
    ("fake_forex", fake_forex_scam),
    ("wrong_transfer", wrong_transfer_scam),
    ("fake_loan_ngo", fake_loan_ngo_scam),
    ("church_prophet", church_prophet_scam),
]

LEGIT_GENERATORS = [
    ("bank_notice", legit_bank_notice),
    ("family_business", legit_family_business),
]


def build_corpus(n_per_scam_category: int, n_per_legit_category: int) -> list[dict]:
    rows = []
    for category, gen in SCAM_GENERATORS:
        for _ in range(n_per_scam_category):
            name = random.choice(NAMES)
            text = gen(name)
            rows.append({"text": text, "label": "scam", "category": category})
    for category, gen in LEGIT_GENERATORS:
        for _ in range(n_per_legit_category):
            name = random.choice(NAMES)
            text = gen(name)
            rows.append({"text": text, "label": "legit", "category": category})
    random.shuffle(rows)
    return rows


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", default=str(Path(__file__).parent / "scam_corpus.jsonl"))
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--per-scam-category", type=int, default=15)
    parser.add_argument("--per-legit-category", type=int, default=30)
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

    with open(args.out, "w", encoding="utf-8") as f:
        for row in unique_rows:
            f.write(json.dumps(row, ensure_ascii=False) + "\n")

    n_scam = sum(1 for r in unique_rows if r["label"] == "scam")
    n_legit = sum(1 for r in unique_rows if r["label"] == "legit")
    print(f"Wrote {len(unique_rows)} messages to {args.out} ({n_scam} scam, {n_legit} legit)")


if __name__ == "__main__":
    main()
