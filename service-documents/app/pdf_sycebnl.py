"""PDF unique des états financiers SYCEBNL : bilan, compte de résultat, tableau des flux de trésorerie, notes annexes calculables."""
from reportlab.lib import colors
from reportlab.lib.units import mm
from reportlab.platypus import KeepTogether, LongTable, PageBreak, Paragraph, Spacer, TableStyle

from .formatting import fcfa, fcfa_total
from .models import NoteRow, StatementPostRow, SycebnlStatementsDocument
from .pdf import CELL, INK, META, NAVY, SAND, _build, _header_block
from .sycebnl import NOTES_NOT_PRODUCED, Row, balance_sheet_assets, balance_sheet_liabilities, income_statement

LIGHT = colors.HexColor("#EFEAE0")


def _percent(current: int, previous: int | None) -> str:
    if previous is None or previous == 0:
        return ""
    return f"{(current - previous) / abs(previous) * 100:.1f}".replace(".", ",") + " %"


def _table(data: list[list], widths: list[float], kinds: list[str], numeric_from: int) -> LongTable:
    """Tableau paginé ; `kinds` donne le type de chaque ligne hors en-tête : section, total, subtotal ou autre."""
    table = LongTable(data, colWidths=widths, repeatRows=1)
    style = [
        ("BACKGROUND", (0, 0), (-1, 0), SAND),
        ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
        ("FONTSIZE", (0, 0), (-1, -1), 7.5),
        ("LINEBELOW", (0, 0), (-1, 0), 0.8, NAVY),
        ("LINEBELOW", (0, 1), (-1, -1), 0.2, colors.HexColor("#DDD8CF")),
        ("ALIGN", (numeric_from, 0), (-1, -1), "RIGHT"),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
        ("TOPPADDING", (0, 0), (-1, -1), 2),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 2),
    ]
    for i, kind in enumerate(kinds, start=1):
        if kind in ("total", "subtotal"):
            style += [("FONTNAME", (0, i), (-1, i), "Helvetica-Bold"), ("BACKGROUND", (0, i), (-1, i), LIGHT)]
        elif kind == "section":
            style += [("FONTNAME", (0, i), (-1, i), "Helvetica-Bold"), ("BACKGROUND", (0, i), (-1, i), SAND)]
    table.setStyle(TableStyle(style))
    return table


def _label(row: Row) -> Paragraph:
    text = f"<b>{row.label}</b>" if row.kind in ("total", "section") else row.label
    return Paragraph(text, CELL)


def _amounts(row: Row, total_cols: bool = True) -> list[str]:
    if row.kind == "section":
        return [""] * len(row.values or [0])
    return [fcfa_total(v) if row.kind == "total" else fcfa(v) for v in row.values]


def _statement_rows(rows: list[Row], columns: int) -> tuple[list[list], list[str]]:
    data, kinds = [], []
    for r in rows:
        values = _amounts(r) if r.values else [""] * columns
        data.append([r.ref, _label(r), r.note, *values])
        kinds.append(r.kind)
    return data, kinds


def _post_map(rows: list[StatementPostRow]) -> dict[str, int]:
    return {r.post_code: r.amount for r in rows}


def _cash_flow_table(d: SycebnlStatementsDocument) -> LongTable:
    prev = _post_map(d.previous_cash_flow)
    head = ["Réf", "Flux de trésorerie", "Exercice N"] + (["Exercice N-1"] if d.has_previous else [])
    data, kinds = [head], []
    for p in d.cash_flow:
        is_total = p.post_code.startswith("Z")
        fmt = fcfa_total if is_total else fcfa
        row = [p.post_code, Paragraph(f"<b>{p.post_label}</b>" if is_total else p.post_label, CELL), fmt(p.amount)]
        if d.has_previous:
            row.append(fmt(prev.get(p.post_code, 0)))
        data.append(row)
        kinds.append("total" if is_total else "post")
    widths = [14 * mm, 182 * mm, 36 * mm] + ([36 * mm] if d.has_previous else [])
    return _table(data, widths, kinds, 2)


def _notes_in_order(notes: list[NoteRow]) -> list[tuple[str, str, list[NoteRow]]]:
    out: list[tuple[str, str, list[NoteRow]]] = []
    for n in notes:
        if not out or out[-1][0] != n.note_code:
            out.append((n.note_code, n.note_title, []))
        out[-1][2].append(n)
    return out


