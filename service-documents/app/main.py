"""API du service de documents. Appelée par l'Edge Function `export-document` avec une clé partagée."""
from typing import Annotated

from fastapi import Depends, FastAPI, Header, HTTPException, Response, status

from . import dgi, excel, pdf, pdf_sycebnl
from .config import Settings, get_settings
from .models import AgedBalanceDocument, FinancialStatementsDocument, JournalDocument, LedgerDocument, ReconciliationDocument, SycebnlStatementsDocument, TrialBalanceDocument

app = FastAPI(title="Akonta — service de documents", version="0.1.0")

PDF = "application/pdf"
XLSX = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"


def require_service_key(x_akonta_service_key: Annotated[str | None, Header()] = None,
                        settings: Settings = Depends(get_settings)) -> None:
    if not x_akonta_service_key or x_akonta_service_key != settings.service_key:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Clé de service invalide")


def _check_size(n: int, settings: Settings) -> None:
    if n > settings.max_rows:
        raise HTTPException(status_code=status.HTTP_413_CONTENT_TOO_LARGE, detail=f"Document trop volumineux ({n} lignes, maximum {settings.max_rows})")


def _file(content: bytes, media_type: str, filename: str) -> Response:
    return Response(content=content, media_type=media_type, headers={"Content-Disposition": f'attachment; filename="{filename}"'})


@app.get("/health")
def health() -> dict:
    return {"status": "ok", "service": "akonta-documents"}


@app.post("/pdf/trial-balance", dependencies=[Depends(require_service_key)])
def pdf_trial_balance(doc: TrialBalanceDocument, settings: Settings = Depends(get_settings)) -> Response:
    _check_size(len(doc.rows), settings)
    return _file(pdf.trial_balance_pdf(doc), PDF, "balance.pdf")


@app.post("/pdf/general-ledger", dependencies=[Depends(require_service_key)])
def pdf_general_ledger(doc: LedgerDocument, settings: Settings = Depends(get_settings)) -> Response:
    _check_size(len(doc.lines), settings)
    return _file(pdf.general_ledger_pdf(doc), PDF, "grand-livre.pdf")


@app.post("/pdf/journal", dependencies=[Depends(require_service_key)])
def pdf_journal(doc: JournalDocument, settings: Settings = Depends(get_settings)) -> Response:
    _check_size(len(doc.lines), settings)
    return _file(pdf.journal_pdf(doc), PDF, f"journal-{doc.journal_code}.pdf")


@app.post("/pdf/aged-balance", dependencies=[Depends(require_service_key)])
def pdf_aged_balance(doc: AgedBalanceDocument, settings: Settings = Depends(get_settings)) -> Response:
    _check_size(len(doc.rows), settings)
    return _file(pdf.aged_balance_pdf(doc), PDF, "balance-agee.pdf")


@app.post("/excel/trial-balance", dependencies=[Depends(require_service_key)])
def excel_trial_balance(doc: TrialBalanceDocument, settings: Settings = Depends(get_settings)) -> Response:
    _check_size(len(doc.rows), settings)
    return _file(excel.trial_balance_xlsx(doc), XLSX, "balance.xlsx")


@app.post("/excel/general-ledger", dependencies=[Depends(require_service_key)])
def excel_general_ledger(doc: LedgerDocument, settings: Settings = Depends(get_settings)) -> Response:
    _check_size(len(doc.lines), settings)
    return _file(excel.general_ledger_xlsx(doc), XLSX, "grand-livre.xlsx")


@app.post("/pdf/reconciliation", dependencies=[Depends(require_service_key)])
def pdf_reconciliation(doc: ReconciliationDocument) -> Response:
    return _file(pdf.reconciliation_pdf(doc), PDF, f"rapprochement-{doc.journal_code}-{doc.as_of.isoformat()}.pdf")


XLSM = "application/vnd.ms-excel.sheet.macroEnabled.12"


@app.post("/excel/dgi", dependencies=[Depends(require_service_key)])
def excel_dgi(doc: dgi.DgiDocument) -> Response:
    try:
        content, skipped = dgi.fill_dgi_workbook(doc)
    except RuntimeError as e:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail=str(e)) from e
    response = _file(content, XLSM, f"etats-financiers-dgi-{doc.template_version}.xlsm")
    response.headers["X-Akonta-Skipped-Cells"] = str(len(skipped))
    return response


@app.post("/pdf/financial-statements", dependencies=[Depends(require_service_key)])
def pdf_financial_statements(doc: FinancialStatementsDocument) -> Response:
    return _file(pdf.financial_statements_pdf(doc), PDF, f"etats-financiers-{doc.header.fiscal_year_label}.pdf")


@app.post("/pdf/financial-statements-sycebnl", dependencies=[Depends(require_service_key)])
def pdf_financial_statements_sycebnl(doc: SycebnlStatementsDocument, settings: Settings = Depends(get_settings)) -> Response:
    _check_size(len(doc.notes), settings)
    return _file(pdf_sycebnl.sycebnl_statements_pdf(doc), PDF, f"etats-financiers-sycebnl-{doc.header.fiscal_year_label}.pdf")
