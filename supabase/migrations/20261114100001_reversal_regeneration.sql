-- Extournes N+1 : relancer la génération avant validation remplace le brouillard (AN-40, rejeu de la recette du 14/11/2026).
-- generated_entry supprime l'ancien brouillard ; les régularisations et réévaluations qui le référençaient bloquaient la suppression.
-- Le lien est reposé par generate_reversals sur le nouveau brouillard : on l'annule simplement à la suppression.
alter table public.accruals drop constraint accruals_reversal_entry_id_fkey,
  add constraint accruals_reversal_entry_id_fkey foreign key (reversal_entry_id) references public.entries (id) on delete set null;
alter table public.fx_revaluations drop constraint fx_revaluations_reversal_entry_id_fkey,
  add constraint fx_revaluations_reversal_entry_id_fkey foreign key (reversal_entry_id) references public.entries (id) on delete set null;
