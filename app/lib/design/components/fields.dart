import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../src/core/formatting.dart';
import '../../src/domain/reference_models.dart';
import '../tokens.dart';
import 'layout.dart';

/// Cadre commun de tous les champs : libellé au-dessus, contrôle, puis aide ou erreur (même style partout).
class AkFieldFrame extends StatelessWidget {
  const AkFieldFrame({super.key, this.label, this.required = false, this.helper, this.error, required this.child});

  final String? label;
  final bool required;
  final String? helper;
  final String? error;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.ak;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AkSpace.s1),
            child: Text.rich(
              TextSpan(
                text: label,
                children: [
                  if (required)
                    TextSpan(
                      text: ' *',
                      style: TextStyle(color: t.danger),
                    ),
                ],
              ),
              style: AkText.label.copyWith(color: t.text),
            ),
          ),
        child,
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: AkSpace.s1),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_outline, size: 16, color: t.danger),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(error!, style: AkText.caption.copyWith(color: t.danger)),
                ),
              ],
            ),
          )
        else if (helper != null)
          Padding(
            padding: const EdgeInsets.only(top: AkSpace.s1),
            child: Text(helper!, style: AkText.caption.copyWith(color: t.textMuted)),
          ),
      ],
    );
  }
}

/// Décoration unique des champs : 40 px (48 px sur mobile, 32 px en mode [dense] dans une grille).
InputDecoration akInputDecoration(
  BuildContext context, {
  String? hint,
  Widget? prefixIcon,
  Widget? suffix,
  String? suffixText,
  bool dense = false,
  bool hasError = false,
}) {
  final h = dense && !akIsCompact(context) ? AkSpace.controlDense : akControlHeight(context);
  return InputDecoration(
    hintText: hint,
    isDense: true,
    prefixIcon: prefixIcon,
    suffixIcon: suffix,
    suffixText: suffixText,
    suffixStyle: AkText.caption.copyWith(color: context.ak.textMuted),
    errorText: null,
    constraints: BoxConstraints(minHeight: h),
    contentPadding: EdgeInsets.symmetric(horizontal: dense ? AkSpace.s2 : AkSpace.s3, vertical: (h - 20) / 2 - 1),
    enabledBorder: hasError
        ? OutlineInputBorder(
            borderRadius: AkRadius.mdAll,
            borderSide: BorderSide(color: context.ak.danger),
          )
        : null,
  );
}

/// Champ texte unique : libellé au-dessus, aide, erreur, mêmes marges et même hauteur partout.
class AkTextField extends StatelessWidget {
  const AkTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.helper,
    this.errorText,
    this.required = false,
    this.onChanged,
    this.onSubmitted,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.enabled = true,
    this.readOnly = false,
    this.autofocus = false,
    this.focusNode,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.inputFormatters,
    this.prefixIcon,
    this.suffix,
    this.suffixText,
    this.textAlign = TextAlign.start,
    this.mono = false,
    this.dense = false,
    this.validator,
    this.initialValue,
    this.autofillHints,
    this.onTap,
    this.textCapitalization = TextCapitalization.none,
    this.selectOnFocus = false,
  });

  /// Sélectionne tout le contenu à l'arrivée dans le champ (saisie au clavier dans une grille).
  final bool selectOnFocus;

  final TextCapitalization textCapitalization;
  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? helper;
  final String? errorText;
  final bool required;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final bool enabled;
  final bool readOnly;
  final bool autofocus;
  final FocusNode? focusNode;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final Widget? prefixIcon;
  final Widget? suffix;
  final String? suffixText;
  final TextAlign textAlign;

  /// Police à chasse fixe (codes, références).
  final bool mono;

  /// Variante de 32 px sans libellé, pour une cellule de grille.
  final bool dense;
  final FormFieldValidator<String>? validator;
  final String? initialValue;
  final Iterable<String>? autofillHints;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final field = TextFormField(
      textCapitalization: textCapitalization,
      controller: controller,
      initialValue: controller == null ? initialValue : null,
      focusNode: focusNode,
      enabled: enabled,
      readOnly: readOnly,
      autofocus: autofocus,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      maxLines: obscureText ? 1 : maxLines,
      minLines: minLines,
      maxLength: maxLength,
      inputFormatters: inputFormatters,
      textAlign: textAlign,
      style: (mono ? AkText.code : AkText.body).copyWith(color: enabled ? context.ak.text : context.ak.textDisabled),
      autofillHints: autofillHints,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      onTap: onTap,
      validator: validator,
      autovalidateMode: validator == null ? null : AutovalidateMode.disabled,
      decoration: akInputDecoration(
        context,
        hint: hint,
        prefixIcon: prefixIcon,
        suffix: suffix,
        suffixText: suffixText,
        dense: dense,
        hasError: errorText != null,
      ).copyWith(counterText: ''),
    );
    final focusAware = !selectOnFocus || controller == null
        ? field
        : Focus(
            canRequestFocus: false,
            skipTraversal: true,
            onFocusChange: (has) {
              if (has) controller!.selection = TextSelection(baseOffset: 0, extentOffset: controller!.text.length);
            },
            child: field,
          );
    if (dense && label == null && errorText == null && helper == null) return focusAware;
    return AkFieldFrame(label: label, required: required, helper: helper, error: errorText, child: focusAware);
  }
}

