"""Rendu PDF avec reportlab : documents comptables en paysage, en-tête d'entité, tableaux paginés, totaux."""
from io import BytesIO

from reportlab.lib import colors
from reportlab.lib.enums import TA_RIGHT
from reportlab.lib.pagesizes import A4, landscape
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.platypus import LongTable, Paragraph, SimpleDocTemplate, Spacer, TableStyle

from .formatting import fcfa, fcfa_total, fr_date
from .models import AgedBalanceDocument, DocumentHeader, FinancialStatementsDocument, JournalDocument, LedgerDocument, ReconciliationDocument, StatementPostRow, TrialBalanceDocument

INK = colors.HexColor("#1A1A18")
TERRACOTTA = colors.HexColor("#B5472A")
SAND = colors.HexColor("#F7F3EC")

_styles = getSampleStyleSheet()
TITLE = ParagraphStyle("akonta_title", parent=_styles["Title"], fontSize=14, textColor=INK, spaceAfter=2 * mm, alignment=0)
META = ParagraphStyle("akonta_meta", parent=_styles["Normal"], fontSize=8.5, textColor=INK, leading=11)
CELL = ParagraphStyle("akonta_cell", parent=_styles["Normal"], fontSize=7.5, leading=9, textColor=INK)
CELL_R = ParagraphStyle("akonta_cell_r", parent=CELL, alignment=TA_RIGHT)


def _header_block(h: DocumentHeader) -> list:
    return [
        Paragraph(h.title, TITLE),
        Paragraph(
            f"<b>{h.entity_name}</b>" + (f" — IFU {h.entity_tax_id}" if h.entity_tax_id else "")
            + f" · Exercice {h.fiscal_year_label} · du {fr_date(h.period_from)} au {fr_date(h.period_to)} · montants en {h.currency}",
            META,
        ),
        Paragraph(f"{h.cabinet_name}" + (f" · édité par {h.generated_by}" if h.generated_by else ""), META),
        Spacer(1, 4 * mm),
    ]


def _table(data: list[list], col_widths: list[float], numeric_from: int, total_row: bool) -> LongTable:
    table = LongTable(data, colWidths=col_widths, repeatRows=1)
    style = [
        ("BACKGROUND", (0, 0), (-1, 0), SAND),
        ("TEXTCOLOR", (0, 0), (-1, 0), INK),
        ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
        ("FONTSIZE", (0, 0), (-1, -1), 7.5),
        ("LINEBELOW", (0, 0), (-1, 0), 0.8, TERRACOTTA),
        ("LINEBELOW", (0, 1), (-1, -1), 0.2, colors.HexColor("#DDD8CF")),
        ("ALIGN", (numeric_from, 1), (-1, -1), "RIGHT"),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
        ("TOPPADDING", (0, 0), (-1, -1), 2),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 2),
    ]
    if total_row:
        style += [("FONTNAME", (0, -1), (-1, -1), "Helvetica-Bold"), ("LINEABOVE", (0, -1), (-1, -1), 0.8, INK)]
    table.setStyle(TableStyle(style))
    return table


def _build(story: list, footer_title: str) -> bytes:
    buf = BytesIO()
    doc = SimpleDocTemplate(buf, pagesize=landscape(A4), leftMargin=12 * mm, rightMargin=12 * mm,
                            topMargin=12 * mm, bottomMargin=12 * mm, title=footer_title, author="Akonta")

    def on_page(canvas, document):
        canvas.saveState()
        canvas.setFont("Helvetica", 7)
        canvas.setFillColor(INK)
        canvas.drawString(12 * mm, 7 * mm, footer_title)
        canvas.drawRightString(landscape(A4)[0] - 12 * mm, 7 * mm, f"Page {document.page}")
        canvas.restoreState()

    doc.build(story, onFirstPage=on_page, onLaterPages=on_page)
    return buf.getvalue()


def trial_balance_pdf(d: TrialBalanceDocument) -> bytes:
    head = ["Compte", "Intitulé", "Ouverture D", "Ouverture C", "Mouvements D", "Mouvements C", "Solde D", "Solde C"]
    rows = [head]
    totals = [0] * 6
    for r in d.rows:
        vals = [r.opening_debit, r.opening_credit, r.period_debit, r.period_credit, r.closing_debit, r.closing_credit]
        totals = [t + v for t, v in zip(totals, vals)]
        rows.append([r.account_code, Paragraph(r.account_label, CELL), *[fcfa(v) for v in vals]])
    rows.append(["", "Totaux", *[fcfa_total(t) for t in totals]])
    widths = [22 * mm, 78 * mm] + [28 * mm] * 6
    story = _header_block(d.header) + [_table(rows, widths, 2, True)]
    return _build(story, f"{d.header.entity_name} — {d.header.title}")


