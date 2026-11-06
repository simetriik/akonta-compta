"""Modèles des documents : l'appelant (Edge Function) fournit les données déjà calculées par PostgreSQL."""
from datetime import date
from typing import Literal

from pydantic import BaseModel, Field


class DocumentHeader(BaseModel):
    cabinet_name: str
    entity_name: str
    entity_tax_id: str | None = None
    fiscal_year_label: str
    period_from: date
    period_to: date
    title: str
    generated_by: str | None = None
    currency: str = "FCFA"


class TrialBalanceRow(BaseModel):
    account_code: str
    account_label: str
    opening_debit: int = 0
    opening_credit: int = 0
    period_debit: int = 0
    period_credit: int = 0
    closing_debit: int = 0
    closing_credit: int = 0


class TrialBalanceDocument(BaseModel):
    header: DocumentHeader
    rows: list[TrialBalanceRow] = Field(default_factory=list)


class Counterpart(BaseModel):
    code: str
    label: str = ""
    amount: int = 0


class LedgerLine(BaseModel):
    account_code: str
    account_label: str
    entry_date: date
    journal_code: str
    number: int
    reference: str | None = None
    label: str
    third_party_code: str | None = None
    third_party_name: str | None = None
    debit: int = 0
    credit: int = 0
    running_balance: int = 0
    letter_code: str | None = None
    # Contrepartie : compte principal, nombre d'autres comptes opposés, liste complète (calculées par PostgreSQL)
    counterpart_code: str | None = None
    counterpart_more: int = 0
    counterparts: list[Counterpart] = Field(default_factory=list)


class LedgerDocument(BaseModel):
    header: DocumentHeader
    lines: list[LedgerLine] = Field(default_factory=list)
    # « main » : contrepartie principale suivie de « + n » ; « all » : liste complète des comptes opposés
    counterpart_mode: Literal["main", "all"] = "main"


class JournalLine(BaseModel):
    entry_date: date
    number: int
    reference: str | None = None
    account_code: str
    account_label: str
    third_party_code: str | None = None
    label: str
    debit: int = 0
    credit: int = 0


class JournalDocument(BaseModel):
    header: DocumentHeader
    journal_code: str
    journal_label: str
    lines: list[JournalLine] = Field(default_factory=list)


class AgedBalanceRow(BaseModel):
    account_code: str
    third_party_code: str
    third_party_name: str
    d0_30: int = 0
    d31_60: int = 0
    d61_90: int = 0
    d91_180: int = 0
    over_180: int = 0
    total: int = 0


class AgedBalanceDocument(BaseModel):
    header: DocumentHeader
    side: Literal["debit", "credit"] = "debit"
    rows: list[AgedBalanceRow] = Field(default_factory=list)


class ReconciliationItem(BaseModel):
    date: date
    label: str
    reference: str | None = None
    amount: int


class ReconciliationDocument(BaseModel):
    header: DocumentHeader
    journal_code: str
    journal_label: str
    as_of: date
    book_balance: int
    bank_balance: int
    deposits_in_transit: list[ReconciliationItem] = Field(default_factory=list)      # comptabilisés, non crédités par la banque
    outstanding_payments: list[ReconciliationItem] = Field(default_factory=list)     # comptabilisés, non débités par la banque
    unmatched_bank_credits: list[ReconciliationItem] = Field(default_factory=list)   # crédités par la banque, non comptabilisés
    unmatched_bank_debits: list[ReconciliationItem] = Field(default_factory=list)    # débités par la banque, non comptabilisés
    difference: int = 0


class StatementPostRow(BaseModel):
    post_code: str
    post_label: str
    column_role: str = "amount"
    amount: int = 0


class FinancialStatementsDocument(BaseModel):
    header: DocumentHeader
    assets: list[StatementPostRow] = Field(default_factory=list)
    liabilities: list[StatementPostRow] = Field(default_factory=list)
    income: list[StatementPostRow] = Field(default_factory=list)
    previous_assets: list[StatementPostRow] = Field(default_factory=list)
    previous_liabilities: list[StatementPostRow] = Field(default_factory=list)
    previous_income: list[StatementPostRow] = Field(default_factory=list)


class NoteRow(BaseModel):
    """Ligne d'une note annexe : montants de N et de N-1 (absent sans exercice précédent)."""
    note_code: str
    note_title: str
    line_code: str
    label: str
    kind: Literal["line", "subtotal", "total"] = "line"
    amount: int = 0
    previous: int | None = None
    sort_order: int = 0


class SycebnlStatementsDocument(BaseModel):
    """États financiers SYCEBNL : bilan, compte de résultat, tableau des flux de trésorerie et notes annexes calculables."""
    header: DocumentHeader
    assets: list[StatementPostRow] = Field(default_factory=list)
    liabilities: list[StatementPostRow] = Field(default_factory=list)
    income: list[StatementPostRow] = Field(default_factory=list)
    cash_flow: list[StatementPostRow] = Field(default_factory=list)
    previous_assets: list[StatementPostRow] = Field(default_factory=list)
    previous_liabilities: list[StatementPostRow] = Field(default_factory=list)
    previous_income: list[StatementPostRow] = Field(default_factory=list)
    previous_cash_flow: list[StatementPostRow] = Field(default_factory=list)
    notes: list[NoteRow] = Field(default_factory=list)
    has_previous: bool = False


class InvoiceParty(BaseModel):
    name: str | None = None
    ifu: str | None = None
    contact: str | None = None
    address: str | None = None


class InvoiceLineDoc(BaseModel):
    code: str | None = None
    name: str
    quantity: float
    price: int            # prix unitaire TTC
    tax_group: Literal["A", "B"]
    amount: int           # quantité × prix, arrondi : montant TTC de la ligne


class InvoicePaymentDoc(BaseModel):
    name: str
    amount: int


class InvoiceSecurity(BaseModel):
    """Éléments de sécurité renvoyés par l'e-MCF : à reproduire à l'identique sur la facture normalisée."""
    code_mecef: str
    qr_code: str
    counters: str
    nim: str
    date_time: str


class InvoiceDocument(BaseModel):
    """Facture normalisée e-MECeF (FV ou FA) prête à imprimer."""
    invoice_type: Literal["FV", "FA"]
    is_test: bool = True
    seller: InvoiceParty
    client: InvoiceParty = Field(default_factory=InvoiceParty)
    operator: str
    reference: str | None = None            # code MECeF/DGI de la facture d'origine (avoir)
    lines: list[InvoiceLineDoc] = Field(default_factory=list)
    total_a: int = 0                        # total du groupe A (exonéré)
    total_b: int = 0                        # total du groupe B (taxable)
    ht_b: int = 0
    vat_b: int = 0
    vat_rate: int = 18
    aib: int = 0
    aib_rate: int = 0
    total: int
    payments: list[InvoicePaymentDoc] = Field(default_factory=list)
    security: InvoiceSecurity
    commercial_message: str | None = None
