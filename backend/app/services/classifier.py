"""Message classification: two pluggable strategies behind one interface.

- `BaselineClassifier`: TF-IDF + logistic regression trained on
  sample_data/scam_corpus.jsonl. Cheap, offline, fully explainable via learned
  feature weights — but only as good as its (synthetic, small) training corpus
  and blind to scam patterns it has never seen.
- `LLMClassifier`: Anthropic API with a few-shot prompt grounded in the
  caller's market. Handles novel phrasing, code-switching between English and
  Shona / Swahili / Pidgin / isiZulu, and reasoning about intent rather than
  surface keywords, at the cost of a network call and per-request $.

Both strategies implement `classify(text, country) -> ClassifyResponse` so
routers and tests can swap them without caring which one is active.

WHY THE MODEL IS NOT PER-COUNTRY
--------------------------------
One classifier serves every market, because the *mechanism* of a scam
generalises even when its vocabulary does not: "reverse this deposit you did
not receive" is the same attack in Harare and Lagos, and a model trained on
all seven markets sees far more examples of it than seven per-country models
would. What is localised is the *grounding* — which wallets, currency and
languages the prompt names, and which words the risk-phrase highlighter
recognises. That keeps a single quality bar while still letting a Kenyan user
see "M-PESA" in the explanation rather than "EcoCash".
"""

from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Protocol

from app.config import get_settings
from app.schemas.classify import ClassifyResponse, RiskPhrase
from app.services.countries import Country, get_country
from app.services.support import UNIVERSAL_FIRST_STEPS
from app.services.taxonomy import get_category

CORPUS_PATH = Path(__file__).resolve().parents[3] / "sample_data" / "scam_corpus.jsonl"
MODEL_ARTIFACT_DIR = Path(__file__).resolve().parent / "model_artifacts"

# Keyword families used both to build human-readable risk-phrase highlights and,
# for the baseline strategy, as a naive-rule comparison point (docs/architecture.md
# explains *why* plain keyword matching is insufficient on its own).
#
# Phrases are chosen to be provider-agnostic wherever the underlying trick is:
# "reverse" catches the wrong-deposit scam across every wallet, so there is no
# need for an EcoCash rule and an M-PESA rule that say the same thing.
SCAM_KEYWORD_REASONS: dict[str, str] = {
    # Wrong-deposit / reversal, the single most widespread pattern in the region
    "reverse": "Asks you to 'reverse' or send back money — the core wrong-deposit scam script.",
    "reversal": "Asks you to 'reverse' or send back money — the core wrong-deposit scam script.",
    "wrong transfer": "'Wrong transfer' is a common pretext to lure you into sending back real money.",
    "wrong deposit": "'Wrong deposit' is a common pretext to lure you into sending back real money.",
    "sent in error": "A claimed error transfer is a standard setup for a reversal scam.",
    "by mistake": "A claimed mistaken transfer is a standard setup for a reversal scam.",
    "kudzorera": "Shona for 'to return' money — wrong-deposit reversal script.",
    "tidzorerwe": "Shona for 'so we can be refunded' — wrong-deposit reversal script.",
    "rudisha": "Swahili for 'return it' — wrong-deposit reversal script.",
    "nirudishie": "Swahili for 'send it back to me' — wrong-deposit reversal script.",
    # Upfront fees
    "registration fee": "Upfront fee requests are a hallmark of fake job and loan scams.",
    "processing fee": "Upfront fee requests are a hallmark of fake job and loan scams.",
    "activation fee": "Upfront fee requests are a hallmark of fake loan, grant and aid scams.",
    "clearance fee": "'Clearance' or 'release' fees are a hallmark of fake delivery and grant scams.",
    "delivery fee": "'Clearance' or 'release' fees are a hallmark of fake delivery and grant scams.",
    "shortlisted": "Unsolicited 'shortlisted' job messages are a common recruitment scam opener.",
    # Credentials
    "otp": "Legitimate services never ask you to share a one-time code.",
    "one-time": "Legitimate services never ask you to share a one-time code.",
    "your pin": "No provider, bank or agent ever needs your wallet PIN.",
    "bvn": "Your BVN is an identity key — a request for it is an account-takeover attempt.",
    "nin": "Your NIN is an identity key — a request for it is an account-takeover attempt.",
    "id number": "Requests for your ID number are a standard identity-theft opener.",
    "verify your account": "'Verify your account' is the most common phishing pretext there is.",
    # SIM swap / line pressure
    "sim swap": "SIM swap messages are a pretext to take over the line that receives your codes.",
    "sim will be": "Threats about your SIM pressure quick action before you can verify.",
    "re-register": "Unprompted SIM re-registration demands are a common takeover pretext.",
    "block": "Threats to block or suspend your line pressure quick, unverified action.",
    "suspended": "Threats to suspend your account pressure quick, unverified action.",
    "deactivated": "Threats to deactivate your line pressure quick, unverified action.",
    # Investment
    "double your": "Guaranteed-return offers are a classic fraud signal.",
    "guaranteed return": "Guaranteed returns do not exist in any legitimate investment.",
    "forex": "Unsolicited forex deals with 'send first' terms are a widespread scam pattern.",
    "crypto": "Unsolicited crypto trading offers with upfront deposits are a widespread scam pattern.",
    "investment opportunity": "Unsolicited investment offers with deadlines are a classic fraud signal.",
    # Aid and grants
    "grant": "Unsolicited grant awards that require a fee are a standard aid scam.",
    "relief aid": "Unsolicited relief aid awards that require a fee are a standard aid scam.",
    "you qualify": "'You qualify' openers for unrequested loans or grants are a standard scam script.",
    # Faith-based
    "seed": "'Sowing a seed' for a blessing is a common faith-based money-request scam.",
    "sow a seed": "'Sowing a seed' for a blessing is a common faith-based money-request scam.",
    "prophecy": "Prophecy conditioned on a payment to a personal number is a known scam script.",
    # Pressure
    "urgent": "Manufactured urgency pressures victims into skipping verification.",
    "immediately": "Manufactured urgency pressures victims into skipping verification.",
    "last chance": "Manufactured scarcity pressures victims into skipping verification.",
}


