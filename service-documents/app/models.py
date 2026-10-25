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


class LedgerLine(BaseModel):
    account_code: str
    account_label: str
    entry_date: date
    journal_code: str
    number: int
    reference: str | None = None
    label: str
    third_party_code: str | None = None
    debit: int = 0
    credit: int = 0
    running_balance: int = 0
    letter_code: str | None = None


class LedgerDocument(BaseModel):
    header: DocumentHeader
    lines: list[LedgerLine] = Field(default_factory=list)


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
