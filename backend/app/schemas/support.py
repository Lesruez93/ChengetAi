from typing import Literal

from pydantic import BaseModel, Field

ChannelKind = Literal["wallet", "regulator", "police", "support"]


class SupportChannelResponse(BaseModel):
    kind: ChannelKind
    organisation: str
    what_it_does: str
    contact: str | None
    url: str | None
    verified: bool = Field(
        ...,
        description="False means the organisation is correct but the contact string "
                    "has not been confirmed against its own published channel. Clients "
                    "must show this distinction rather than hiding it.",
    )


class SupportPathwayResponse(BaseModel):
    country: str
    country_name: str
    category: str | None
    immediate_steps: list[str]
    category_first_action: str | None
    channels: list[SupportChannelResponse]
    data_note: str
