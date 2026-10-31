"""États financiers SYCEBNL : totaux de présentation, colonnes N-1, PDF unique."""
from app.models import StatementPostRow
from app.pdf_sycebnl import _percent
from app.sycebnl import ASSETS, balance_sheet_assets, balance_sheet_liabilities, income_statement, unknown_codes


def post(code: str, amount: int, role: str = "amount", label: str = "") -> StatementPostRow:
    return StatementPostRow(post_code=code, post_label=label or code, column_role=role, amount=amount)


# Association : banque 2 000 000 ; dotation 1 000 000, emprunt 500 000, fournisseurs 50 000, excédent 450 000
ASSET_POSTS = [post("BW", 2000000, "gross")]
LIABILITY_POSTS = [post("CA", 1000000), post("DA", 500000), post("DH", 50000), post("CH", 450000)]
INCOME_POSTS = [post("RA", 400000), post("RC", 100000), post("RF", 300000), post("TA", -150000), post("TG", -120000), post("TJ", -80000)]


def by_ref(rows):
    return {r.ref: r for r in rows}


def test_balance_sheet_totals_tie():
    assets = by_ref(balance_sheet_assets(ASSET_POSTS, [], False))
    liabilities = by_ref(balance_sheet_liabilities(LIABILITY_POSTS, [], False))
    assert assets["BX"].values == [2000000, 0, 2000000]
    assert assets["BZ"].values[2] == 2000000
    assert liabilities["CK"].values == [1450000]
    assert liabilities["CZ"].values == [1450000]
    assert liabilities["DV"].values == [50000]
    assert liabilities["DZ"].values == [2000000]
    assert assets["BZ"].values[2] == liabilities["DZ"].values[0]


def test_assets_net_is_gross_minus_depreciation():
    posts = [post("AL", 900000, "gross"), post("AL", 300000, "depreciation")]
    assets = by_ref(balance_sheet_assets(posts, [], False))
    assert assets["AL"].values == [900000, 300000, 600000]
    assert assets["AZ"].values == [900000, 300000, 600000]


def test_previous_year_columns():
    prev_assets = [post("BW", 1000000, "gross")]
    assets = by_ref(balance_sheet_assets(ASSET_POSTS, prev_assets, True))
    assert assets["BW"].values == [2000000, 0, 2000000, 1000000]
    assert assets["BZ"].values[3] == 1000000
    liabilities = by_ref(balance_sheet_liabilities(LIABILITY_POSTS, [post("CA", 1000000)], True))
    assert liabilities["DZ"].values == [2000000, 1000000]


def test_income_statement_presents_charges_as_positive_and_xa_includes_reprises():
    rows = by_ref(income_statement(INCOME_POSTS, [], False))
    assert rows["TA"].values == [150000]
    assert rows["XA"].values == [800000]
    assert rows["XB"].values == [350000]
    assert rows["XC"].values == [450000]
    assert rows["XE"].values == [450000]
    with_reprise = by_ref(income_statement(INCOME_POSTS + [post("RH", 50000)], [], False))
    assert with_reprise["XA"].values == [850000]   # RA à RH, reprises comprises (D-024)
    assert with_reprise["XE"].values == [500000]


def test_hao_result():
    rows = by_ref(income_statement(INCOME_POSTS + [post("TM", 80000), post("TN", -30000)], [], False))
    assert rows["XD"].values == [50000]
    assert rows["XE"].values == [500000]


def test_unknown_posts_are_reported():
    assert unknown_codes([post("BW", 1), post("ZZ", 2)], ASSETS) == ["ZZ"]


def test_percent():
    assert _percent(120000, 100000) == "20,0 %"
    assert _percent(5, 0) == ""
    assert _percent(5, None) == ""


def sycebnl_doc(header: dict, with_previous: bool) -> dict:
    doc = {
        "header": {**header, "title": "États financiers SYCEBNL"},
        "assets": [{"post_code": "BW", "post_label": "Banques", "column_role": "gross", "amount": 2000000}],
        "liabilities": [{"post_code": c, "post_label": c, "column_role": "amount", "amount": a} for c, a in [("CA", 1000000), ("DA", 500000), ("DH", 50000), ("CH", 450000)]],
        "income": [{"post_code": c, "post_label": c, "column_role": "amount", "amount": a} for c, a in [("RA", 400000), ("RC", 100000), ("RF", 300000), ("TA", -150000), ("TG", -120000), ("TJ", -80000)]],
        "cash_flow": [
            {"post_code": "ZA", "post_label": "Trésorerie nette au 1er janvier", "column_role": "amount", "amount": 1000000},
            {"post_code": "FA", "post_label": "+ Encaissement des cotisations", "column_role": "amount", "amount": 400000},
            {"post_code": "ZG", "post_label": "Trésorerie nette au 31 décembre", "column_role": "amount", "amount": 1400000},
        ],
        "notes": [
            {"note_code": "23", "note_title": "Revenus et autres produits", "line_code": "23-1", "label": "Cotisations des adhérents", "kind": "line", "amount": 400000, "previous": 300000 if with_previous else None, "sort_order": 10},
            {"note_code": "23", "note_title": "Revenus et autres produits", "line_code": "23-T", "label": "TOTAL", "kind": "total", "amount": 400000, "previous": 300000 if with_previous else None, "sort_order": 20},
            {"note_code": "11", "note_title": "Titres de placement", "line_code": "11-1", "label": "Actions", "kind": "line", "amount": 0, "previous": None, "sort_order": 30},
        ],
        "has_previous": with_previous,
    }
    if with_previous:
        doc["previous_assets"] = [{"post_code": "BW", "post_label": "Banques", "column_role": "gross", "amount": 1000000}]
        doc["previous_liabilities"] = [{"post_code": "CA", "post_label": "Dotation", "column_role": "amount", "amount": 1000000}]
        doc["previous_cash_flow"] = [{"post_code": "ZG", "post_label": "Trésorerie nette au 31 décembre", "column_role": "amount", "amount": 1000000}]
    return doc


def test_pdf_with_previous_year(client, auth, header):
    r = client.post("/pdf/financial-statements-sycebnl", json=sycebnl_doc(header, True), headers=auth)
    assert r.status_code == 200
    assert r.headers["content-type"] == "application/pdf"
    assert r.content.startswith(b"%PDF")
    assert "etats-financiers-sycebnl-2026.pdf" in r.headers["content-disposition"]


def test_pdf_without_previous_year(client, auth, header):
    r = client.post("/pdf/financial-statements-sycebnl", json=sycebnl_doc(header, False), headers=auth)
    assert r.status_code == 200 and r.content.startswith(b"%PDF")


def test_pdf_minimal_document(client, auth, header):
    r = client.post("/pdf/financial-statements-sycebnl", json={"header": header}, headers=auth)
    assert r.status_code == 200 and r.content.startswith(b"%PDF")


def test_service_key_required(client, header):
    r = client.post("/pdf/financial-statements-sycebnl", json=sycebnl_doc(header, False))
    assert r.status_code == 401
