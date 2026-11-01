-- Pièces justificatives (D-040) : par défaut, l'application prévient (sans bloquer) quand on valide une écriture sans pièce jointe.
-- Le cabinet peut désactiver cet avertissement dans ses paramètres.
alter table public.cabinets add column warn_missing_document boolean not null default true;
comment on column public.cabinets.warn_missing_document is 'Avertir à la validation d''une écriture sans pièce jointe (non bloquant).';
