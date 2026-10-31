#!/usr/bin/env python3
"""Génère la migration de seed du catalogue des notes annexes SYCEBNL calculables depuis le grand livre.

Usage : python3 scripts/generate_sycebnl_notes.py outputs/sycebnl/plan-sycebnl.csv \
            supabase/migrations/20261031400002_seed_sycebnl_note_lines.sql

Source : Journal officiel OHADA 2023, SYCEBNL, partie 4, notes annexes (pages 349 à 394). Les notes de type « libellé, année N, année N-1,
variation » dont les lignes se calculent à partir des comptes sont couvertes. Pour les notes 8 à 13, 16, 17A, 17B, 19, 23 et 29A, les lignes
sont celles de la page officielle. Pour les notes 18A, 20, 21, 22, 24 à 28, 31 et 32, les pages n'ont pas été relues : les lignes sont les comptes
à 3 chiffres du plan (leurs libellés), regroupés comme le bilan et le compte de résultat. Les colonnes d'échéances (créances à un an au plus, etc.)
et les rubriques à saisie libre ne sont pas produites. À faire valider par ABC (Q-021).

Montants : `sign` 1 = solde débiteur positif (actif, charges), -1 = solde créditeur positif (passif, produits).
Totaux : `sum_of` liste les lignes à additionner ; un préfixe « - » soustrait (dépréciations).
"""
import csv
import sys

VERSION = "SYCEBNL-2024"


class Spec:
    def __init__(self, plan: dict[str, str]):
        self.plan = plan
        self.notes: list[tuple[str, str, list[dict]]] = []

    def children(self, parent: str, exclude: tuple[str, ...] = ()) -> list[str]:
        return [c for c in sorted(self.plan) if len(c) == len(parent) + 1 and c.startswith(parent) and c not in exclude]

    def label(self, code: str) -> str:
        return self.plan[code]

    def note(self, code: str, title: str, lines: list[dict]) -> None:
        self.notes.append((code, title, lines))


def line(code, label, ranges, side="any", sign=1):
    return {"kind": "line", "code": code, "label": label, "ranges": ranges, "side": side, "sign": sign}


def total(code, label, sum_of, kind="total"):
    return {"kind": kind, "code": code, "label": label, "sum_of": sum_of}


def from_plan(spec: Spec, note: str, parents: list[str], sign: int, side="any", exclude=()) -> list[dict]:
    """Une ligne par compte à 3 chiffres sous les comptes parents, avec le libellé du plan, et un total."""
    lines = []
    for p in parents:
        for c in spec.children(p, exclude):
            lines.append(line(f"{note}-{c}", spec.label(c), [(c, c)], side, sign))
    lines.append(total(f"{note}-T", "TOTAL", [l["code"] for l in lines]))
    return lines


