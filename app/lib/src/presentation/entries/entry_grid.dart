import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:akonta/design/design.dart';

import '../../core/formatting.dart';
import '../../domain/entry_models.dart';
import '../../domain/reference_models.dart';
import '../../application/providers/references_providers.dart';

const double kEntryIndexWidth = AkEntryGridCols.index;

const double kEntryAmountWidth = AkEntryGridCols.amount;

const double kEntryRemoveWidth = AkEntryGridCols.remove;

class EntryGridHeader extends StatelessWidget {
  const EntryGridHeader({super.key, required this.withThirdParty});

  final bool withThirdParty;

  @override
  Widget build(BuildContext context) {
    final t = context.ak;
    final style = AkText.tableHead.copyWith(color: t.textMuted);
    // Même marge interne que les cellules de saisie, pour aligner texte d'en-tête et contenu.
    const cellPad = EdgeInsets.symmetric(horizontal: AkSpace.s2);
    return Container(
      constraints: BoxConstraints(minHeight: akIsTouch(context) ? AkSpace.rowTouch : AkSpace.rowCompact),
      color: t.tableHead,
      padding: const EdgeInsets.symmetric(horizontal: AkSpace.s2),
      child: Row(
        children: [
          const SizedBox(width: kEntryIndexWidth),
          SizedBox(
            width: AkEntryGridCols.account,
            child: Padding(
              padding: cellPad,
              child: Text('Compte', style: style),
            ),
          ),
          const SizedBox(width: AkSpace.s2),
          SizedBox(
            width: withThirdParty ? AkEntryGridCols.thirdParty : AkEntryGridCols.thirdPartyEmpty,
            child: Padding(
              padding: cellPad,
              child: Text('Tiers', style: style, overflow: TextOverflow.ellipsis),
            ),
          ),
          const SizedBox(width: AkSpace.s2),
          Expanded(
            child: Padding(
              padding: cellPad,
              child: Text('Libellé', style: style),
            ),
          ),
          const SizedBox(width: AkSpace.s2),
          SizedBox(
            width: kEntryAmountWidth,
            child: Padding(
              padding: cellPad,
              child: Text('D · Débit (FCFA)', style: style, textAlign: TextAlign.right),
            ),
          ),
          const SizedBox(width: AkSpace.s2),
          Container(
            width: kEntryAmountWidth + AkSpace.s2,
            padding: const EdgeInsets.only(left: AkSpace.s2),
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: t.border)),
            ),
            child: Padding(
              padding: cellPad,
              child: Text('C · Crédit (FCFA)', style: style, textAlign: TextAlign.right),
            ),
          ),
          const SizedBox(width: kEntryRemoveWidth),
        ],
      ),
    );
  }
}

/// Une ligne de la grille : compte avec autocomplétion (numéro ou intitulé), tiers si collectif, libellé, débit, crédit.
class EntryLineRow extends ConsumerStatefulWidget {
  const EntryLineRow({
    super.key,
    required this.index,
    required this.line,
    required this.entityId,
    required this.readOnly,
    required this.withThirdParty,
    required this.onChanged,
    this.card = false,
    this.onRemove,
    this.onEnterOnLast,
  });

  final int index;
  final DraftLine line;
  final String entityId;
  final bool readOnly;
  final bool withThirdParty;

  /// Mise en page « une carte par ligne » pour les écrans étroits.
  final bool card;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;
  final VoidCallback? onEnterOnLast;

  @override
  ConsumerState<EntryLineRow> createState() => _LineRowState();
}

class _LineRowState extends ConsumerState<EntryLineRow> {
  late final _label = TextEditingController(text: widget.line.label);
  late final _debit = TextEditingController(text: Fmt.fcfa(widget.line.debit));
  late final _credit = TextEditingController(text: Fmt.fcfa(widget.line.credit));
  bool _active = false;

  @override
  void dispose() {
    _label.dispose();
    _debit.dispose();
    _credit.dispose();
    super.dispose();
  }

  /// Applique le compte choisi (liste ou code tapé) à la ligne.
  void _selectAccount(DraftLine l, Account a) {
    l.accountId = a.id;
    l.accountCode = a.code;
    l.accountLabel = a.label;
    l.isCollective = a.isCollective;
    if (!a.isCollective) {
      l.thirdPartyId = null;
      l.thirdPartyCode = '';
    }
    widget.onChanged();
  }

