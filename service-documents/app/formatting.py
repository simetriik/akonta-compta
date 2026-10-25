"""Formats français : montants FCFA entiers avec séparateur de milliers insécable, dates jj/mm/aaaa."""
from datetime import date

NBSP = " "  # espace fine insécable


def fcfa(amount: int | None) -> str:
    if amount is None or amount == 0:
        return ""
    sign = "-" if amount < 0 else ""
    digits = f"{abs(amount):,}".replace(",", NBSP)
    return f"{sign}{digits}"


def fcfa_total(amount: int) -> str:
    """Comme fcfa() mais affiche aussi zéro (lignes de totaux)."""
    return fcfa(amount) if amount else "0"


def fr_date(d: date) -> str:
    return d.strftime("%d/%m/%Y")