def build(plan: dict[str, str]) -> Spec:
    s = Spec(plan)

    # Note 8 : stocks et encours
    s.note("8", "Stocks et encours", [
        line("8-1", "Biens et services liés à l'activité", [("31", "31")]),
        line("8-2", "Marchandises, matières premières", [("32", "32")]),
        line("8-3", "Autres approvisionnements", [("33", "33")]),
        line("8-4", "Dons en nature", [("34", "34")]),
        line("8-5", "Produits finis", [("35", "36")]),
        line("8-6", "Dons en nature HAO", [("38", "38")]),
        line("8-7", "Autres stocks HAO", [("37", "37")]),
        total("8-T", "TOTAL STOCKS ET ENCOURS", ["8-1", "8-2", "8-3", "8-4", "8-5", "8-6", "8-7"], "subtotal"),
        line("8-D", "Dépréciations des stocks", [("39", "39")], sign=-1),
        total("8-N", "TOTAL NET DE DÉPRÉCIATIONS", ["8-T", "-8-D"]),
    ])

    # Note 9 : adhérents, clients-usagers
    s.note("9", "Adhérents, clients-usagers", [
        line("9-1", "Adhérents", [("411", "411")]),
        line("9-2", "Clients-usagers", [("412", "412")]),
        line("9-3", "Adhérents, clients-usagers, chèques, effets et autres valeurs impayés", [("413", "413")]),
        line("9-4", "Adhérents, créances litigieuses ou douteuses", [("416", "416")]),
        line("9-5", "Adhérents, clients-usagers, produits à recevoir", [("418", "418")]),
        total("9-B", "TOTAL BRUT ADHÉRENTS, CLIENTS-USAGERS", ["9-1", "9-2", "9-3", "9-4", "9-5"], "subtotal"),
        line("9-D", "Dépréciations des comptes adhérents et clients-usagers", [("491", "491")], sign=-1),
        total("9-N", "TOTAL NET DE DÉPRÉCIATIONS", ["9-B", "-9-D"], "subtotal"),
        line("9-6", "Adhérents, avances reçues", [("4191", "4191")], sign=-1),
        line("9-7", "Clients-usagers, avances et acomptes reçus", [("4192", "4192")], sign=-1),
        line("9-8", "Autres clients créditeurs", [("4194", "4194"), ("4198", "4198")], sign=-1),
        total("9-C", "TOTAL CLIENTS CRÉDITEURS", ["9-6", "9-7", "9-8"]),
    ])

    # Note 10 : autres créances (soldes débiteurs)
    s.note("10", "Autres créances", [
        line("10-1", "Personnel", [("42", "42")], "debit"),
        line("10-2", "Organismes sociaux", [("43", "43")], "debit"),
        line("10-3", "État et collectivités publiques", [("44", "44")], "debit"),
        line("10-4", "Fondateurs, apporteurs et comptes courants", [("45", "45")], "debit"),
        line("10-5", "Bailleurs, État et autres organismes, fonds d'administration", [("46", "46")], "debit"),
        line("10-6", "Débiteurs divers", [("471", "471")], "debit"),
        line("10-7", "Autres débiteurs divers", [("472", "477")], "debit"),
        total("10-B", "TOTAL BRUT", ["10-1", "10-2", "10-3", "10-4", "10-5", "10-6", "10-7"], "subtotal"),
        line("10-D", "Dépréciations des autres créances", [("492", "494"), ("497", "497")], sign=-1),
        total("10-N", "TOTAL NET DE DÉPRÉCIATIONS", ["10-B", "-10-D"]),
    ])

    # Note 11 : titres de placement
    s.note("11", "Titres de placement", [
        line("11-1", "Titres de trésor et bons de caisse à court terme", [("501", "501")]),
        line("11-2", "Actions", [("502", "502")]),
        line("11-3", "Obligations", [("503", "503")]),
        line("11-4", "Bons de souscription", [("504", "504")]),
        line("11-5", "Titres négociables hors région", [("505", "505")]),
        line("11-6", "Intérêts courus", [("506", "506")]),
        line("11-7", "Autres valeurs assimilées", [("508", "508")]),
        total("11-B", "TOTAL BRUT", ["11-1", "11-2", "11-3", "11-4", "11-5", "11-6", "11-7"], "subtotal"),
        line("11-D", "Dépréciations des titres de placement", [("590", "590")], sign=-1),
        total("11-N", "TOTAL NET DE DÉPRÉCIATIONS", ["11-B", "-11-D"]),
    ])

    # Note 12 : valeurs à encaisser
    s.note("12", "Valeurs à encaisser", [
        line("12-1", "Chèques à encaisser", [("513", "513")]),
        line("12-2", "Chèques à l'encaissement", [("514", "514")]),
        line("12-3", "Cartes de crédit à encaisser", [("515", "515")]),
        line("12-4", "Autres valeurs à encaisser", [("518", "518")]),
        total("12-B", "TOTAL BRUT", ["12-1", "12-2", "12-3", "12-4"], "subtotal"),
        line("12-D", "Dépréciations des valeurs à encaisser", [("591", "591")], sign=-1),
        total("12-N", "TOTAL NET DE DÉPRÉCIATIONS", ["12-B", "-12-D"]),
    ])

    # Note 13 : disponibilités (soldes débiteurs ; les soldes créditeurs sont en note 22)
    s.note("13", "Disponibilités", [
        line("13-1", "Banques locales", [("521", "521")], "debit"),
        line("13-2", "Banques autres États région", [("522", "522")], "debit"),
        line("13-3", "Banques, dépôt à terme", [("525", "525")], "debit"),
        line("13-4", "Autres banques", [("523", "524")], "debit"),
        line("13-5", "Banques, intérêts courus", [("526", "526")], "debit"),
        line("13-6", "Banques postales", [("531", "531")], "debit"),
        line("13-7", "Autres établissements financiers", [("532", "533"), ("538", "538")], "debit"),
        line("13-8", "Établissements financiers, intérêts courus", [("536", "536")], "debit"),
        line("13-9", "Instruments de monnaie électronique", [("55", "55")], "debit"),
        line("13-10", "Caisse", [("57", "57")], "debit"),
        total("13-B", "TOTAL BRUT", [f"13-{i}" for i in range(1, 11)], "subtotal"),
        line("13-D", "Dépréciations", [("592", "593"), ("595", "595")], sign=-1),
        total("13-N", "TOTAL NET DE DÉPRÉCIATIONS", ["13-B", "-13-D"]),
    ])

    # Note 16 : réserves
    s.note("16", "Réserves", [
        line("16-1", "Réserves statutaires ou contractuelles", [("112", "112")], sign=-1),
        line("16-2", "Autres réserves", [("118", "118")], sign=-1),
        total("16-T", "TOTAL RÉSERVES", ["16-1", "16-2"], "subtotal"),
        line("16-3", "Report à nouveau", [("12", "12")], sign=-1),
    ])

    # Note 17A : subventions d'investissement et provisions réglementées
    s.note("17A", "Subventions et provisions réglementées", [
        line("17A-1", "État", [("1411", "1411")], sign=-1),
        line("17A-2", "Région", [("1412", "1412")], sign=-1),
        line("17A-3", "Département", [("1413", "1413")], sign=-1),
        line("17A-4", "Communes et collectivités publiques décentralisées", [("1414", "1414")], sign=-1),
        line("17A-5", "Entités publiques ou mixtes", [("1415", "1415")], sign=-1),
        line("17A-6", "Entités et organismes privés", [("1416", "1416")], sign=-1),
        line("17A-7", "Organismes internationaux", [("1417", "1417")], sign=-1),
        line("17A-8", "Autres subventions d'investissements", [("1418", "1418"), ("148", "148")], sign=-1),
        total("17A-S", "TOTAL SUBVENTIONS", [f"17A-{i}" for i in range(1, 9)], "subtotal"),
        line("17A-P", "PROVISIONS RÉGLEMENTÉES", [("15", "15")], sign=-1),
        total("17A-T", "TOTAL SUBVENTIONS ET PROVISIONS RÉGLEMENTÉES", ["17A-S", "17A-P"]),
    ])

    # Note 17B : fonds affectés et reportés
    s.note("17B", "Fonds affectés et reportés", [
        line("17B-1", "Fonds affectés aux investissements", [("162", "164")], sign=-1),
        line("17B-2", "Fonds non consommés en fin d'exercice destinés à un projet spécifique", [("165", "165")], sign=-1),
        line("17B-3", "Fonds provenant des dons et legs d'immobilisations", [("167", "167")], sign=-1),
        line("17B-4", "Autres fonds affectés", [("161", "161"), ("168", "169")], sign=-1),
        total("17B-A", "TOTAL FONDS AFFECTÉS", ["17B-1", "17B-2", "17B-3", "17B-4"], "subtotal"),
        line("17B-5", "Donations et legs non encore reçus d'immobilisations destinés à la vente", [("172", "172")], sign=-1),
        line("17B-6", "Donation temporaire d'usufruit", [("171", "171")], sign=-1),
        line("17B-7", "Autres fonds reportés", [("178", "178")], sign=-1),
        total("17B-R", "TOTAL FONDS REPORTÉS", ["17B-5", "17B-6", "17B-7"], "subtotal"),
        total("17B-T", "TOTAL FONDS AFFECTÉS ET REPORTÉS", ["17B-A", "17B-R"]),
    ])

    # Note 18A : dettes financières et ressources assimilées (plan)
    n18 = from_plan(s, "18A", ["18"], -1, exclude=("187",))
    n18.insert(-1, line("18A-187", s.label("187"), [("187", "187")], sign=-1))
    n18.insert(-1, line("18A-19", "Provisions pour risques et charges", [("19", "19")], sign=-1))
    n18[-1] = total("18A-T", "TOTAL DETTES FINANCIÈRES ET RESSOURCES ASSIMILÉES", [l["code"] for l in n18[:-1]])
    s.note("18A", "Dettes financières et ressources assimilées", n18)

    # Note 19 : fournisseurs d'exploitation
    s.note("19", "Fournisseurs d'exploitation", [
        line("19-1", "Fournisseurs, dettes en compte", [("4011", "4012"), ("4014", "4015"), ("4018", "4019")], sign=-1),
        line("19-2", "Fournisseurs, réserve de propriété", [("4016", "4016")], sign=-1),
        line("19-3", "Fournisseurs, retenue de garantie", [("4017", "4017")], sign=-1),
        line("19-4", "Fournisseurs sous-traitants", [("4013", "4013")], sign=-1),
        line("19-5", "Fournisseurs effets à payer", [("402", "402")], sign=-1),
        line("19-6", "Fournisseurs factures non parvenues", [("408", "408")], sign=-1),
        total("19-T", "TOTAL FOURNISSEURS", ["19-1", "19-2", "19-3", "19-4", "19-5", "19-6"], "subtotal"),
        line("19-7", "Fournisseurs, avances et acomptes", [("4091", "4092")], sign=1),
        line("19-8", "Fournisseurs sous-traitants, avances et acomptes", [("4093", "4093")], sign=1),
        line("19-9", "Autres fournisseurs débiteurs", [("4094", "4099")], sign=1),
        total("19-D", "TOTAL FOURNISSEURS DÉBITEURS", ["19-7", "19-8", "19-9"]),
    ])

    # Note 20 : dettes fiscales et sociales ; note 21 : autres dettes (soldes créditeurs)
    s.note("20", "Dettes fiscales et sociales", [
        line("20-1", "Personnel", [("42", "42")], "credit", -1),
        line("20-2", "Organismes sociaux", [("43", "43")], "credit", -1),
        line("20-3", "État et collectivités publiques", [("44", "44")], "credit", -1),
        total("20-T", "TOTAL DETTES FISCALES ET SOCIALES", ["20-1", "20-2", "20-3"]),
    ])
    s.note("21", "Autres dettes et provisions à court terme", [
        line("21-1", "Fondateurs, apporteurs et comptes courants", [("45", "45")], "credit", -1),
        line("21-2", "Bailleurs, fonds d'administration", [("46", "46")], "credit", -1),
        line("21-3", "Créditeurs divers", [("470", "477")], "credit", -1),
        line("21-4", "Provisions pour risques à court terme", [("4990", "4997"), ("4999", "4999"), ("599", "599")], "credit", -1),
        total("21-T", "TOTAL AUTRES DETTES ET PROVISIONS À COURT TERME", ["21-1", "21-2", "21-3", "21-4"]),
    ])

    # Note 22 : banques et crédits de trésorerie (soldes créditeurs)
    s.note("22", "Banques et crédits de trésorerie", [
        line("22-1", "Banques, soldes créditeurs", [("52", "52")], "credit", -1),
        line("22-2", "Établissements financiers, soldes créditeurs", [("53", "53")], "credit", -1),
        line("22-3", "Crédits de trésorerie", [("561", "561")], sign=-1),
        line("22-4", "Escompte de crédits ordinaires", [("565", "565")], sign=-1),
        line("22-5", "Banques, crédits de trésorerie, intérêts courus", [("566", "566")], sign=-1),
        total("22-T", "TOTAL BANQUES ET CRÉDITS DE TRÉSORERIE", ["22-1", "22-2", "22-3", "22-4", "22-5"]),
    ])

    # Note 23 : revenus et autres produits
    s.note("23", "Revenus et autres produits", [
        line("23-1", "Cotisations des adhérents", [("701", "701")], sign=-1),
        line("23-2", "Quote-part de dotation consomptible transférée", [("703", "703")], sign=-1),
        line("23-3", "Revenus liés à la générosité", [("704", "704")], sign=-1),
        line("23-4", "Ventes de marchandises, services et produits finis", [("705", "705")], sign=-1),
        line("23-5", "Revenus des manifestations", [("706", "706")], sign=-1),
        line("23-6", "Autres revenus", [("702", "702"), ("707", "708")], sign=-1),
        total("23-R", "TOTAL : REVENUS", [f"23-{i}" for i in range(1, 7)], "subtotal"),
        line("23-7", "Subventions d'exploitation", [("71", "71")], sign=-1),
        line("23-8", "Autres produits et transferts de charges d'exploitation", [("72", "73"), ("75", "75"), ("78", "78")], sign=-1),
        total("23-S", "TOTAL : SUBVENTIONS D'EXPLOITATION ET AUTRES PRODUITS", ["23-7", "23-8"], "subtotal"),
        total("23-T", "TOTAL", ["23-R", "23-S"]),
    ])

    # Notes 24 à 28 : charges, une ligne par compte à 3 chiffres du plan
    s.note("24", "Achats", from_plan(s, "24", ["60"], 1, exclude=("603", "609")))
    s.note("25", "Transports", from_plan(s, "25", ["61"], 1))
    s.note("26", "Services extérieurs", from_plan(s, "26", ["62", "63"], 1))
    s.note("27", "Impôts et taxes", from_plan(s, "27", ["64"], 1))
    s.note("28", "Autres charges", from_plan(s, "28", ["65"], 1, exclude=("659",)))

    # Note 29A : charges de personnel
    s.note("29A", "Charges de personnel", from_plan(s, "29A", ["66"], 1))

    # Note 31 : charges et revenus financiers
    n31 = from_plan(s, "31C", ["67"], 1)
    n31 = [dict(l, code=l["code"].replace("31C", "31-C")) for l in n31]
    n31[-1] = total("31-C-T", "TOTAL FRAIS FINANCIERS ET CHARGES ASSIMILÉES", [l["code"] for l in n31[:-1]], "subtotal")
    n31r = [dict(l, code=l["code"].replace("31C", "31-R")) for l in from_plan(s, "31C", ["77"], -1)]
    n31r[-1] = total("31-R-T", "TOTAL REVENUS FINANCIERS ET PRODUITS ASSIMILÉS", [l["code"] for l in n31r[:-1]], "subtotal")
    s.note("31", "Charges et revenus financiers", n31 + n31r)

    # Note 32 : autres charges et produits HAO
    s.note("32", "Autres charges et produits HAO", [
        line("32-1", s.label("84").capitalize(), [("84", "84")], sign=-1),
        line("32-2", s.label("86").capitalize(), [("86", "86")], sign=-1),
        line("32-3", s.label("82").capitalize(), [("82", "82")], sign=-1),
        line("32-4", s.label("88").capitalize(), [("88", "88")], sign=-1),
        total("32-P", "TOTAL PRODUITS HAO", ["32-1", "32-2", "32-3", "32-4"], "subtotal"),
        line("32-5", s.label("81").capitalize(), [("81", "81")], sign=1),
        line("32-6", s.label("83").capitalize(), [("83", "83")], sign=1),
        line("32-7", s.label("85").capitalize(), [("85", "85")], sign=1),
        line("32-8", s.label("87").capitalize(), [("87", "87")], sign=1),
        total("32-C", "TOTAL CHARGES HAO", ["32-5", "32-6", "32-7", "32-8"], "subtotal"),
    ])
    return s


