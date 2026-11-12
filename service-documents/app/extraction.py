"""Extraction de champs comptables depuis une pièce scannée (facture, reçu) : texte natif du PDF, sinon OCR Tesseract.

Le résultat est une proposition : tout champ non trouvé reste à `None`, jamais deviné. L'humain valide toujours.
"""
import io
import re
from datetime import date

import pytesseract
from PIL import Image, ImageOps
from pypdf import PdfReader

from .models import ExtractedDocument

# En dessous de ce nombre de caractères, un PDF est considéré comme un scan sans couche de texte.
MIN_NATIVE_TEXT = 20
CURRENCIES = ("FCFA", "XOF", "EUR", "USD")
_AMOUNT = r"(-?\d[\d   ]*(?:[.,]\d{1,6})?)"
_SPACES = re.compile(r"[   ]+")


class UnsupportedDocument(ValueError):
    """Type de fichier non pris en charge ou fichier illisible."""


def _normalize(text: str) -> str:
    return "\n".join(_SPACES.sub(" ", line).strip() for line in text.replace("\r", "").split("\n"))


def extract_text(content: bytes, mime_type: str) -> tuple[str, str]:
    """Retourne (texte, méthode) : « pdf-text » pour un PDF avec texte, « ocr » pour une image ou un PDF sans texte."""
    if mime_type == "application/pdf":
        try:
            reader = PdfReader(io.BytesIO(content))
            text = "\n".join((page.extract_text() or "") for page in reader.pages)
        except Exception as error:  # fichier PDF corrompu ou chiffré
            raise UnsupportedDocument("PDF illisible") from error
        if len(text.strip()) >= MIN_NATIVE_TEXT:
            return _normalize(text), "pdf-text"
        raise UnsupportedDocument("PDF sans texte (scan) : déposer l'image de la page (JPEG ou PNG)")
    if mime_type in ("image/jpeg", "image/png"):
        try:
            image = ImageOps.exif_transpose(Image.open(io.BytesIO(content))).convert("L")
        except Exception as error:
            raise UnsupportedDocument("Image illisible") from error
        return _normalize(pytesseract.image_to_string(image, lang="fra", config="--psm 6")), "ocr"
    raise UnsupportedDocument(f"Type non pris en charge : {mime_type}")


def _amount(raw: str) -> float | None:
    cleaned = _SPACES.sub("", raw).replace(",", ".")
    try:
        return float(cleaned)
    except ValueError:
        return None


def _find_amount(text: str, label: str) -> float | None:
    match = re.search(label + r"[^\n\d-]*" + _AMOUNT, text, re.IGNORECASE)
    return _amount(match.group(1)) if match else None


def _find_date(text: str) -> date | None:
    match = re.search(r"\b(\d{1,2})[/.-](\d{1,2})[/.-](\d{4})\b", text)
    if not match:
        return None
    day, month, year = (int(g) for g in match.groups())
    try:
        return date(year, month, day)
    except ValueError:
        return None


def _find_text(text: str, label: str) -> str | None:
    match = re.search(label + r"\s*:?\s*([^\n]+)", text, re.IGNORECASE)
    return match.group(1).strip() if match else None


def _supplier(text: str) -> str | None:
    for line in text.split("\n"):
        if len(line) >= 3 and re.search(r"[A-Za-zÀ-ÿ]{3}", line):
            return line
    return None


def _currency(text: str) -> str | None:
    """Devise de la ligne de total (ex. « Total : 3 000.00 EUR »), sinon première devise citée."""
    on_total = re.search(r"(?:total|montant)[^\n]*", text, re.IGNORECASE)
    for scope in ([on_total.group(0)] if on_total else []) + [text]:
        code = _first_currency(scope)
        if code:
            return code
    return None


def _first_currency(text: str) -> str | None:
    for code in CURRENCIES:
        if re.search(rf"\b{code}\b", text):
            return "FCFA" if code == "XOF" else code
    return None


def parse_fields(text: str) -> ExtractedDocument:
    """Applique des règles simples ; un champ absent ou ambigu reste `None`."""
    currency = _currency(text)
    total = _find_amount(text, r"total\s+ttc") or _find_amount(text, r"\btotal\b") or _find_amount(text, r"\bmontant\b(?!\s+ht)")
    counter_value = _find_amount(text, r"contre[- ]valeur")
    tax_id = re.search(r"\bIFU\b\D{0,5}(\d{13})\b", text, re.IGNORECASE)
    fields = ExtractedDocument(
        supplier=_supplier(text),
        document_date=_find_date(text),
        reference=_find_text(text, r"r[ée]f[ée]rence"),
        currency=currency,
        amount_excl_tax=_find_amount(text, r"montant\s+ht"),
        vat_amount=_find_amount(text, r"tva(?:\s+\d+\s*%)?"),
        total=total,
        exchange_rate=_find_amount(text, r"(?:taux[^\n:]*:)"),
        counter_value=counter_value,
        tax_id=tax_id.group(1) if tax_id else None,
    )
    return fields.model_copy(update={"consistent": _is_consistent(fields)})


def _is_consistent(fields: ExtractedDocument) -> bool | None:
    """HT + TVA = total à l'unité près ; `None` quand les trois montants ne sont pas tous lus."""
    if None in (fields.amount_excl_tax, fields.vat_amount, fields.total):
        return None
    return abs(fields.amount_excl_tax + fields.vat_amount - fields.total) <= 1


def extract_document(content: bytes, mime_type: str) -> ExtractedDocument:
    text, method = extract_text(content, mime_type)
    return parse_fields(text).model_copy(update={"method": method, "raw_text": text})
