"""Facture normalisée e-MECeF en PDF (A4 portrait) : lignes, totaux par groupe de taxe, éléments de sécurité et QR code.
La DGI vérifie à l'audit que les montants, les articles et les éléments de sécurité (mêmes étiquettes et valeurs) sont
identiques à ceux du serveur, et que le QR code est présent ; sur le serveur de test, « TEST FACTURE » doit apparaître."""
from io import BytesIO

from reportlab.graphics import renderPDF
from reportlab.graphics.barcode import qr
from reportlab.graphics.shapes import Drawing
from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_RIGHT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.platypus import Flowable, KeepTogether, Paragraph, SimpleDocTemplate, Spacer, Table, TableStyle

from .formatting import fcfa_total
from .models import InvoiceDocument, InvoiceParty

INK = colors.HexColor("#1A1A18")
NAVY = colors.HexColor("#1E2A5A")
SAND = colors.HexColor("#F7F3EC")
RED = colors.HexColor("#B3261E")

_styles = getSampleStyleSheet()
TITLE = ParagraphStyle("inv_title", parent=_styles["Title"], fontSize=15, textColor=INK, alignment=0, spaceAfter=1 * mm)
NORMAL = ParagraphStyle("inv_normal", parent=_styles["Normal"], fontSize=9, leading=11.5, textColor=INK)
SMALL = ParagraphStyle("inv_small", parent=NORMAL, fontSize=8, leading=10)
CELL_R = ParagraphStyle("inv_cell_r", parent=NORMAL, alignment=TA_RIGHT)
TEST_BANNER = ParagraphStyle("inv_test", parent=NORMAL, fontSize=13, textColor=RED, alignment=TA_CENTER, fontName="Helvetica-Bold")

TYPE_LABELS = {"FV": "FACTURE DE VENTE", "FA": "FACTURE D'AVOIR"}
GROUP_LABELS = {"A": "A – Exonéré", "B": "B – Taxable"}


class _QrCode(Flowable):
    """QR code dessiné en vectoriel avec reportlab (aucune bibliothèque supplémentaire)."""

    def __init__(self, value: str, size: float):
        super().__init__()
        self.value, self.size = value, size
        self.width = self.height = size

    def draw(self) -> None:
        widget = qr.QrCodeWidget(self.value, barLevel="M")
        x0, y0, x1, y1 = widget.getBounds()
        drawing = Drawing(self.size, self.size, transform=[self.size / (x1 - x0), 0, 0, self.size / (y1 - y0), 0, 0])
        drawing.add(widget)
        renderPDF.draw(drawing, self.canv, 0, 0)


def _party_lines(p: InvoiceParty) -> str:
    parts = [f"<b>{p.name}</b>" if p.name else None, f"IFU {p.ifu}" if p.ifu else None, p.address, p.contact]
    return "<br/>".join(x for x in parts if x) or "—"


def _money(n: int) -> str:
    return fcfa_total(n)


