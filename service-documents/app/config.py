"""Configuration du service, lue dans l'environnement."""
import os
from functools import lru_cache

from pydantic import BaseModel


class Settings(BaseModel):
    service_key: str
    max_rows: int = 50_000


@lru_cache
def get_settings() -> Settings:
    key = os.environ.get("AKONTA_SERVICE_KEY", "")
    if not key:
        raise RuntimeError("AKONTA_SERVICE_KEY manquante : clé partagée avec l'Edge Function export-document")
    return Settings(service_key=key, max_rows=int(os.environ.get("AKONTA_MAX_ROWS", "50000")))
