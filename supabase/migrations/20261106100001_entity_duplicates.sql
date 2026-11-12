-- Recette du 05/11/2026, point 8 : doublons de dossiers.
-- Règle : un client = un dossier. Trois protections s'ajoutent à l'index unique existant sur l'IFU
-- (qui ne protège rien quand l'IFU est vide, cas du doublon « Maître ASSANI ») :
--   1. idempotence : une demande de création porte un identifiant (request_id) ; la rejouer ne crée rien de plus ;
--   2. homonyme : à la création, un dossier du même cabinet portant le même nom (sans casse ni accents) est refusé
--      quand l'un des deux n'a pas d'IFU (réglage cabinet block_homonym_entities, activé par défaut) ;
--   3. reprise : suppression d'un dossier en double tant qu'il ne contient aucune donnée de travail.
-- Aucune donnée existante n'est modifiée ni supprimée par cette migration.

alter table public.entities add column request_id uuid;
comment on column public.entities.request_id is 'Identifiant de la demande de création (idempotence) : rejouer la même demande ne crée pas de second dossier.';
create unique index entities_request_unique on public.entities (cabinet_id, request_id) where request_id is not null;

alter table public.cabinets add column block_homonym_entities boolean not null default true;
comment on column public.cabinets.block_homonym_entities is 'Refuse la création d''un dossier homonyme d''un dossier existant quand l''un des deux n''a pas d''IFU (décision provisoire, à valider par le cabinet).';

create or replace function public.entities_guard_homonym()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_block boolean;
begin
  select block_homonym_entities into v_block from public.cabinets where id = new.cabinet_id;
  if coalesce(v_block, true) and exists (
    select 1 from public.entities e
     where e.cabinet_id = new.cabinet_id
       and public.norm_label(e.name) = public.norm_label(new.name)
       and (e.tax_id is null or nullif(trim(new.tax_id), '') is null)
  ) then
    raise exception 'Un dossier nommé « % » existe déjà. Ouvrez-le depuis la liste des dossiers, ou renseignez un IFU pour distinguer deux clients homonymes.', new.name
      using errcode = '23505';
  end if;
  return new;
end $$;

create trigger entities_guard_homonym before insert on public.entities
  for each row execute function public.entities_guard_homonym();

-- Suppression d'un dossier en double encore vide. Réservée à qui gère les dossiers ; refuse dès qu'il y a
-- une écriture, une pièce, un tiers, un import, une facture, un relevé ou un état d'inventaire/clôture.
-- Les structures posées à l'ouverture (plan de comptes, journaux, exercice, périodes, modèles, dirigeants) partent avec lui.
create or replace function public.delete_empty_duplicate_entity(p_entity uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_cabinet uuid := public.current_cabinet_id();
  v_name text;
  v_table text;
  v_used bigint;
begin
  if v_cabinet is null or not public.has_permission(p_entity, 'entities.manage') then
    raise exception 'Permission refusée : entities.manage' using errcode = '42501';
  end if;
  select name into v_name from public.entities where id = p_entity and cabinet_id = v_cabinet;
  if not found then
    raise exception 'Dossier introuvable' using errcode = 'P0002';
  end if;
  foreach v_table in array array['entries', 'documents', 'third_parties', 'bank_statements', 'import_batches', 'invoices',
                                 'fixed_assets', 'provisions', 'accruals', 'inventory_stocks', 'fx_revaluations',
                                 'financial_statements', 'closing_archives', 'letterings'] loop
    execute format('select count(*) from public.%I where entity_id = $1', v_table) into v_used using p_entity;
    if v_used > 0 then
      raise exception 'Le dossier « % » contient déjà des données (%) : il ne peut pas être supprimé. Archivez-le (désactivation) ou contactez l''administrateur.', v_name, v_table
        using errcode = '23503';
    end if;
  end loop;
  delete from public.assignments where entity_id = p_entity;
  -- Le plan de comptes se supprime des feuilles vers la racine (un compte à subdivisions ne se supprime pas).
  loop
    delete from public.accounts a where a.entity_id = p_entity
      and not exists (select 1 from public.accounts c where c.parent_id = a.id);
    exit when not found;
  end loop;
  delete from public.entities where id = p_entity;
end $$;
revoke all on function public.delete_empty_duplicate_entity(uuid) from public, anon;
grant execute on function public.delete_empty_duplicate_entity(uuid) to authenticated;

-- Retour arrière (à exécuter à la main, ne perd aucune donnée de travail) :
--   drop function public.delete_empty_duplicate_entity(uuid);
--   drop trigger entities_guard_homonym on public.entities; drop function public.entities_guard_homonym();
--   alter table public.cabinets drop column block_homonym_entities;
--   drop index public.entities_request_unique; alter table public.entities drop column request_id;
