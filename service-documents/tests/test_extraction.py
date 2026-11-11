"""Extraction de pièces : les 12 pièces fictives de `recette/pieces/` servent de jeu d'essai."""
import shutil
from datetime import date
from pathlib import Path

import pytest

PIECES = Path(__file__).resolve().parents[2] / "recette" / "pieces"
needs_tesseract = pytest.mark.skipif(shutil.which("tesseract") is None, reason="Tesseract absent")


def _post(client, auth, name: str, mime: str):
    return client.post("/extract/document", content=(PIECES / name).read_bytes(), headers={**auth, "Content-Type": mime})


def test_pdf_with_tax(client, auth):
    body = _post(client, auth, "01-facture-fa-fcg-0215.pdf", "application/pdf")
    assert body.status_code == 200
    data = body.json()
    assert data["method"] == "pdf-text"
    assert data["supplier"] == "Cimenterie du Golfe"
    assert data["document_date"] == "2027-01-03"
    assert data["reference"] == "FA-FCG-0215"
    assert (data["amount_excl_tax"], data["vat_amount"], data["total"]) == (4200000, 756000, 4956000)
    assert data["currency"] == "FCFA"
    assert data["consistent"] is True


def test_pdf_without_tax_lines(client, auth):
    data = _post(client, auth, "05-avis-vir-0114.pdf", "application/pdf").json()
    assert data["total"] == 950000
    assert data["amount_excl_tax"] is None and data["vat_amount"] is None
    assert data["consistent"] is None


def test_foreign_currency(client, auth):
    data = _post(client, auth, "10-facture-fact-eu-3381.pdf", "application/pdf").json()
    assert (data["currency"], data["total"], data["exchange_rate"], data["counter_value"]) == ("EUR", 3000, 655.957, 1967871)


@needs_tesseract
def test_image_ocr(client, auth):
    data = _post(client, auth, "06-facture-fa-en-0127.jpg", "image/jpeg").json()
    assert data["method"] == "ocr"
    assert data["document_date"] == date(2027, 1, 15).isoformat()
    assert (data["amount_excl_tax"], data["vat_amount"], data["total"]) == (180000, 32400, 212400)


def test_all_recette_pieces_give_a_date_and_amount(client, auth):
    for path in sorted(PIECES.glob("*")):
        mime = "application/pdf" if path.suffix == ".pdf" else "image/jpeg"
        if mime == "image/jpeg" and shutil.which("tesseract") is None:
            continue
        data = _post(client, auth, path.name, mime).json()
        assert data["document_date"], path.name
        assert data["total"], path.name


def test_requires_service_key(client):
    assert client.post("/extract/document", content=b"x", headers={"Content-Type": "application/pdf"}).status_code == 401


def test_rejects_unsupported_and_empty(client, auth):
    assert client.post("/extract/document", content=b"x", headers={**auth, "Content-Type": "text/plain"}).status_code == 415
    assert client.post("/extract/document", content=b"", headers={**auth, "Content-Type": "application/pdf"}).status_code == 400
    assert client.post("/extract/document", content=b"pas un pdf", headers={**auth, "Content-Type": "application/pdf"}).status_code == 415