  void _next() => FocusScope.of(context).nextFocus();

  @override
  Widget build(BuildContext context) {
    final accounts = (ref.watch(accountsProvider(widget.entityId)).value ?? const <Account>[]).where((a) => a.isActive && a.allowPosting).toList();
    final thirdParties = (ref.watch(thirdPartiesProvider(widget.entityId)).value ?? const <ThirdParty>[]).where((t) => t.isActive).toList();
    final l = widget.line;
    final t = context.ak;
    final mobile = akIsTouch(context);
    final card = widget.card;
    final accountField = AkAccountField(
      key: Key('line-account-${widget.index}'),
      accounts: accounts,
      dense: !mobile,
      label: card ? 'Compte' : null,
      enabled: !widget.readOnly,
      selected: l.accountCode.isEmpty
          ? null
          : Account(
              id: l.accountId ?? '',
              code: l.accountCode,
              label: l.accountLabel,
              classNo: 0,
              normalSide: 'debit',
              isCollective: l.isCollective,
              isLetterable: false,
              allowPosting: true,
              isActive: true,
            ),
      resolved: l.accountId != null,
      onSelected: (a) => _selectAccount(l, a),
      onCleared: () {
        if (l.accountId != null) {
          l.accountId = null;
          l.accountCode = '';
          widget.onChanged();
        }
      },
      onSubmittedPick: _next,
    );
    final thirdField = AkThirdPartyField(
      thirdParties: thirdParties,
      dense: !mobile,
      label: card ? 'Tiers' : null,
      enabled: !widget.readOnly,
      initialCode: l.thirdPartyCode,
      resolved: l.thirdPartyId != null,
      onSelected: (t) {
        l.thirdPartyId = t.id;
        l.thirdPartyCode = t.code;
        widget.onChanged();
      },
      onSubmittedPick: _next,
    );
    final labelField = AkTextField(
      controller: _label,
      dense: !mobile,
      label: card ? 'Libellé' : null,
      enabled: !widget.readOnly,
      textInputAction: TextInputAction.next,
      onChanged: (v) => l.label = v,
      onSubmitted: (_) => _next(),
    );
    final remove = widget.onRemove == null
        ? null
        : ExcludeFocus(
            child: AkIconButton(tooltip: 'Supprimer la ligne', icon: Icons.close, size: AkSpace.iconMd, dense: true, onPressed: widget.onRemove),
          );

    // Petit écran : une carte par ligne, tous les champs visibles sans défilement horizontal.
    if (card) {
      return Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onFocusChange: (has) => setState(() => _active = has),
        child: Container(
          padding: const EdgeInsets.all(AkSpace.s3),
          decoration: BoxDecoration(
            color: _active ? t.rowActive : null,
            border: Border(bottom: BorderSide(color: t.border)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: Text('Ligne ${widget.index + 1}', style: AkText.label.copyWith(color: t.textMuted))),
                  ?remove,
                ],
              ),
              const SizedBox(height: AkSpace.s2),
              accountField,
              if (l.isCollective) ...[const SizedBox(height: AkSpace.s2), thirdField],
              const SizedBox(height: AkSpace.s2),
              labelField,
              const SizedBox(height: AkSpace.s2),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _amountField(_debit, (v) => l.debit = v, () => l.credit = 0, _credit, label: 'Débit')),
                  const SizedBox(width: AkSpace.s2),
                  Expanded(child: _amountField(_credit, (v) => l.credit = v, () => l.debit = 0, _debit, last: true, label: 'Crédit')),
                ],
              ),
            ],
          ),
        ),
      );
    }

    // Ligne active : la ligne qui contient le focus prend `rowActive` ; la cellule active montre l'anneau de focus.
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (has) => setState(() => _active = has),
      child: Container(
        constraints: BoxConstraints(minHeight: mobile ? AkSpace.rowTouch : AkSpace.controlDense + AkSpace.s1),
        padding: const EdgeInsets.symmetric(horizontal: AkSpace.s2),
        decoration: BoxDecoration(
          color: _active ? t.rowActive : null,
          border: Border(bottom: BorderSide(color: t.border)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: kEntryIndexWidth,
              child: Text('${widget.index + 1}', style: AkText.caption.copyWith(color: t.textMuted)),
            ),
            SizedBox(width: AkEntryGridCols.account, child: accountField),
            const SizedBox(width: AkSpace.s2),
            SizedBox(
              width: widget.withThirdParty ? AkEntryGridCols.thirdParty : AkEntryGridCols.thirdPartyEmpty,
              child: l.isCollective
                  ? thirdField
                  : Padding(
                      padding: const EdgeInsets.only(left: AkSpace.s2),
                      child: Text('—', style: AkText.table.copyWith(color: t.borderControl)),
                    ),
            ),
            const SizedBox(width: AkSpace.s2),
            Expanded(child: labelField),
            const SizedBox(width: AkSpace.s2),
            SizedBox(width: kEntryAmountWidth, child: _amountField(_debit, (v) => l.debit = v, () => l.credit = 0, _credit)),
            const SizedBox(width: AkSpace.s2),
            const SizedBox(width: AkSpace.s2),
            Container(
              width: kEntryAmountWidth + AkSpace.s2,
              padding: const EdgeInsets.only(left: AkSpace.s2),
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: t.border)),
              ),
              child: _amountField(_credit, (v) => l.credit = v, () => l.debit = 0, _debit, last: true),
            ),
            // Hors du parcours au clavier : Tab va de ligne en ligne sans s'arrêter sur la suppression.
            SizedBox(width: kEntryRemoveWidth, child: remove),
          ],
        ),
      ),
    );
  }

  Widget _amountField(TextEditingController c, void Function(int) set, VoidCallback clearOther, TextEditingController other, {bool last = false, String? label}) {
    return AkAmountField(
      controller: c,
      label: label,
      enabled: !widget.readOnly,
      dense: !akIsTouch(context),
      textInputAction: TextInputAction.next,
      onChanged: (n) {
        set(n);
        if (n > 0) {
          clearOther();
          other.clear();
        }
        widget.onChanged();
      },
      onSubmitted: (_) => last && widget.onEnterOnLast != null ? widget.onEnterOnLast!() : _next(),
    );
  }
}