# Matching is word-bounded, not substring. Several keys are short enough that a
# naive `phrase in text` would fire constantly on innocent words — "nin" inside
# "morning", "grant" inside "granted", "otp" inside a reference code — and a
# highlighter that flags "morning" teaches users to ignore the highlights.
_KEYWORD_PATTERNS: tuple[tuple[str, re.Pattern[str], str], ...] = tuple(
    (phrase, re.compile(rf"\b{re.escape(phrase)}\b", re.IGNORECASE), reason)
    for phrase, reason in SCAM_KEYWORD_REASONS.items()
)


def _find_risk_phrases(text: str) -> list[RiskPhrase]:
    found: list[RiskPhrase] = []
    seen_reasons: set[str] = set()
    for phrase, pattern, reason in _KEYWORD_PATTERNS:
        # Several phrases intentionally map to the same reason (e.g. "reverse"
        # and "reversal"). Showing that reason twice reads as padding, so the
        # first match wins and the rest are dropped.
        if reason not in seen_reasons and pattern.search(text):
            found.append(RiskPhrase(phrase=phrase, reason=reason))
            seen_reasons.add(reason)
    return found


def _next_steps(verdict: str, category: str | None, country: Country) -> list[str]:
    """A verdict without a next step is only half an answer.

    The Safety, Reporting & Protection framing is explicit that people need a
    pathway, not a label — so every non-safe verdict carries the universal
    first steps plus the category's specific first action, without the client
    needing a second round trip to /support.
    """
    if verdict == "safe":
        return []
    steps = list(UNIVERSAL_FIRST_STEPS)
    if category:
        steps.insert(0, get_category(category).first_action)
    steps.append(
        f"For the full list of who to contact in {country.name}, open Get help "
        f"in the app or call GET /support/{country.code}."
    )
    return steps


def _resolve_country(country_code: str | None) -> Country:
    try:
        return get_country(country_code or get_settings().default_country)
    except ValueError:
        return get_country(get_settings().default_country)


class ClassifierStrategy(Protocol):
    def classify(self, text: str, country_code: str | None = None) -> ClassifyResponse: ...