def _note_story(code: str, title: str, lines: list[NoteRow], has_previous: bool) -> list:
    block = [Paragraph(f"<b>Note {code} : {title}</b>", META), Spacer(1, 1.5 * mm)]
    empty = all(n.amount == 0 and not n.previous for n in lines)
    if empty:
        block.append(Paragraph("Aucun solde ni mouvement sur l'exercice.", CELL))
    else:
        head = ["Libellé", "Année N"] + (["Année N-1", "Variation", "%"] if has_previous else [])
        data, kinds = [head], []
        for n in lines:
            total = n.kind != "line"
            fmt = fcfa_total if total else fcfa
            row = [Paragraph(f"<b>{n.label}</b>" if total else n.label, CELL), fmt(n.amount)]
            if has_previous:
                prev = n.previous
                row += [fmt(prev) if prev is not None else "", fmt(n.amount - prev) if prev is not None else "", _percent(n.amount, prev)]
            data.append(row)
            kinds.append(n.kind)
        widths = [150 * mm, 36 * mm] + ([36 * mm, 36 * mm, 24 * mm] if has_previous else [])
        block.append(_table(data, widths, kinds, 1))
    block += [Spacer(1, 1.5 * mm), Paragraph("Commentaire : " + "." * 150, CELL), Spacer(1, 4 * mm)]
    return [KeepTogether(block)]


def sycebnl_statements_pdf(d: SycebnlStatementsDocument) -> bytes:
    story = _header_block(d.header)
    prev = d.has_previous

    # Bilan
    assets = balance_sheet_assets(d.assets, d.previous_assets, prev)
    data, kinds = _statement_rows(assets, 4 if prev else 3)
    head = ["Réf", "ACTIF", "Note", "Brut", "Amort. et dépréc.", "Net N"] + (["Net N-1"] if prev else [])
    story.append(Paragraph("<b>Bilan — Actif</b>", META))
    story.append(_table([head, *data], [12 * mm, 120 * mm, 18 * mm, 30 * mm, 30 * mm, 30 * mm] + ([30 * mm] if prev else []), kinds, 3))
    story.append(PageBreak())
    liabilities = balance_sheet_liabilities(d.liabilities, d.previous_liabilities, prev)
    data, kinds = _statement_rows(liabilities, 2 if prev else 1)
    head = ["Réf", "PASSIF", "Note", "Exercice N"] + (["Exercice N-1"] if prev else [])
    story.append(Paragraph("<b>Bilan — Passif</b>", META))
    story.append(_table([head, *data], [12 * mm, 170 * mm, 24 * mm, 36 * mm] + ([36 * mm] if prev else []), kinds, 3))

    # Compte de résultat
    story.append(PageBreak())
    income = income_statement(d.income, d.previous_income, prev)
    data, kinds = _statement_rows(income, 2 if prev else 1)
    head = ["Réf", "COMPTE DE RÉSULTAT", "Note", "Exercice N"] + (["Exercice N-1"] if prev else [])
    story.append(Paragraph("<b>Compte de résultat</b> (charges présentées en positif)", META))
    story.append(_table([head, *data], [12 * mm, 170 * mm, 24 * mm, 36 * mm] + ([36 * mm] if prev else []), kinds, 3))

    # Tableau des flux de trésorerie
    if d.cash_flow:
        story.append(PageBreak())
        story.append(Paragraph("<b>Tableau des flux de trésorerie</b> (encaissements +, décaissements -)", META))
        story.append(_cash_flow_table(d))

    # Notes annexes
    if d.notes:
        story.append(PageBreak())
        story.append(Paragraph("<b>Notes annexes</b>", META))
        story.append(Spacer(1, 2 * mm))
        for code, title, lines in _notes_in_order(d.notes):
            story += _note_story(code, title, lines, prev)
        story.append(Paragraph("<b>Notes non produites automatiquement</b> (à rédiger ou à compléter par le cabinet)", META))
        story.append(Spacer(1, 1.5 * mm))
        story.append(Paragraph("; ".join(f"Note {c} : {t}" for c, t in NOTES_NOT_PRODUCED) + ".", CELL))
    return _build(story, f"{d.header.entity_name} — États financiers SYCEBNL {d.header.fiscal_year_label}")
