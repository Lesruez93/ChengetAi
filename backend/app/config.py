"""Centralized, typed application settings loaded from environment variables."""

from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    app_env: str = "development"
    log_level: str = "info"

    supabase_url: str = ""
    supabase_service_role_key: str = ""
    supabase_anon_key: str = ""
    use_supabase: bool = False

    classifier_strategy: str = "baseline"  # baseline | llm
    anthropic_api_key: str = ""
    anthropic_model: str = "claude-sonnet-5"

    sms_transport: str = "console"  # console | twilio
    twilio_account_sid: str = ""
    twilio_auth_token: str = ""
    twilio_from_number: str = ""

    report_rate_limit_per_hour: int = 5
    number_public_flag_threshold: int = 3


@lru_cache
def get_settings() -> Settings:
    return Settings()
