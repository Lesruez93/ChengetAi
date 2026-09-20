from pydantic import BaseModel


class CountryResponse(BaseModel):
    """Everything a client needs to render country-correct forms and copy,
    fetched once instead of hardcoded per platform."""

    code: str
    name: str
    dial_code: str
    region_label: str
    regions: list[str]
    providers: list[str]
    currency_code: str
    currency_symbol: str
    example_msisdn: str


class CategoryResponse(BaseModel):
    key: str
    label: str
    description: str
    first_action: str
