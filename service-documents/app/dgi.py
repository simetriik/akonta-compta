"""Remplissage du modèle Excel DGI (états financiers) en conservant les macros (`openpyxl`, `keep_vba=True`).

Le service ne connaît pas la comptabilité : il reçoit la liste des cellules à écrire (feuille, cellule, valeur),
établie par PostgreSQL à partir de la cartographie versionnée `dgi_cell_mappings` et des états financiers générés.
"""
import os
from io import BytesIO
from pathlib import Path

from openpyxl import load_workbook
from pydantic import BaseModel, Field


class DgiCell(BaseModel):
    sheet: str
    cell: str
    value: str | int | float | None


class DgiDocument(BaseModel):
    template_version: str = "SN-2025"
    cells: list[DgiCell] = Field(default_factory=list)


def template_path() -> Path:
    p = os.environ.get("AKONTA_DGI_TEMPLATE")
    if not p:
        raise RuntimeError("AKONTA_DGI_TEMPLATE manquante : chemin du modèle Excel DGI (.xlsm)")
    path = Path(p)
    if not path.exists():
        raise RuntimeError(f"Modèle DGI introuvable : {path}")
    return path


def fill_dgi_workbook(doc: DgiDocument, template: Path | None = None) -> tuple[bytes, list[str]]:
    """Écrit les cellules dans une copie du modèle et renvoie le classeur (.xlsm) et la liste des cellules ignorées."""
    path = template or template_path()
    wb = load_workbook(path, keep_vba=True)
    skipped: list[str] = []
    for c in doc.cells:
        if c.sheet not in wb.sheetnames:
            skipped.append(f"{c.sheet}!{c.cell} (feuille inconnue)")
            continue
        ws = wb[c.sheet]
        try:
            target = ws[c.cell]
        except (ValueError, KeyError):
            skipped.append(f"{c.sheet}!{c.cell} (cellule invalide)")
            continue
        if isinstance(target.value, str) and target.value.startswith("="):
            skipped.append(f"{c.sheet}!{c.cell} (formule conservée)")
            continue
        target.value = c.value
    buf = BytesIO()
    wb.save(buf)
    return buf.getvalue(), skipped
