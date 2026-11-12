-- GÉNÉRÉ par recette/generer-jeu.py : ne pas modifier à la main.
-- source-sha256: 9fe422f477a7e54c9b49d6d39714b3fd693500d270efd467bd2fd6a9785f3190
-- Recette interne : l'export Perfecto simulé (recette/export-perfecto-simule.txt, décodé de Windows-1252) est lu sans erreur
-- par le module d'import en mode essai ; les à-nouveaux sont équilibrés ; tous les comptes du jeu de données existent dans le plan de l'entité.
begin;
select plan(11);

select tests.create_cabinet('Cabinet recette') as id \gset a_
select tests.create_user('manager@recette.test', :'a_id') as id \gset manager_
select tests.create_entity(:'a_id', 'Comptoir Aïdé Négoce SARL') as id \gset e1_
select tests.assign(:'manager_id', :'a_id', 'manager', :'e1_id');
insert into public.fiscal_years (cabinet_id, entity_id, start_date, end_date) values (:'a_id', :'e1_id', '2027-01-01', '2027-12-31');
select id as id from public.journals where entity_id = :'e1_id' and code = 'AN' \gset an_

select is((select count(*) from public.accounts where entity_id = :'e1_id' and code in ('1010000','1181000','1210000','1301000','1620000','2441000','2444000','2451000','2844000','2845000','3111000','4011000','4111000','4220000','4311000','4431000','4441000','4451000','4452000','4472000','4478000','5210000','6011000','6012000','6052000','6056000','6222000','6251000','6281000','6311000','6312000','6611000','6641000','7011000')), 34::bigint,
          'les 34 comptes du jeu de données existent dans le plan à 7 chiffres de l''entité');

select tests.authenticate_as(:'manager_id');
insert into public.import_batches (cabinet_id, entity_id, kind, source_file_name, target_journal_id)
values (:'a_id', :'e1_id', 'journal', 'export-perfecto-simule.txt', :'an_id');
select id as id from public.import_batches where entity_id = :'e1_id' \gset batch_

select public.import_parse_perfecto_journal(:'batch_id', $perf$JOURNAL <AN> À-nouveaux
Pièces du 01/01/2027  au 01/01/2027		
						
Date	N° pièce	Compte	Intitulé	Débit	Crédit	Libellé
01/01/2027	000001	2441000	Matériel de bureau	2400000	0	À-nouveaux au 01/01/2027
01/01/2027	000001	2444000	Mobilier de bureau	1800000	0	À-nouveaux au 01/01/2027
01/01/2027	000001	2451000	Matériel automobile	8500000	0	À-nouveaux au 01/01/2027
01/01/2027	000001	2844000	Amortissements du matériel et mobilier	0	2040000	À-nouveaux au 01/01/2027
01/01/2027	000001	2845000	Amortissements du matériel de transport	0	3400000	À-nouveaux au 01/01/2027
01/01/2027	000001	3111000	Marchandises A1	4800000	0	À-nouveaux au 01/01/2027
01/01/2027	000001	4111CBM	Quincaillerie Bénin Matériaux	1770000	0	Facture FA-2026-131 non réglée
01/01/2027	000001	4111CAK	Akpakpa Bâtiment SA	2360000	0	Facture FA-2026-140 non réglée
01/01/2027	000001	4111CMA	Mairie d'Abomey-Calavi	5900000	0	Facture FA-2026-152 non réglée
01/01/2027	000001	4111CDX	Entreprise DOSSOU BTP	3540000	0	Facture FA-2025-077 non réglée
01/01/2027	000001	4111CBS	Établissements BOSSOU	1416000	0	Facture FA-2025-102 non réglée
01/01/2027	000001	4011FCG	Cimenterie du Golfe	0	3068000	Facture FA-FCG-0198 non réglée
01/01/2027	000001	4011FPL	Peintures du Littoral	0	1180000	Facture FA-FPL-0511 non réglée
01/01/2027	000001	4311000	Sécurité sociale (CNSS)	0	218500	CNSS de décembre 2026 à payer
01/01/2027	000001	4441000	État, TVA due	0	410000	TVA due de décembre 2026
01/01/2027	000001	4472000	Impôts sur salaires (IRPP)	0	52000	IRPP retenu sur salaires de décembre 2026
01/01/2027	000001	1010000	Capital social	0	20000000	À-nouveaux au 01/01/2027
01/01/2027	000001	1181000	Réserves facultatives	0	4000000	À-nouveaux au 01/01/2027
01/01/2027	000001	1210000	Report à nouveau créditeur	0	3250000	À-nouveaux au 01/01/2027
01/01/2027	000001	1301000	Résultat en instance d'affectation : bénéfice	0	6750000	À-nouveaux au 01/01/2027
01/01/2027	000001	1620000	Emprunts auprès des établissements de crédit	0	6000000	À-nouveaux au 01/01/2027
01/01/2027	000001	5210ECO	Ecobank Bénin	17882500	0	Solde bancaire au 31/12/2026
Sous-total	000001			50368500	50368500	
Total	Journal			50368500	50368500	
$perf$) as report \gset parse_
select is((select source_journal from public.import_batches where id = :'batch_id'), 'AN', 'code du journal source lu dans l''en-tête');
select is((select period_from::text || '→' || period_to::text from public.import_batches where id = :'batch_id'), '2027-01-01→2027-01-01', 'période lue');
select is((:'parse_report'::jsonb ->> 'lines')::int, 22, '22 lignes de données lues');
select is((:'parse_report'::jsonb ->> 'pieces')::int, 1, 'une pièce (à-nouveaux)');
select is((:'parse_report'::jsonb ->> 'subtotal_errors')::int, 0, 'sous-total cohérent');
-- Comme sur le vrai JOURNAL BANQUE.TXT (Q-007), la ligne d'en-tête faite de seules tabulations et la ligne « Total Journal » finale
-- ne sont plus signalées comme des dates illisibles (AN-06, recette du 11/11/2026) : aucune erreur d'analyse.
select is((select jsonb_array_length(:'parse_report'::jsonb -> 'parse_errors')), 0, 'AN-06 : aucune erreur d''analyse sur l''export réel (en-tête de tabulations et total ignorés)');

select public.import_propose_mappings(:'batch_id') as report \gset map_
select is((select account_code || '|' || third_party_code from public.import_account_mappings where entity_id = :'e1_id' and raw_account = '4111CBM'), '4111000|CBM', '4111CBM → collectif 4111000 + tiers CBM');
-- La banque (5210ECO) n'est pas un tiers : la correspondance éditable retire le suffixe, comme le fera l'équipe (jeu-de-donnees.md).
update public.import_account_mappings set third_party_code = null, third_party_name = null, create_third_party = false where entity_id = :'e1_id' and raw_account = '5210ECO';
select public.import_apply(:'batch_id', true) as report \gset dry_
select is((:'dry_report'::jsonb ->> 'error_count')::int, 0, 'essai sans erreur');
select is((:'dry_report'::jsonb ->> 'entries')::int, 1, 'essai : une écriture de à-nouveaux serait créée');
select is((select count(*) from public.entries where entity_id = :'e1_id'), 0::bigint, 'essai : aucune écriture créée');

select * from finish();
rollback;
