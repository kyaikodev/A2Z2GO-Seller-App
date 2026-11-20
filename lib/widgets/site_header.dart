import 'package:flutter/material.dart';

import '../core/theme.dart';

/// The top of the A2Z2GO website on a phone: the red tag logo, then a search
/// bar with a yellow "Search" button.
class SiteHeader extends StatefulWidget {
  final ValueChanged<String> onSearch;
  const SiteHeader({super.key, required this.onSearch});

  @override
  State<SiteHeader> createState() => _SiteHeaderState();
}

class _SiteHeaderState extends State<SiteHeader> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _submit() => widget.onSearch(_text.text.trim());

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.paddingOf(context).top + 10,
        16,
        12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.asset(
            'assets/brand/a2z_tag.png',
            height: 34,
            semanticLabel: 'A2Z2GO',
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _text,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _submit(),
                  decoration: const InputDecoration(
                    hintText: "I'm looking for...",
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: Brand.accent,
                  foregroundColor: Brand.navy,
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                child: const Text('Search'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
