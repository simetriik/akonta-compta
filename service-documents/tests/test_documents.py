from io import BytesIO

from openpyxl import load_workbook

from app.formatting import fcfa, fcfa_total


def test_health(client):
    assert client.get("/health").json()["status"] == "ok"


def test_service_key_required(client, header):
    r = client.post("/pdf/trial-balance", json={"header": header, "rows": []})
    assert r.status_code == 401
    r = client.post("/pdf/trial-balance", json={"header": header, "rows": []}, headers={"X-Akonta-Service-Key": "mauvaise"})
    assert r.status_code == 401


def test_fcfa_formatting():
    assert fcfa(1180000) == "1\u00a0180\u00a0000"
    assert fcfa(-2500) == "-2\u00a0500"
    assert fcfa(0) == ""
    assert fcfa_total(0) == "0"


def test_trial_balance_pdf(client, auth, header):
    rows = [
        {"account_code": "4111000", "account_label": "Clients", "period_debit": 1770000, "period_credit": 500000, "closing_debit": 1270000},
        {"account_code": "7011000", "account_label": "Ventes de marchandises", "period_credit": 1500000, "closing_credit": 1500000},
    ]
    r = client.post("/pdf/trial-balance", json={"header": header, "rows": rows}, headers=auth)
    assert r.status_code == 200
    assert r.headers["content-type"] == "application/pdf"
    assert r.content.startswith(b"%PDF")
    assert len(r.content) > 1500


def test_general_ledger_pdf_groups_accounts(client, auth, header):
    header = {**header, "title": "Grand livre"}
    lines = [
        {"account_code": "4111000", "account_label": "Clients", "entry_date": "2026-01-10", "journal_code": "VT", "number": 1,
         "label": "Facture 001", "third_party_code": "CHU", "debit": 1180000, "running_balance": 1180000},
        {"account_code": "4111000", "account_label": "Clients", "entry_date": "2026-03-20", "journal_code": "BQ", "number": 1,
         "label": "Règlement", "third_party_code": "CHU", "credit": 500000, "running_balance": 680000},
        {"account_code": "5210000", "account_label": "Banques locales", "entry_date": "2026-03-20", "journal_code": "BQ", "number": 1,
         "label": "Règlement", "debit": 500000, "running_balance": 500000},
    ]
    r = client.post("/pdf/general-ledger", json={"header": header, "lines": lines}, headers=auth)
    assert r.status_code == 200 and r.content.startswith(b"%PDF")


def test_journal_and_aged_balance_pdf(client, auth, header):
    r = client.post("/pdf/journal", json={"header": {**header, "title": "Journal des ventes"}, "journal_code": "VT", "journal_label": "Ventes",
                                          "lines": [{"entry_date": "2026-01-10", "number": 1, "account_code": "4111000", "account_label": "Clients",
                                                     "third_party_code": "CHU", "label": "Facture 001", "debit": 1180000},
                                                    {"entry_date": "2026-01-10", "number": 1, "account_code": "7011000", "account_label": "Ventes",
                                                     "label": "Facture 001", "credit": 1180000}]}, headers=auth)
    assert r.status_code == 200 and r.content.startswith(b"%PDF")
    r = client.post("/pdf/aged-balance", json={"header": {**header, "title": "Balance âgée clients"},
                                               "rows": [{"account_code": "4111000", "third_party_code": "CHU", "third_party_name": "CHU - Parakou",
                                                         "d91_180": 1770000, "d61_90": -500000, "total": 1270000}]}, headers=auth)
    assert r.status_code == 200 and r.content.startswith(b"%PDF")


def test_trial_balance_xlsx(client, auth, header):
    rows = [
        {"account_code": "4111000", "account_label": "Clients", "period_debit": 1770000, "period_credit": 500000, "closing_debit": 1270000},
        {"account_code": "7011000", "account_label": "Ventes", "period_credit": 1500000, "closing_credit": 1500000},
    ]
    r = client.post("/excel/trial-balance", json={"header": header, "rows": rows}, headers=auth)
    assert r.status_code == 200
    wb = load_workbook(BytesIO(r.content))
    ws = wb["Balance"]
    assert ws["A6"].value == "4111000"
    assert ws["E6"].value == 1770000
    assert ws["B8"].value == "Totaux"
    assert ws["E8"].value == "=SUM(E6:E7)"