/// Mise en forme d'un montant FCFA entier pendant la frappe : chiffres seuls, milliers séparés.
class AkAmountFormatter extends TextInputFormatter {
  const AkAmountFormatter();

  static final _group = NumberFormat('#,##0', 'fr_FR');

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return const TextEditingValue();
    final text = _group.format(int.parse(digits));
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// Champ montant : FCFA entier, séparateur de milliers, aligné à droite, Plex Mono à chiffres tabulaires.
/// [onChanged] reçoit le montant (0 si vide).
class AkAmountField extends StatelessWidget {
  const AkAmountField({
    super.key,
    this.controller,
    this.label,
    this.helper,
    this.errorText,
    this.required = false,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.readOnly = false,
    this.dense = false,
    this.autofocus = false,
    this.focusNode,
    this.textInputAction,
    this.showCurrency = true,
    this.hint,
  });

  final TextEditingController? controller;
  final String? label;
  final String? helper;
  final String? errorText;
  final bool required;
  final ValueChanged<int>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final bool readOnly;
  final bool dense;
  final bool autofocus;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final bool showCurrency;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return AkTextField(
      controller: controller,
      label: label,
      helper: helper,
      errorText: errorText,
      required: required,
      enabled: enabled,
      readOnly: readOnly,
      dense: dense,
      autofocus: autofocus,
      focusNode: focusNode,
      hint: hint,
      textInputAction: textInputAction,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.right,
      inputFormatters: const [AkAmountFormatter()],
      suffixText: showCurrency && !dense ? 'FCFA' : null,
      onChanged: onChanged == null ? null : (v) => onChanged!(Fmt.parseAmount(v) ?? 0),
      onSubmitted: onSubmitted,
      mono: true,
      selectOnFocus: dense,
    );
  }
}

/// Champ date jj/mm/aaaa avec calendrier. [onChanged] reçoit la date saisie ou null si elle est invalide.
class AkDateField extends StatefulWidget {
  const AkDateField({
    super.key,
    required this.controller,
    this.label,
    this.helper,
    this.errorText,
    this.required = false,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.dense = false,
    this.firstDate,
    this.lastDate,
  });

  final TextEditingController controller;
  final String? label;
  final String? helper;
  final String? errorText;
  final bool required;
  final ValueChanged<DateTime?>? onChanged;

  /// Appelé à la validation clavier (Entrée) avec le texte saisi.
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final bool dense;
  final DateTime? firstDate;
  final DateTime? lastDate;

  @override
  State<AkDateField> createState() => _AkDateFieldState();
}

class _AkDateFieldState extends State<AkDateField> {
  final _focus = FocusNode();
  String? _error;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _validate();
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _validate() {
    final text = widget.controller.text.trim();
    setState(() => _error = text.isNotEmpty && Fmt.parseDate(text) == null ? 'Date invalide (jj/mm/aaaa)' : null);
  }