def _load_corpus() -> list[dict]:
    if not CORPUS_PATH.exists():
        return []
    rows = []
    with open(CORPUS_PATH, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line:
                rows.append(json.loads(line))
    return rows


class BaselineClassifier:
    """TF-IDF + LogisticRegression, trained lazily from the synthetic corpus."""

    def __init__(self) -> None:
        self._pipeline = None

    def _ensure_trained(self) -> None:
        if self._pipeline is not None:
            return
        from sklearn.feature_extraction.text import TfidfVectorizer
        from sklearn.linear_model import LogisticRegression
        from sklearn.pipeline import Pipeline

        rows = _load_corpus()
        if len(rows) < 10:
            raise RuntimeError(
                f"Scam corpus at {CORPUS_PATH} has too few rows to train a baseline classifier. "
                "Run sample_data/generate_scam_corpus.py first."
            )
        texts = [r["text"] for r in rows]
        labels = [1 if r["label"] == "scam" else 0 for r in rows]

        pipeline = Pipeline([
            ("tfidf", TfidfVectorizer(ngram_range=(1, 2), min_df=1, lowercase=True)),
            ("clf", LogisticRegression(max_iter=1000, class_weight="balanced")),
        ])
        pipeline.fit(texts, labels)
        self._pipeline = pipeline

    def classify(self, text: str, country_code: str | None = None) -> ClassifyResponse:
        self._ensure_trained()
        assert self._pipeline is not None
        country = _resolve_country(country_code)
        proba_scam = float(self._pipeline.predict_proba([text])[0][1])

        if proba_scam >= 0.66:
            verdict = "scam"
        elif proba_scam >= 0.35:
            verdict = "suspicious"
        else:
            verdict = "safe"

        risk_phrases = _find_risk_phrases(text)
        explanation = (
            f"Baseline TF-IDF/LogisticRegression model estimates a {proba_scam:.0%} probability "
            f"this message matches known mobile-money scam patterns."
        )
        if risk_phrases:
            explanation += " Flagged phrases: " + "; ".join(rp.phrase for rp in risk_phrases) + "."

        return ClassifyResponse(
            verdict=verdict,
            confidence=proba_scam if verdict != "safe" else 1 - proba_scam,
            risk_phrases=risk_phrases,
            explanation=explanation,
            matched_category=None,
            strategy_used="baseline",
            country=country.code,
            next_steps=_next_steps(verdict, None, country),
        )


LLM_SYSTEM_TEMPLATE = """You are ChengetAI's scam-message classifier. You review SMS and \
WhatsApp messages and decide whether they are a scam, suspicious, or safe.

You are currently reviewing a message for a user in {country_name}. Ground your judgement in \
that market:
- Mobile money platforms in everyday use there: {providers}
- Messages may arrive in any of: {languages}, often code-switched within a single message
- Local currency: {currency_code} ({currency_symbol})

Scam patterns that recur across African mobile-money markets, and that you are tuned to catch:
- Wrong-deposit / reversal scams: a fake or reversible deposit notice, then pressure to send \
"the money back" to a different number
- Fake job or recruitment offers requiring an upfront registration, processing or medical fee
- Fake investment, forex or crypto deals promising guaranteed or doubled returns
- Fake loans, government grants or NGO relief aid requiring an activation or clearance fee
- SIM swap and line-suspension pretexts aimed at capturing the number that receives one-time codes
- OTP, PIN and identity phishing (including BVN in Nigeria and ID numbers elsewhere)
- Impersonation of a bank, mobile operator, wallet support desk or known agent
- Faith-based "sow a seed" or prophecy requests paid to a personal wallet number

Legitimate messages include real transaction notices from the platforms above, real bank alerts, \
OTP delivery messages (which tell you NOT to share the code — an OTP arriving is normal; someone \
asking you to read it out is not), and everyday personal or business texts.

Use these category keys for matched_category, or null if none fits: {category_keys}

Respond with ONLY a JSON object, no prose, matching this exact shape:
{{"verdict": "scam"|"suspicious"|"safe", "confidence": 0.0-1.0, "matched_category": string|null, \
"risk_phrases": [{{"phrase": string, "reason": string}}], "explanation": string}}

The explanation must be 1-3 plain-language sentences a non-technical user can understand. Name \
the platform the message is impersonating when you can, and never assume the user is in a country \
other than {country_name}."""

# Few-shot examples span markets and languages on purpose: a single-country set
# teaches the model that the local wallet name is itself the signal, which is
# exactly the overfit that broke generic spam filters for this region in the
# first place. The safe example is deliberately an OTP delivery, the single
# most common false positive in this domain.
FEW_SHOT_EXAMPLES = [
    {
        "text": "Confirmed. You have received $80 from Tendai. Ref:AB12CD34EF. Kana yakanga isiri "
                "yako pindura kuti tidzorerwe (mistake transfer) tinokutumira number yekudzorera mari.",
        "response": {
            "verdict": "scam", "confidence": 0.95, "matched_category": "mobile_money_reversal",
            "risk_phrases": [{"phrase": "tidzorerwe (mistake transfer)",
                               "reason": "Classic wrong-deposit reversal script."}],
            "explanation": "This is the wrong-deposit scam: a fake or reversible deposit notice "
                            "pressures you to send real money back to a stranger.",
        },
    },
    {
        "text": "Habari, nimekutumia KSh 5,000 kwa bahati mbaya kwenye M-PESA yako badala ya "
                "supplier wangu. Tafadhali nirudishie kwa 0712345678, ni ya matibabu ya mtoto.",
        "response": {
            "verdict": "scam", "confidence": 0.93, "matched_category": "mobile_money_reversal",
            "risk_phrases": [{"phrase": "nirudishie",
                               "reason": "Asks you to send money back for a transfer you never received."}],
            "explanation": "This is the wrong-deposit scam in Swahili. Check your real M-PESA "
                            "balance in the app before believing any deposit arrived.",
        },
    },
    {
        "text": "FBN ALERT: Your BVN is due for revalidation. Failure to update within 24hrs will "
                "restrict your account. Click http://fbn-verify.example/update to revalidate now.",
        "response": {
            "verdict": "scam", "confidence": 0.96, "matched_category": "otp_phishing",
            "risk_phrases": [
                {"phrase": "BVN is due for revalidation",
                 "reason": "Banks do not revalidate your BVN by SMS link."},
                {"phrase": "within 24hrs", "reason": "Manufactured deadline to stop you verifying."},
            ],
            "explanation": "This impersonates your bank to harvest your BVN. No Nigerian bank "
                            "asks you to revalidate a BVN through a link in an SMS.",
        },
    },
    {
        "text": "M-PESA: Your one time password is 482913. Do not share this code with anyone, "
                "including Safaricom staff.",
        "response": {
            "verdict": "safe", "confidence": 0.92, "matched_category": None, "risk_phrases": [],
            "explanation": "This is a normal one-time password delivery. It is safe to receive — "
                            "just never read the code out to anyone who calls or messages you.",
        },
    },
]


class LLMClassifier:
    """Anthropic-backed classifier using a few-shot, market-grounded prompt."""

    def __init__(self) -> None:
        settings = get_settings()
        if not settings.anthropic_api_key:
            raise RuntimeError("ANTHROPIC_API_KEY is not set; cannot use the llm classifier strategy.")
        import anthropic

        self._client = anthropic.Anthropic(api_key=settings.anthropic_api_key)
        self._model = settings.anthropic_model

    @staticmethod
    def _system_prompt(country: Country) -> str:
        from app.services.taxonomy import SCAM_CATEGORY_KEYS

        return LLM_SYSTEM_TEMPLATE.format(
            country_name=country.name,
            providers=", ".join(country.providers),
            languages=", ".join(country.languages),
            currency_code=country.currency_code,
            currency_symbol=country.currency_symbol,
            category_keys=", ".join(SCAM_CATEGORY_KEYS),
        )

    def _build_messages(self, text: str) -> list[dict]:
        messages: list[dict] = []
        for ex in FEW_SHOT_EXAMPLES:
            messages.append({"role": "user", "content": ex["text"]})
            messages.append({"role": "assistant", "content": json.dumps(ex["response"])})
        messages.append({"role": "user", "content": text})
        return messages

    def classify(self, text: str, country_code: str | None = None) -> ClassifyResponse:
        country = _resolve_country(country_code)
        response = self._client.messages.create(
            model=self._model,
            max_tokens=500,
            system=self._system_prompt(country),
            messages=self._build_messages(text),
        )
        raw = response.content[0].text if response.content else "{}"
        raw = re.sub(r"^```(?:json)?|```$", "", raw.strip(), flags=re.MULTILINE).strip()
        data = json.loads(raw)

        verdict = data["verdict"]
        matched_category = data.get("matched_category")
        return ClassifyResponse(
            verdict=verdict,
            confidence=float(data.get("confidence", 0.5)),
            risk_phrases=[RiskPhrase(**rp) for rp in data.get("risk_phrases", [])],
            explanation=data.get("explanation", ""),
            matched_category=matched_category,
            strategy_used="llm",
            country=country.code,
            next_steps=_next_steps(verdict, matched_category, country),
        )


_baseline_singleton: BaselineClassifier | None = None


def get_classifier(strategy: str | None = None) -> ClassifierStrategy:
    global _baseline_singleton
    settings = get_settings()
    chosen = strategy or settings.classifier_strategy

    if chosen == "llm":
        try:
            return LLMClassifier()
        except RuntimeError:
            chosen = "baseline"  # graceful degradation when no API key is configured

    if _baseline_singleton is None:
        _baseline_singleton = BaselineClassifier()
    return _baseline_singleton
