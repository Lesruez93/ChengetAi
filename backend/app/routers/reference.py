"""Reference data: the country registry and scam taxonomy, served to clients.

The Flutter app and the web dashboard both need region lists, provider names
and category labels. Serving them from here rather than hardcoding them per
platform means adding a country is a backend deploy, not a coordinated release
across three codebases — and the two clients can never drift apart on what a
category is called.
"""

from fastapi import APIRouter, HTTPException

from app.schemas.reference import CategoryResponse, CountryResponse
from app.services.countries import UnknownCountryError, all_countries, get_country
from app.services.taxonomy import SCAM_CATEGORIES

router = APIRouter(prefix="/reference", tags=["reference"])


def _to_response(country) -> CountryResponse:
    return CountryResponse(
        code=country.code, name=country.name, dial_code=country.dial_code,
        region_label=country.region_label, regions=list(country.regions),
        providers=list(country.providers), languages=list(country.languages),
        currency_code=country.currency_code, currency_symbol=country.currency_symbol,
        example_msisdn=country.example_msisdn,
    )


@router.get("/countries", response_model=list[CountryResponse])
def list_countries() -> list[CountryResponse]:
    return [_to_response(c) for c in all_countries()]


@router.get("/countries/{country_code}", response_model=CountryResponse)
def get_country_reference(country_code: str) -> CountryResponse:
    try:
        return _to_response(get_country(country_code))
    except UnknownCountryError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@router.get("/categories", response_model=list[CategoryResponse])
def list_categories() -> list[CategoryResponse]:
    return [
        CategoryResponse(key=c.key, label=c.label, description=c.description,
                         first_action=c.first_action)
        for c in SCAM_CATEGORIES
    ]