def sql(v: str) -> str:
    return v.replace("'", "''")


def main(src: str, dst: str) -> None:
    with open(src, encoding="utf-8-sig", newline="") as f:
        plan = {r[0].strip(): r[1].strip() for r in list(csv.reader(f, delimiter=";"))[1:]}
    spec = build(plan)
    rows = []
    order = 0
    for note, title, lines in spec.notes:
        for l in lines:
            order += 10
            if l["kind"] == "line":
                for lo, hi in l["ranges"]:
                    rows.append(f"  ('{VERSION}', '{note}', '{sql(title)}', '{l['code']}', '{sql(l['label'])}', 'line', '{lo}', '{hi}', '{l['side']}', {l['sign']}, null, {order})")
            else:
                rows.append(f"  ('{VERSION}', '{note}', '{sql(title)}', '{l['code']}', '{sql(l['label'])}', '{l['kind']}', null, null, 'any', 1, '{','.join(l['sum_of'])}', {order})")
    out = ["-- Généré par scripts/generate_sycebnl_notes.py — ne pas modifier à la main.",
           "-- Source : Journal officiel OHADA 2023, SYCEBNL, partie 4, notes annexes (voir l'en-tête du script pour le périmètre et les interprétations).",
           "insert into public.statement_note_lines (version, note_code, note_title, line_code, label, kind, account_from, account_to, balance_side, sign, sum_of, sort_order) values",
           ",\n".join(rows) + ";"]
    with open(dst, "w", encoding="utf-8") as f:
        f.write("\n".join(out) + "\n")
    print(f"{len(spec.notes)} notes, {len(rows)} règles écrites dans {dst}")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2])
