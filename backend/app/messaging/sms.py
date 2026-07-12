"""SMS messaging layer: report confirmations and scam-alert broadcasts.

Env-driven transport selection (SMS_TRANSPORT=console|twilio). The console
transport is the default and is used in dev/test/demo — it logs the message
instead of sending it, so the MVP never needs live Twilio credentials to run
end to end. Swapping to twilio only requires setting SMS_TRANSPORT=twilio and
the TWILIO_* env vars; no calling code changes.
"""

from __future__ import annotations

import logging
from typing import Protocol

from app.config import get_settings

logger = logging.getLogger("chengetai.sms")


class SmsTransport(Protocol):
    def send(self, to: str, body: str) -> None: ...


class ConsoleSmsTransport:
    """Dev/demo transport: logs instead of sending."""

    def send(self, to: str, body: str) -> None:
        logger.info("[console-sms] to=%s body=%s", to, body)


class TwilioSmsTransport:
    def __init__(self, account_sid: str, auth_token: str, from_number: str) -> None:
        from twilio.rest import Client

        self._client = Client(account_sid, auth_token)
        self._from_number = from_number

    def send(self, to: str, body: str) -> None:
        self._client.messages.create(to=to, from_=self._from_number, body=body)


def get_sms_transport() -> SmsTransport:
    settings = get_settings()
    if settings.sms_transport == "twilio" and settings.twilio_account_sid:
        return TwilioSmsTransport(
            settings.twilio_account_sid, settings.twilio_auth_token, settings.twilio_from_number
        )
    return ConsoleSmsTransport()


def send_report_confirmation(to: str, msisdn_reported: str, category: str) -> None:
    transport = get_sms_transport()
    transport.send(
        to,
        f"ChengetAI: Thanks for reporting {msisdn_reported} ({category.replace('_', ' ')}). "
        "Your report helps protect other Zimbabweans from scams.",
    )


def send_scam_alert_broadcast(to: str, title: str, summary: str) -> None:
    transport = get_sms_transport()
    transport.send(to, f"ChengetAI Alert: {title} - {summary}")
