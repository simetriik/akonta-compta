"""Formats français : montants FCFA entiers avec séparateur de milliers insécable, dates jj/mm/aaaa."""
from datetime import date

NBSP = "\u00a0"  # espace insécable ; l'espace fine U+202F est absente de la police Helvetica des PDF (carré noir)


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


def ledger_counterpart_text(line, mode: str = "main") -> str:
    """Contrepartie d'une ligne du grand livre : « 6011000 + 1 » (principale et nombre d'autres) ou la liste complète."""
    if mode == "all" and line.counterparts:
        return ", ".join(c.code for c in line.counterparts)
    if not line.counterpart_code:
        return ""
    return f"{line.counterpart_code} + {line.counterpart_more}" if line.counterpart_more > 0 else line.counterpart_code


def ledger_third_party_text(line) -> str:
    """Tiers d'une ligne du grand livre : son nom, à défaut son code (jamais le numéro de compte)."""
    return line.third_party_name or line.third_party_code or ""
