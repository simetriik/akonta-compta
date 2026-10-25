"""Exports Excel (openpyxl) des états de consultation."""
from io import BytesIO

from openpyxl import Workbook
from openpyxl.styles import Alignment, Font, PatternFill
from openpyxl.utils import get_column_letter

from .models import LedgerDocument, TrialBalanceDocument

HEADER_FILL = PatternFill("solid", fgColor="F7F3EC")
NUMBER_FORMAT = '#,##0;[Red]-#,##0;""'


def _sheet_header(ws, header, titles: list[str]) -> int:
    ws["A1"] = header.title
    ws["A1"].font = Font(bold=True, size=13)
    ws["A2"] = f"{header.entity_name} · Exercice {header.fiscal_year_label} · du {header.period_from:%d/%m/%Y} au {header.period_to:%d/%m/%Y}"
    ws["A3"] = header.cabinet_name
    row = 5
    for col, title in enumerate(titles, start=1):
        cell = ws.cell(row=row, column=col, value=title)
        cell.font = Font(bold=True)
        cell.fill = HEADER_FILL
        cell.alignment = Alignment(horizontal="center")
    ws.freeze_panes = f"A{row + 1}"   # (ne pas créer la cellule : openpyxl décalerait les append)
    return row + 1


def _finish(wb: Workbook) -> bytes:
    buf = BytesIO()
    wb.save(buf)
    return buf.getvalue()


def trial_balance_xlsx(d: TrialBalanceDocument) -> bytes:
    wb = Workbook()
    ws = wb.active
    ws.title = "Balance"
    titles = ["Compte", "Intitulé", "Ouverture débit", "Ouverture crédit", "Mouvements débit", "Mouvements crédit", "Solde débit", "Solde crédit"]
    row = _sheet_header(ws, d.header, titles)
    first = row
    for r in d.rows:
        ws.append([r.account_code, r.account_label, r.opening_debit, r.opening_credit, r.period_debit, r.period_credit, r.closing_debit, r.closing_credit])
        row += 1
    if d.rows:
        ws.cell(row=row, column=2, value="Totaux").font = Font(bold=True)
        for col in range(3, 9):
            letter = get_column_letter(col)
            cell = ws.cell(row=row, column=col, value=f"=SUM({letter}{first}:{letter}{row - 1})")
            cell.font = Font(bold=True)
    for r in ws.iter_rows(min_row=first, max_row=row, min_col=3, max_col=8):
        for cell in r:
            cell.number_format = NUMBER_FORMAT
    ws.column_dimensions["A"].width = 12
    ws.column_dimensions["B"].width = 48
    for col in range(3, 9):
        ws.column_dimensions[get_column_letter(col)].width = 18
    return _finish(wb)


def general_ledger_xlsx(d: LedgerDocument) -> bytes:
    wb = Workbook()
    ws = wb.active
    ws.title = "Grand livre"
    titles = ["Compte", "Intitulé compte", "Date", "Journal", "N°", "Référence", "Libellé", "Tiers", "Débit", "Crédit", "Solde", "Lettrage"]
    row = _sheet_header(ws, d.header, titles)
    first = row
    for line in d.lines:
        ws.append([line.account_code, line.account_label, line.entry_date, line.journal_code, line.number, line.reference or "",
                   line.label, line.third_party_code or "", line.debit, line.credit, line.running_balance, line.letter_code or ""])
        row += 1
    for r in ws.iter_rows(min_row=first, max_row=row, min_col=9, max_col=11):
        for cell in r:
            cell.number_format = NUMBER_FORMAT
    for r in ws.iter_rows(min_row=first, max_row=row, min_col=3, max_col=3):
        for cell in r:
            cell.number_format = "DD/MM/YYYY"
    widths = [12, 36, 12, 8, 8, 16, 48, 10, 16, 16, 16, 8]
    for i, w in enumerate(widths, start=1):
        ws.column_dimensions[get_column_letter(i)].width = w
    return _finish(wb)
