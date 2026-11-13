import 'package:flutter/material.dart';

import '../core/theme.dart';

/// A field label with a red star, for required fields.
Widget reqLabel(String text) => Text.rich(
  TextSpan(
    text: text,
    children: const [
      TextSpan(
        text: ' *',
        style: TextStyle(color: Brand.bad, fontWeight: FontWeight.w800),
      ),
    ],
  ),
);

/// The label for a field that may stay empty.
Widget optLabel(String text) => Text('$text (optional)');

/// Scrolls the screen to the first field (in the order given) that shows an
/// error, so a missing required field is never off-screen. Call it after
/// `validate()` returned false. Returns true if it found one.
bool scrollToFirstError(List<GlobalKey<FormFieldState<dynamic>>> keys) {
  for (final k in keys) {
    final state = k.currentState;
    final ctx = k.currentContext;
    if (state != null && state.hasError && ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.15,
        duration: Motion.normal,
        curve: Motion.curve,
      );
      return true;
    }
  }
  return false;
}

/// A field that shows what already exists in the app (categories, brands,
/// customers...) in a list to pick from, with a search box and "Add new" for
/// something that is not there yet. It looks like a drop-down and behaves the
/// same everywhere.
class PickOrAddField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool required;
  final List<String> options;

  /// What is being picked, in lower case ("category"), for the messages.
  final String noun;
  final GlobalKey<FormFieldState<String>>? fieldKey;
  final IconData? icon;
  final void Function(String value)? onPicked;

  const PickOrAddField({
    super.key,
    required this.controller,
    required this.label,
    required this.options,
    required this.noun,
    this.required = false,
    this.fieldKey,
    this.icon,
    this.onPicked,
  });

  Future<void> _open(BuildContext context) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _PickSheet(
        title: 'Choose a $noun',
        noun: noun,
        options: options,
        current: controller.text.trim(),
        canClear: !required,
      ),
    );
    if (picked == null) return;
    // didChange tells the form something changed (and clears the error).
    final state = fieldKey?.currentState;
    if (state != null) {
      state.didChange(picked);
    } else {
      controller.text = picked;
    }
    onPicked?.call(picked);
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: fieldKey,
      controller: controller,
      readOnly: true,
      showCursor: false,
      onTap: () => _open(context),
      validator: (v) => required && (v == null || v.trim().isEmpty)
          ? 'Pick a $noun, or add a new one.'
          : null,
      decoration: InputDecoration(
        label: required ? reqLabel(label) : optLabel(label),
        hintText: 'Tap to choose',
        prefixIcon: icon == null ? null : Icon(icon),
        suffixIcon: const Icon(Icons.arrow_drop_down),
      ),
    );
  }
}

class _PickSheet extends StatefulWidget {
  final String title;
  final String noun;
  final List<String> options;
  final String current;
  final bool canClear;
  const _PickSheet({
    required this.title,
    required this.noun,
    required this.options,
    required this.current,
    required this.canClear,
  });

  @override
  State<_PickSheet> createState() => _PickSheetState();
}

class _PickSheetState extends State<_PickSheet> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String get _query => _search.text.trim().replaceAll(RegExp(r'\s+'), ' ');

  @override
  Widget build(BuildContext context) {
    final q = _query.toLowerCase();
    final shown = [
      for (final o in widget.options)
        if (q.isEmpty || o.toLowerCase().contains(q)) o,
    ];
    final exact = widget.options.any((o) => o.toLowerCase() == q);
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (widget.canClear && widget.current.isNotEmpty)
                    TextButton(
                      onPressed: () => Navigator.pop(context, ''),
                      child: const Text('Clear'),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: TextField(
                controller: _search,
                autofocus: widget.options.isEmpty,
                textCapitalization: TextCapitalization.words,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: widget.options.isEmpty
                      ? 'Type the first ${widget.noun}'
                      : 'Search or type a new ${widget.noun}',
                  prefixIcon: const Icon(Icons.search),
                ),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 12),
                children: [
                  if (q.isNotEmpty && !exact)
                    ListTile(
                      leading: const Icon(
                        Icons.add_circle_outline,
                        color: Brand.primary,
                      ),
                      title: Text('Add "$_query"'),
                      onTap: () => Navigator.pop(context, _query),
                    ),
                  for (final o in shown)
                    ListTile(
                      title: Text(o),
                      trailing: o.toLowerCase() == widget.current.toLowerCase()
                          ? const Icon(Icons.check, color: Brand.primary)
                          : null,
                      onTap: () => Navigator.pop(context, o),
                    ),
                  if (shown.isEmpty && q.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        'Nothing here yet. Type a ${widget.noun} above to add the first one.',
                        style: const TextStyle(color: Brand.muted),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
