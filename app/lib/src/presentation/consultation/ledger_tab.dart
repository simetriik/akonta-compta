import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:akonta/design/design.dart';

import '../../core/formatting.dart';
import '../widgets/async_view.dart';
import '../../application/providers/consultation_providers.dart';
import '../../domain/consultation_models.dart';
import 'consultation_widgets.dart';

sealed class LedgerRow {}

class LedgerRowHead extends LedgerRow {
  LedgerRowHead(this.code, this.label);
  final String code;
  final String label;
}

class LedgerRowLine extends LedgerRow {
  LedgerRowLine(this.line);
  final LedgerLine line;
}

class LedgerRowTotal extends LedgerRow {
  LedgerRowTotal(this.debit, this.credit);
  final int debit;
  final int credit;
}

class LedgerTab extends ConsumerWidget {
  const LedgerTab({super.key, required this.params});

  final ConsultationParams params;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lines = ref.watch(generalLedgerProvider(params));
    return AsyncView(
      value: lines,
      onRetry: () => ref.invalidate(generalLedgerProvider(params)),
      builder: (list) {
        if (list.isEmpty) return const AkEmptyState('Aucune écriture validée sur la période.');
        final items = <LedgerRow>[];
        String? current;
        var subD = 0, subC = 0;
        void flush() {
          if (current != null) items.add(LedgerRowTotal(subD, subC));
          subD = 0;
          subC = 0;
        }

        for (final l in list) {
          if (l.accountCode != current) {
            flush();
            current = l.accountCode;
            items.add(LedgerRowHead(l.accountCode, l.accountLabel));
          }
          subD += l.debit;
          subC += l.credit;
          items.add(LedgerRowLine(l));
        }
        flush();
        return akIsCompact(context) ? LedgerList(items: items) : LedgerGrid(items: items);
      },
    );
  }
}

class LedgerGrid extends StatelessWidget {
  const LedgerGrid({super.key, required this.items});

  final List<LedgerRow> items;

  @override
  Widget build(BuildContext context) {
    final rows = <AkGridRow>[
      for (final it in items)
        switch (it) {
          LedgerRowHead h => AkGridRow.section(
            Row(
              children: [
                consultationCode(context, h.code, bold: true),
                const SizedBox(width: AkSpace.s2),
                Flexible(child: consultationSection(context, '— ${h.label}')),
              ],
            ),
          ),
          LedgerRowLine(:final line) => AkGridRow([
            consultationText(context, Fmt.date(line.entryDate)),
            consultationCode(context, '${line.journalCode}-${line.number}'),
            consultationCode(context, line.reference ?? ''),
            consultationText(context, line.label),
            consultationCode(context, line.thirdPartyCode ?? ''),
            consultationAmount(Fmt.fcfa(line.debit)),
            consultationAmount(Fmt.fcfa(line.credit)),
            consultationAmount(Fmt.balance(line.runningBalance)),
            consultationCode(context, line.letterCode ?? ''),
          ], onTap: () => context.go('/saisie/${line.entryId}')),
          LedgerRowTotal tot => AkGridRow([
            const SizedBox.shrink(),
            const SizedBox.shrink(),
            const SizedBox.shrink(),
            consultationText(context, 'Total compte', bold: true),
            const SizedBox.shrink(),
            consultationAmount(Fmt.fcfa(tot.debit, showZero: true), bold: true),
            consultationAmount(Fmt.fcfa(tot.credit, showZero: true), bold: true),
            consultationAmount(Fmt.balance(tot.debit - tot.credit), bold: true),
          ], kind: AkGridRowKind.total),
        },
    ];
    return AkGrid(
      columns: const [
        AkGridColumn('Date', 116),
        AkGridColumn('Pièce', 124),
        AkGridColumn('Référence', 110),
        AkGridColumn('Libellé', 240, grow: true),
        AkGridColumn('Tiers', 90),
        AkGridColumn('Débit', 120, numeric: true),
        AkGridColumn('Crédit', 120, numeric: true),
        AkGridColumn('Solde', 130, numeric: true),
        AkGridColumn('Lettre', 70),
      ],
      rows: rows,
    );
  }
}

/// Grand livre sur mobile : une ligne tactile par mouvement, lecture seule (maquette MobileCompte).
class LedgerList extends StatelessWidget {
  const LedgerList({super.key, required this.items});

  final List<LedgerRow> items;

  @override
  Widget build(BuildContext context) {
    final t = context.ak;
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, i) {
        switch (items[i]) {
          case LedgerRowHead h:
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: AkSpace.s4, vertical: AkSpace.s2),
              decoration: BoxDecoration(
                color: t.surfaceSunken,
                border: Border(bottom: BorderSide(color: t.border)),
              ),
              child: Row(
                children: [
                  Text(
                    h.code,
                    style: AkText.code.copyWith(color: t.text, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: AkSpace.s2),
                  Expanded(
                    child: Text(
                      h.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AkText.bodyStrong.copyWith(color: t.text),
                    ),
                  ),
                ],
              ),
            );
          case LedgerRowTotal tot:
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: AkSpace.s4, vertical: AkSpace.s2),
              decoration: BoxDecoration(
                color: t.surfaceSunken,
                border: Border(bottom: BorderSide(color: t.border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Total compte', style: AkText.bodyStrong.copyWith(color: t.text)),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      AkAmountText('D ${Fmt.fcfa(tot.debit, showZero: true)}', bold: true),
                      AkAmountText('C ${Fmt.fcfa(tot.credit, showZero: true)}', bold: true),
                      AkAmountText('Solde ${Fmt.balance(tot.debit - tot.credit)}', bold: true),
                    ],
                  ),
                ],
              ),
            );
          case LedgerRowLine(:final line):
            final debit = line.debit != 0;
            final meta = [
              '${line.journalCode}-${line.number}',
              if (line.reference != null && line.reference!.isNotEmpty) line.reference!,
              if (line.thirdPartyCode != null) line.thirdPartyCode!,
              if (line.letterCode != null) 'lettre ${line.letterCode}',
            ].join(' · ');
            return InkWell(
              onTap: () => context.go('/saisie/${line.entryId}'),
              child: Container(
                constraints: const BoxConstraints(minHeight: 64),
                padding: const EdgeInsets.symmetric(horizontal: AkSpace.s4, vertical: 10),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: t.border)),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 84,
                      child: Text(
                        Fmt.date(line.entryDate),
                        style: AkText.caption.copyWith(color: t.textMuted, fontFeatures: const [FontFeature.tabularFigures()]),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            line.label,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AkText.body.copyWith(color: t.text),
                          ),
                          Text(
                            meta,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AkText.code.copyWith(color: t.textMuted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AkSpace.s2),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        AkAmountText('${debit ? 'D' : 'C'} ${Fmt.fcfa(debit ? line.debit : line.credit)}', bold: true),
                        Text(
                          'Solde ${Fmt.balance(line.runningBalance)}',
                          style: AkText.caption.copyWith(color: t.textMuted, fontFeatures: const [FontFeature.tabularFigures()]),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
        }
      },
    );
  }
}