  Future<void> _pick() async {
    final current = Fmt.parseDate(widget.controller.text) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: widget.firstDate ?? DateTime(2000),
      lastDate: widget.lastDate ?? DateTime(2100),
    );
    if (picked == null) return;
    widget.controller.text = Fmt.date(picked);
    setState(() => _error = null);
    widget.onChanged?.call(picked);
  }

  @override
  Widget build(BuildContext context) {
    return AkTextField(
      controller: widget.controller,
      focusNode: _focus,
      label: widget.label,
      helper: widget.helper,
      errorText: widget.errorText ?? _error,
      required: widget.required,
      enabled: widget.enabled,
      dense: widget.dense,
      hint: 'jj/mm/aaaa',
      onSubmitted: widget.onSubmitted,
      keyboardType: TextInputType.datetime,
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9/]')), LengthLimitingTextInputFormatter(10)],
      suffix: widget.dense
          ? null
          : IconButton(
              tooltip: 'Choisir dans le calendrier',
              icon: const Icon(Icons.calendar_today_outlined, size: 18),
              onPressed: widget.enabled ? _pick : null,
            ),
      onChanged: (v) {
        if (_error != null) setState(() => _error = null);
        widget.onChanged?.call(Fmt.parseDate(v));
      },
    );
  }
}

/// Option d'une liste déroulante.
class AkOption<T> {
  const AkOption(this.value, this.label, {this.child});

  final T value;
  final String label;

  /// Contenu personnalisé de l'option ; [label] sert alors au champ fermé.
  final Widget? child;
}

/// Liste déroulante unique (libellé au-dessus, mêmes hauteur et erreur que les champs texte).
class AkDropdown<T> extends StatelessWidget {
  const AkDropdown({
    super.key,
    required this.items,
    required this.onChanged,
    this.value,
    this.label,
    this.hint,
    this.helper,
    this.errorText,
    this.required = false,
    this.dense = false,
    this.isExpanded = true,
  });

  final List<AkOption<T>> items;
  final ValueChanged<T?>? onChanged;
  final T? value;
  final String? label;
  final String? hint;
  final String? helper;
  final String? errorText;
  final bool required;
  final bool dense;
  final bool isExpanded;