def invoice_pdf(doc: InvoiceDocument) -> bytes:
    buf = BytesIO()
    pdf = SimpleDocTemplate(buf, pagesize=A4, leftMargin=15 * mm, rightMargin=15 * mm, topMargin=14 * mm, bottomMargin=14 * mm,
                            title=f"{TYPE_LABELS[doc.invoice_type]} {doc.security.code_mecef}", author="Akonta")
    story: list = []
    if doc.is_test:
        story += [Paragraph("TEST FACTURE", TEST_BANNER), Spacer(1, 2 * mm)]
    story += [Paragraph(TYPE_LABELS[doc.invoice_type], TITLE)]
    if doc.invoice_type == "FA" and doc.reference:
        story += [Paragraph(f"Facture d'origine (référence) : <b>{doc.reference}</b>", NORMAL)]
    story += [Spacer(1, 3 * mm)]

    parties = Table([[Paragraph("<b>Vendeur</b><br/>" + _party_lines(doc.seller), NORMAL),
                      Paragraph("<b>Client</b><br/>" + _party_lines(doc.client), NORMAL)]], colWidths=[90 * mm, 90 * mm])
    parties.setStyle(TableStyle([("VALIGN", (0, 0), (-1, -1), "TOP"), ("BOX", (0, 0), (-1, -1), 0.5, colors.HexColor("#DDD8CF")),
                                 ("INNERGRID", (0, 0), (-1, -1), 0.5, colors.HexColor("#DDD8CF")), ("BACKGROUND", (0, 0), (-1, -1), SAND)]))
    story += [parties, Spacer(1, 2 * mm), Paragraph(f"Opérateur : {doc.operator}", SMALL), Spacer(1, 4 * mm)]

    rows = [["Désignation", "Qté", "Prix unitaire TTC", "Groupe", "Montant TTC"]]
    for l in doc.lines:
        qty = f"{l.quantity:g}".replace(".", ",")
        rows.append([Paragraph(l.name + (f" <font size=7>({l.code})</font>" if l.code else ""), NORMAL), qty,
                     _money(l.price), l.tax_group, _money(l.amount)])
    lines_table = Table(rows, colWidths=[74 * mm, 18 * mm, 32 * mm, 18 * mm, 38 * mm], repeatRows=1)
    lines_table.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), SAND), ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"), ("FONTSIZE", (0, 0), (-1, -1), 8.5),
        ("LINEBELOW", (0, 0), (-1, 0), 0.8, NAVY), ("LINEBELOW", (0, 1), (-1, -1), 0.2, colors.HexColor("#DDD8CF")),
        ("ALIGN", (1, 0), (2, -1), "RIGHT"), ("ALIGN", (4, 0), (4, -1), "RIGHT"), ("ALIGN", (3, 0), (3, -1), "CENTER"),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
    ]))
    story += [lines_table, Spacer(1, 4 * mm)]

    totals = [[GROUP_LABELS["A"] + " (total)", _money(doc.total_a)],
              [GROUP_LABELS["B"] + " (total)", _money(doc.total_b)],
              [f"Montant HT groupe B", _money(doc.ht_b)],
              [f"TVA groupe B ({doc.vat_rate} %)", _money(doc.vat_b)]]
    if doc.aib:
        totals.append([f"AIB ({doc.aib_rate} %)", _money(doc.aib)])
    totals.append(["TOTAL", _money(doc.total)])
    totals_table = Table(totals, colWidths=[60 * mm, 38 * mm], hAlign="RIGHT")
    totals_table.setStyle(TableStyle([("FONTSIZE", (0, 0), (-1, -1), 9), ("ALIGN", (1, 0), (1, -1), "RIGHT"),
                                      ("FONTNAME", (0, -1), (-1, -1), "Helvetica-Bold"), ("LINEABOVE", (0, -1), (-1, -1), 0.8, INK)]))
    story += [totals_table]
    if doc.payments:
        story += [Spacer(1, 2 * mm), Paragraph("Paiement : " + " · ".join(f"{p.name} {_money(p.amount)}" for p in doc.payments), SMALL)]
    if doc.commercial_message:
        story += [Spacer(1, 3 * mm), Paragraph(doc.commercial_message, SMALL)]

    # Éléments de sécurité : mêmes étiquettes et valeurs que la réponse de la DGI.
    s = doc.security
    security_text = Paragraph(
        f"<b>Code MECeF/DGI</b> : {s.code_mecef}<br/><b>MECeF NIM</b> : {s.nim}<br/>"
        f"<b>MECeF Compteurs</b> : {s.counters}<br/><b>MECeF Heure</b> : {s.date_time}", NORMAL)
    security = Table([[security_text, _QrCode(s.qr_code, 34 * mm)]], colWidths=[140 * mm, 40 * mm])
    security.setStyle(TableStyle([("VALIGN", (0, 0), (-1, -1), "MIDDLE"), ("BOX", (0, 0), (-1, -1), 0.8, NAVY), ("TOPPADDING", (0, 0), (-1, -1), 4),
                                  ("BOTTOMPADDING", (0, 0), (-1, -1), 4)]))
    story += [Spacer(1, 6 * mm), KeepTogether([security])]
    pdf.build(story)
    return buf.getvalue()