def general_ledger_pdf(d: LedgerDocument) -> bytes:
    head = ["Date", "Jal", "N°", "Référence", "Libellé", "Tiers", "Débit", "Crédit", "Solde", "Let."]
    widths = [18 * mm, 10 * mm, 14 * mm, 24 * mm, 92 * mm, 18 * mm, 26 * mm, 26 * mm, 28 * mm, 10 * mm]
    story = _header_block(d.header)
    current = None
    rows: list[list] = []
    sub_d = sub_c = 0

    def flush():
        nonlocal rows, sub_d, sub_c
        if rows:
            rows.append(["", "", "", "", "Total compte", "", fcfa_total(sub_d), fcfa_total(sub_c), fcfa_total(sub_d - sub_c), ""])
            story.append(_table([head] + rows, widths, 6, True))
            story.append(Spacer(1, 3 * mm))
        rows, sub_d, sub_c = [], 0, 0

    for line in d.lines:
        key = (line.account_code, line.account_label)
        if key != current:
            flush()
            current = key
            story.append(Paragraph(f"<b>{line.account_code}</b> — {line.account_label}", META))
        rows.append([fr_date(line.entry_date), line.journal_code, str(line.number), line.reference or "",
                     Paragraph(line.label, CELL), line.third_party_code or "", fcfa(line.debit), fcfa(line.credit),
                     fcfa_total(line.running_balance), line.letter_code or ""])
        sub_d += line.debit
        sub_c += line.credit
    flush()
    if not d.lines:
        story.append(Paragraph("Aucune écriture validée sur la période.", META))
    return _build(story, f"{d.header.entity_name} — {d.header.title}")


def journal_pdf(d: JournalDocument) -> bytes:
    head = ["Date", "N°", "Référence", "Compte", "Intitulé", "Tiers", "Libellé", "Débit", "Crédit"]
    widths = [18 * mm, 14 * mm, 24 * mm, 20 * mm, 50 * mm, 18 * mm, 70 * mm, 26 * mm, 26 * mm]
    rows: list[list] = [head]
    td = tc = 0
    for line in d.lines:
        rows.append([fr_date(line.entry_date), str(line.number), line.reference or "", line.account_code,
                     Paragraph(line.account_label, CELL), line.third_party_code or "", Paragraph(line.label, CELL),
                     fcfa(line.debit), fcfa(line.credit)])
        td += line.debit
        tc += line.credit
    rows.append(["", "", "", "", "", "", "Total journal", fcfa_total(td), fcfa_total(tc)])
    story = _header_block(d.header) + [Paragraph(f"Journal <b>{d.journal_code}</b> — {d.journal_label}", META), Spacer(1, 2 * mm),
                                       _table(rows, widths, 7, True)]
    return _build(story, f"{d.header.entity_name} — {d.header.title}")


def aged_balance_pdf(d: AgedBalanceDocument) -> bytes:
    head = ["Compte", "Code", "Tiers", "0-30 j", "31-60 j", "61-90 j", "91-180 j", "> 180 j", "Total"]
    rows: list[list] = [head]
    totals = [0] * 6
    for r in d.rows:
        vals = [r.d0_30, r.d31_60, r.d61_90, r.d91_180, r.over_180, r.total]
        totals = [t + v for t, v in zip(totals, vals)]
        rows.append([r.account_code, r.third_party_code, Paragraph(r.third_party_name, CELL), *[fcfa(v) for v in vals]])
    rows.append(["", "", "Totaux", *[fcfa_total(t) for t in totals]])
    widths = [22 * mm, 20 * mm, 70 * mm] + [26 * mm] * 6
    story = _header_block(d.header) + [_table(rows, widths, 3, True)]
    return _build(story, f"{d.header.entity_name} — {d.header.title}")


def reconciliation_pdf(d: ReconciliationDocument) -> bytes:
    """État de rapprochement bancaire : solde banque ± suspens = solde comptable, listes détaillées, écart."""
    story = _header_block(d.header)
    story.append(Paragraph(f"Journal <b>{d.journal_code}</b> — {d.journal_label} · état au {fr_date(d.as_of)}", META))
    story.append(Spacer(1, 3 * mm))

    def total(items):
        return sum(i.amount for i in items)

    summary = [
        ["Solde du relevé bancaire", fcfa_total(d.bank_balance)],
        ["+ Encaissements comptabilisés non crédités", fcfa_total(total(d.deposits_in_transit))],
        ["- Décaissements comptabilisés non débités", fcfa_total(total(d.outstanding_payments))],
        ["+ Débits bancaires non comptabilisés", fcfa_total(total(d.unmatched_bank_debits))],
        ["- Crédits bancaires non comptabilisés", fcfa_total(total(d.unmatched_bank_credits))],
        ["= Solde comptable attendu", fcfa_total(d.bank_balance + total(d.deposits_in_transit) - total(d.outstanding_payments) + total(d.unmatched_bank_debits) - total(d.unmatched_bank_credits))],
        ["Solde comptable (grand livre)", fcfa_total(d.book_balance)],
        ["Écart", fcfa_total(d.difference)],
    ]
    story.append(_table(summary, [120 * mm, 40 * mm], 1, True))
    story.append(Spacer(1, 5 * mm))
    for title, items in [("Encaissements comptabilisés non crédités", d.deposits_in_transit), ("Décaissements comptabilisés non débités", d.outstanding_payments),
                         ("Débits bancaires non comptabilisés", d.unmatched_bank_debits), ("Crédits bancaires non comptabilisés", d.unmatched_bank_credits)]:
        if not items:
            continue
        story.append(Paragraph(f"<b>{title}</b>", META))
        rows = [["Date", "Référence", "Libellé", "Montant"]] + [[fr_date(i.date), i.reference or "", Paragraph(i.label, CELL), fcfa(i.amount)] for i in items]
        rows.append(["", "", "Total", fcfa_total(total(items))])
        story.append(_table(rows, [24 * mm, 30 * mm, 140 * mm, 36 * mm], 3, True))
        story.append(Spacer(1, 3 * mm))
    status = "Écart nul : état rapproché." if d.difference == 0 else "Écart non nul : état provisoire."
    story.append(Paragraph(status, META))
    return _build(story, f"{d.header.entity_name} — Rapprochement {d.journal_code} au {fr_date(d.as_of)}")