  @override
  Widget build(BuildContext context) {
    final t = context.ak;
    final selected = items.any((o) => o.value == value) ? value : null;
    final field = DropdownButtonFormField<T>(
      initialValue: selected,
      isExpanded: isExpanded,
      isDense: true,
      icon: Icon(Icons.expand_more, size: 20, color: t.textMuted),
      dropdownColor: t.surface,
      borderRadius: AkRadius.mdAll,
      style: AkText.body.copyWith(color: t.text),
      hint: hint == null ? null : Text(hint!, style: AkText.body.copyWith(color: t.textDisabled)),
      decoration: akInputDecoration(context, dense: dense, hasError: errorText != null),
      items: [
        for (final o in items)
          DropdownMenuItem<T>(
            value: o.value,
            child: o.child ?? Text(o.label, overflow: TextOverflow.ellipsis),
          ),
      ],
      selectedItemBuilder: (_) => [
        for (final o in items)
          Align(
            alignment: Alignment.centerLeft,
            child: Text(o.label, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: onChanged,
    );
    if (dense && label == null && errorText == null && helper == null) return field;
    return AkFieldFrame(label: label, required: required, helper: helper, error: errorText, child: field);
  }
}

/// Champ à autocomplétion générique : saisie libre, liste filtrée, sélection au clavier (↑ ↓ Entrée).
class AkAutocompleteField<T extends Object> extends StatelessWidget {
  const AkAutocompleteField({
    super.key,
    required this.options,
    required this.display,
    required this.onSelected,
    this.initialText = '',
    this.label,
    this.hint,
    this.helper,
    this.errorText,
    this.required = false,
    this.enabled = true,
    this.dense = false,
    this.mono = false,
    this.onChanged,
    this.optionLabel,
    this.optionsWidth,
    this.resolved = false,
    this.pickOnBlur = false,
    this.onSubmittedPick,
    this.unresolvedError,
  });

  /// Message affiché quand le champ a perdu le focus avec une saisie non résolue.
  final String? unresolvedError;

  /// Une valeur est déjà retenue (pas de choix automatique à la sortie du champ).
  final bool resolved;

  /// Clavier : en quittant le champ (Tab) sans valeur retenue, la première proposition est choisie.
  final bool pickOnBlur;

  /// Appelé après un Entrée qui a choisi une proposition (ex. passer au champ suivant).
  final VoidCallback? onSubmittedPick;

  /// Options correspondant à la saisie.
  final Iterable<T> Function(String query) options;
  final String Function(T) display;
  final ValueChanged<T> onSelected;
  final String initialText;
  final String? label;
  final String? hint;
  final String? helper;
  final String? errorText;
  final bool required;
  final bool enabled;
  final bool dense;
  final bool mono;
  final ValueChanged<String>? onChanged;

  /// Libellé d'une ligne de la liste (par défaut [display]).
  final String Function(T)? optionLabel;
  final double? optionsWidth;

  @override
  Widget build(BuildContext context) {
    final t = context.ak;
    return LayoutBuilder(
      builder: (context, c) {
        final width = optionsWidth ?? (c.maxWidth.isFinite ? c.maxWidth.clamp(280.0, 520.0) : 360.0);
        return RawAutocomplete<T>(
          initialValue: TextEditingValue(text: initialText),
          displayStringForOption: display,
          optionsBuilder: (v) => options(v.text),
          onSelected: onSelected,
          fieldViewBuilder: (context, controller, focus, onSubmit) => Focus(
            canRequestFocus: false,
            skipTraversal: true,
            onFocusChange: (has) {
              if (has || !pickOnBlur || resolved || controller.text.trim().isEmpty) return;
              final first = options(controller.text).firstOrNull;
              if (first == null) return;
              controller.text = display(first);
              onSelected(first);
            },
            child: ListenableBuilder(
              listenable: Listenable.merge([controller, focus]),
              builder: (context, _) => AkTextField(
                controller: controller,
                focusNode: focus,
                label: label,
                hint: hint,
                helper: helper,
                errorText: errorText ?? (unresolvedError != null && !resolved && !focus.hasFocus && controller.text.trim().isNotEmpty ? unresolvedError : null),
                required: required,
                enabled: enabled,
                dense: dense,
                mono: mono,
                textInputAction: TextInputAction.next,
                onChanged: onChanged,
                onSubmitted: (_) {
                  final has = options(controller.text).isNotEmpty;
                  onSubmit();
                  if (has) onSubmittedPick?.call();
                },
              ),
            ),
          ),
          optionsViewBuilder: (context, onSelect, opts) => Align(
            alignment: Alignment.topLeft,
            child: Material(
              color: t.surface,
              elevation: 4,
              shadowColor: t.shadowOverlay,
              shape: RoundedRectangleBorder(
                borderRadius: AkRadius.mdAll,
                side: BorderSide(color: t.border),
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: 280, maxWidth: width),
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: opts.length,
                  itemBuilder: (context, i) {
                    final o = opts.elementAt(i);
                    final highlighted = AutocompleteHighlightedOption.of(context) == i;
                    return InkWell(
                      onTap: () => onSelect(o),
                      child: Container(
                        color: highlighted ? t.brandTint : null,
                        padding: const EdgeInsets.symmetric(horizontal: AkSpace.s3, vertical: AkSpace.s2),
                        child: Text(
                          (optionLabel ?? display)(o),
                          overflow: TextOverflow.ellipsis,
                          style: (mono ? AkText.code : AkText.body).copyWith(color: t.text),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Champ compte : autocomplétion par numéro ou intitulé ; un numéro complet tapé sélectionne directement le compte.
class AkAccountField extends StatelessWidget {
  const AkAccountField({
    super.key,
    required this.accounts,
    required this.onSelected,
    this.onCleared,
    this.selected,
    this.label,
    this.hint = 'Numéro ou intitulé',
    this.helper,
    this.required = false,
    this.enabled = true,
    this.dense = false,
    this.invalid = false,
    this.resolved,
    this.onSubmittedPick,
  });

  /// Un compte est retenu (par défaut : [selected] non nul).
  final bool? resolved;
  final VoidCallback? onSubmittedPick;

  final List<Account> accounts;

  /// Appelé quand un compte est choisi (liste ou numéro tapé).
  final ValueChanged<Account> onSelected;

  /// Appelé quand la saisie ne correspond plus à un compte précédemment choisi.
  final VoidCallback? onCleared;

  /// Compte actuellement retenu (affiché au premier rendu).
  final Account? selected;
  final String? label;
  final String? hint;
  final String? helper;
  final bool required;
  final bool enabled;
  final bool dense;

  /// Saisie non vide sans compte retenu : affiche « Choisir dans la liste ».
  final bool invalid;

  @override
  Widget build(BuildContext context) {
    return AkAutocompleteField<Account>(
      initialText: selected == null ? '' : '${selected!.code} ${selected!.label}',
      label: label,
      hint: hint,
      helper: helper,
      required: required,
      enabled: enabled,
      dense: dense,
      mono: true,
      pickOnBlur: true,
      resolved: resolved ?? selected != null,
      onSubmittedPick: onSubmittedPick,
      errorText: invalid ? 'Choisir dans la liste' : null,
      unresolvedError: 'Choisir dans la liste',
      display: (a) => '${a.code} ${a.label}',
      options: (q) {
        final s = q.trim().toLowerCase();
        if (s.isEmpty) return const Iterable<Account>.empty();
        return accounts.where((a) => a.code.startsWith(s) || a.label.toLowerCase().contains(s)).take(12);
      },
      onSelected: onSelected,
      onChanged: (v) {
        final typed = matchAccountCode(accounts, v);
        if (typed != null) {
          onSelected(typed);
        } else {
          onCleared?.call();
        }
      },
    );
  }
}

/// Champ tiers : autocomplétion par code ou nom.
class AkThirdPartyField extends StatelessWidget {
  const AkThirdPartyField({
    super.key,
    required this.thirdParties,
    required this.onSelected,
    this.initialCode = '',
    this.label,
    this.hint = 'Code tiers',
    this.enabled = true,
    this.dense = false,
    this.resolved = false,
    this.onSubmittedPick,
  });

  final bool resolved;
  final VoidCallback? onSubmittedPick;
  final List<ThirdParty> thirdParties;
  final ValueChanged<ThirdParty> onSelected;
  final String initialCode;
  final String? label;
  final String? hint;
  final bool enabled;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return AkAutocompleteField<ThirdParty>(
      initialText: initialCode,
      label: label,
      hint: hint,
      enabled: enabled,
      dense: dense,
      mono: true,
      pickOnBlur: true,
      resolved: resolved,
      onSubmittedPick: onSubmittedPick,
      display: (t) => t.code,
      optionLabel: (t) => '${t.code} · ${t.name}',
      options: (q) {
        final s = q.trim().toUpperCase();
        return thirdParties.where((t) => s.isEmpty || t.code.contains(s) || t.name.toUpperCase().contains(s)).take(12);
      },
      onSelected: onSelected,
    );
  }
}

/// Case à cocher avec libellé cliquable.
class AkCheckbox extends StatelessWidget {
  const AkCheckbox({super.key, required this.value, required this.onChanged, this.label, this.child, this.dense = false});

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? label;

  /// Libellé riche (prend le pas sur [label]).
  final Widget? child;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final t = context.ak;
    final text = child ?? (label == null ? null : Text(label!, style: AkText.body.copyWith(color: onChanged == null ? t.textDisabled : t.text)));
    return InkWell(
      borderRadius: AkRadius.mdAll,
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: dense ? AkSpace.controlDense : akControlHeight(context)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Checkbox(
              value: value,
              onChanged: onChanged == null ? null : (v) => onChanged!(v ?? false),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            if (text != null)
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.only(right: AkSpace.s2),
                  child: text,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Interrupteur avec libellé.
class AkSwitch extends StatelessWidget {
  const AkSwitch({super.key, required this.value, required this.onChanged, this.label});

  final bool value;
  final ValueChanged<bool>? onChanged;

  /// Libellé facultatif : sans libellé, l'interrupteur seul s'affiche (ligne de liste).
  final String? label;

  @override
  Widget build(BuildContext context) {
    final t = context.ak;
    return InkWell(
      borderRadius: AkRadius.mdAll,
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: akControlHeight(context)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(value: value, onChanged: onChanged),
            if (label != null) ...[
              const SizedBox(width: AkSpace.s2),
              Flexible(
                child: Text(label!, style: AkText.body.copyWith(color: t.text)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Choix exclusif entre quelques valeurs (onglets de filtre, sens débit/crédit).
class AkSegmented<T> extends StatelessWidget {
  const AkSegmented({super.key, required this.options, required this.selected, required this.onChanged, this.dense = false});

  final List<AkOption<T>> options;
  final T selected;
  final ValueChanged<T> onChanged;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final h = dense ? AkSpace.controlDense : akControlHeight(context);
    return SegmentedButton<T>(
      showSelectedIcon: false,
      style: ButtonStyle(minimumSize: WidgetStatePropertyAll(Size(0, h)), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
      segments: [for (final o in options) ButtonSegment<T>(value: o.value, label: Text(o.label))],
      selected: {selected},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}
