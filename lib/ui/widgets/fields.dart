import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/formatting.dart';
import '../../core/tokens.dart';

/// `.field` — a label, a control, and room for the per-field error the server
/// sends back in `fields` on a 400.
class Field extends StatelessWidget {
  const Field({super.key, this.label, required this.child, this.error, this.hint});

  final String? label;
  final Widget child;
  final String? error;
  final String? hint;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (label != null) ...[
            Text(
              label!,
              style: TextStyle(fontFamily: T.fontFamily, fontSize: 12, color: T.ink(0.7)),
            ),
            const SizedBox(height: 6),
          ],
          child,
          if (hint != null) ...[
            const SizedBox(height: 4),
            Text(hint!, style: T.body.copyWith(fontSize: 12, color: T.ink(0.55))),
          ],
          if (error != null) ...[
            const SizedBox(height: 4),
            Text(
              error!,
              style: TextStyle(fontFamily: T.fontFamily, fontSize: 12, color: T.accent700),
            ),
          ],
        ],
      );
}

/// `.input` — the one text control the whole app uses.
class BunyadInput extends StatelessWidget {
  const BunyadInput({
    super.key,
    required this.controller,
    this.focusNode,
    this.hintText,
    this.keyboardType,
    this.obscureText = false,
    this.maxLength,
    this.maxLines = 1,
    this.enabled = true,
    this.autofocus = false,
    this.invalid = false,
    this.textInputAction,
    this.onSubmitted,
    this.onChanged,
    this.autofillHints,
    this.textCapitalization = TextCapitalization.sentences,
    this.inputFormatters,
    this.suffix,
  });

  /// A decimal the user types by hand — "1,250" and "84" both work.
  factory BunyadInput.decimal({
    Key? key,
    required TextEditingController controller,
    String? hintText,
    bool invalid = false,
    TextInputAction? textInputAction,
    ValueChanged<String>? onSubmitted,
  }) =>
      BunyadInput(
        key: key,
        controller: controller,
        hintText: hintText,
        invalid: invalid,
        textInputAction: textInputAction,
        onSubmitted: onSubmitted,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textCapitalization: TextCapitalization.none,
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\s]'))],
      );

  final TextEditingController controller;
  final FocusNode? focusNode;
  final String? hintText;
  final TextInputType? keyboardType;
  final bool obscureText;
  final int? maxLength;
  final int maxLines;
  final bool enabled;
  final bool autofocus;

  /// Paints the accent ring the web app's `.input.invalid` shows.
  final bool invalid;

  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final Iterable<String>? autofillHints;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        focusNode: focusNode,
        enabled: enabled,
        autofocus: autofocus,
        obscureText: obscureText,
        keyboardType: keyboardType,
        maxLength: maxLength,
        maxLines: obscureText ? 1 : maxLines,
        minLines: 1,
        textInputAction: textInputAction,
        onSubmitted: onSubmitted,
        onChanged: onChanged,
        autofillHints: autofillHints,
        textCapitalization: textCapitalization,
        inputFormatters: inputFormatters,
        style: T.body.copyWith(fontSize: 14, color: enabled ? T.text : T.ink(0.5)),
        decoration: InputDecoration(
          hintText: hintText,
          counterText: '',
          suffixIcon: suffix,
          filled: true,
          fillColor: enabled ? T.raised : T.surface,
          enabledBorder: OutlineInputBorder(
            borderRadius: T.brMd,
            borderSide: BorderSide(color: invalid ? T.accent : T.hairlineStrong),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: T.brMd,
            borderSide: const BorderSide(color: T.accent, width: 1.6),
          ),
        ),
      );
}

/// A `<select>`: one of a short list, drawn as the same recessed box.
class BunyadSelect<T2> extends StatelessWidget {
  const BunyadSelect({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.itemLabel,
  });

  final T2 value;
  final List<({T2 value, String label})> items;
  final ValueChanged<T2?> onChanged;
  final String Function(T2)? itemLabel;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: T.raised,
          borderRadius: T.brMd,
          border: Border.all(color: T.hairlineStrong),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T2>(
            value: value,
            isExpanded: true,
            isDense: false,
            borderRadius: T.brMd,
            style: T.body.copyWith(fontSize: 14),
            icon: const Icon(Icons.expand_more_rounded, size: 20, color: T.neutral600),
            dropdownColor: T.raised,
            onChanged: onChanged,
            items: [
              for (final item in items)
                DropdownMenuItem<T2>(
                  value: item.value,
                  child: Text(
                    item.label,
                    overflow: TextOverflow.ellipsis,
                    style: T.body.copyWith(fontSize: 14),
                  ),
                ),
            ],
          ),
        ),
      );
}

/// `.seg` — the two-option segmented control the weight unit uses.
class SegmentedPair<T2> extends StatelessWidget {
  const SegmentedPair({
    super.key,
    required this.value,
    required this.first,
    required this.second,
    required this.onChanged,
  });

  final T2 value;
  final ({T2 value, String label}) first;
  final ({T2 value, String label}) second;
  final ValueChanged<T2> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: T.raised,
          borderRadius: T.brMd,
          border: Border.all(color: T.hairlineStrong),
          boxShadow: T.shadowXs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _option(first, isFirst: true),
            Container(width: 1, height: 38, color: T.hairlineStrong),
            _option(second, isFirst: false),
          ],
        ),
      );

  Widget _option(({T2 value, String label}) option, {required bool isFirst}) {
    final selected = option.value == value;
    return Material(
      color: selected ? T.accent : Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(option.value),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text(
            option.label,
            style: T.body.copyWith(
              fontSize: 13,
              color: selected ? T.bg : T.text,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

/// A date box that opens the platform picker. Empty means "not set", which the
/// stage form uses to clear a date.
class DateField extends StatelessWidget {
  const DateField({
    super.key,
    required this.value,
    required this.onChanged,
    this.hintText = 'Not set',
    this.firstDate,
    this.lastDate,
    this.clearable = true,
  });

  /// ISO yyyy-MM-dd, or null.
  final String? value;
  final ValueChanged<String?> onChanged;
  final String hintText;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final bool clearable;

  @override
  Widget build(BuildContext context) {
    final parsed = parseDate(value);
    final shown = longDate(value);

    return InkWell(
      borderRadius: T.brMd,
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: parsed ?? now,
          firstDate: firstDate ?? DateTime(2000),
          lastDate: lastDate ?? DateTime(now.year + 5, 12, 31),
        );
        if (picked != null) onChanged(isoDate(picked));
      },
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: T.raised,
          borderRadius: T.brMd,
          border: Border.all(color: T.hairlineStrong),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                shown ?? hintText,
                overflow: TextOverflow.ellipsis,
                style: T.body.copyWith(
                  fontSize: 14,
                  color: shown == null ? T.ink(0.38) : T.text,
                ),
              ),
            ),
            if (shown != null && clearable)
              InkResponse(
                onTap: () => onChanged(null),
                radius: 16,
                child: const Icon(Icons.close_rounded, size: 16, color: T.neutral600),
              )
            else
              const Icon(Icons.calendar_today_rounded, size: 15, color: T.neutral600),
          ],
        ),
      ),
    );
  }
}