def _posts_by_code(rows: list[StatementPostRow]) -> dict:
    out: dict = {}
    for r in rows:
        e = out.setdefault(r.post_code, {"label": r.post_label, "gross": 0, "dep": 0, "amount": 0})
        if r.column_role == "gross":
            e["gross"] = r.amount
        elif r.column_role == "depreciation":
            e["dep"] = r.amount
        else:
            e["amount"] = r.amount
    return out


def financial_statements_pdf(d: FinancialStatementsDocument) -> bytes:
    """Bilan (actif / passif) et compte de résultat SYSCOHADA système normal, avec colonne N-1."""
    story = _header_block(d.header)
    assets, prev_assets = _posts_by_code(d.assets), _posts_by_code(d.previous_assets)
    rows = [["Réf", "Actif", "Brut", "Amort. / dépréc.", "Net", "Net N-1"]]
    ta = [0, 0, 0, 0]
    for code, e in assets.items():
        net = e["gross"] - e["dep"]
        prev = prev_assets.get(code, {"gross": 0, "dep": 0})
        pn = prev["gross"] - prev["dep"]
        ta = [ta[0] + e["gross"], ta[1] + e["dep"], ta[2] + net, ta[3] + pn]
        rows.append([code, Paragraph(e["label"], CELL), fcfa(e["gross"]), fcfa(e["dep"]), fcfa_total(net), fcfa(pn)])
    rows.append(["", "TOTAL ACTIF", fcfa_total(ta[0]), fcfa_total(ta[1]), fcfa_total(ta[2]), fcfa_total(ta[3])])
    story.append(Paragraph("<b>Bilan — Actif</b>", META))
    story.append(_table(rows, [14 * mm, 110 * mm, 36 * mm, 36 * mm, 36 * mm, 36 * mm], 2, True))
    story.append(Spacer(1, 5 * mm))
    liab, prev_liab = _posts_by_code(d.liabilities), _posts_by_code(d.previous_liabilities)
    rows = [["Réf", "Passif", "Net", "Net N-1"]]
    tl = [0, 0]
    for code, e in liab.items():
        pn = prev_liab.get(code, {"amount": 0})["amount"]
        tl = [tl[0] + e["amount"], tl[1] + pn]
        rows.append([code, Paragraph(e["label"], CELL), fcfa_total(e["amount"]), fcfa(pn)])
    rows.append(["", "TOTAL PASSIF", fcfa_total(tl[0]), fcfa_total(tl[1])])
    story.append(Paragraph("<b>Bilan — Passif</b>", META))
    story.append(_table(rows, [14 * mm, 182 * mm, 36 * mm, 36 * mm], 2, True))
    story.append(Spacer(1, 5 * mm))
    inc, prev_inc = _posts_by_code(d.income), _posts_by_code(d.previous_income)
    rows = [["Réf", "Compte de résultat", "Exercice N", "Exercice N-1"]]
    ti = [0, 0]
    for code, e in inc.items():
        pn = prev_inc.get(code, {"amount": 0})["amount"]
        ti = [ti[0] + e["amount"], ti[1] + pn]
        rows.append([code, Paragraph(e["label"], CELL), fcfa_total(e["amount"]), fcfa(pn)])
    rows.append(["XI", "RÉSULTAT NET", fcfa_total(ti[0]), fcfa_total(ti[1])])
    story.append(Paragraph("<b>Compte de résultat</b> (produits positifs, charges négatives)", META))
    story.append(_table(rows, [14 * mm, 182 * mm, 36 * mm, 36 * mm], 2, True))
    return _build(story, f"{d.header.entity_name} — États financiers {d.header.fiscal_year_label}")