/// Pied de la grille : filet fort, totaux alignés sur les colonnes Débit / Crédit.
class EntryGridTotals extends StatelessWidget {
  const EntryGridTotals({super.key, required this.debit, required this.credit});

  final int debit;
  final int credit;

  @override
  Widget build(BuildContext context) {
    final t = context.ak;
    const cellPad = EdgeInsets.symmetric(horizontal: AkSpace.s2);
    return Container(
      decoration: BoxDecoration(
        color: t.surfaceSunken,
        border: Border(top: BorderSide(color: t.borderControl, width: 2)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AkSpace.s2, vertical: AkSpace.s2),
      child: Row(
        children: [
          const SizedBox(width: kEntryIndexWidth),
          Expanded(
            child: Padding(
              padding: cellPad,
              child: Text('Totaux', style: AkText.tableHead.copyWith(color: t.textStrong)),
            ),
          ),
          const SizedBox(width: AkSpace.s2),
          SizedBox(
            width: kEntryAmountWidth,
            child: Padding(padding: cellPad, child: AkAmountText(Fmt.fcfa(debit, showZero: true), bold: true)),
          ),
          const SizedBox(width: AkSpace.s2),
          SizedBox(
            width: kEntryAmountWidth + AkSpace.s2,
            child: Padding(padding: cellPad, child: AkAmountText(Fmt.fcfa(credit, showZero: true), bold: true)),
          ),
          const SizedBox(width: kEntryRemoveWidth),
        ],
      ),
    );
  }
}

/// Pied de l'écran étroit : totaux débit et crédit sous les cartes.
class EntryCardTotals extends StatelessWidget {
  const EntryCardTotals({super.key, required this.debit, required this.credit});

  final int debit;
  final int credit;

  @override
  Widget build(BuildContext context) {
    final t = context.ak;
    Widget total(String label, int v) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(label, style: AkText.tableHead.copyWith(color: t.textMuted)),
          AkAmountText(Fmt.fcfa(v, showZero: true), bold: true),
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.all(AkSpace.s3),
      decoration: BoxDecoration(
        color: t.surfaceSunken,
        border: Border(top: BorderSide(color: t.borderControl, width: 2)),
      ),
      child: Row(children: [total('Total débit', debit), const SizedBox(width: AkSpace.s3), total('Total crédit', credit)]),
    );
  }
}