def test_too_many_rows(client, auth, header, monkeypatch):
    from app import config
    config.get_settings.cache_clear()
    monkeypatch.setenv("AKONTA_MAX_ROWS", "1")
    rows = [{"account_code": str(i), "account_label": "x"} for i in range(3)]
    r = client.post("/pdf/trial-balance", json={"header": header, "rows": rows}, headers=auth)
    assert r.status_code == 413
    config.get_settings.cache_clear()


def test_reconciliation_pdf(client, auth, header):
    doc = {
        "header": {**header, "title": "État de rapprochement bancaire"},
        "journal_code": "BQ", "journal_label": "Ecobank", "as_of": "2026-01-31",
        "book_balance": 1100000, "bank_balance": 1283500,
        "outstanding_payments": [{"date": "2026-01-25", "label": "Chèque 112", "reference": "112", "amount": 200000}],
        "unmatched_bank_debits": [{"date": "2026-01-31", "label": "Frais de tenue de compte", "amount": 16500}],
        "difference": 0,
    }
    r = client.post("/pdf/reconciliation", json=doc, headers=auth)
    assert r.status_code == 200 and r.content.startswith(b"%PDF")


def test_dgi_fill_keeps_macros(client, auth, monkeypatch, tmp_path):
    import os
    from pathlib import Path
    template = Path(__file__).resolve().parents[2] / "inputs" / "Modèle DGI-Etats-Financiers-SN.xlsm"
    if not template.exists():
        import pytest
        pytest.skip("modèle DGI absent (inputs/ non versionné)")
    monkeypatch.setenv("AKONTA_DGI_TEMPLATE", str(template))
    r = client.post("/excel/dgi", json={"template_version": "SN-2025", "cells": [
        {"sheet": "BILAN", "cell": "F12", "value": 1500000},
        {"sheet": "BILAN", "cell": "F36", "value": 21300000},
        {"sheet": "BILAN", "cell": "H36", "value": 1},
        {"sheet": "INCONNUE", "cell": "A1", "value": 1},
    ]}, headers=auth)
    assert r.status_code == 200
    assert r.headers["content-type"].startswith("application/vnd.ms-excel.sheet.macroEnabled")
    assert r.headers["X-Akonta-Skipped-Cells"] == "2", "feuille inconnue + formule H36 conservée"
    out = tmp_path / "out.xlsm"
    out.write_bytes(r.content)
    from openpyxl import load_workbook
    wb = load_workbook(out, keep_vba=True)
    assert wb["BILAN"]["F12"].value == 1500000
    assert wb["BILAN"]["F36"].value == 21300000
    assert str(wb["BILAN"]["H36"].value).startswith("="), "les formules du modèle ne sont pas écrasées"
    assert wb.vba_archive is not None, "les macros doivent être conservées"


def test_financial_statements_pdf(client, auth, header):
    doc = {
        "header": {**header, "title": "États financiers SYSCOHADA"},
        "assets": [{"post_code": "BS", "post_label": "Banques", "column_role": "gross", "amount": 21300000}, {"post_code": "AN", "post_label": "Matériel de transport", "column_role": "gross", "amount": 12000000}, {"post_code": "AN", "post_label": "Matériel de transport", "column_role": "depreciation", "amount": 1800000}],
        "liabilities": [{"post_code": "CA", "post_label": "Capital", "amount": 10000000}, {"post_code": "CJ", "post_label": "Résultat net", "amount": 2600000}],
        "income": [{"post_code": "TA", "post_label": "Ventes de marchandises", "amount": 10000000}, {"post_code": "RA", "post_label": "Achats de marchandises", "amount": -6000000}],
    }
    r = client.post("/pdf/financial-statements", json=doc, headers=auth)
    assert r.status_code == 200 and r.content.startswith(b"%PDF")
